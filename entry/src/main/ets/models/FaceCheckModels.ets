import type image from '@ohos.multimedia.image';

export type AttendanceStatus = 'success' | 'fail' | 'pending';
export type VerificationMethod = 'face' | 'mock' | 'cameraMock';
export type CourseType = 'theory' | 'lab' | 'practice';

export interface SemesterOption {
  label: string;
  value: string;
}
export type CourseSignStatus = 'signed' | 'notStarted' | 'active' | 'missed';
export type FaceRunMode = 'demoSafe' | 'visionReady';
export type FaceStageStatus = 'waitingPermission' | 'preparingCamera' | 'cameraPreview' | 'detecting' | 'success' | 'failed' | 'demoMode';
export type NotificationType = 'signReminder' | 'signSuccess' | 'signFailed' | 'system';
export type BadgeType = 'first_login' | 'first_sign' | 'streak_3' | 'streak_7' | 'streak_30' | 'total_10' | 'total_50' | 'total_100' | 'face_enrolled' | 'perfect_week';
export type FeedbackType = 'bug' | 'feature' | 'improvement' | 'other';
export type FeedbackStatus = 'pending' | 'received' | 'resolved';

export interface BadgeItem {
  type: BadgeType;
  title: string;
  description: string;
  icon: string;
  unlocked: boolean;
  unlockedAt?: number;
  progress?: number;
  target?: number;
}

export interface User {
  userId: string;
  name: string;
  studentId: string;
  className: string;
  academy: string;
  faceRegistered: boolean;
  avatarPath?: string;  // 可选字段，存储用户自定义头像路径
}

export interface StudentAccount {
  studentId: string;
  password: string;
  user: User;
}

export interface Course {
  courseId: string;
  courseName: string;
  classroom: string;
  teacher: string;
  weekDay: number;
  section: string;
  sectionStart: number;
  sectionEnd: number;
  startTime: string;
  endTime: string;
  weekRange: string;
  type: CourseType;
  color?: string;
}

export interface AttendanceRecord {
  recordId: string;
  userId: string;
  courseId: string;
  courseName: string;
  classroom: string;
  time: string;
  displayDate: string;
  status: AttendanceStatus;
  verificationMethod: VerificationMethod;
  message: string;
  absence?: boolean;
}

export interface AttendanceStats {
  successCount: number;
  failCount: number;
  totalCount: number;
  rateText: string;
}

export interface CourseSignState {
  status: CourseSignStatus;
  label: string;
  color: string;
  background: string;
  canSign: boolean;
  hint: string;
}

export interface FaceDemoResult {
  success: boolean;
  message: string;
}

export interface FaceProfile {
  studentId: string;
  templateId: string;
  registeredAt: string;
  provider: VerificationMethod;
  qualityScore: number;
  templateDigest: string;
  referenceImagePath?: string;
  lastSimilarity?: number;
}

export interface NotificationItem {
  id: string;
  type: NotificationType;
  title: string;
  content: string;
  timestamp: number;
  read: boolean;
  studentId: string;
  courseId?: string;
}

export interface FaceServiceResult {
  success: boolean;
  message: string;
  method: VerificationMethod;
  profile?: FaceProfile;
  similarity?: number;
  pixelMap?: image.PixelMap;
}

export const DEMO_USER: User = {
  userId: 'u-202440011987',
  name: '戴奇威',
  studentId: '202440011987',
  className: '24软件工程（计算机科学创新实验班）',
  academy: '计算机科学与技术学院',
  faceRegistered: false
};

export const ROOT_USER: User = {
  userId: 'u-202440011111',
  name: 'root',
  studentId: '202440011111',
  className: '24软件工程（计算机科学创新实验班）',
  academy: '计算机科学与技术学院',
  faceRegistered: false
};

export const ANONYMOUS_USER: User = {
  userId: 'anonymous',
  name: '未登录',
  studentId: '',
  className: '',
  academy: 'FaceCheck',
  faceRegistered: false
};

export interface FeedbackItem {
  id: string;
  type: FeedbackType;
  title: string;
  content: string;
  contact: string;
  timestamp: number;
  status: FeedbackStatus;
  studentId: string;
}

export interface FeedbackTypeOption {
  label: string;
  value: FeedbackType;
  icon: string;
  placeholder: string;
}

export const FEEDBACK_TYPE_OPTIONS: FeedbackTypeOption[] = [
  { label: 'Bug 反馈', value: 'bug', icon: '🐛', placeholder: '请描述遇到的问题，包括复现步骤…' },
  { label: '功能建议', value: 'feature', icon: '💡', placeholder: '请描述您希望新增的功能…' },
  { label: '优化建议', value: 'improvement', icon: '✨', placeholder: '请描述您觉得可以改进的地方…' },
  { label: '其他问题', value: 'other', icon: '💬', placeholder: '请描述您的其他问题或建议…' }
];

