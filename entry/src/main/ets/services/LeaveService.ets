import { LeaveRequest, Course, CourseSignState } from '../models/FaceCheckModels';

const ORANGE = '#F0A030';
const ORANGE_SOFT = '#FFF8EC';
const BLUE = '#0B67D1';
const BLUE_SOFT = '#E7F1FF';
const MUTED = '#697386';
const MUTED_SOFT = '#EEF2F8';
const GREEN = '#18B86B';
const GREEN_SOFT = '#EAFBF2';
const RED = '#F05252';
const RED_SOFT = '#FFF0F0';

export class LeaveService {
  /**
   * 检查某门课在今天是否已有请假记录
   */
  static hasLeave(leaveRequests: LeaveRequest[], courseId: string, dateKey: string): boolean {
    return leaveRequests.some((req: LeaveRequest) =>
      req.courseId === courseId && req.dateKey === dateKey
    );
  }

  /**
   * 获取某门课今天的请假记录
   */
  static getLeave(leaveRequests: LeaveRequest[], courseId: string, dateKey: string): LeaveRequest | null {
    return leaveRequests.find((req: LeaveRequest) =>
      req.courseId === courseId && req.dateKey === dateKey
    ) || null;
  }

  /**
   * 创建请假申请
   */
  static createLeaveRequest(
    course: Course,
    userId: string,
    dateKey: string,
    reason: string,
    now: Date = new Date()
  ): LeaveRequest {
    const month = now.getMonth() + 1;
    const day = now.getDate();
    const hour = now.getHours().toString().padStart(2, '0');
    const minute = now.getMinutes().toString().padStart(2, '0');
    return {
      leaveId: `leave-${course.courseId}-${dateKey}-${now.getTime()}`,
      courseId: course.courseId,
      userId,
      courseName: course.courseName,
      classroom: course.classroom,
      dateKey,
      reason,
      status: 'pending',
      applyTime: `${month}月${day}日 ${hour}:${minute}`
    };
  }

  /**
   * 请假状态标签文本
   */
  static leaveStatusLabel(status: 'pending' | 'approved' | 'rejected'): string {
    switch (status) {
      case 'pending':
        return '审核中';
      case 'approved':
        return '已批假';
      case 'rejected':
        return '未通过';
    }
  }

  /**
   * 请假状态颜色
   */
  static leaveStatusColor(status: 'pending' | 'approved' | 'rejected'): string {
    switch (status) {
      case 'pending':
        return ORANGE;
      case 'approved':
        return GREEN;
      case 'rejected':
        return RED;
    }
  }

  /**
   * 请假状态背景色
   */
  static leaveStatusBg(status: 'pending' | 'approved' | 'rejected'): string {
    switch (status) {
      case 'pending':
        return ORANGE_SOFT;
      case 'approved':
        return GREEN_SOFT;
      case 'rejected':
        return RED_SOFT;
    }
  }

  /**
   * 课程签到状态 — 请假版本
   * 如果课程已请假，返回 leave 状态
   */
  static courseSignStateWithLeave(
    course: Course,
    leaveRequests: LeaveRequest[],
    dateKey: string,
    baseState: CourseSignState
  ): CourseSignState {
    if (LeaveService.hasLeave(leaveRequests, course.courseId, dateKey)) {
      const leave = LeaveService.getLeave(leaveRequests, course.courseId, dateKey);
      const label = LeaveService.leaveStatusLabel(leave!.status);
      return {
        status: 'leave',
        label,
        color: LeaveService.leaveStatusColor(leave!.status),
        background: LeaveService.leaveStatusBg(leave!.status),
        canSign: false,
        hint: `已提交请假申请（${label}）`
      };
    }
    return baseState;
  }
}
