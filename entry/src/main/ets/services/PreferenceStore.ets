import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { AttendanceRecord, BadgeItem, Course, FaceProfile, FeedbackItem, NotificationItem, StudentAccount } from '../models/FaceCheckModels';

const STORE_NAME = 'facecheck_demo_store';
const KEY_LOGGED_IN = 'logged_in';
const KEY_CURRENT_STUDENT_ID = 'current_student_id';
const KEY_DARK_MODE = 'dark_mode';
const KEY_ACCOUNTS = 'student_accounts';
const KEY_COURSES = 'custom_courses';

export class PreferenceStore {
  private pref?: preferences.Preferences;

  async init(context: common.Context): Promise<void> {
    try {
      this.pref = await preferences.getPreferences(context, { name: STORE_NAME });
    } catch (err) {
      this.pref = undefined;
    }
  }

  // 同步初始化，供 FormExtensionAbility（卡片进程）使用
  initSync(context: common.Context): void {
    try {
      this.pref = preferences.getPreferencesSync(context, { name: STORE_NAME });
    } catch (err) {
      this.pref = undefined;
    }
  }

  isLoggedIn(): boolean {
    return this.getBoolean(KEY_LOGGED_IN, false);
  }

  async setLoggedIn(value: boolean): Promise<void> {
    await this.putBoolean(KEY_LOGGED_IN, value);
  }

  currentStudentId(): string {
    return this.getString(KEY_CURRENT_STUDENT_ID, '');
  }

  async setCurrentStudentId(studentId: string): Promise<void> {
    await this.putString(KEY_CURRENT_STUDENT_ID, studentId);
  }

  isFaceRegistered(studentId: string): boolean {
    return this.getBoolean(this.studentKey('face_registered', studentId), false);
  }

  async setFaceRegistered(studentId: string, value: boolean): Promise<void> {
    await this.putBoolean(this.studentKey('face_registered', studentId), value);
  }

  faceProfile(studentId: string): FaceProfile | undefined {
    if (!this.pref) {
      return undefined;
    }
    try {
      const raw = this.pref.getSync(this.studentKey('face_profile', studentId), '') as string;
      if (raw.length === 0) {
        return undefined;
      }
      return JSON.parse(raw) as FaceProfile;
    } catch (err) {
      return undefined;
    }
  }

  async saveFaceProfile(studentId: string, profile: FaceProfile): Promise<void> {
    await this.putString(this.studentKey('face_profile', studentId), JSON.stringify(profile));
  }

  async clearFaceProfile(studentId: string): Promise<void> {
    if (!this.pref) {
      return;
    }
    try {
      this.pref.deleteSync(this.studentKey('face_profile', studentId));
      this.pref.putSync(this.studentKey('face_registered', studentId), false);
      await this.pref.flush();
    } catch (err) {
    }
  }

  isDarkMode(): boolean {
    return this.getBoolean(KEY_DARK_MODE, false);
  }

  async setDarkMode(value: boolean): Promise<void> {
    await this.putBoolean(KEY_DARK_MODE, value);
  }

  records(studentId: string): AttendanceRecord[] {
    if (!this.pref) {
      return [];
    }
    try {
      const raw = this.pref.getSync(this.studentKey('attendance_records', studentId), '[]') as string;
      const parsed = JSON.parse(raw) as AttendanceRecord[];
      return Array.isArray(parsed) ? parsed : [];
    } catch (err) {
      return [];
    }
  }

  async saveRecords(studentId: string, records: AttendanceRecord[]): Promise<void> {
    if (!this.pref) {
      return;
    }
    try {
      this.pref.putSync(this.studentKey('attendance_records', studentId), JSON.stringify(records));
      await this.pref.flush();
    } catch (err) {
    }
  }

  async resetSession(): Promise<void> {
    if (!this.pref) {
      return;
    }
    try {
      this.pref.putSync(KEY_LOGGED_IN, false);
      this.pref.putSync(KEY_CURRENT_STUDENT_ID, '');
      await this.pref.flush();
    } catch (err) {
    }
  }

  accounts(): StudentAccount[] {
    if (!this.pref) {
      return [];
    }
    try {
      const raw: string = this.pref.getSync(KEY_ACCOUNTS, '[]') as string;
      const parsed: StudentAccount[] = JSON.parse(raw) as StudentAccount[];
      return Array.isArray(parsed) ? parsed : [];
    } catch (err) {
      return [];
    }
  }

  async saveAccounts(accounts: StudentAccount[]): Promise<void> {
    if (!this.pref) {
      return;
    }
    try {
      this.pref.putSync(KEY_ACCOUNTS, JSON.stringify(accounts));
      await this.pref.flush();
    } catch (err) {
    }
  }

  courses(): Course[] {
    if (!this.pref) {
      return [];
    }
    try {
      const raw: string = this.pref.getSync(KEY_COURSES, '[]') as string;
      const parsed: Course[] = JSON.parse(raw) as Course[];
      return Array.isArray(parsed) ? parsed : [];
    } catch (err) {
      return [];
    }
  }

  async saveCourses(courses: Course[]): Promise<void> {
    if (!this.pref) {
      return;
    }
    try {
      this.pref.putSync(KEY_COURSES, JSON.stringify(courses));
      await this.pref.flush();
    } catch (err) {
    }
  }

