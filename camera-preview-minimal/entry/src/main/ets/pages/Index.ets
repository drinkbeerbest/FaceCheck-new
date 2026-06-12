import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { promptAction } from '@kit.ArkUI';
import camera from '@ohos.multimedia.camera';
import interactiveLiveness from '@hms.ai.interactiveLiveness';

const CAMERA_PERMISSION: Permissions = 'ohos.permission.CAMERA';
const LIVENESS_TIMEOUT_MS = 90000;
const INTERACTIVE_LIVENESS = 0;
const SILENT_LIVENESS = 1;
const NOT_LIVENESS = 2;

@Entry
@Component
struct Index {
  private xComponentController: XComponentController = new XComponentController();
  private cameraInput?: camera.CameraInput;
  private previewOutput?: camera.PreviewOutput;
  private session?: camera.PhotoSession;
  private livenessSerial: number = 0;
  private waitingLivenessResult: boolean = false;

  @State status: string = 'Tap a button to test camera preview or system liveness.';
  @State running: boolean = false;
  @State livenessRunning: boolean = false;

  aboutToDisappear(): void {
    this.releaseCamera();
  }

  onPageShow(): void {
    if (this.waitingLivenessResult) {
      setTimeout(() => {
        this.fetchLivenessResult('pageShow');
      }, 500);
    }
  }

