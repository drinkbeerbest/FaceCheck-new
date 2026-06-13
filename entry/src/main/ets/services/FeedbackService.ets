import { FeedbackItem, FeedbackStatus, FeedbackType } from '../models/FaceCheckModels';
import { PreferenceStore } from './PreferenceStore';

export class FeedbackService {
  private static store?: PreferenceStore;

  static init(store: PreferenceStore): void {
    FeedbackService.store = store;
  }

  static loadFeedbacks(studentId: string): FeedbackItem[] {
    if (!FeedbackService.store) {
      return [];
    }
    const items: FeedbackItem[] = FeedbackService.store.feedbacks(studentId);
    return items.sort((a: FeedbackItem, b: FeedbackItem) => b.timestamp - a.timestamp);
  }

  static saveFeedbacks(studentId: string, feedbacks: FeedbackItem[]): void {
    if (!FeedbackService.store) {
      return;
    }
    FeedbackService.store.saveFeedbacks(studentId, feedbacks);
  }

  static addFeedback(studentId: string, feedback: FeedbackItem): void {
    const items: FeedbackItem[] = FeedbackService.loadFeedbacks(studentId);
    items.unshift(feedback);
    FeedbackService.saveFeedbacks(studentId, items);
  }

  static clearAllFeedbacks(studentId: string): void {
    FeedbackService.saveFeedbacks(studentId, []);
  }

  static unreadCount(studentId: string): number {
    const items: FeedbackItem[] = FeedbackService.loadFeedbacks(studentId);
    let count = 0;
    for (let i = 0; i < items.length; i++) {
      if (items[i].status === 'pending') {
        count++;
      }
    }
    return count;
  }

  static typeLabel(type: FeedbackType): string {
    if (type === 'bug') {
      return 'Bug 反馈';
    }
    if (type === 'feature') {
      return '功能建议';
    }
    if (type === 'improvement') {
      return '优化建议';
    }
    return '其他问题';
  }

  static typeColor(type: FeedbackType): string {
    if (type === 'bug') {
      return '#F05252';
    }
    if (type === 'feature') {
      return '#0B67D1';
    }
    if (type === 'improvement') {
      return '#18B86B';
    }
    return '#697386';
  }

  static typeBgColor(type: FeedbackType): string {
    if (type === 'bug') {
      return '#FFF0F0';
    }
    if (type === 'feature') {
      return '#E7F1FF';
    }
    if (type === 'improvement') {
      return '#EAFBF2';
    }
    return '#EEF2F8';
  }

  static statusLabel(status: FeedbackStatus): string {
    if (status === 'pending') {
      return '处理中';
    }
    if (status === 'received') {
      return '已收到';
    }
    return '已解决';
  }

  static statusColor(status: FeedbackStatus): string {
    if (status === 'pending') {
      return '#F59E0B';
    }
    if (status === 'received') {
      return '#0B67D1';
    }
    return '#18B86B';
  }

  static formatTime(timestamp: number): string {
    const now: Date = new Date();
    const date: Date = new Date(timestamp);
    const diffMs: number = now.getTime() - date.getTime();
    const diffMins: number = Math.floor(diffMs / 60000);
    const diffHours: number = Math.floor(diffMs / 3600000);
    const diffDays: number = Math.floor(diffMs / 86400000);

    if (diffMins < 1) {
      return '刚刚';
    }
    if (diffMins < 60) {
      return `${diffMins}分钟前`;
    }
    if (diffHours < 24) {
      return `${diffHours}小时前`;
    }
    if (diffDays < 7) {
      return `${diffDays}天前`;
    }
    const month: number = date.getMonth() + 1;
    const day: number = date.getDate();
    const hour: string = date.getHours() < 10 ? `0${date.getHours()}` : `${date.getHours()}`;
    const minute: string = date.getMinutes() < 10 ? `0${date.getMinutes()}` : `${date.getMinutes()}`;
    return `${month}月${day}日 ${hour}:${minute}`;
  }
}