  notifications(studentId: string): NotificationItem[] {
    if (!this.pref) {
      return [];
    }
    try {
      const raw: string = this.pref.getSync(this.studentKey('notifications', studentId), '[]') as string;
      const parsed: NotificationItem[] = JSON.parse(raw) as NotificationItem[];
      return Array.isArray(parsed) ? parsed : [];
    } catch (err) {
      return [];
    }
  }

  async saveNotifications(studentId: string, notifications: NotificationItem[]): Promise<void> {
    if (!this.pref) {
      return;
    }
    try {
      this.pref.putSync(this.studentKey('notifications', studentId), JSON.stringify(notifications));
      await this.pref.flush();
    } catch (err) {
    }
  }

  badges(studentId: string): BadgeItem[] {
    if (!this.pref) {
      return [];
    }
    try {
      const raw: string = this.pref.getSync(this.studentKey('badges', studentId), '[]') as string;
      const parsed: BadgeItem[] = JSON.parse(raw) as BadgeItem[];
      return Array.isArray(parsed) ? parsed : [];
    } catch (err) {
      return [];
    }
  }

  async saveBadges(studentId: string, badges: BadgeItem[]): Promise<void> {
    if (!this.pref) {
      return;
    }
    try {
      this.pref.putSync(this.studentKey('badges', studentId), JSON.stringify(badges));
      await this.pref.flush();
    } catch (err) {
    }
  }

  feedbacks(studentId: string): FeedbackItem[] {
    if (!this.pref) {
      return [];
    }
    try {
      const raw: string = this.pref.getSync(this.studentKey('feedbacks', studentId), '[]') as string;
      const parsed: FeedbackItem[] = JSON.parse(raw) as FeedbackItem[];
      return Array.isArray(parsed) ? parsed : [];
    } catch (err) {
      return [];
    }
  }

  async saveFeedbacks(studentId: string, feedbacks: FeedbackItem[]): Promise<void> {
    if (!this.pref) {
      return;
    }
    try {
      this.pref.putSync(this.studentKey('feedbacks', studentId), JSON.stringify(feedbacks));
      await this.pref.flush();
    } catch (err) {
    }
  }

  private getBoolean(key: string, fallback: boolean): boolean {
    if (!this.pref) {
      return fallback;
    }
    try {
      return this.pref.getSync(key, fallback) as boolean;
    } catch (err) {
      return fallback;
    }
  }

  private async putBoolean(key: string, value: boolean): Promise<void> {
    if (!this.pref) {
      return;
    }
    try {
      this.pref.putSync(key, value);
      await this.pref.flush();
    } catch (err) {
    }
  }

  private getString(key: string, fallback: string): string {
    if (!this.pref) {
      return fallback;
    }
    try {
      return this.pref.getSync(key, fallback) as string;
    } catch (err) {
      return fallback;
    }
  }

  private async putString(key: string, value: string): Promise<void> {
    if (!this.pref) {
      return;
    }
    try {
      this.pref.putSync(key, value);
      await this.pref.flush();
    } catch (err) {
    }
  }

  isReminderEnabled(): boolean {
    return this.getBoolean('reminder_enabled', true);
  }

  async setReminderEnabled(value: boolean): Promise<void> {
    await this.putBoolean('reminder_enabled', value);
  }

  formIds(): string[] {
    return this.getStringArray('widget_form_ids', []);
  }

  addFormId(formId: string): void {
    const ids = this.formIds();
    if (ids.indexOf(formId) < 0) {
      ids.push(formId);
      this.putStringArray('widget_form_ids', ids);
    }
  }

  removeFormId(formId: string): void {
    const ids = this.formIds().filter((id: string) => id !== formId);
    this.putStringArray('widget_form_ids', ids);
  }

  reminderIds(): number[] {
    return this.getNumberArray('reminder_ids', []);
  }

  saveReminderIds(ids: number[]): void {
    this.putStringArray('reminder_ids', ids.map((id: number) => `${id}`));
  }

  ignoredVersion(): string {
    return this.getString('ignored_version', '');
  }

  async saveIgnoredVersion(version: string): Promise<void> {
    await this.putString('ignored_version', version);
  }

  private studentKey(prefix: string, studentId: string): string {
    return `${prefix}_${studentId}`;
  }

  private getStringArray(key: string, fallback: string[]): string[] {
    if (!this.pref) {
      return fallback;
    }
    try {
      const raw = this.pref.getSync(key, '[]') as string;
      const parsed: Object = JSON.parse(raw);
      return Array.isArray(parsed) ? (parsed as string[]) : fallback;
    } catch (err) {
      return fallback;
    }
  }

  private getNumberArray(key: string, fallback: number[]): number[] {
    const strings = this.getStringArray(key, []);
    return strings.map((s: string) => Number(s)).filter((n: number) => !isNaN(n));
  }

  private putStringArray(key: string, value: string[]): void {
    if (!this.pref) {
      return;
    }
    try {
      this.pref.putSync(key, JSON.stringify(value));
      this.pref.flushSync();
    } catch (err) {
    }
  }
}
