import { common } from '@kit.AbilityKit';
import { notificationManager } from '@kit.NotificationKit';
import reminderAgentManager from '@ohos.reminderAgentManager';
import { AttendanceRecord, Course } from '../models/FaceCheckModels';
import { CourseService } from './CourseService';
import { PreferenceStore } from './PreferenceStore';

/**
 * 课前智能提醒服务。
 * 基于课程表为当天每节课在开始前推送系统级代理提醒；
 * 对历史签到异常（常迟到/常失败）的课程额外提前提醒，体现"智能"。
 */
export class ReminderService {
  /**
   * 为当天课程安排课前提醒。
   */
  static async scheduleTodayReminders(
    store: PreferenceStore,
    context?: common.UIAbilityContext,
    now?: Date,
    forceSchedule?: boolean,
    demoCourse?: Course
  ): Promise<void> {
    // 演示模式（forceSchedule）跳过偏好检查，强制发送提醒
    if (!forceSchedule && !store.isReminderEnabled()) {
      console.info('FaceCheck: 提醒功能未开启，跳过');
      return;
    }

    const studentId: string = store.currentStudentId();
    if (!studentId) {
      console.warn('FaceCheck: 未登录，无法安排提醒');
      return;
    }

    // 先取消之前发布的提醒，避免重复堆积
    await ReminderService.cancelAll(store);

    const records: AttendanceRecord[] = store.records(studentId);
    const lateProne: Set<string> = ReminderService.lateProneCourseIds(records);
    const _now: Date = now || new Date();
    // 演示模式：只通知选中的那一门课
    const courses: Course[] = (forceSchedule && demoCourse)
      ? [demoCourse]
      : CourseService.today(_now);

    console.info(`FaceCheck: scheduleTodayReminders forceSchedule=${forceSchedule}, courseCount=${courses.length}, now=${_now.toISOString()}`);

    for (let i = 0; i < courses.length; i++) {
      const course: Course = courses[i];
      const parts = course.startTime.split(':');
      if (parts.length !== 2) {
        continue;
      }
      const hour = Number(parts[0]);
      const minute = Number(parts[1]);
      const courseDate = new Date(_now.getFullYear(), _now.getMonth(), _now.getDate(), hour, minute, 0, 0);
      // 已经开始或已过去的课程不再提醒（演示模式下立刻触发）
      if (courseDate.getTime() <= _now.getTime()) {
        if (!forceSchedule) {
          continue;
        }
        courseDate.setTime(_now.getTime());  // 演示模式：立刻弹出
      } else {
        // 常迟到课程提前 20 分钟，其余提前 10 分钟
        const leadMinutes: number = lateProne.has(course.courseId) ? 20 : 10;
        courseDate.setMinutes(courseDate.getMinutes() - leadMinutes);
      }

      const title = `《${course.courseName}》即将开始`;
      const content = lateProne.has(course.courseId)
        ? `你常在这门课签到异常，请提前准备：${course.classroom} · ${course.startTime}`
        : `请提前到 ${course.classroom} 准备签到（${course.startTime} 开始）`;

      console.info(`FaceCheck: 发布提醒 [${course.courseName}] trigger=${courseDate.toISOString()}`);

      // 演示模式：用 setTimeout + 直接通知（避免代理提醒 30 条累计上限）
      if (forceSchedule) {
        const delayMs = courseDate.getTime() - _now.getTime();
        const notifyTitle = title;
        const notifyContent = content;
        setTimeout(() => {
          try {
            notificationManager.publish({
              id: Date.now(),
              content: {
                notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
                normal: {
                  title: notifyTitle,
                  text: notifyContent
                }
              }
            }).then(() => {
              console.info(`FaceCheck: 演示通知已弹出 [${course.courseName}]`);
            }).catch((err: Error) => {
              console.error('FaceCheck: 演示通知失败', JSON.stringify(err));
            });
          } catch (e) {
            console.error('FaceCheck: 演示通知异常', JSON.stringify(e));
          }
        }, Math.max(delayMs, 1000));
        continue;
      }

      try {
        const reminderRequest: reminderAgentManager.ReminderRequestCalendar = {
          reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_CALENDAR,
          dateTime: {
            year: courseDate.getFullYear(),
            month: courseDate.getMonth() + 1,
            day: courseDate.getDate(),
            hour: courseDate.getHours(),
            minute: courseDate.getMinutes(),
            second: 0
          },
          title: title,
          content: content
        };
        const id: number = await reminderAgentManager.publishReminder(reminderRequest);
        ReminderService.trackId(store, id);
        console.info(`FaceCheck: 代理提醒成功 id=${id} course=${course.courseName}`);
      } catch (err) {
        console.error('FaceCheck: 代理提醒失败', JSON.stringify(err));
      }
    }
  }

  static async cancelAll(store: PreferenceStore): Promise<void> {
    // 先获取系统中所有有效提醒，逐个清除（避免累积超过30条上限）
    try {
      const allReminders = await reminderAgentManager.getAllValidReminders();
      console.info(`FaceCheck: 发现 ${allReminders.length} 条有效提醒，开始清除`);
      let cancelled = 0;
      for (let i = 0; i < allReminders.length; i++) {
        try {
          await reminderAgentManager.cancelReminder(allReminders[i].reminderId);
          cancelled++;
        } catch (_e) {
          console.warn(`FaceCheck: 取消提醒 ${allReminders[i].reminderId} 失败`);
        }
      }
      console.info(`FaceCheck: 已清除 ${cancelled} 条提醒`);
    } catch (e) {
      console.warn('FaceCheck: getAllValidReminders 失败，尝试 cancelAllReminders', JSON.stringify(e));
      try {
        await reminderAgentManager.cancelAllReminders();
      } catch (e2) {
        // 最终回退：用 store 记录的 ID
        const ids: number[] = store.reminderIds();
        for (let i = 0; i < ids.length; i++) {
          try {
            await reminderAgentManager.cancelReminder(ids[i]);
          } catch (_e) {
            // 忽略
          }
        }
      }
    }
    store.saveReminderIds([]);
  }

  // 从历史记录中找出"经常签到异常"的课程
  private static lateProneCourseIds(records: AttendanceRecord[]): Set<string> {
    const fail: Record<string, number> = {};
    const success: Record<string, number> = {};
    for (let i = 0; i < records.length; i++) {
      const r = records[i];
      if (r.status === 'fail') {
        fail[r.courseId] = (fail[r.courseId] || 0) + 1;
      } else if (r.status === 'success') {
        success[r.courseId] = (success[r.courseId] || 0) + 1;
      }
    }
    const set = new Set<string>();
    const failIds: string[] = Object.keys(fail);
    for (let i = 0; i < failIds.length; i++) {
      const id: string = failIds[i];
      const total = (success[id] || 0) + fail[id];
      if (fail[id] >= 2 && fail[id] / total >= 0.3) {
        set.add(id);
      }
    }
    return set;
  }

  private static trackId(store: PreferenceStore, id: number): void {
    const ids = store.reminderIds();
    ids.push(id);
    store.saveReminderIds(ids);
  }
}