export interface UpdateLogItem {
  version: string;
  date: string;
  title: string;
  changes: string[];
  force: boolean;
}

export interface VersionInfo {
  currentVersion: string;
  latestVersion: string;
  updateUrl: string;
  releaseNotes: string;
  forceUpdate: boolean;
  publishDate: string;
}

// ===================== 定位与地理围栏 =====================

/** 定位结果 */
export interface LocationResult {
  latitude: number;
  longitude: number;
  accuracy: number;          // 精度（米）
  sourceType: number;       // 定位来源：1=GNSS, 2=NETWORK
  timestamp: number;
}

/** 地理围栏校验结果 */
export interface GeofenceCheckResult {
  inside: boolean;
  userLatitude: number;
  userLongitude: number;
  userAddress: string;       // 用户当前位置的描述
  targetName: string;        // 目标区域名称
  targetLatitude: number;
  targetLongitude: number;
  distanceMeters: number;    // 距离目标中心（米）
  radiusMeters: number;      // 围栏半径（米）
  hint: string;              // UI 提示文字
}

/** 围栏中心：华南师范大学南海校区 */
export const GEOFENCE_CENTER_LAT = 23.146825;
export const GEOFENCE_CENTER_LNG = 113.028439;
export const GEOFENCE_CENTER_NAME = '华南师范大学南海校区';
export const GEOFENCE_RADIUS_METERS = 700;  // 700米围栏半径

export const CURRENT_VERSION = '2.2.0';

export const UPDATE_LOGS: UpdateLogItem[] = [
  {
    version: '2.2.0',
    date: '2026-07-09',
    title: '地理围栏 & 课程管理 & 模拟定位',
    changes: [
      '新增地理围栏签到校验，确保仅在指定校园范围内可签到',
      '新增课程管理功能，支持手动添加课程与文件导入课表',
      '新增可视化课程表，支持周视图查看每日课程安排',
      '新增学年学期全局切换功能，支持跨学期查看课表',
      '新增模拟定位功能（开发测试用），支持模拟校内/校外位置',
      '优化课表 UI：课程块圆角调整为 8px、按周几+节次自动排序',
      '修复课程变更后页面不及时刷新的问题',
      '移除不稳定的地图查看功能'
    ],
    force: false
  },
  {
    version: '2.1.0',
    date: '2026-06-28',
    title: '反馈建议 & 启动优化',
    changes: [
      '新增反馈建议功能，支持 Bug 反馈、功能建议、优化建议',
      '新增应用启动页，优化冷启动体验与品牌展示',
      '新增版本更新检测与更新日志页面',
      '修复深色模式下部分 UI 显示异常问题',
      '优化签到记录列表加载性能'
    ],
    force: false
  },
  {
    version: '2.0.0',
    date: '2026-06-20',
    title: '全新版本上线 — FaceCheck 2.0',
    changes: [
      '全新 Material Design 风格 UI，支持浅色/深色主题一键切换',
      '新增签到记录筛选（按课程/日期/状态）与统计面板',
      '新增勋章成就系统，签到达标自动解锁纪念勋章',
      '新增通知中心，支持签到提醒与系统消息推送',
      '正式上线人脸录入与交互式活体检测功能',
      '新增个人资料管理页面，支持头像与信息编辑',
      '重构底层架构，大幅提升应用启动与页面切换流畅度',
      '支持人脸识别签到打卡，快速完成考勤'
    ],
    force: false
  },
  {
    version: '1.5.0',
    date: '2026-06-12',
    title: '稳定性改进与隐私合规',
    changes: [
      '优化人脸识别模型精度，降低弱光环境误识别率',
      '修复部分机型相机预览黑屏或画面拉伸问题',
      '改进签到流程用户提示与操作引导',
      '新增隐私政策页面，明确数据收集与使用范围',
      '优化应用内存占用，降低长时间运行崩溃概率'
    ],
    force: false
  },
  {
    version: '1.0.0',
    date: '2026-06-05',
    title: '首发版本 — 基础签到',
    changes: [
      '支持基础人脸识别签到功能',
      '支持签到记录查询，按时间线展示历史考勤',
      '支持个人资料管理（学号、姓名、班级、院系）',
      '适配 HarmonyOS NEXT，支持主流鸿蒙设备'
    ],
    force: false
  }
];
