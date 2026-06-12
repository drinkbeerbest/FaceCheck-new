import type image from '@ohos.multimedia.image';

export type AttendanceStatus = 'success' | 'fail' | 'pending';
export type VerificationMethod = 'face' | 'mock' | 'cameraMock';
export type CourseType = 'theory' | 'lab' | 'practice';
export type CourseSignStatus = 'signed' | 'notStarted' | 'active' | 'missed';
export type FaceRunMode = 'demoSafe' | 'visionReady';
export type FaceStageStatus = 'waitingPermission' | 'preparingCamera' | 'cameraPreview' | 'detecting' | 'success' | 'failed' | 'demoMode';

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
