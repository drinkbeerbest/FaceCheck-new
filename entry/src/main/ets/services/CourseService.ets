import { COURSE_DATA, WEEKDAY_LABELS } from '../data/CourseData';
import { AttendanceRecord, Course } from '../models/FaceCheckModels';
import { AttendanceService } from './AttendanceService';

export class CourseService {
  static all(): Course[] {
    return COURSE_DATA;
  }

  static today(now: Date = new Date()): Course[] {
    const weekDay = now.getDay();
    return COURSE_DATA.filter((course: Course) => course.weekDay === weekDay);
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
    return COURSE_DATA.find((course: Course) => course.courseId === courseId);
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
}
