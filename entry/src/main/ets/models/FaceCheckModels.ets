import type image from '@ohos.multimedia.image';

export type AttendanceStatus = 'success' | 'fail' | 'pending';
export type VerificationMethod = 'face' | 'mock' | 'cameraMock';
export type CourseType = 'theory' | 'lab' | 'practice';
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

export const CURRENT_VERSION = '2.1.0';

export const UPDATE_LOGS: UpdateLogItem[] = [
  {
    version: '2.1.0',
    date: '2025-06-13',
    title: '反馈建议 & 启动优化',
    changes: [
      '新增反馈建议功能，支持 Bug 反馈、功能建议、优化建议',
      '新增启动页面，优化冷启动体验',
      '修复深色模式下部分 UI 显示问题',
      '优化课程导入体验'
    ],
    force: false
  },
  {
    version: '2.0.0',
    date: '2025-05-20',
    title: '全新版本上线',
    changes: [
      '全新 UI 设计，支持浅色/深色模式',
      '新增课程表查看功能',
      '新增签到记录筛选与统计',
      '新增勋章系统',
      '新增通知中心',
      '支持人脸录入与活体检测'
    ],
    force: false
  },
  {
    version: '1.5.0',
    date: '2025-04-10',
    title: '稳定性改进',
    changes: [
      '优化人脸识别准确率',
      '修复部分机型相机预览问题',
      '改进签到流程提示',
      '新增隐私政策页面'
    ],
    force: false
  },
  {
    version: '1.0.0',
    date: '2025-03-01',
    title: '首发版本',
    changes: [
      '支持人脸签到打卡',
      '支持课程管理与导入',
      '支持签到记录查询',
      '支持个人资料管理'
    ],
    force: false
  }
];
