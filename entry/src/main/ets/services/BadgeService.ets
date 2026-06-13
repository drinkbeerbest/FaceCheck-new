import { AttendanceRecord, BadgeItem, BadgeType, Course } from '../models/FaceCheckModels';
import { PreferenceStore } from './PreferenceStore';

export class BadgeService {
  private static store?: PreferenceStore;

  static init(store: PreferenceStore): void {
    BadgeService.store = store;
  }

  static loadBadges(studentId: string): BadgeItem[] {
    if (!BadgeService.store) {
      return BadgeService.defaultBadges();
    }
    const saved: BadgeItem[] = BadgeService.store.badges(studentId);
    if (saved.length === 0) {
      return BadgeService.defaultBadges();
    }
    return BadgeService.mergeWithDefaults(saved);
  }

  static saveBadges(studentId: string, badges: BadgeItem[]): void {
    if (!BadgeService.store) {
      return;
    }
    BadgeService.store.saveBadges(studentId, badges);
  }

  static unlockBadge(studentId: string, type: BadgeType): boolean {
    const badges: BadgeItem[] = BadgeService.loadBadges(studentId);
    let changed: boolean = false;
    for (let i = 0; i < badges.length; i++) {
      if (badges[i].type === type && !badges[i].unlocked) {
        badges[i].unlocked = true;
        badges[i].unlockedAt = Date.now();
        changed = true;
      }
    }
    if (changed) {
      BadgeService.saveBadges(studentId, badges);
    }
    return changed;
  }

  static updateProgress(studentId: string, type: BadgeType, progress: number): void {
    const badges: BadgeItem[] = BadgeService.loadBadges(studentId);
    for (let i = 0; i < badges.length; i++) {
      if (badges[i].type === type) {
        badges[i].progress = progress;
      }
    }
    BadgeService.saveBadges(studentId, badges);
  }

  static checkSignBadges(studentId: string, records: AttendanceRecord[], courses: Course[]): BadgeType[] {
    const unlocked: BadgeType[] = [];
    const successRecords: AttendanceRecord[] = records.filter((r: AttendanceRecord) => r.status === 'success');

    if (successRecords.length >= 1) {
      if (BadgeService.unlockBadge(studentId, 'first_sign')) {
        unlocked.push('first_sign');
      }
    }

    const total: number = successRecords.length;
    if (total >= 10) {
      if (BadgeService.unlockBadge(studentId, 'total_10')) {
        unlocked.push('total_10');
      }
    }
    if (total >= 50) {
      if (BadgeService.unlockBadge(studentId, 'total_50')) {
        unlocked.push('total_50');
      }
    }
    if (total >= 100) {
      if (BadgeService.unlockBadge(studentId, 'total_100')) {
        unlocked.push('total_100');
      }
    }

    BadgeService.updateProgress(studentId, 'total_10', total);
    BadgeService.updateProgress(studentId, 'total_50', total);
    BadgeService.updateProgress(studentId, 'total_100', total);

    const streak: number = BadgeService.calcMaxConsecutiveDays(successRecords);
    if (streak >= 3) {
      if (BadgeService.unlockBadge(studentId, 'streak_3')) {
        unlocked.push('streak_3');
      }
    }
    if (streak >= 7) {
      if (BadgeService.unlockBadge(studentId, 'streak_7')) {
        unlocked.push('streak_7');
      }
    }
    if (streak >= 30) {
      if (BadgeService.unlockBadge(studentId, 'streak_30')) {
        unlocked.push('streak_30');
      }
    }

    BadgeService.updateProgress(studentId, 'streak_3', streak);
    BadgeService.updateProgress(studentId, 'streak_7', streak);
    BadgeService.updateProgress(studentId, 'streak_30', streak);

    const now: Date = new Date();
    const weekStart: Date = new Date(now);
    weekStart.setDate(now.getDate() - now.getDay());
    const weekCourses: Course[] = courses.filter((c: Course) => c.weekDay >= 1 && c.weekDay <= 7);
    let allSigned: boolean = true;
    for (let i = 0; i < weekCourses.length; i++) {
      const dayOffset: number = weekCourses[i].weekDay - weekStart.getDay();
      const targetDate: Date = new Date(weekStart);
      targetDate.setDate(weekStart.getDate() + dayOffset);
      const dateKey: string = `${targetDate.getMonth() + 1}月${targetDate.getDate()}日`;
      const signed: boolean = successRecords.some((r: AttendanceRecord) => r.courseId === weekCourses[i].courseId && r.displayDate === dateKey);
      if (!signed) {
        allSigned = false;
        break;
      }
    }
    if (allSigned && weekCourses.length > 0) {
      if (BadgeService.unlockBadge(studentId, 'perfect_week')) {
        unlocked.push('perfect_week');
      }
    }

    return unlocked;
  }

