import { BusinessError } from '@kit.BasicServicesKit';
import image from '@ohos.multimedia.image';
import faceComparator from '@hms.ai.face.faceComparator';
import interactiveLiveness from '@hms.ai.interactiveLiveness';
import { FaceDemoService } from './FaceDemoService';
import { FaceProfile, FaceRunMode, FaceServiceResult, VerificationMethod } from '../models/FaceCheckModels';

const FACE_SIMILARITY_THRESHOLD = 0.60;
const LIVENESS_TIMEOUT_MS = 90000;
const FACE_COMPARE_TIMEOUT_MS = 30000;
const INTERACTIVE_LIVENESS = 0;
const SILENT_LIVENESS = 1;
const NOT_LIVENESS = 2;

export interface FaceAdapter {
  enroll(studentId: string, referencePath?: string, templateDigest?: string): Promise<FaceServiceResult>;
  runLiveness(): Promise<FaceServiceResult>;
  compare(studentId: string, referencePixelMap?: image.PixelMap, currentPixelMap?: image.PixelMap): Promise<FaceServiceResult>;
}

class FaceMockAdapter implements FaceAdapter {
  async enroll(studentId: string, referencePath?: string, templateDigest?: string): Promise<FaceServiceResult> {
    const result = FaceDemoService.enroll();
    return {
      success: result.success,
      message: result.message,
      method: 'cameraMock',
      profile: FaceService.createProfile(studentId, 'cameraMock', referencePath, templateDigest)
    };
  }

  async runLiveness(): Promise<FaceServiceResult> {
    const result = FaceDemoService.liveness();
    return {
      success: result.success,
      message: result.message,
      method: 'cameraMock'
    };
  }

  async compare(studentId: string, referencePixelMap?: image.PixelMap, currentPixelMap?: image.PixelMap): Promise<FaceServiceResult> {
    const result = FaceDemoService.compare();
    return {
      success: result.success,
      message: result.message,
      method: 'cameraMock',
      similarity: 1
    };
  }
}

class FaceVisionAdapter implements FaceAdapter {
  async enroll(studentId: string, referencePath?: string, templateDigest?: string): Promise<FaceServiceResult> {
    return {
      success: true,
      message: '基准人脸图已保存到本机',
      method: 'face',
      profile: FaceService.createProfile(studentId, 'face', referencePath, templateDigest, 0)
    };
  }

  async runLiveness(): Promise<FaceServiceResult> {
    try {
      const config: interactiveLiveness.InteractiveLivenessConfig = {
        isSilentMode: interactiveLiveness.DetectionMode.INTERACTIVE_MODE,
        actionsNum: interactiveLiveness.ActionsNumber.THREE_ACTION,
        routeMode: interactiveLiveness.RouteRedirectionMode.BACK_MODE,
        speechSwitch: true
      };
      return await FaceVisionAdapter.runInteractiveLiveness(config);
    } catch (err) {
      const error = err as BusinessError;
      return FaceService.fail(`活体检测接口异常：${FaceService.errorText(error)}`);
    }
  }

  private static runInteractiveLiveness(config: interactiveLiveness.InteractiveLivenessConfig): Promise<FaceServiceResult> {
    return new Promise((resolve) => {
      let settled = false;
      const settle = (result: FaceServiceResult): void => {
        if (settled) {
          return;
        }
        settled = true;
        resolve(result);
      };

      interactiveLiveness.startLivenessDetection(config, (err, data) => {
        if (err) {
          if (FaceService.isSuccessError(err)) {
            settle(data ? FaceService.livenessResult(data) : FaceService.livenessSuccess());
            return;
          }
          settle(FaceService.fail(`活体检测失败：${FaceService.errorText(err)}`));
          return;
        }
        if (!data) {
          settle(FaceService.fail('活体检测未返回结果，请重新尝试'));
          return;
        }
        settle(FaceService.livenessResult(data));
      }).then((started: boolean) => {
        if (!started) {
          settle(FaceService.fail('活体检测启动失败，请重新尝试'));
        }
      }).catch((err: BusinessError) => {
        settle(FaceService.fail(`活体检测启动异常：${FaceService.errorText(err)}`));
      });

      setTimeout(() => {
        settle(FaceService.fail('活体检测超时或已取消，请重新尝试'));
      }, LIVENESS_TIMEOUT_MS);
    });
  }

