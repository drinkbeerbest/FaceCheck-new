import { COURSE_DATA, WEEKDAY_LABELS } from '../data/CourseData';
import { AttendanceRecord, Course } from '../models/FaceCheckModels';
import { AttendanceService } from './AttendanceService';
import { PreferenceStore } from './PreferenceStore';

export class CourseService {
  private static store?: PreferenceStore;
  private static customCourses: Course[] = [];
  private static useCustom: boolean = false;

  static init(store: PreferenceStore): void {
    CourseService.store = store;
    const saved: Course[] = store.courses();
    if (saved.length > 0) {
      CourseService.customCourses = saved;
      CourseService.useCustom = true;
      console.log('加载自定义课表:', saved.length);
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
    return CourseService.courseData().filter((course: Course) => course.weekDay === weekDay);
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