  static checkLoginBadge(studentId: string): boolean {
    return BadgeService.unlockBadge(studentId, 'first_login');
  }

  static checkFaceEnrolledBadge(studentId: string): boolean {
    return BadgeService.unlockBadge(studentId, 'face_enrolled');
  }

  private static calcMaxConsecutiveDays(records: AttendanceRecord[]): number {
    if (records.length === 0) {
      return 0;
    }
    const dateSet: Set<string> = new Set<string>();
    for (let i = 0; i < records.length; i++) {
      const r: AttendanceRecord = records[i];
      if (r.status === 'success' && r.displayDate.indexOf('月') >= 0) {
        dateSet.add(r.displayDate);
      }
    }
    const dates: string[] = Array.from(dateSet);
    if (dates.length === 0) {
      return 0;
    }
    const parsed: Date[] = [];
    for (let i = 0; i < dates.length; i++) {
      const parts: string[] = dates[i].replace('日', '').split('月');
      if (parts.length === 2) {
        const month: number = Number(parts[0]) - 1;
        const day: number = Number(parts[1]);
        const d: Date = new Date();
        d.setMonth(month);
        d.setDate(day);
        d.setHours(0, 0, 0, 0);
        parsed.push(d);
      }
    }
    if (parsed.length === 0) {
      return 0;
    }
    parsed.sort((a: Date, b: Date) => a.getTime() - b.getTime());

    let maxStreak: number = 1;
    let currentStreak: number = 1;
    for (let i = 1; i < parsed.length; i++) {
      const diff: number = (parsed[i].getTime() - parsed[i - 1].getTime()) / 86400000;
      if (diff === 1) {
        currentStreak += 1;
        if (currentStreak > maxStreak) {
          maxStreak = currentStreak;
        }
      } else if (diff > 1) {
        currentStreak = 1;
      }
    }
    return maxStreak;
  }

  private static defaultBadges(): BadgeItem[] {
    return [
      { type: 'first_login', title: '初来乍到', description: '首次登录 FaceCheck', icon: 'person', unlocked: false, target: 1 },
      { type: 'first_sign', title: '第一次签到', description: '完成首次课程签到', icon: 'check-circle', unlocked: false, target: 1 },
      { type: 'streak_3', title: '坚持不懈', description: '连续 3 天签到', icon: 'calendar-check', unlocked: false, target: 3 },
      { type: 'streak_7', title: '一周全勤', description: '连续 7 天签到', icon: 'award', unlocked: false, target: 7 },
      { type: 'streak_30', title: '月度之星', description: '连续 30 天签到', icon: 'award', unlocked: false, target: 30 },
      { type: 'total_10', title: '签到达人', description: '累计签到 10 次', icon: 'book', unlocked: false, target: 10 },
      { type: 'total_50', title: '签到专家', description: '累计签到 50 次', icon: 'book', unlocked: false, target: 50 },
      { type: 'total_100', title: '签到大师', description: '累计签到 100 次', icon: 'book', unlocked: false, target: 100 },
      { type: 'face_enrolled', title: '面貌一新', description: '完成人脸录入', icon: 'camera', unlocked: false, target: 1 },
      { type: 'perfect_week', title: '完美一周', description: '本周所有课程全勤', icon: 'shield', unlocked: false, target: 1 }
    ];
  }

  private static mergeWithDefaults(saved: BadgeItem[]): BadgeItem[] {
    const defaults: BadgeItem[] = BadgeService.defaultBadges();
    const result: BadgeItem[] = [];
    for (let i = 0; i < defaults.length; i++) {
      let found: boolean = false;
      for (let j = 0; j < saved.length; j++) {
        if (saved[j].type === defaults[i].type) {
          result.push(saved[j]);
          found = true;
          break;
        }
      }
      if (!found) {
        result.push(defaults[i]);
      }
    }
    return result;
  }
}
