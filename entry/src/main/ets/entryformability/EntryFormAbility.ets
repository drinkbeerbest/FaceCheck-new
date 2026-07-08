import { formBindingData, FormExtensionAbility, formInfo, formProvider } from '@kit.FormKit';
import { Want } from '@kit.AbilityKit';
import { Course } from '../models/FaceCheckModels';
import { PreferenceStore } from '../services/PreferenceStore';
import { CourseService } from '../services/CourseService';
import { AttendanceService } from '../services/AttendanceService';

const FORM_IDENTITY_KEY = 'ohos.extra.param.key.form_identity';

interface WidgetData {
  todayCourseName: string;
  todayCourseTime: string;
  todayCourseRoom: string;
  rateText: string;
  successCount: number;
  failCount: number;
  signedToday: number;
  loggedIn: boolean;
  hasFace: boolean;
}

// 根据当前持久化数据构建卡片展示内容
function buildWidgetData(store: PreferenceStore): WidgetData {
  const studentId: string = store.currentStudentId();
  const records = studentId ? store.records(studentId) : [];
  const custom = store.courses();
  const courses: Course[] = custom.length > 0 ? custom : CourseService.all();
  const stats = AttendanceService.stats(records, courses);

  const today = new Date();
  const weekDay = today.getDay();
  const todayCourses = courses
    .filter((c: Course) => c.weekDay === weekDay)
    .sort((a: Course, b: Course) => CourseService.toMinutes(a.startTime) - CourseService.toMinutes(b.startTime));
  const first: Course | undefined = todayCourses[0];

  const data: WidgetData = {
    todayCourseName: first ? first.courseName : '今日无课',
    todayCourseTime: first ? `${first.startTime} - ${first.endTime}` : '',
    todayCourseRoom: first ? first.classroom : '',
    rateText: stats.rateText,
    successCount: stats.successCount,
    failCount: stats.failCount,
    signedToday: records.filter((r) => r.status === 'success' && r.displayDate === AttendanceService.dateKey(today)).length,
    loggedIn: studentId.length > 0,
    hasFace: studentId.length > 0 && store.isFaceRegistered(studentId)
  };
  return data;
}

export default class EntryFormAbility extends FormExtensionAbility {
  onAddForm(want: Want) {
    const formId: string = want.parameters ? (want.parameters[FORM_IDENTITY_KEY] as string) : '';
    const data: WidgetData = buildWidgetData(this.getStore());
    if (formId) {
      this.getStore().addFormId(formId);
    }
    return formBindingData.createFormBindingData(data);
  }

  onUpdateForm(formId: string): void {
    const data: WidgetData = buildWidgetData(this.getStore());
    try {
      formProvider.updateForm(formId, formBindingData.createFormBindingData(data));
    } catch (e) {
      // ignore
    }
  }

  onFormEvent(formId: string, message: string): void {
    // 预留：可处理卡片交互（如点击签到按钮触发应用内动作）
  }

  onRemoveForm(formId: string): void {
    this.getStore().removeFormId(formId);
  }

  onAcquireFormState(want: Want) {
    return formInfo.FormState.READY;
  }

  // 供主应用调用：在签到等数据变化后主动刷新所有卡片
  static updateForms(store: PreferenceStore): void {
    const ids: string[] = store.formIds();
    if (ids.length === 0) {
      return;
    }
    const data: WidgetData = buildWidgetData(store);
    const binding = formBindingData.createFormBindingData(data);
    for (let i = 0; i < ids.length; i++) {
      try {
        formProvider.updateForm(ids[i], binding);
      } catch (e) {
        // ignore
      }
    }
  }

  private getStore(): PreferenceStore {
    const store = new PreferenceStore();
    store.initSync(this.context);
    return store;
  }
}
