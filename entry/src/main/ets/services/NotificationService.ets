import { NotificationItem, NotificationType } from '../models/FaceCheckModels';
import { PreferenceStore } from './PreferenceStore';

export class NotificationService {
  private static store?: PreferenceStore;

  static init(store: PreferenceStore): void {
    NotificationService.store = store;
  }

  static loadNotifications(studentId: string): NotificationItem[] {
    if (!NotificationService.store) {
      return [];
    }
    const items: NotificationItem[] = NotificationService.store.notifications(studentId);
    return items.sort((a: NotificationItem, b: NotificationItem) => b.timestamp - a.timestamp);
  }

  static saveNotifications(studentId: string, notifications: NotificationItem[]): void {
    if (!NotificationService.store) {
      return;
    }
    NotificationService.store.saveNotifications(studentId, notifications);
  }

  static addNotification(studentId: string, notification: NotificationItem): void {
    const items: NotificationItem[] = NotificationService.loadNotifications(studentId);
    items.unshift(notification);
    NotificationService.saveNotifications(studentId, items);
  }

  static markAsRead(studentId: string, id: string): void {
    const items: NotificationItem[] = NotificationService.loadNotifications(studentId);
    const updated: NotificationItem[] = [];
    for (let i = 0; i < items.length; i++) {
      if (items[i].id === id) {
        const item: NotificationItem = items[i];
        updated.push({
          id: item.id,
          type: item.type,
          title: item.title,
          content: item.content,
          timestamp: item.timestamp,
          read: true,
          studentId: item.studentId,
          courseId: item.courseId
        });
      } else {
        updated.push(items[i]);
      }
    }
    NotificationService.saveNotifications(studentId, updated);
  }

  static markAllAsRead(studentId: string): void {
    const items: NotificationItem[] = NotificationService.loadNotifications(studentId);
    const updated: NotificationItem[] = [];
    for (let i = 0; i < items.length; i++) {
      updated.push({
        id: items[i].id,
        type: items[i].type,
        title: items[i].title,
        content: items[i].content,
        timestamp: items[i].timestamp,
        read: true,
        studentId: items[i].studentId,
        courseId: items[i].courseId
      });
    }
    NotificationService.saveNotifications(studentId, updated);
  }

  static deleteNotification(studentId: string, id: string): void {
    const items: NotificationItem[] = NotificationService.loadNotifications(studentId);
    const filtered: NotificationItem[] = items.filter((item: NotificationItem) => item.id !== id);
    NotificationService.saveNotifications(studentId, filtered);
  }

  static clearAllNotifications(studentId: string): void {
    NotificationService.saveNotifications(studentId, []);
  }

  static unreadCount(studentId: string): number {
    const items: NotificationItem[] = NotificationService.loadNotifications(studentId);
    return items.filter((item: NotificationItem) => !item.read).length;
  }

  static seedNotifications(studentId: string): NotificationItem[] {
    const now: number = Date.now();
    const seed: NotificationItem[] = [
      {
        id: `notif-system-${now}`,
        type: 'system' as NotificationType,
        title: '欢迎使用 FaceCheck',
        content: 'FaceCheck 校园签到助手已就绪，请完成人脸录入后即可使用签到功能。',
        timestamp: now,
        read: false,
        studentId
      },
      {
        id: `notif-reminder-${now - 3600000}`,
        type: 'signReminder' as NotificationType,
        title: '课程签到提醒',
        content: '您有课程即将开始，请提前准备好签到。',
        timestamp: now - 3600000,
        read: true,
        studentId,
        courseId: 'course-java-theory'
      }
    ];
    NotificationService.saveNotifications(studentId, seed);
    return seed;
  }

  static createSignSuccessNotification(studentId: string, courseName: string, courseId: string): NotificationItem {
    const now: number = Date.now();
    return {
      id: `notif-success-${courseId}-${now}`,
      type: 'signSuccess' as NotificationType,
      title: '签到成功',
      content: `您已成功完成《${courseName}》的签到。`,
      timestamp: now,
      read: false,
      studentId,
      courseId
    };
  }

  static createSignFailedNotification(studentId: string, courseName: string, courseId: string, reason: string): NotificationItem {
    const now: number = Date.now();
    return {
      id: `notif-fail-${courseId}-${now}`,
      type: 'signFailed' as NotificationType,
      title: '签到失败',
      content: `《${courseName}》签到失败：${reason}`,
      timestamp: now,
      read: false,
      studentId,
      courseId
    };
  }

  static createSignReminderNotification(studentId: string, courseName: string, courseId: string, startTime: string): NotificationItem {
    const now: number = Date.now();
    return {
      id: `notif-reminder-${courseId}-${now}`,
      type: 'signReminder' as NotificationType,
      title: '课程签到提醒',
      content: `《${courseName}》将于 ${startTime} 开始，请及时签到。`,
      timestamp: now,
      read: false,
      studentId,
      courseId
    };
  }

  static typeLabel(type: NotificationType): string {
    if (type === 'signReminder') return '提醒';
    if (type === 'signSuccess') return '成功';
    if (type === 'signFailed') return '失败';
    if (type === 'system') return '系统';
    return '通知';
  }

  static typeColor(type: NotificationType): string {
    if (type === 'signReminder') return '#0B67D1';
    if (type === 'signSuccess') return '#18B86B';
    if (type === 'signFailed') return '#F05252';
    if (type === 'system') return '#697386';
    return '#697386';
  }

  static typeBgColor(type: NotificationType): string {
    if (type === 'signReminder') return '#E7F1FF';
    if (type === 'signSuccess') return '#EAFBF2';
    if (type === 'signFailed') return '#FFF0F0';
    if (type === 'system') return '#EEF2F8';
    return '#EEF2F8';
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