  build() {
    Column({ space: 14 }) {
      Text('FaceCheck Minimal Camera + Liveness')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor('#111827')
        .margin({ top: 20 })

      Text(this.status)
        .fontSize(14)
        .fontColor(this.running || this.livenessRunning ? '#047857' : '#4B5563')
        .width('92%')
        .textAlign(TextAlign.Center)

      Stack() {
        XComponent({
          id: 'front-camera-preview',
          type: XComponentType.SURFACE,
          controller: this.xComponentController
        })
          .width('100%')
          .height('100%')
          .backgroundColor('#111827')

        if (!this.running) {
          Text('PREVIEW AREA')
            .fontSize(26)
            .fontWeight(FontWeight.Bold)
            .fontColor('#CBD5E1')
        }
      }
      .width('92%')
      .layoutWeight(1)
      .borderRadius(8)
      .clip(true)
      .backgroundColor('#111827')

      Button(this.running ? 'Restart Front Preview' : 'Start Front Preview')
        .height(50)
        .width('92%')
        .fontColor(Color.White)
        .backgroundColor('#0B67D1')
        .borderRadius(8)
        .onClick(() => {
          this.startPreview();
        })

      Row({ space: 12 }) {
        Button(this.livenessRunning ? 'Liveness Running' : 'Start System Liveness')
          .height(50)
          .layoutWeight(1)
          .fontColor(Color.White)
          .backgroundColor(this.livenessRunning ? '#6B7280' : '#16A34A')
          .borderRadius(8)
          .enabled(!this.livenessRunning)
          .onClick(() => {
            this.startLiveness();
          })

        Button('Stop Preview')
          .height(50)
          .width(130)
          .fontColor('#0B67D1')
          .backgroundColor('#E8F1FF')
          .borderRadius(8)
          .onClick(() => {
            this.releaseCamera();
          })
      }
      .width('92%')
      .margin({ bottom: 22 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F4F7FB')
  }

  private async startPreview(): Promise<void> {
    this.status = 'Requesting camera permission for preview...';
    const context = getContext(this) as common.UIAbilityContext;
    const granted = await this.requestCameraPermission(context);
    if (!granted) {
      this.status = 'Camera permission denied.';
      this.running = false;
      return;
    }

    await this.releaseCamera();
    this.status = 'Waiting for XComponent surfaceId...';
    const surfaceId = await this.waitForSurfaceId(12);
    if (surfaceId.length === 0) {
      this.status = 'surfaceId is empty. Reopen this page and retry.';
      return;
    }

    try {
      const manager = camera.getCameraManager(context);
      const device = this.frontCamera(manager);
      if (!device) {
        this.status = 'No camera device found.';
        return;
      }

      const capability = manager.getSupportedOutputCapability(device, camera.SceneMode.NORMAL_PHOTO);
      const previewProfile = this.bestProfile(capability.previewProfiles);
      if (!previewProfile) {
        this.status = 'No supported preview profile found.';
        return;
      }

      this.status = `Opening front camera ${previewProfile.size.width}x${previewProfile.size.height}...`;
      this.cameraInput = manager.createCameraInput(device);
      await this.cameraInput.open();
      this.previewOutput = manager.createPreviewOutput(previewProfile, surfaceId);
      this.session = manager.createSession<camera.PhotoSession>(camera.SceneMode.NORMAL_PHOTO);
      this.session.beginConfig();
      this.session.addInput(this.cameraInput);
      this.session.addOutput(this.previewOutput);
      await this.session.commitConfig();
      await this.session.start();
      this.running = true;
      this.status = 'Front camera preview started.';
    } catch (err) {
      const error = err as BusinessError;
      this.running = false;
      this.status = `Preview failed: ${this.errorText(error)}`;
      await this.releaseCamera();
    }
  }

  private async startLiveness(): Promise<void> {
    this.livenessSerial += 1;
    const token = this.livenessSerial;
    this.livenessRunning = true;
    this.status = 'Requesting camera permission for system liveness...';
    const context = getContext(this) as common.UIAbilityContext;
    const granted = await this.requestCameraPermission(context);
    if (!granted) {
      this.livenessRunning = false;
      this.status = 'Camera permission denied. System liveness cannot start.';
      return;
    }

    this.status = 'Starting system liveness control...';
    const config: interactiveLiveness.InteractiveLivenessConfig = {
      isSilentMode: interactiveLiveness.DetectionMode.INTERACTIVE_MODE,
      actionsNum: interactiveLiveness.ActionsNumber.THREE_ACTION,
      routeMode: interactiveLiveness.RouteRedirectionMode.BACK_MODE,
      speechSwitch: true
    };

    let settled = false;
    const settle = (message: string): void => {
      if (settled || this.livenessSerial !== token) {
        return;
      }
      settled = true;
      this.waitingLivenessResult = false;
      this.livenessRunning = false;
      this.showStatus(message);
    };

    try {
      interactiveLiveness.startLivenessDetection(config, (err, data) => {
        if (err) {
          if (this.isSuccessError(err)) {
            settle(data ? this.livenessMessage(data, 'callback') : 'Liveness PASS (callback): code 0 test succeeded');
            return;
          }
          settle(`Liveness callback error: ${this.errorText(err)}`);
          return;
        }
        if (!data) {
          this.status = 'Liveness callback returned no result. Waiting for page return result...';
          return;
        }
        settle(this.livenessMessage(data, 'callback'));
      }).then((started: boolean) => {
        if (!started) {
          settle('startLivenessDetection returned false.');
          return;
        }
        this.waitingLivenessResult = true;
        this.status = 'System liveness page started. Complete the action prompts.';
      }).catch((err: BusinessError) => {
        settle(`Liveness start rejected: ${this.errorText(err)}`);
      });
    } catch (err) {
      const error = err as BusinessError;
      settle(`Liveness start threw: ${this.errorText(error)}`);
      return;
    }

    setTimeout(() => {
      if (!settled) {
        this.fetchLivenessResult('timeout');
      }
    }, LIVENESS_TIMEOUT_MS);
  }

  private async fetchLivenessResult(source: string): Promise<void> {
    if (!this.waitingLivenessResult) {
      return;
    }
    try {
      const result = await interactiveLiveness.getInteractiveLivenessResult();
      if (result === undefined || result === null || result.livenessType === undefined) {
        if (source === 'pageShow') {
          this.status = 'Returned to app, liveness result is not ready yet.';
          return;
        }
        this.waitingLivenessResult = false;
        this.livenessRunning = false;
        this.showStatus(`Liveness result is not ready (${source}): 1008302004`);
        return;
      }
      this.waitingLivenessResult = false;
      this.livenessRunning = false;
      this.showStatus(this.livenessMessage(result, source));
    } catch (err) {
      const error = err as BusinessError;
      const text = this.errorText(error);
      if (text.indexOf('1008302004') >= 0 && source === 'pageShow') {
        this.status = 'Returned to app, liveness result is not ready yet.';
        return;
      }
      this.waitingLivenessResult = false;
      this.livenessRunning = false;
      this.showStatus(`Liveness result read failed (${source}): ${text}`);
    }
  }

  private livenessMessage(result?: interactiveLiveness.InteractiveLivenessResult, source: string = 'unknown'): string {
    if (result === undefined || result === null || result.livenessType === undefined) {
      return `Liveness result is not ready (${source}): 1008302004`;
    }
    if (result.livenessType === INTERACTIVE_LIVENESS) {
      return `Liveness PASS (${source}): INTERACTIVE_LIVENESS`;
    }
    if (result.livenessType === SILENT_LIVENESS) {
      return `Liveness PASS (${source}): SILENT_LIVENESS`;
    }
    if (result.livenessType === NOT_LIVENESS) {
      return `Liveness FAIL (${source}): NOT_LIVENESS`;
    }
    return `Liveness FAIL (${source}): NOT_LIVENESS`;
  }

  private showStatus(message: string): void {
    this.status = message;
    try {
      promptAction.showToast({ message, duration: 3000 });
    } catch (err) {
    }
  }

  private async requestCameraPermission(context: common.UIAbilityContext): Promise<boolean> {
    try {
      const manager = abilityAccessCtrl.createAtManager();
      const result = await manager.requestPermissionsFromUser(context, [CAMERA_PERMISSION]);
      return result.authResults.length === 0 || result.authResults[0] === 0;
    } catch (err) {
      return true;
    }
  }

  private async waitForSurfaceId(retries: number): Promise<string> {
    for (let index = 0; index < retries; index++) {
      const surfaceId = this.safeSurfaceId();
      if (surfaceId.length > 0) {
        return surfaceId;
      }
      await this.sleep(250);
    }
    return '';
  }

  private safeSurfaceId(): string {
    try {
      return this.xComponentController.getXComponentSurfaceId();
    } catch (err) {
      return '';
    }
  }

  private sleep(ms: number): Promise<void> {
    return new Promise((resolve) => {
      setTimeout(() => {
        resolve();
      }, ms);
    });
  }

  private frontCamera(manager: camera.CameraManager): camera.CameraDevice | undefined {
    const devices = manager.getSupportedCameras();
    for (let index = 0; index < devices.length; index++) {
      if (devices[index].cameraPosition === camera.CameraPosition.CAMERA_POSITION_FRONT) {
        return devices[index];
      }
    }
    return devices.length > 0 ? devices[0] : undefined;
  }

  private bestProfile(profiles: Array<camera.Profile>): camera.Profile | undefined {
    if (profiles.length === 0) {
      return undefined;
    }
    let selected = profiles[0];
    let selectedScore = this.profileScore(selected);
    for (let index = 1; index < profiles.length; index++) {
      const score = this.profileScore(profiles[index]);
      if (score > selectedScore && score <= 1280 * 720) {
        selected = profiles[index];
        selectedScore = score;
      }
    }
    return selected;
  }

  private profileScore(profile: camera.Profile): number {
    return profile.size.width * profile.size.height;
  }

  private async releaseCamera(): Promise<void> {
    this.running = false;
    if (this.session) {
      try {
        await this.session.stop();
      } catch (err) {
      }
      try {
        await this.session.release();
      } catch (err) {
      }
      this.session = undefined;
    }
    if (this.cameraInput) {
      try {
        await this.cameraInput.close();
      } catch (err) {
      }
      this.cameraInput = undefined;
    }
    this.previewOutput = undefined;
    this.status = 'Preview stopped.';
  }

  private errorText(error?: BusinessError): string {
    if (error === undefined || error === null) {
      return 'unknown error';
    }
    const code = error.code !== undefined ? `${error.code}` : '';
    const message = error.message !== undefined ? error.message : '';
    if (code.length > 0 && message.length > 0) {
      return `${code} ${message}`;
    }
    if (message.length > 0) {
      return message;
    }
    if (code.length > 0) {
      return code;
    }
    return JSON.stringify(error);
  }

  private isSuccessError(error?: BusinessError): boolean {
    return error !== undefined && error !== null && error.code === 0;
  }
}
