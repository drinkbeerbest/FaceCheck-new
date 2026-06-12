import { AttendanceRecord, AttendanceStats, Course, CourseSignState, VerificationMethod } from '../models/FaceCheckModels';

const BLUE = '#0B67D1';
const BLUE_SOFT = '#E7F1FF';
const MUTED = '#697386';
const MUTED_SOFT = '#EEF2F8';
const GREEN = '#18B86B';
const GREEN_SOFT = '#EAFBF2';
const RED = '#F05252';
const RED_SOFT = '#FFF0F0';

export class AttendanceService {
  static hasSigned(records: AttendanceRecord[], courseId: string, dateKey: string): boolean {
    return records.some((record: AttendanceRecord) => {
      return record.courseId === courseId && record.displayDate === dateKey && record.status === 'success';
    });
  }

  static createSuccessRecord(userId: string, course: Course, now: Date = new Date(), method: VerificationMethod = 'mock'): AttendanceRecord {
    const dateKey = AttendanceService.dateKey(now);
    return {
      recordId: `record-${course.courseId}-${now.getTime()}`,
      userId,
      courseId: course.courseId,
      courseName: course.courseName,
      classroom: course.classroom,
      time: AttendanceService.timeText(now),
      displayDate: dateKey,
      status: 'success',
      verificationMethod: method,
      message: '人脸匹配成功，已完成签到'
    };
  }

  static createFailureRecord(userId: string, course: Course, message: string, now: Date = new Date(), method: VerificationMethod = 'cameraMock', absence: boolean = false): AttendanceRecord {
    const dateKey = AttendanceService.dateKey(now);
    return {
      recordId: `record-fail-${course.courseId}-${now.getTime()}`,
      userId,
      courseId: course.courseId,
      courseName: course.courseName,
      classroom: course.classroom,
      time: AttendanceService.timeText(now),
      displayDate: dateKey,
      status: 'fail',
      verificationMethod: method,
      message,
      absence
    };
  }

  static seedRecords(userId: string): AttendanceRecord[] {
    return [
      {
        recordId: 'seed-java',
        userId,
        courseId: 'course-java-theory',
        courseName: 'Java语言程序设计',
        classroom: '教C101',
        time: '昨天 15:58',
        displayDate: '昨天',
        status: 'success',
        verificationMethod: 'mock',
        message: '已签到'
      },
      {
        recordId: 'seed-os',
        userId,
        courseId: 'course-os-theory',
        courseName: '操作系统',
        classroom: '教C105',
        time: '本周 16:02',
        displayDate: '本周',
        status: 'fail',
        verificationMethod: 'mock',
        message: '人脸匹配失败，请联系老师'
      }
    ];
  }

  static stats(records: AttendanceRecord[], courses: Course[] = [], now: Date = new Date()): AttendanceStats {
    const successCount = records.filter((record: AttendanceRecord) => record.status === 'success').length;
    const signedKeys = new Set<string>();
    records.forEach((record: AttendanceRecord) => {
      if (record.status === 'success') {
        signedKeys.add(AttendanceService.recordCourseDateKey(record));
      }
    });

    const absenceKeys = new Set<string>();
    records.forEach((record: AttendanceRecord) => {
      if (record.status !== 'fail') {
        return;
      }
      const key = AttendanceService.recordCourseDateKey(record);
      if (signedKeys.has(key)) {
        return;
      }
      if (AttendanceService.recordCountsAsAbsence(record)) {
        absenceKeys.add(key);
      }
    });

    const todayKey = AttendanceService.dateKey(now);
    const nowMinutes = now.getHours() * 60 + now.getMinutes();
    courses.forEach((course: Course) => {
      if (course.weekDay !== now.getDay()) {
        return;
      }
      const key = AttendanceService.courseDateKey(course.courseId, todayKey);
      if (signedKeys.has(key)) {
        return;
      }
      if (nowMinutes > AttendanceService.toMinutes(course.startTime) + 10) {
        absenceKeys.add(key);
      }
    });

    const failCount = absenceKeys.size;
    const total = successCount + failCount;
    const rate = total === 0 ? 0 : Math.round((successCount / total) * 100);
    return {
      successCount,
      failCount,
      totalCount: total,
      rateText: `${rate}%`
    };
  }

  static courseSignState(course: Course, records: AttendanceRecord[], now: Date = new Date()): CourseSignState {
    if (AttendanceService.hasSigned(records, course.courseId, AttendanceService.dateKey(now))) {
      return {
        status: 'signed',
        label: '已签到',
        color: GREEN,
        background: GREEN_SOFT,
        canSign: false,
        hint: '该课程已完成签到'
      };
    }

    const nowMinutes = now.getHours() * 60 + now.getMinutes();
    const startMinutes = AttendanceService.toMinutes(course.startTime);
    if (nowMinutes < startMinutes) {
      return {
        status: 'notStarted',
        label: '未开始签到',
        color: MUTED,
        background: MUTED_SOFT,
        canSign: false,
        hint: '课程尚未到签到时间'
      };
    }

    if (nowMinutes <= startMinutes + 10) {
      return {
        status: 'active',
        label: '开始签到',
        color: BLUE,
        background: BLUE_SOFT,
        canSign: true,
        hint: '签到窗口开放中'
      };
    }

    return {
      status: 'missed',
      label: '未签到',
      color: RED,
      background: RED_SOFT,
      canSign: false,
      hint: '签到已结束'
    };
  }

  static dateKey(now: Date = new Date()): string {
    const month = now.getMonth() + 1;
    const day = now.getDate();
    return `${month}月${day}日`;
  }

  private static timeText(now: Date): string {
    const hour = AttendanceService.pad(now.getHours());
    const minute = AttendanceService.pad(now.getMinutes());
    return `今天 ${hour}:${minute}`;
  }

  private static pad(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }

  private static toMinutes(time: string): number {
    const parts = time.split(':');
    if (parts.length !== 2) {
      return 0;
    }
    return Number(parts[0]) * 60 + Number(parts[1]);
  }

  private static recordCourseDateKey(record: AttendanceRecord): string {
    return AttendanceService.courseDateKey(record.courseId, record.displayDate);
  }

  private static courseDateKey(courseId: string, dateKey: string): string {
    return `${courseId}|${dateKey}`;
  }

  private static recordCountsAsAbsence(record: AttendanceRecord): boolean {
    if (record.absence === true) {
      return true;
    }
    const message = record.message || '';
    return message.indexOf('超过') >= 0 ||
      message.indexOf('缺勤') >= 0 ||
      message.indexOf('未签到') >= 0 ||
      message.indexOf('签到已结束') >= 0;
  }
}
