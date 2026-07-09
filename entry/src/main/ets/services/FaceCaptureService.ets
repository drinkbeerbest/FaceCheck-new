import { common } from '@kit.AbilityKit';
import image from '@ohos.multimedia.image';
import camera from '@ohos.multimedia.camera';

const CAPTURE_TIMEOUT_MS = 20000;
const SURFACE_SETTLE_MS = 300;

export interface CapturedFaceImage {
  buffer: ArrayBuffer;
  pixelMap: image.PixelMap;
}

export class FaceCaptureService {
  private static cameraInput?: camera.CameraInput;
  private static previewOutput?: camera.PreviewOutput;
  private static session?: camera.PhotoSession;
  private static activeSurfaceId: string = '';

  static async startPreview(context: common.UIAbilityContext, surfaceId: string): Promise<boolean> {
    if (surfaceId.length === 0) {
      return false;
    }
    if (FaceCaptureService.session && FaceCaptureService.activeSurfaceId === surfaceId) {
      return true;
    }
    await FaceCaptureService.releasePreview();
    try {
      const manager = camera.getCameraManager(context);
      const device = FaceCaptureService.frontCamera(manager);
      if (!device) {
        return false;
      }
      const capability = manager.getSupportedOutputCapability(device, camera.SceneMode.NORMAL_PHOTO);
      const previewProfile = FaceCaptureService.bestPreviewProfile(capability.previewProfiles);
      if (!previewProfile) {
        return false;
      }
      FaceCaptureService.cameraInput = manager.createCameraInput(device);
      await FaceCaptureService.cameraInput.open();
      FaceCaptureService.previewOutput = manager.createPreviewOutput(previewProfile, surfaceId);
      FaceCaptureService.session = manager.createSession<camera.PhotoSession>(camera.SceneMode.NORMAL_PHOTO);
      FaceCaptureService.session.beginConfig();
      FaceCaptureService.session.addInput(FaceCaptureService.cameraInput);
      FaceCaptureService.session.addOutput(FaceCaptureService.previewOutput);
      await FaceCaptureService.session.commitConfig();
      await FaceCaptureService.session.start();
      FaceCaptureService.activeSurfaceId = surfaceId;
      return true;
    } catch (err) {
      await FaceCaptureService.releasePreview();
      return false;
    }
  }

  static async captureFace(context: common.UIAbilityContext, surfaceId?: string): Promise<CapturedFaceImage | undefined> {
    if (surfaceId === undefined || surfaceId.length === 0) {
      return undefined;
    }
    // 调用方（finishEnroll / finishRecognition）在调用前已通过 startFacePreview
    // 确保 session 处于运行状态。此处不再重复 startPreview，避免：
    // 1) releasePreview → 重新 open camera → create session → commit → start 的冗余开销
    // 2) 反复创建/销毁 session 与 PreviewOutput 写帧之间的 native 层资源竞争导致主线程卡死
    // 防御：若 session 意外未就绪则尝试初始化
    if (!FaceCaptureService.session) {
      const ready = await FaceCaptureService.startPreview(context, surfaceId);
      if (!ready) {
        return undefined;
      }
    }
    // 停止预览输出，释放 surface 写权限，避免 createPixelMapFromSurface
    // 与 PreviewOutput 写入帧时产生缓冲区竞争
    try {
      await FaceCaptureService.session!.stop();
    } catch (err) {
      console.error('FaceCaptureService', `停止预览失败，放弃截图: ${JSON.stringify(err)}`);
      return undefined;
    }
    // 等待最后一帧完全落定到 surface 缓冲区（摄像头硬件到 surface 的延迟）
    await FaceCaptureService.delay(SURFACE_SETTLE_MS);

    try {
      return await Promise.race([
        FaceCaptureService.captureFromPreviewSurface(surfaceId),
        FaceCaptureService.timeout()
      ]);
    } finally {
      // 恢复预览：失败后用户可以重试
      if (FaceCaptureService.session) {
        try {
          await FaceCaptureService.session!.start();
        } catch (err) {
          await FaceCaptureService.releasePreview();
        }
      }
    }
  }

  static async releasePreview(): Promise<void> {
    await FaceCaptureService.safeRelease(FaceCaptureService.session, FaceCaptureService.cameraInput);
    FaceCaptureService.session = undefined;
    FaceCaptureService.cameraInput = undefined;
    FaceCaptureService.previewOutput = undefined;
    FaceCaptureService.activeSurfaceId = '';
  }

  private static async captureFromPreviewSurface(surfaceId: string): Promise<CapturedFaceImage | undefined> {
    if (surfaceId.length === 0) {
      return undefined;
    }
    try {
      const pixelMap = await image.createPixelMapFromSurface(surfaceId);
      const buffer = await FaceCaptureService.packPixelMap(pixelMap);
      return {
        buffer,
        pixelMap
      };
    } catch (err) {
      return undefined;
    }
  }

  private static frontCamera(manager: camera.CameraManager): camera.CameraDevice | undefined {
    const devices = manager.getSupportedCameras();
    for (let index = 0; index < devices.length; index++) {
      if (devices[index].cameraPosition === camera.CameraPosition.CAMERA_POSITION_FRONT) {
        return devices[index];
      }
    }
    return devices.length > 0 ? devices[0] : undefined;
  }

  private static bestPreviewProfile(profiles: Array<camera.Profile>): camera.Profile | undefined {
    if (profiles.length === 0) {
      return undefined;
    }
    let selected = profiles[0];
    let selectedScore = selected.size.width * selected.size.height;
    for (let index = 1; index < profiles.length; index++) {
      const score = profiles[index].size.width * profiles[index].size.height;
      if (score > selectedScore && score <= 1280 * 720) {
        selected = profiles[index];
        selectedScore = score;
      }
    }
    return selected;
  }

  private static async safeRelease(session?: camera.PhotoSession, input?: camera.CameraInput): Promise<void> {
    if (session) {
      try {
        await session.stop();
      } catch (err) {
      }
      try {
        await session.release();
      } catch (err) {
      }
    }
    if (input) {
      try {
        await input.close();
      } catch (err) {
      }
    }
  }

  private static timeout(): Promise<undefined> {
    return new Promise((resolve) => {
      setTimeout(() => {
        resolve(undefined);
      }, CAPTURE_TIMEOUT_MS);
    });
  }

  private static delay(ms: number): Promise<void> {
    return new Promise<void>(resolve => setTimeout(resolve, ms));
  }

  private static async packPixelMap(pixelMap: image.PixelMap): Promise<ArrayBuffer> {
    const imagePacker = image.createImagePacker();
    try {
      return await imagePacker.packToData(pixelMap, {
        format: 'image/jpeg',
        quality: 92
      });
    } finally {
      try {
        imagePacker.release();
      } catch (err) {
      }
    }
  }

  static async pixelMapFromUri(uri: string): Promise<image.PixelMap> {
    const source = image.createImageSource(uri);
    return await source.createPixelMap({
      desiredSize: {
        width: 720,
        height: 720
      }
    });
  }

  static async pixelMapFromBuffer(buffer: ArrayBuffer): Promise<image.PixelMap> {
    const source = image.createImageSource(buffer);
    return await source.createPixelMap({
      desiredSize: {
        width: 720,
        height: 720
      }
    });
  }
}