  async compare(studentId: string, referencePixelMap?: image.PixelMap, currentPixelMap?: image.PixelMap): Promise<FaceServiceResult> {
    if (!referencePixelMap || !currentPixelMap) {
      return FaceService.fail('缺少比对图像，请重新采集');
    }
    try {
      console.info('FaceService', 'faceComparator.init() 开始初始化');
      const initResult = await Promise.race([
        faceComparator.init(),
        new Promise<never>((_, reject) => {
          setTimeout(() => reject(new Error('faceComparator.init 超时')), FACE_COMPARE_TIMEOUT_MS);
        })
      ]);
      console.info('FaceService', 'faceComparator.init() 初始化成功，开始比对');
      const result = await Promise.race([
        faceComparator.compareFaces({ pixelMap: referencePixelMap }, { pixelMap: currentPixelMap }),
        new Promise<never>((_, reject) => {
          setTimeout(() => reject(new Error('faceComparator.compareFaces 超时')), FACE_COMPARE_TIMEOUT_MS);
        })
      ]);
      console.info('FaceService', `比对完成: isSamePerson=${result.isSamePerson}, similarity=${result.similarity}`);
      await faceComparator.release();
      const success = result.isSamePerson && result.similarity >= FACE_SIMILARITY_THRESHOLD;
      return {
        success,
        message: success ? `人脸比对成功，相似度 ${FaceService.percent(result.similarity)}` : `人脸检测失败，相似度 ${FaceService.percent(result.similarity)}`,
        method: 'face',
        similarity: result.similarity
      };
    } catch (err) {
      try {
        await faceComparator.release();
      } catch (releaseErr) {
      }
      const error = err as BusinessError;
      const errorCode = error.code !== undefined ? `${error.code}` : 'unknown';
      const errorMessage = error.message !== undefined ? error.message : '';
      console.error('FaceService', `人脸比对失败: 错误码=${errorCode}, 错误信息=${errorMessage}`);
      return FaceService.fail(`人脸比对接口异常，请重试 (错误码: ${errorCode}, 错误信息: ${errorMessage})`);
    }
  }
}

export class FaceService {
  private static mode: FaceRunMode = 'visionReady';

  static runMode(): FaceRunMode {
    return FaceService.mode;
  }

  static modeLabel(): string {
    return FaceService.mode === 'visionReady' ? '真实端侧识别' : 'Demo 备用模式';
  }

  static useVisionReady(value: boolean): void {
    FaceService.mode = value ? 'visionReady' : 'demoSafe';
  }

  static async enroll(studentId: string, referencePath?: string, templateDigest?: string): Promise<FaceServiceResult> {
    return await FaceService.adapter().enroll(studentId, referencePath, templateDigest);
  }

  static async runLiveness(): Promise<FaceServiceResult> {
    return await FaceService.adapter().runLiveness();
  }

  static async readLivenessResult(): Promise<FaceServiceResult> {
    if (FaceService.mode !== 'visionReady') {
      return await new FaceMockAdapter().runLiveness();
    }
    try {
      const result = await interactiveLiveness.getInteractiveLivenessResult();
      return FaceService.livenessResult(result);
    } catch (err) {
      const error = err as BusinessError;
      return FaceService.fail(`活体检测结果读取失败：${FaceService.errorText(error)}`);
    }
  }

  static async compare(studentId: string, referencePixelMap?: image.PixelMap, currentPixelMap?: image.PixelMap): Promise<FaceServiceResult> {
    return await FaceService.adapter().compare(studentId, referencePixelMap, currentPixelMap);
  }

  static createProfile(studentId: string, provider: VerificationMethod, referencePath?: string, templateDigest?: string, qualityScore: number = 0): FaceProfile {
    const stamp = new Date();
    const seed = `${studentId}-${stamp.getTime()}-${provider}-${templateDigest || ''}`;
    return {
      studentId,
      templateId: `tpl-${studentId}-${stamp.getTime()}`,
      registeredAt: `${stamp.getFullYear()}-${FaceService.pad(stamp.getMonth() + 1)}-${FaceService.pad(stamp.getDate())} ${FaceService.pad(stamp.getHours())}:${FaceService.pad(stamp.getMinutes())}`,
      provider,
      qualityScore,
      templateDigest: templateDigest || FaceService.digest(seed),
      referenceImagePath: referencePath
    };
  }

  static fail(message: string): FaceServiceResult {
    return {
      success: false,
      message,
      method: FaceService.mode === 'visionReady' ? 'face' : 'cameraMock'
    };
  }

  static percent(value: number): string {
    return `${Math.round(value * 100)}%`;
  }

  static errorText(err?: BusinessError): string {
    if (err === undefined || err === null) {
      return 'unknown error';
    }
    const code = err.code !== undefined ? `${err.code}` : '';
    const message = err.message !== undefined ? err.message : '';
    if (code.length > 0 && message.length > 0) {
      return `${code} ${message}`;
    }
    if (message.length > 0) {
      return message;
    }
    if (code.length > 0) {
      return code;
    }
    return JSON.stringify(err);
  }

  static livenessResult(result?: interactiveLiveness.InteractiveLivenessResult): FaceServiceResult {
    if (result === undefined || result === null || result.livenessType === undefined) {
      return FaceService.fail('1008302004 活体检测结果尚未就绪');
    }
    if (result.livenessType === NOT_LIVENESS) {
      return FaceService.fail('活体检测失败，请重新尝试');
    }
    if (result.livenessType === INTERACTIVE_LIVENESS || result.livenessType === SILENT_LIVENESS) {
      return FaceService.livenessSuccess();
    }
    return FaceService.livenessSuccess();
  }

  static livenessSuccess(): FaceServiceResult {
    return {
      success: true,
      message: '活体检测通过',
      method: 'face'
    };
  }

  static isSuccessError(err?: BusinessError): boolean {
    return err !== undefined && err !== null && err.code === 0;
  }

  private static adapter(): FaceAdapter {
    return FaceService.mode === 'visionReady' ? new FaceVisionAdapter() : new FaceMockAdapter();
  }

  private static digest(seed: string): string {
    let value = 0;
    for (let index = 0; index < seed.length; index++) {
      value = (value * 31 + seed.charCodeAt(index)) % 1000000007;
    }
    return `fc-${value}`;
  }

  private static pad(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }
}
