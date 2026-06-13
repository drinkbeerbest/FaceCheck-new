import { CURRENT_VERSION, UPDATE_LOGS, type UpdateLogItem, type VersionInfo } from '../models/FaceCheckModels';
import { PreferenceStore } from './PreferenceStore';

export class VersionService {
  private static store: PreferenceStore | null = null;

  static init(store: PreferenceStore): void {
    VersionService.store = store;
  }

  static getCurrentVersion(): string {
    return CURRENT_VERSION;
  }

  static getUpdateLogs(): UpdateLogItem[] {
    return UPDATE_LOGS;
  }

  /**
   * 检查是否有新版本（模拟网络请求）
   * 实际项目中可以替换为真实的 HTTP 请求
   */
  static async checkUpdate(): Promise<VersionInfo | null> {
    // 模拟网络延迟
    await new Promise<void>((resolve) => setTimeout(resolve, 1200));

    // 模拟远程版本（实际项目中从服务器获取）
    const remoteVersion = '2.2.0';

    if (VersionService.compareVersion(CURRENT_VERSION, remoteVersion) < 0) {
      return {
        currentVersion: CURRENT_VERSION,
        latestVersion: remoteVersion,
        updateUrl: 'https://example.com/download/FaceCheck-v2.2.0.hap',
        releaseNotes: '修复已知问题，优化签到体验，新增版本更新功能',
        forceUpdate: false,
        publishDate: '2025-06-20'
      };
    }

    return null;
  }

  /**
   * 比较版本号
   * @returns 负数: v1 < v2, 0: v1 === v2, 正数: v1 > v2
   */
  static compareVersion(v1: string, v2: string): number {
    const parts1 = v1.split('.').map(Number);
    const parts2 = v2.split('.').map(Number);
    const maxLen = Math.max(parts1.length, parts2.length);

    for (let i = 0; i < maxLen; i++) {
      const a = parts1[i] || 0;
      const b = parts2[i] || 0;
      if (a !== b) {
        return a - b;
      }
    }
    return 0;
  }

  /**
   * 获取已被忽略的版本号
   */
  static getIgnoredVersion(): string {
    if (!VersionService.store) {
      return '';
    }
    return VersionService.store.ignoredVersion();
  }

  /**
   * 忽略指定版本
   */
  static ignoreVersion(version: string): void {
    if (VersionService.store) {
      VersionService.store.saveIgnoredVersion(version);
    }
  }

  /**
   * 清除忽略的版本记录
   */
  static clearIgnoredVersion(): void {
    if (VersionService.store) {
      VersionService.store.saveIgnoredVersion('');
    }
  }

  /**
   * 判断是否需要提醒更新（未被忽略的新版本）
   */
  static shouldRemind(latestVersion: string): boolean {
    const ignored = VersionService.getIgnoredVersion();
    if (!ignored) {
      return true;
    }
    return VersionService.compareVersion(ignored, latestVersion) < 0;
  }

  static formatDate(dateStr: string): string {
    const date = new Date(dateStr);
    return `${date.getFullYear()}年${date.getMonth() + 1}月${date.getDate()}日`;
  }
}
