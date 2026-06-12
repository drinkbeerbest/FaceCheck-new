import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { AttendanceRecord, FaceProfile, StudentAccount } from '../models/FaceCheckModels';

const STORE_NAME = 'facecheck_demo_store';
const KEY_LOGGED_IN = 'logged_in';
const KEY_CURRENT_STUDENT_ID = 'current_student_id';
const KEY_DARK_MODE = 'dark_mode';
const KEY_ACCOUNTS = 'student_accounts';

export class PreferenceStore {
  private pref?: preferences.Preferences;

  async init(context: common.UIAbilityContext): Promise<void> {
    try {
      this.pref = await preferences.getPreferences(context, { name: STORE_NAME });
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

  private studentKey(prefix: string, studentId: string): string {
    return `${prefix}_${studentId}`;
  }
}
