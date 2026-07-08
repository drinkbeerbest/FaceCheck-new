import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';

export type CameraPermissionStatus = 'granted' | 'denied' | 'unavailable';

const CAMERA_PERMISSION: Permissions = 'ohos.permission.CAMERA';
const REQUEST_TIMEOUT_MS = 12000;

export class CameraPermissionService {
  static async requestCamera(context: common.UIAbilityContext): Promise<CameraPermissionStatus> {
    try {
      const atManager = abilityAccessCtrl.createAtManager();
      const result = await Promise.race([
        atManager.requestPermissionsFromUser(context, [CAMERA_PERMISSION]),
        CameraPermissionService.timeout()
      ]);
      if (result === 'timeout') {
        return 'denied';
      }
      if (!result || result.authResults.length === 0) {
        return 'denied';
      }
      return result.authResults[0] === 0 ? 'granted' : 'denied';
    } catch (err) {
      return 'denied';
    }
  }

  private static timeout(): Promise<'timeout'> {
    return new Promise((resolve) => {
      setTimeout(() => {
        resolve('timeout');
      }, REQUEST_TIMEOUT_MS);
    });
  }
}
