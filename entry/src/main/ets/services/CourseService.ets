import { COURSE_DATA, WEEKDAY_LABELS } from '../data/CourseData';
import { AttendanceRecord, Course } from '../models/FaceCheckModels';
import { AttendanceService } from './AttendanceService';
import { PreferenceStore } from './PreferenceStore';

export class CourseService {
  private static store?: PreferenceStore;
  private static customCourses: Course[] = [];
  private static useCustom: boolean = false;
  private static currentAcademicYear: string = '2025-2026';
  private static currentSemester: string = '1';

  static init(store: PreferenceStore): void {
    CourseService.store = store;
    const saved: Course[] = store.courses();
    if (saved.length > 0) {
      CourseService.customCourses = saved;
      CourseService.useCustom = true;
      console.log('加载自定义课表:', saved.length);
    }
    // 恢复保存的学年学期
    const savedYear = store.get('current_academic_year');
    const savedSemester = store.get('current_semester');
    if (savedYear) {
      CourseService.currentAcademicYear = savedYear;
    }
    if (savedSemester) {
      CourseService.currentSemester = savedSemester;
    }
  }

  static get year(): string { return CourseService.currentAcademicYear; }
  static get semester(): string { return CourseService.currentSemester; }

  static semesterLabel(): string {
    return `${CourseService.currentAcademicYear} 学年第 ${CourseService.currentSemester} 学期`;
  }

  static setYearSemester(year: string, semester: string): void {
    CourseService.currentAcademicYear = year;
    CourseService.currentSemester = semester;
    if (CourseService.store) {
      CourseService.store.save('current_academic_year', year);
      CourseService.store.save('current_semester', semester);
    }
  }

  private static courseData(): Course[] {
    return CourseService.useCustom ? CourseService.customCourses : COURSE_DATA;
  }

  static all(): Course[] {
    return CourseService.courseData();
  }

  static today(now: Date = new Date()): Course[] {
    const weekDay = now.getDay();
    return CourseService.all().filter((course: Course) => course.weekDay === weekDay);
  }

  static nextCourse(now: Date = new Date()): Course | undefined {
    const todayCourses = CourseService.today(now);
    const nowMinutes = now.getHours() * 60 + now.getMinutes();
    const upcoming = todayCourses.filter((course: Course) => CourseService.toMinutes(course.endTime) >= nowMinutes);
    if (upcoming.length > 0) {
      return upcoming[0];
    }
    return todayCourses.length > 0 ? todayCourses[0] : undefined;
  }

  static activeSignCourse(records: AttendanceRecord[], now: Date = new Date()): Course | undefined {
    const todayCourses = CourseService.today(now);
    return todayCourses.find((course: Course) => {
      return AttendanceService.courseSignState(course, records, now).canSign;
    });
  }

  static courseById(courseId: string): Course | undefined {
    return CourseService.courseData().find((course: Course) => course.courseId === courseId);
  }

  static weekdayLabel(weekDay: number): string {
    return WEEKDAY_LABELS[weekDay] || '周内';
  }

  static toMinutes(time: string): number {
    const parts = time.split(':');
    if (parts.length !== 2) {
      return 0;
    }
    return Number(parts[0]) * 60 + Number(parts[1]);
  }

  static saveCourses(courses: Course[]): void {
    CourseService.customCourses = [...courses];
    CourseService.useCustom = true;
    if (CourseService.store) {
      CourseService.store.saveCourses(courses);
    }
  }

  static addCourse(course: Course): void {
    const current = CourseService.courseData();
    current.push(course);
    CourseService.saveCourses(current);
  }

  static updateCourse(courseId: string, updated: Course): boolean {
    const current = CourseService.courseData();
    const index = current.findIndex((c: Course) => c.courseId === courseId);
    if (index === -1) {
      return false;
    }
    current[index] = updated;
    CourseService.saveCourses(current);
    return true;
  }

  static courseColor(courseId: string): string {
    const PALETTE: string[] = [
      '#0B67D1', '#C62828', '#047857', '#B45309', '#5B21B6',
      '#BE185D', '#0369A1', '#C2410C', '#065F46', '#831843',
      '#1E40AF', '#9D174D', '#0D9488', '#4338CA', '#A21CAF'
    ];
    let hash = 0;
    for (let i = 0; i < courseId.length; i++) {
      hash = ((hash << 5) - hash) + courseId.charCodeAt(i);
      hash |= 0;
    }
    return PALETTE[Math.abs(hash) % PALETTE.length];
  }

  static courseBgColor(courseId: string): string {
    return CourseService.courseBgColorForHex(CourseService.courseColor(courseId));
  }

  static courseBgColorForHex(hex: string): string {
    const opacity20: Record<string, string> = {
      '#0B67D1': '#E7F1FF', '#C62828': '#FDE8E8', '#047857': '#D1FAE5',
      '#B45309': '#FEF3C7', '#5B21B6': '#EDE9FE', '#BE185D': '#FCE7F3',
      '#0369A1': '#E0F2FE', '#C2410C': '#FFF7ED', '#065F46': '#ECFDF5',
      '#831843': '#FDF2F8', '#1E40AF': '#DBEAFE', '#9D174D': '#FCE7F3',
      '#0D9488': '#CCFBF1', '#4338CA': '#E0E7FF', '#A21CAF': '#FAE8FF'
    };
    return opacity20[hex] || '#F3F4F6';
  }

  static deleteCourse(courseId: string): boolean {
    const current = CourseService.courseData();
    const filtered = current.filter((c: Course) => c.courseId !== courseId);
    if (filtered.length === current.length) {
      return false;
    }
    CourseService.saveCourses(filtered);
    return true;
  }

  static resetToDefault(): void {
    CourseService.customCourses = [];
    CourseService.useCustom = false;
    if (CourseService.store) {
      CourseService.store.saveCourses([]);
    }
  }
}
