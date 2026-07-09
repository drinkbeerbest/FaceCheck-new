import { common } from '@kit.AbilityKit';
import { promptAction, router } from '@kit.ArkUI';
import image from '@ohos.multimedia.image';
import photoAccessHelper from '@ohos.file.photoAccessHelper';
import { SECTION_TIMES } from '../data/CourseData';
import { ANONYMOUS_USER, AttendanceRecord, AttendanceStats, BadgeItem, Course, CourseSignState, FaceServiceResult, FaceStageStatus, FeedbackItem, FeedbackType, FeedbackTypeOption, FEEDBACK_TYPE_OPTIONS, GEOFENCE_CENTER_NAME, GEOFENCE_RADIUS_METERS, GeofenceCheckResult, NotificationItem, SemesterOption, type UpdateLogItem, type VersionInfo, User, VerificationMethod } from '../models/FaceCheckModels';
import { AccountService } from '../services/AccountService';
import { AttendanceService } from '../services/AttendanceService';
import { CameraPermissionService } from '../services/CameraPermissionService';
import { CourseService } from '../services/CourseService';
import { BadgeService } from '../services/BadgeService';
import { FaceCaptureService, CapturedFaceImage } from '../services/FaceCaptureService';
import { FaceReferenceStore } from '../services/FaceReferenceStore';
import { FaceService } from '../services/FaceService';
import { FeedbackService } from '../services/FeedbackService';
import { NotificationService } from '../services/NotificationService';
import { PreferenceStore } from '../services/PreferenceStore';
import { LocationService } from '../services/LocationService';
import { VersionService } from '../services/VersionService';
import { ReminderService } from '../services/ReminderService';
import EntryFormAbility from '../entryformability/EntryFormAbility';

type MainTab = 'home' | 'records' | 'profile' | 'settings';
type FlowPage = 'main' | 'login' | 'register' | 'enroll' | 'liveness' | 'recognition' | 'schedule' | 'privacy' | 'courseEdit' | 'courseImport' | 'notifications' | 'badge' | 'feedback' | 'version';
type RecordFilter = 'today' | 'week' | 'earlier';
type IconName = 'house' | 'calendar-check' | 'person' | 'gear' | 'bell' | 'book' | 'award' | 'shield' | 'box-arrow-right' | 'person-circle' | 'lock' | 'card' | 'chevron-right' | 'camera' | 'eye' | 'check-circle' | 'x-circle' | 'clock';

interface CourseTypeOption {
  label: string;
  value: string;
}

const BLUE = '#0B67D1';
const BLUE_SOFT = '#E7F1FF';
const BG = '#F5F7FC';
const CARD = '#FFFFFF';
const TEXT = '#151922';
const MUTED = '#697386';
const LINE = '#E6EAF2';
const GREEN = '#18B86B';
const GREEN_SOFT = '#EAFBF2';
const RED = '#F05252';
const RED_SOFT = '#FFF0F0';
const DARK_BG = '#101722';
const DARK_CARD = '#182233';

interface ScheduleDaySegment {
  type: 'gap' | 'course';
  startSec: number;
  endSec: number;
  spanCount: number;
  course?: Course;
  displayColor?: string;
  displayBgColor?: string;
}

const COURSE_TYPE_OPTIONS: CourseTypeOption[] = [
  { label: '理论', value: 'theory' },
  { label: '实验', value: 'lab' },
  { label: '实践', value: 'practice' }
];

@Entry
@Component
struct Index {
  private store: PreferenceStore = new PreferenceStore();
  private captureAttemptSerial: number = 0;
  private previewStartSerial: number = 0;
  private livenessSerial: number = 0;
  private waitingLivenessResult: boolean = false;
  private facePreviewController: XComponentController = new XComponentController();
  private lastBackPressTime: number = 0;

  @State currentTab: MainTab = 'home';
  @State flowPage: FlowPage = 'main';
  @State user: User = ANONYMOUS_USER;
  @State loggedIn: boolean = false;
  @State currentStudentId: string = '';
  @State faceRegistered: boolean = false;
  @State darkMode: boolean = false;
  @State reminderEnabled: boolean = false;
  @State records: AttendanceRecord[] = [];
  @State recordFilter: RecordFilter = 'today';
  @State showAllRecords: boolean = false;
  @State recordStatusFilter: 'all' | 'success' | 'fail' = 'all';
  @State loginStudentId: string = '202440011987';
  @State loginPassword: string = '';
  @State loginError: string = '';
  @State registerStudentId: string = '';
  @State registerName: string = '';
  @State registerClassName: string = '';
  @State registerAcademy: string = '';
  @State registerPassword: string = '';
  @State registerConfirmPassword: string = '';
  @State registerError: string = '';
  @State flowMessage: string = '请正对摄像头，保持光线充足';
  @State livenessAction: string = '请眨眼';
  @State recognitionMessage: string = '等待采集当前人脸样本';
  @State activeCourseId: string = '';
  @State allCourses: Course[] = [];
  @State semesterLabel: string = '';
  @State faceStageStatus: FaceStageStatus = 'waitingPermission';
  @State cameraReady: boolean = false;
  @State cameraPreviewReady: boolean = false;
  @State faceModeLabel: string = FaceService.modeLabel();
  @State demoSignMode: boolean = false;
  @State userAvatarPath: string = '';  // 用户自定义头像路径
  private demoCourseCache: Course | null = null;  // 缓存随机选中的演示课程
  // 课程编辑状态
  @State editCourseId: string = '';
  @State editCourseName: string = '';
  @State editClassroom: string = '';
  @State editTeacher: string = '';
  @State editWeekDay: number = 1;
  @State editSectionStart: number = 1;
  @State editSectionEnd: number = 2;
  @State editWeekRange: string = '1-16周';
  @State editCourseType: string = 'theory';
  @State editCourseError: string = '';
  @State importJsonText: string = '';
  @State importError: string = '';
  // 学年学期选择
  @State showYearSemesterPicker: boolean = false;
  @State pickerYearIndex: number = 0;
  @State pickerSemesterIndex: number = 0;
  private yearOptions: string[] = ['2024-2025', '2025-2026', '2026-2027', '2027-2028'];
  private semesterOptions: string[] = ['1', '2'];
  // 通知状态
  @State notifications: NotificationItem[] = [];
  @State notificationUnreadCount: number = 0;
  // 勋章状态
  @State badges: BadgeItem[] = [];
  // 反馈状态
  @State feedbacks: FeedbackItem[] = [];
  @State feedbackType: string = 'bug';
  @State feedbackTitle: string = '';
  @State feedbackContent: string = '';
  @State feedbackContact: string = '';
  @State feedbackError: string = '';
  @State feedbackTab: string = 'list'; // 'list' | 'write'
  @State versionInfo: VersionInfo | null = null;
  @State checkingUpdate: boolean = false;
  @State versionHasNew: boolean = false;
  @State versionTab: string = 'current'; // 'current' | 'history'

  // 地理围栏与定位状态
  @State lastGeofenceResult: GeofenceCheckResult | null = null;
  @State locationChecking: boolean = false;
  @State locationPermissionGranted: boolean = false;
  @State mockMode: number = 0; // 0=无模拟 1=模拟校内 -1=模拟校外

  aboutToAppear(): void {
    const context = getContext(this) as common.UIAbilityContext;
    this.store.init(context).then(() => {
      // 初始化 AccountService 和 CourseService，加载持久化数据
      AccountService.init(this.store);
      CourseService.init(this.store);
      NotificationService.init(this.store);
      BadgeService.init(this.store);
      FeedbackService.init(this.store);
      VersionService.init(this.store);

      this.loggedIn = this.store.isLoggedIn();
      this.currentStudentId = this.store.currentStudentId();
      const savedUser = AccountService.userByStudentId(this.currentStudentId);
      this.user = this.loggedIn && savedUser ? this.withFaceState(savedUser, this.store.isFaceRegistered(this.currentStudentId)) : ANONYMOUS_USER;
      this.faceRegistered = this.loggedIn ? this.user.faceRegistered : false;
      this.darkMode = this.store.isDarkMode();
      this.records = this.loggedIn ? this.store.records(this.currentStudentId) : [];

      // 加载课程数据
      this.refreshCourses();

      // 加载用户头像
      if (this.loggedIn && this.currentStudentId) {
        this.userAvatarPath = AccountService.getAvatarPath(this.currentStudentId) || '';
      }

      // 加载通知
      this.loadNotifications();

      // 加载勋章
      this.loadBadges();

      // 课前提醒：根据设置刷新当天提醒
      this.reminderEnabled = this.store.isReminderEnabled();
      if (this.loggedIn) {
        ReminderService.scheduleTodayReminders(this.store, context, this.now(), this.demoSignMode);
      }
    });
  }

  private loadBadges(): void {
    if (this.loggedIn && this.currentStudentId.length > 0) {
      this.badges = BadgeService.loadBadges(this.currentStudentId);
    } else {
      this.badges = [];
    }
  }

  onBackPress(): boolean {
    if (this.flowPage !== 'main') {
      if (this.flowPage === 'enroll' || this.flowPage === 'liveness' || this.flowPage === 'recognition') {
        this.stopFacePreview();
      }
      const parent: FlowPage | null = this.getParentPage(this.flowPage);
      if (parent !== null) {
        this.flowPage = parent;
      } else {
        this.flowPage = 'main';
        this.currentTab = 'home';
      }
      return true;
    }

    const now: number = Date.now();
    if (now - this.lastBackPressTime <= 2000) {
      return false;
    }
    this.lastBackPressTime = now;
    this.toast('再按一次退出');
    return true;
  }

  aboutToDisappear(): void {
    FaceCaptureService.releasePreview();
  }

  private getParentPage(page: FlowPage): FlowPage | null {
    if (page === 'courseEdit' || page === 'courseImport') {
      return 'schedule';
    }
    if (page === 'schedule' || page === 'notifications' || page === 'badge' || page === 'privacy' || page === 'feedback') {
      return 'main';
    }
    if (page === 'login' || page === 'register' || page === 'enroll' || page === 'liveness' || page === 'recognition') {
      return 'main';
    }
    return null;
  }

  private loadNotifications(): void {
    if (this.loggedIn && this.currentStudentId.length > 0) {
      let items: NotificationItem[] = NotificationService.loadNotifications(this.currentStudentId);
      if (items.length === 0) {
        items = NotificationService.seedNotifications(this.currentStudentId);
      }
      this.notifications = items;
      this.notificationUnreadCount = NotificationService.unreadCount(this.currentStudentId);
    } else {
      this.notifications = [];
      this.notificationUnreadCount = 0;
    }
  }

  private refreshNotificationState(): void {
    if (this.loggedIn && this.currentStudentId.length > 0) {
      this.notifications = NotificationService.loadNotifications(this.currentStudentId);
      this.notificationUnreadCount = NotificationService.unreadCount(this.currentStudentId);
    }
  }

  onPageShow(): void {
    if (this.waitingLivenessResult && this.flowPage === 'liveness') {
      setTimeout(() => {
        this.fetchLivenessResult('pageShow');
      }, 500);
    }
  }

  build() {
    Stack() {
      if (this.flowPage === 'login') {
        this.LoginPage()
      } else if (this.flowPage === 'register') {
        this.RegisterPage()
      } else if (this.flowPage === 'enroll') {
        this.FaceEnrollPage()
      } else if (this.flowPage === 'liveness') {
        this.LivenessPage()
      } else if (this.flowPage === 'recognition') {
        this.RecognitionPage()
      } else if (this.flowPage === 'schedule') {
        this.SchedulePage()
      } else if (this.flowPage === 'privacy') {
        this.PrivacyPage()
      } else if (this.flowPage === 'courseEdit') {
        this.CourseEditPage()
      } else if (this.flowPage === 'courseImport') {
        this.CourseImportPage()
      } else if (this.flowPage === 'notifications') {
        this.NotificationsPage()
      } else if (this.flowPage === 'badge') {
        this.BadgePage()
      } else if (this.flowPage === 'feedback') {
        this.FeedbackPage()
      } else if (this.flowPage === 'version') {
        this.VersionPage()
      } else {
        this.MainShell()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.pageBg())
  }

  @Builder
  MainShell() {
    Column() {
      this.Header()
      Scroll() {
        Column({ space: 18 }) {
          if (this.currentTab === 'home') {
            this.HomePage()
          } else if (this.currentTab === 'records') {
            this.RecordsPage()
          } else if (this.currentTab === 'profile') {
            this.ProfilePage()
          } else {
            this.SettingsPage()
          }
        }
        .width('100%')
        .constraintSize({ maxWidth: 980 })
        .padding({ left: 24, right: 24, top: 20, bottom: 120 })
      }
      .layoutWeight(1)
      .width('100%')

      this.BottomNavigation()
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  Header() {
    Row() {
      Row({ space: 12 }) {
        this.DefaultAvatar(44)
        Text('FaceCheck')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(BLUE)
      }

      this.NotificationButton()
    }
    .width('100%')
    .height(72)
    .padding({ left: 30, right: 30 })
    .justifyContent(FlexAlign.SpaceBetween)
    .backgroundColor(this.surface())
  }

  @Builder
  HomePage() {
    Column({ space: 18 }) {
      if (!this.loggedIn) {
        this.LoginPromptCard()
      } else {
        this.UserSummaryCard()
      }
      this.HomeActionCard()
      this.TodayCoursesCard()
    }
    .width('100%')
  }

  @Builder
  LoginPromptCard() {
    Column({ space: 16 }) {
      Row({ space: 12 }) {
        Column({ space: 6 }) {
          Text('未登录')
            .fontSize(26)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.primaryText())
          Text('登录后可同步课程、录入人脸并完成签到')
            .fontSize(15)
            .fontColor(this.secondaryText())
        }
        .layoutWeight(1)
        Column({ space: 8 }) {
          Button('立即登录')
            .height(48)
            .backgroundColor(BLUE)
            .fontColor(Color.White)
            .borderRadius(8)
            .onClick(() => this.openLogin())
          Button('注册账号')
            .height(48)
            .backgroundColor(this.surfaceAlt())
            .fontColor(BLUE)
            .border({ width: 1, color: BLUE })
            .borderRadius(8)
            .onClick(() => this.openRegister())
        }
      }
    }
    .width('100%')
    .padding(24)
    .justifyContent(FlexAlign.SpaceBetween)
    .backgroundColor(this.surface())
    .borderRadius(8)
    .shadow(this.cardShadow())
  }

  @Builder
  UserSummaryCard() {
    Row() {
      Row({ space: 18 }) {
        this.DefaultAvatar(72)
        Column({ space: 8 }) {
          Text(this.user.academy)
            .fontSize(14)
            .fontColor(this.secondaryText())
          Text(`${this.user.name}，你好`)
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.primaryText())
          Row({ space: 10 }) {
            this.Pill(this.user.studentId, BLUE, BLUE_SOFT)
            this.Pill(this.user.className.indexOf('软件工程') >= 0 ? '软件工程' : '计算机科学', '#4B5F84', '#EEF2F8')
          }
        }
      }
      this.Pill(this.faceRegistered ? '身份已认证' : '待录入人脸', this.faceRegistered ? BLUE : RED, this.faceRegistered ? BLUE_SOFT : RED_SOFT)
    }
    .width('100%')
    .padding(24)
    .justifyContent(FlexAlign.SpaceBetween)
    .backgroundColor(this.surface())
    .borderRadius(8)
    .shadow(this.cardShadow())
  }

  @Builder
  HomeActionCard() {
    Column({ space: 20 }) {
      this.FaceOrbit(this.faceRegistered ? GREEN : BLUE)
      Text(this.homeTitle())
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.primaryText())
      Text(this.homeDescription())
        .fontSize(16)
        .fontColor(this.secondaryText())
        .textAlign(TextAlign.Center)
        .lineHeight(24)
        .width('78%')

      Button(this.homeButtonText())
        .height(56)
        .width('72%')
        .backgroundColor(this.loggedIn ? BLUE : '#A6B0C2')
        .fontColor(Color.White)
        .borderRadius(8)
        .onClick(() => this.handleHomeAction())

      Row({ space: 18 }) {
        Text('人脸数据仅加密存储于本地设备')
          .fontSize(13)
          .fontColor(this.secondaryText())
        Text('符合校级安全标准')
          .fontSize(13)
          .fontColor(this.secondaryText())
      }
    }
    .width('100%')
    .padding({ top: 36, bottom: 32, left: 24, right: 24 })
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(this.surface())
    .borderRadius(8)
    .shadow(this.cardShadow())
  }

  @Builder
  TodayCoursesCard() {
    Column({ space: 14 }) {
      Row() {
        Text('今日课程')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.primaryText())
        Text(this.todayCourses().length === 0 ? '今日无课程' : `${this.todayCourses().length} 门`)
          .fontSize(14)
          .fontColor(this.todayCourses().length === 0 ? MUTED : BLUE)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)

      if (this.todayCourses().length === 0) {
        this.EmptyState('今天暂无课程安排，可以查看我的课表。')
      } else {
        ForEach(this.todayCourses(), (course: Course) => {
          this.TodayCourseRow(course)
        }, (course: Course) => course.courseId)
      }
    }
    .width('100%')
    .padding(22)
    .backgroundColor(this.surface())
    .borderRadius(8)
    .shadow(this.cardShadow())
  }

  @Builder
  RecordsPage() {
    Column({ space: 18 }) {
      Column({ space: 6 }) {
        Text('签到记录')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.primaryText())
        Text('查看你的签到历史和当前状态。')
          .fontSize(15)
          .fontColor(this.secondaryText())
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Row({ space: 12 }) {
        this.FilterPill('today', '今日')
        this.FilterPill('week', '本周')
        this.FilterPill('earlier', '更早')
      }
      .width('100%')

      this.RecordStatsCard()

      if (this.recordStatusFilter !== 'all') {
        Row({ space: 10 }) {
          Text(this.recordStatusFilter === 'success' ? '已筛选：已到记录' : '已筛选：缺勤记录')
            .fontSize(14)
            .fontColor(this.recordStatusFilter === 'success' ? GREEN : RED)
          Text('清除筛选')
            .fontSize(13)
            .fontColor(BLUE)
            .onClick(() => {
              this.recordStatusFilter = 'all';
            })
        }
        .width('100%')
        .padding({ top: 4, bottom: 4 })
      }

      Column({ space: 12 }) {
        if (this.filteredRecords().length === 0) {
          this.EmptyState('当前筛选下暂无签到记录。')
        } else {
          ForEach(this.visibleRecords(), (record: AttendanceRecord) => {
            this.RecordCard(record)
          }, (record: AttendanceRecord) => record.recordId)
        }
      }
      .width('100%')

      if (this.filteredRecords().length > 3) {
        Button(this.showAllRecords ? '收起记录' : '加载更多记录')
          .height(48)
          .fontColor(BLUE)
          .backgroundColor(BLUE_SOFT)
          .borderRadius(8)
          .onClick(() => {
            this.showAllRecords = !this.showAllRecords;
          })
      }
    }
    .width('100%')
  }

  @Builder
  RecordStatsCard() {
    Row({ space: 16 }) {
      this.StatCard('已到', `${this.stats().successCount}`, GREEN, GREEN_SOFT, () => {
        this.recordStatusFilter = this.recordStatusFilter === 'success' ? 'all' : 'success';
      })
      this.StatCard('缺勤', `${this.stats().failCount}`, RED, RED_SOFT, () => {
        this.recordStatusFilter = this.recordStatusFilter === 'fail' ? 'all' : 'fail';
      })
      this.StatCard('出勤率', this.stats().rateText, BLUE, BLUE_SOFT)
    }
    .width('100%')
  }


  @Builder
  ProfilePage() {
    Column({ space: 18 }) {
      if (!this.loggedIn) {
        this.ProfileLoggedOutCard()
      } else {
        this.ProfileHeroCard()
        Row({ space: 16 }) {
          this.StatCard('总签到次', `${this.stats().successCount}`, BLUE, BLUE_SOFT)
          this.StatCard('总缺勤次', `${this.stats().failCount}`, RED, RED_SOFT)
          this.StatCard('出勤率', this.stats().rateText, GREEN, GREEN_SOFT)
        }
        .width('100%')
        this.ProfileMenu()
        Button('退出登录')
          .height(54)
          .width('100%')
          .fontColor(RED)
          .backgroundColor(this.surface())
          .border({ width: 1, color: '#FFD0D0' })
          .borderRadius(8)
          .onClick(() => {
            this.logout();
          })
      }
    }
    .width('100%')
  }

  @Builder
  ProfileHeroCard() {
    Row({ space: 20 }) {
      // 点击头像可以修改
      Stack({ alignContent: Alignment.BottomEnd }) {
        this.DefaultAvatar(96)
        // 添加编辑图标
        Stack({ alignContent: Alignment.Center }) {
          Circle()
            .width(28)
            .height(28)
            .fill(BLUE)
          this.IconBox('camera', 20, 14, '#FFFFFF')
        }
        .onClick(() => {
          if (this.loggedIn) {
            this.selectAvatar();
          }
        })
      }
      .onClick(() => {
        if (this.loggedIn) {
          this.selectAvatar();
        }
      })

      Column({ space: 8 }) {
        Text(this.user.name)
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.primaryText())
        Text(this.user.studentId)
          .fontSize(16)
          .fontColor(this.secondaryText())
        Row({ space: 10 }) {
          this.Pill('计算机科学', '#4B5F84', '#EEF2F8')
          this.Pill('大二', BLUE, BLUE_SOFT)
        }
      }
    }
    .width('100%')
    .padding(26)
    .backgroundColor(this.surface())
    .borderRadius(8)
    .shadow(this.cardShadow())
  }

  @Builder
  ProfileLoggedOutCard() {
    Column({ space: 18 }) {
      this.DefaultAvatar(84)
      Text('未登录')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.primaryText())
      Text('登录后可查看个人资料、出勤统计、我的课表和隐私设置。')
        .fontSize(16)
        .fontColor(this.secondaryText())
        .textAlign(TextAlign.Center)
        .lineHeight(24)
      Column({ space: 12 }) {
        Button('立即登录')
          .height(52)
          .width(220)
          .backgroundColor(BLUE)
          .fontColor(Color.White)
          .borderRadius(8)
          .onClick(() => this.openLogin())
        Button('注册账号')
          .height(52)
          .width(220)
          .backgroundColor(this.surfaceAlt())
          .fontColor(BLUE)
          .border({ width: 1, color: BLUE })
          .borderRadius(8)
          .onClick(() => this.openRegister())
      }
    }
    .width('100%')
    .padding(34)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(this.surface())
    .borderRadius(8)
    .shadow(this.cardShadow())
  }


  @Builder
  ProfileMenu() {
    Column() {
      this.MenuRow('book', '我的课表', '查看本学期课程', 'schedule')
      Divider().color(LINE)
      this.MenuRow('award', '我的勋章', '连续签到与出勤成就', 'badge')
      Divider().color(LINE)
      this.MenuRow('shield', '隐私政策', '了解人脸数据本地存储策略', 'privacy')
    }
    .width('100%')
    .backgroundColor(this.surface())
    .borderRadius(8)
    .shadow(this.cardShadow())
  }

  @Builder
  SettingsPage() {
    Column({ space: 18 }) {
      Row() {
        Row({ space: 14 }) {
          this.DefaultAvatar(56)
          Column({ space: 4 }) {
            Text(this.loggedIn ? this.user.name : '未登录')
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.primaryText())
            Text(this.loggedIn ? '账号与本地数据已启用' : '登录以同步数据')
              .fontSize(14)
              .fontColor(this.secondaryText())
          }
        }
        Button(this.loggedIn ? '已登录' : '立即登录')
          .height(44)
          .backgroundColor(this.loggedIn ? BLUE_SOFT : BLUE)
          .fontColor(this.loggedIn ? BLUE : Color.White)
          .borderRadius(8)
          .enabled(!this.loggedIn)
          .onClick(() => this.openLogin())
      }
    .width('100%')
    .padding(22)
    .justifyContent(FlexAlign.SpaceBetween)
    .backgroundColor(this.surface())
    .borderRadius(8)
    .shadow(this.cardShadow())

      if (!this.loggedIn) {
        Row({ space: 14 }) {
          this.IconBox('person-circle', 40, 30, BLUE)
          Column({ space: 4 }) {
            Text('注册账号')
              .fontSize(17)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.primaryText())
            Text('创建新的校园账号')
              .fontSize(13)
              .fontColor(this.secondaryText())
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          Text('去注册')
            .fontSize(14)
            .fontColor(BLUE)
            .width(58)
            .textAlign(TextAlign.End)
        }
        .width('100%')
        .padding(18)
        .justifyContent(FlexAlign.SpaceBetween)
        .backgroundColor(this.surface())
        .borderRadius(8)
        .shadow(this.cardShadow())
        .onClick(() => this.openRegister())
      }

      Column({ space: 12 }) {
        Text('系统设置')
          .fontSize(16)
          .fontColor(this.secondaryText())
          .width('100%')
        this.SettingsRow('bell', '通知管理', '课程开始前提醒', false, () => this.openNotifications())
        this.SettingsToggleRow()
        this.ReminderToggleRow()
        this.DemoSignWindowRow()
        this.LocationStatusRow()
        this.MockLocationRow()
        this.GeofenceInfoRow()
      }
      .width('100%')

      this.FaceDataSettingsCard()

      Column({ space: 12 }) {
        Text('关于我们')
          .fontSize(16)
          .fontColor(this.secondaryText())
          .width('100%')
        this.SettingsRow('check-circle', '版本更新', this.versionSubtitle(), false, () => this.openVersion())
        this.SettingsRow('person', '反馈建议', '提交反馈与查看历史', false, () => this.openFeedback())
      }
      .width('100%')

      Button('退出登录')
        .height(54)
        .width('100%')
        .fontColor(RED)
        .backgroundColor(this.surface())
        .border({ width: 1, color: '#FFD0D0' })
        .borderRadius(8)
        .onClick(() => {
          this.logout();
        })
    }
    .width('100%')
  }

  @Builder
  LoginPage() {
    Column() {
      this.AuthHeader()
      Column({ space: 22 }) {
        Column({ space: 8 }) {
          Text('欢迎回来')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.primaryText())
          Text('请登录以继续使用校园面部识别系统')
            .fontSize(16)
            .fontColor(this.secondaryText())
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        this.InputBlock('card', '学号', '请输入您的学号', this.loginStudentId, false)
        this.InputBlock('lock', '密码', '请输入密码', this.loginPassword, true)

        if (this.loginError.length > 0) {
          Text(this.loginError)
            .fontSize(14)
            .fontColor(RED)
            .width('100%')
        }

        Button('登录')
          .height(56)
          .width('100%')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .backgroundColor(BLUE)
          .borderRadius(8)
          .onClick(() => {
            this.login();
          })

        Divider().color(LINE)
        Row({ space: 24 }) {
          Text('遇到问题？提交反馈')
            .fontSize(15)
            .fontColor(BLUE)
            .onClick(() => this.toast('登录后可在设置页提交反馈建议'))
          Text('还没有账号？立即注册')
            .fontSize(15)
            .fontColor(BLUE)
            .onClick(() => this.openRegister())
        }
        .justifyContent(FlexAlign.SpaceBetween)
        .width('100%')
      }
      .width('52%')
      .constraintSize({ minWidth: 340, maxWidth: 640 })
      .padding(34)
      .backgroundColor(this.surface())
      .borderRadius(8)
      .shadow(this.cardShadow())
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(this.pageBg())
  }

  @Builder
  RegisterPage() {
    Column() {
      this.AuthHeader()
      Column({ space: 22 }) {
        Column({ space: 8 }) {
          Text('创建新账号')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.primaryText())
          Text('注册校园人脸识别系统账号')
            .fontSize(16)
            .fontColor(this.secondaryText())
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        this.InputBlock('card', '学号', '请输入您的学号', this.registerStudentId, false, (input: string) => {
          this.registerStudentId = input;
          this.registerError = '';
        })
        this.InputBlock('person-circle', '姓名', '请输入真实姓名', this.registerName, false, (input: string) => {
          this.registerName = input;
          this.registerError = '';
        })
        this.InputBlock('book', '班级', '例如：24软件工程', this.registerClassName, false, (input: string) => {
          this.registerClassName = input;
          this.registerError = '';
        })
        this.InputBlock('award', '学院', '请输入所在学院', this.registerAcademy, false, (input: string) => {
          this.registerAcademy = input;
          this.registerError = '';
        })
        this.InputBlock('lock', '密码', '请输入密码（至少6位）', this.registerPassword, true, (input: string) => {
          this.registerPassword = input;
          this.registerError = '';
        })
        this.InputBlock('lock', '确认密码', '请再次输入密码', this.registerConfirmPassword, true, (input: string) => {
          this.registerConfirmPassword = input;
          this.registerError = '';
        })

        if (this.registerError.length > 0) {
          Text(this.registerError)
            .fontSize(14)
            .fontColor(RED)
            .width('100%')
        }

        Button('注册')
          .height(56)
          .width('100%')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .backgroundColor(BLUE)
          .borderRadius(8)
          .onClick(() => {
            this.register();
          })

        Divider().color(LINE)
        Row({ space: 24 }) {
          Text('已有账号？立即登录')
            .fontSize(15)
            .fontColor(BLUE)
            .onClick(() => this.openLogin())
        }
        .justifyContent(FlexAlign.SpaceBetween)
        .width('100%')
      }
      .width('52%')
      .constraintSize({ minWidth: 340, maxWidth: 640 })
      .padding(34)
      .backgroundColor(this.surface())
      .borderRadius(8)
      .shadow(this.cardShadow())
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(this.pageBg())
  }

  @Builder
  FaceEnrollPage() {
    this.ImmersiveFacePage('人脸录入', this.flowMessage, '拍摄基准人脸图', 'enroll', false)
  }

  @Builder
  LivenessPage() {
    this.ImmersiveFacePage('活体检测', this.livenessAction, '开始活体检测', 'liveness', true)
  }

  @Builder
  RecognitionPage() {
    this.ImmersiveFacePage('上课识别', this.recognitionMessage, '拍摄当前人脸并比对', 'recognition', true)
  }

  @Builder
  ImmersiveFacePage(title: string, message: string, buttonText: string, stage: FlowPage, closeShot: boolean) {
    Stack() {
      this.CameraPreviewSurface(closeShot)

      Column() {
        Row() {
          Text('返回')
            .fontSize(15)
            .fontColor(Color.White)
            .padding({ left: 16, right: 16, top: 10, bottom: 10 })
            .backgroundColor('#304056')
            .borderRadius(8)
            .onClick(() => this.returnFromFaceFlow())
          Text('FaceCheck')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
          this.DefaultAvatar(44)
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .padding({ left: 24, right: 24, top: 20 })

        Blank()
          .hitTestBehavior(HitTestMode.Transparent)

        Column({ space: 24 }) {
          Text(title)
            .fontSize(30)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)

          Row({ space: 10 }) {
            this.Pill(this.faceStageLabelFor(stage), '#FFFFFF', this.faceStageColor())
            Text(this.faceStageModeText(stage))
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#D9E8FF')
          }
          .padding({ left: 14, right: 14, top: 10, bottom: 10 })
          .backgroundColor('#101722CC')
          .borderRadius(8)

          Stack() {
            Column()
              .width(closeShot ? 320 : 420)
              .height(closeShot ? 420 : 440)
              .borderRadius(closeShot ? 150 : 8)
              .border({ width: 2, color: this.cameraPreviewReady ? '#2D89FF' : '#7EAFFF' })
              .hitTestBehavior(HitTestMode.Transparent)
            Column()
              .width(closeShot ? 250 : 330)
              .height(closeShot ? 330 : 300)
              .borderRadius(closeShot ? 120 : 8)
              .border({ width: 3, color: '#0D77FF' })
              .hitTestBehavior(HitTestMode.Transparent)
          }
          .hitTestBehavior(HitTestMode.Transparent)

          Text(message)
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
            .padding({ left: 22, right: 22, top: 12, bottom: 12 })
            .backgroundColor('#25354D')
            .borderRadius(8)

          Button(buttonText)
            .height(54)
            .width(260)
            .fontColor(Color.White)
            .backgroundColor(this.faceActionEnabled() ? (this.faceStageStatus === 'failed' ? RED : BLUE) : MUTED)
            .borderRadius(8)
            .enabled(this.faceActionEnabled())
            .onClick(() => this.handleFaceStageAction(stage))
        }
        .alignItems(HorizontalAlign.Center)

        Blank()
          .hitTestBehavior(HitTestMode.Transparent)

        Text(`${this.faceModeLabel}：参考人脸图仅保存在本机沙箱，清除后不会保留。`)
          .fontSize(13)
          .fontColor('#B8C4D8')
          .margin({ bottom: 28 })
      }
      .width('100%')
      .height('100%')
    }
  }

  @Builder
  CameraPreviewSurface(closeShot: boolean) {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(DARK_BG)
        .hitTestBehavior(HitTestMode.Transparent)
      if (this.cameraReady) {
        XComponent({ id: 'facecheck-camera-preview', type: XComponentType.SURFACE, controller: this.facePreviewController })
          .width('100%')
          .height('100%')
          .opacity(1)
          .hitTestBehavior(HitTestMode.Transparent)
      }
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.cameraPreviewReady ? '#00142733' : (this.cameraReady ? '#00142799' : '#101722'))
        .hitTestBehavior(HitTestMode.Transparent)
      Column()
        .width(closeShot ? 520 : 680)
        .height(closeShot ? 520 : 480)
        .borderRadius(closeShot ? 260 : 8)
        .border({ width: 1, color: this.cameraReady ? '#2D89FF' : '#304056' })
        .hitTestBehavior(HitTestMode.Transparent)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  SchedulePage() {
    Column() {
      this.AuthHeader()
      if (this.showYearSemesterPicker) {
        this.YearSemesterPicker()
      }
      Scroll() {
        Column({ space: 16 }) {
          Row() {
            this.SectionTitle('我的课表', this.semesterLabel)
            Row({ space: 10 }) {
              Button('学期')
                .fontSize(14)
                .height(36)
                .backgroundColor(this.surfaceAlt())
                .fontColor(this.secondaryText())
                .onClick(() => {
                  const yrIdx = this.yearOptions.indexOf(CourseService.year);
                  const semIdx = this.semesterOptions.indexOf(CourseService.semester);
                  this.pickerYearIndex = yrIdx >= 0 ? yrIdx : 0;
                  this.pickerSemesterIndex = semIdx >= 0 ? semIdx : 0;
                  this.showYearSemesterPicker = true;
                })
              Button('导入')
                .fontSize(14)
                .height(36)
                .backgroundColor(BLUE_SOFT)
                .fontColor(BLUE)
                .onClick(() => {
                  this.importJsonText = '';
                  this.importError = '';
                  this.flowPage = 'courseImport';
                })
              Button('添加')
                .fontSize(14)
                .height(36)
                .backgroundColor(BLUE)
                .fontColor(Color.White)
                .onClick(() => {
                  this.resetCourseEditForm();
                  this.flowPage = 'courseEdit';
                })
            }
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)
          Text('长按或双击可编辑或删除课程，点击空白处可新增')
            .fontSize(12)
            .fontColor(MUTED)
            .width('100%')
            .padding({ bottom: 4 })
          this.ScheduleTable()
          Row() {
            this.SectionTitle('课程列表', '长按或双击可编辑或删除')
            Button('新增课程')
              .fontSize(14)
              .height(36)
              .backgroundColor(BLUE)
              .fontColor(Color.White)
              .borderRadius(8)
              .padding({ left: 16, right: 16 })
              .onClick(() => {
                this.resetCourseEditForm();
                this.flowPage = 'courseEdit';
              })
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)
          .alignItems(VerticalAlign.Center)
          ForEach([...this.allCourses].sort((a: Course, b: Course) => {
            if (a.weekDay !== b.weekDay) {
              return a.weekDay - b.weekDay;
            }
            return a.sectionStart - b.sectionStart;
          }), (course: Course) => {
            this.CourseRow(course)
          }, (course: Course) => course.courseId)
        }
        .width('100%')
        .constraintSize({ maxWidth: 1040 })
        .padding({ left: 24, right: 24, top: 20, bottom: 40 })
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(this.pageBg())
  }

  @Builder
  PrivacyPage() {
    Column() {
      this.AuthHeader()
      Column({ space: 18 }) {
        Text('隐私政策')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.primaryText())
          .width('100%')
        Text('FaceCheck 会请求摄像头权限，用于人脸录入、交互式活体检测和刷脸签到。录入时会在应用本机沙箱保存一份经过混淆处理的参考人脸图，仅用于端侧比对，不上传到服务器，也不会写入签到记录。你可以在设置页随时清除本机人脸数据，清除后需要重新录入。')
          .fontSize(17)
          .fontColor(this.secondaryText())
          .lineHeight(28)
          .width('100%')
      }
      .width('70%')
      .constraintSize({ minWidth: 340, maxWidth: 760 })
      .padding(30)
      .backgroundColor(this.surface())
      .borderRadius(8)
      .shadow(this.cardShadow())
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(this.pageBg())
  }

  @Builder
  AuthHeader() {
    Row() {
      Text('返回')
        .fontSize(16)
        .fontColor(this.primaryText())
        .padding({ left: 16, right: 16, top: 10, bottom: 10 })
        .backgroundColor(this.surfaceAlt())
        .borderRadius(8)
        .onClick(() => this.flowPage = 'main')
      Text('FaceCheck')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor(BLUE)
      this.DefaultAvatar(48)
    }
    .width('100%')
    .height(92)
    .padding({ left: 26, right: 26 })
    .justifyContent(FlexAlign.SpaceBetween)
  }

  @Builder
  BottomNavigation() {
    Row() {
      this.NavItem('home', '首页')
      this.NavItem('records', '记录')
      this.NavItem('profile', '个人')
      this.NavItem('settings', '设置')
    }
    .width('100%')
    .height(82)
    .padding({ left: 22, right: 22, top: 10, bottom: 10 })
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.surface())
  }

  @Builder
  NavItem(tab: MainTab, label: string) {
    Column({ space: 6 }) {
      this.IconBox(this.navIconName(tab), 32, 28, this.currentTab === tab ? '#FFFFFF' : this.secondaryText())
      Text(label)
        .fontSize(14)
        .fontColor(this.currentTab === tab ? Color.White : this.primaryText())
    }
    .width(120)
    .height(58)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .borderRadius(8)
    .backgroundColor(this.currentTab === tab ? BLUE : this.surface())
    .onClick(() => {
      this.currentTab = tab;
      this.showAllRecords = false;
    })
  }

  @Builder
  AppIcon(name: IconName, size: number, color: string) {
    Image(this.iconResource(name))
      .width(size)
      .height(size)
      .objectFit(ImageFit.Contain)
      .renderMode(ImageRenderMode.Template)
      .fillColor(color)
      .interpolation(ImageInterpolation.High)
  }

  private iconResource(name: IconName): Resource {
    if (name === 'house') {
      return $r('app.media.icon_house');
    }
    if (name === 'calendar-check') {
      return $r('app.media.icon_calendar_check');
    }
    if (name === 'person') {
      return $r('app.media.icon_person');
    }
    if (name === 'gear') {
      return $r('app.media.icon_gear');
    }
    if (name === 'bell') {
      return $r('app.media.icon_bell');
    }
    if (name === 'book') {
      return $r('app.media.icon_book');
    }
    if (name === 'award') {
      return $r('app.media.icon_award');
    }
    if (name === 'shield') {
      return $r('app.media.icon_shield');
    }
    if (name === 'person-circle') {
      return $r('app.media.icon_person_circle');
    }
    if (name === 'lock') {
      return $r('app.media.icon_lock');
    }
    if (name === 'card') {
      return $r('app.media.icon_card');
    }
    if (name === 'camera') {
      return $r('app.media.icon_camera');
    }
    if (name === 'check-circle') {
      return $r('app.media.icon_check_circle');
    }
    return $r('app.media.icon_clock');
  }

  @Builder
  IconBox(name: IconName, boxSize: number, iconSize: number, color: string) {
    Stack({ alignContent: Alignment.Center }) {
      this.AppIcon(name, iconSize, color)
    }
    .width(boxSize)
    .height(boxSize)
  }

  @Builder
  IconButton(name: IconName, label: string, action: () => void) {
    Row({ space: 8 }) {
      this.IconBox(name, 28, 22, MUTED)
      Text(label)
        .fontSize(14)
        .fontColor(MUTED)
    }
    .height(44)
    .padding({ left: 14, right: 14 })
    .borderRadius(8)
    .backgroundColor(this.surfaceAlt())
    .onClick(action)
  }

  @Builder
  NotificationButton() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Row({ space: 8 }) {
        this.IconBox('bell', 28, 22, MUTED)
        Text('通知')
          .fontSize(14)
          .fontColor(MUTED)
      }
      .height(44)
      .padding({ left: 14, right: 14 })
      .borderRadius(8)
      .backgroundColor(this.surfaceAlt())
      .onClick(() => this.openNotifications())

      if (this.notificationUnreadCount > 0) {
        Text(`${this.notificationUnreadCount}`)
          .fontSize(11)
          .fontColor('#FFFFFF')
          .fontWeight(FontWeight.Bold)
          .width(18)
          .height(18)
          .textAlign(TextAlign.Center)
          .backgroundColor(RED)
          .borderRadius(9)
          .margin({ top: -6, right: -6 })
      }
    }
    .height(44)
  }

  @Builder
  DefaultAvatar(size: number) {
    Stack() {
      if (this.loggedIn && this.userAvatarPath && this.userAvatarPath.length > 0) {
        // 显示用户自定义头像
        Image(this.userAvatarPath)
          .width(size)
          .height(size)
          .borderRadius(size / 2)
          .objectFit(ImageFit.Cover)
          .border({ width: 2, color: BLUE })
      } else {
        // 显示默认头像
        Column()
          .width(size)
          .height(size)
          .borderRadius(size / 2)
          .backgroundColor(BLUE_SOFT)
          .border({ width: 1, color: '#D6E6FF' })
        this.IconBox('person-circle', size, Math.max(22, Math.floor(size * 0.72)), BLUE)
      }
    }
    .width(size)
    .height(size)
  }

  @Builder
  SectionTitle(title: string, description: string) {
    Column({ space: 4 }) {
      Text(title)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.primaryText())
      Text(description)
        .fontSize(14)
        .fontColor(this.secondaryText())
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  YearSemesterPicker() {
    Column() {
      Column({ space: 18 }) {
        Text('选择学年学期')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.primaryText())
          .width('100%')

        Column({ space: 8 }) {
          Text('学年')
            .fontSize(16)
            .fontColor(this.primaryText())
            .width('100%')
          Row({ space: 10 }) {
            ForEach(this.yearOptions, (year: string, index: number) => {
              Text(year)
                .fontSize(14)
                .fontWeight(this.pickerYearIndex === index ? FontWeight.Bold : FontWeight.Normal)
                .fontColor(this.pickerYearIndex === index ? '#FFFFFF' : this.secondaryText())
                .textAlign(TextAlign.Center)
                .padding({ left: 14, right: 14, top: 8, bottom: 8 })
                .backgroundColor(this.pickerYearIndex === index ? BLUE : this.surfaceAlt())
                .borderRadius(8)
                .onClick(() => {
                  this.pickerYearIndex = index;
                })
            }, (year: string) => year)
          }
          .width('100%')
        }
        .width('100%')

        Column({ space: 8 }) {
          Text('学期')
            .fontSize(16)
            .fontColor(this.primaryText())
            .width('100%')
          Row({ space: 10 }) {
            ForEach([{ label: '第1学期', value: '1' } as SemesterOption, { label: '第2学期', value: '2' } as SemesterOption],
            (item: SemesterOption, index: number) => {
              Text(item.label)
                .fontSize(14)
                .fontWeight(this.pickerSemesterIndex === index ? FontWeight.Bold : FontWeight.Normal)
                .fontColor(this.pickerSemesterIndex === index ? '#FFFFFF' : this.secondaryText())
                .textAlign(TextAlign.Center)
                .padding({ left: 14, right: 14, top: 8, bottom: 8 })
                .backgroundColor(this.pickerSemesterIndex === index ? BLUE : this.surfaceAlt())
                .borderRadius(8)
                .onClick(() => {
                  this.pickerSemesterIndex = index;
                })
            }, (item: SemesterOption) => item.value)
          }
          .width('100%')
        }
        .width('100%')

        Row({ space: 10 }) {
          Button('取消')
            .height(48)
            .layoutWeight(1)
            .fontSize(16)
            .backgroundColor(this.surfaceAlt())
            .fontColor(this.secondaryText())
            .borderRadius(8)
            .onClick(() => {
              this.showYearSemesterPicker = false;
            })
          Button('确定')
            .height(48)
            .layoutWeight(1)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .backgroundColor(BLUE)
            .fontColor(Color.White)
            .borderRadius(8)
            .onClick(() => {
              const year = this.yearOptions[this.pickerYearIndex] || '2025-2026';
              const semester = this.semesterOptions[this.pickerSemesterIndex] || '1';
              CourseService.setYearSemester(year, semester);
              this.refreshCourses();
              this.showYearSemesterPicker = false;
            })
        }
        .width('100%')
      }
      .width('100%')
      .padding(24)
      .backgroundColor(this.surface())
      .borderRadius(12)
      .shadow(this.cardShadow())
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#80000000')
    .padding({ left: 32, right: 32 })
    .onClick(() => {
      this.showYearSemesterPicker = false;
    })
    .zIndex(100)
  }

  @Builder
  FaceOrbit(color: string) {
    Stack() {
      Column()
        .width(150)
        .height(150)
        .borderRadius(75)
        .backgroundColor(color === GREEN ? GREEN_SOFT : BLUE_SOFT)
        .border({ width: 2, color })
      Text('FACE')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
    }
  }

  @Builder
  Pill(label: string, color: string, bg: string) {
    Text(label)
      .fontSize(14)
      .fontWeight(FontWeight.Medium)
      .fontColor(color)
      .padding({ left: 12, right: 12, top: 7, bottom: 7 })
      .backgroundColor(bg)
      .borderRadius(8)
  }

  @Builder
  CourseRow(course: Course) {
    Row({ space: 14 }) {
      this.IconBox(course.type === 'lab' ? 'camera' : course.type === 'practice' ? 'award' : 'book', 36, 28, CourseService.courseColor(course.courseId))
      Column({ space: 6 }) {
        Text(course.courseName)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.primaryText())
        Text(`${CourseService.weekdayLabel(course.weekDay)} ${course.section}  ${course.startTime}-${course.endTime}`)
          .fontSize(14)
          .fontColor(this.secondaryText())
        Text(`${course.classroom} · ${course.teacher} · ${course.weekRange}`)
          .fontSize(14)
          .fontColor(this.secondaryText())
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      this.Pill(course.type === 'lab' ? '实验' : course.type === 'practice' ? '实践' : '理论', course.type === 'lab' ? BLUE : GREEN, course.type === 'lab' ? BLUE_SOFT : GREEN_SOFT)
    }
    .width('100%')
    .padding(16)
    .backgroundColor(this.surfaceAlt())
    .borderRadius(8)
    .border({ width: { left: 4 }, color: CourseService.courseColor(course.courseId) })
    .gesture(
      GestureGroup(GestureMode.Parallel,
        LongPressGesture({ duration: 500 })
          .onAction(() => {
            this.showCourseActionDialog(course);
          }),
        TapGesture({ count: 2 })
          .onAction(() => {
            this.showCourseActionDialog(course);
          })
      )
    )
  }

  @Builder
  TodayCourseRow(course: Course) {
    Row({ space: 14 }) {
      this.IconBox('book', 36, 28, BLUE)
      Column({ space: 6 }) {
        Text(course.courseName)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.primaryText())
        Text(`${course.startTime}-${course.endTime}  ${course.classroom} · ${course.teacher}`)
          .fontSize(14)
          .fontColor(this.secondaryText())
        Text(this.courseSignState(course).hint)
          .fontSize(13)
          .fontColor(this.courseSignState(course).color)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      this.SignStatusButton(course)
    }
    .width('100%')
    .padding(16)
    .backgroundColor(this.surfaceAlt())
    .borderRadius(8)
  }

  @Builder
  SignStatusButton(course: Course) {
    Text(this.courseSignState(course).label)
      .fontSize(14)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.courseSignState(course).color)
      .textAlign(TextAlign.Center)
      .width(104)
      .height(40)
      .borderRadius(8)
      .backgroundColor(this.courseSignState(course).background)
      .onClick(() => this.handleCourseSignAction(course))
  }

  @Builder
  ScheduleTable() {
    Column() {
      // 表头行
      Row() {
        Text('节次')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.primaryText())
          .textAlign(TextAlign.Center)
          .height(42)
          .width(48)
          .backgroundColor(this.surfaceAlt())
        ForEach([1, 2, 3, 4, 5, 6, 0], (day: number) => {
          Text(CourseService.weekdayLabel(day))
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.primaryText())
            .textAlign(TextAlign.Center)
            .height(42)
            .layoutWeight(1)
            .backgroundColor(this.surfaceAlt())
        }, (day: number) => `${day}`)
      }
      .width('100%')
      // 主体：左侧节次列 + 7 天课程列 + 统一网格线
      Stack({ alignContent: Alignment.TopStart }) {
        Row() {
          // 左侧节次时间列
          Column() {
            ForEach([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11], (section: number) => {
              Column({ space: 1 }) {
                Text(`${section}`)
                  .fontSize(12)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.primaryText())
                Text(SECTION_TIMES[section])
                  .fontSize(8)
                  .fontColor(this.secondaryText())
                  .textAlign(TextAlign.Center)
              }
              .height(68)
              .width(48)
              .justifyContent(FlexAlign.Center)
              .backgroundColor(this.surfaceAlt())
            }, (section: number) => `${section}`)
          }
          // 7 天课程列
          ForEach([1, 2, 3, 4, 5, 6, 0], (day: number) => {
            Column() {
              ForEach(this.scheduleDaySegments(day), (seg: ScheduleDaySegment) => {
                if (seg.type === 'course' && seg.course) {
                  this.ScheduleCourseBlock(seg)
                } else {
                  Column()
                    .height(68 * seg.spanCount)
                    .width('100%')
                    .backgroundColor(this.surface())
                    .onClick(() => {
                      this.startAddCourseFromBlank(day, seg.startSec);
                    })
                }
              }, (seg: ScheduleDaySegment) => `${day}-${seg.type}-${seg.startSec}`)
            }
            .border({ width: { left: 0.5 }, color: LINE })
            .layoutWeight(1)
          }, (day: number) => `${day}`)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
        // 网格横线覆盖层：11个68px容器，每个顶部画线；末尾补一条底线，共12条线严格对齐68px边界
        Column() {
          ForEach([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10], (i: number) => {
            Column() {
              Divider()
                .color(LINE)
                .strokeWidth(0.5)
                .hitTestBehavior(HitTestMode.None)
              Column()
                .width('100%')
                .layoutWeight(1)
                .hitTestBehavior(HitTestMode.None)
            }
            .height(68)
            .width('100%')
            .hitTestBehavior(HitTestMode.None)
          }, (i: number) => `grid-row-${i}`)
          Divider()
            .color(LINE)
            .strokeWidth(0.5)
            .hitTestBehavior(HitTestMode.None)
        }
        .width('100%')
        .hitTestBehavior(HitTestMode.None)
      }
      .width('100%')
    }
    .width('100%')
    .backgroundColor(this.surface())
    .borderRadius(8)
    .shadow(this.cardShadow())
    .clip(true)
  }

  @Builder
  ScheduleCourseBlock(seg: ScheduleDaySegment) {
    Column() {
      if (seg.course) {
        Text(seg.course.courseName)
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor(seg.displayColor || CourseService.courseColor(seg.course.courseId))
          .maxLines(seg.spanCount >= 3 ? 3 : 2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (seg.spanCount >= 2) {
          Text(seg.course.classroom)
            .fontSize(10)
            .fontColor(this.secondaryText())
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        if (seg.spanCount >= 3) {
          Text(seg.course.teacher)
            .fontSize(9)
            .fontColor(MUTED)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
    }
    .height(68 * seg.spanCount)
    .width('100%')
    .padding({ left: 5, right: 5, top: 3, bottom: 3 })
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .borderRadius(8)
    .backgroundColor(seg.course ? (seg.displayBgColor || CourseService.courseBgColor(seg.course.courseId)) : this.surface())
    .gesture(
      GestureGroup(GestureMode.Parallel,
        LongPressGesture({ duration: 500 })
          .onAction(() => {
            if (seg.course) {
              this.showCourseActionDialog(seg.course);
            }
          }),
        TapGesture({ count: 2 })
          .onAction(() => {
            if (seg.course) {
              this.showCourseActionDialog(seg.course);
            }
          })
      )
    )
  }

  @Builder
  RecordCard(record: AttendanceRecord) {
    Row({ space: 14 }) {
      Text(record.status === 'success' ? 'OK' : 'NO')
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(record.status === 'success' ? GREEN : RED)
        .textAlign(TextAlign.Center)
        .width(46)
        .height(46)
        .borderRadius(23)
        .backgroundColor(record.status === 'success' ? GREEN_SOFT : RED_SOFT)
      Column({ space: 6 }) {
        Text(record.courseName)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.primaryText())
        Text(`${record.time}  ${record.classroom}`)
          .fontSize(14)
          .fontColor(this.secondaryText())
        if (record.status === 'fail') {
          Text(record.message)
            .fontSize(13)
            .fontColor(RED)
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      this.Pill(
        record.status === 'success' ? '成功' : (this.isAbsenceRecord(record) ? '缺勤' : '签到失败'),
        record.status === 'success' ? GREEN : RED,
        record.status === 'success' ? GREEN_SOFT : RED_SOFT
      )
    }
    .width('100%')
    .padding(16)
    .backgroundColor(this.surface())
    .borderRadius(8)
    .border({ width: 1, color: record.status === 'success' ? LINE : '#FFD0D0' })
  }

  @Builder
  StatCard(title: string, value: string, color: string, bg: string, onClick?: () => void) {
    Column({ space: 8 }) {
      Text(title)
        .fontSize(14)
        .fontColor(this.secondaryText())
      Text(value)
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
    }
    .layoutWeight(1)
    .height(112)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(this.surface())
    .border({ width: 1, color: bg })
    .borderRadius(8)
    .shadow(this.cardShadow())
    .onClick(() => {
      if (onClick) {
        onClick();
      }
    })
  }

  @Builder
  FilterPill(filter: RecordFilter, label: string) {
    Text(label)
      .fontSize(15)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.recordFilter === filter ? Color.White : this.primaryText())
      .padding({ left: 18, right: 18, top: 10, bottom: 10 })
      .backgroundColor(this.recordFilter === filter ? BLUE : this.surface())
      .borderRadius(8)
      .onClick(() => {
        this.recordFilter = filter;
        this.showAllRecords = false;
      })
  }

  @Builder
  MenuRow(icon: IconName, title: string, description: string, target: string) {
    Row({ space: 14 }) {
      this.IconBox(icon, 40, 30, BLUE)
      Column({ space: 4 }) {
        Text(title)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.primaryText())
        Text(description)
          .fontSize(13)
          .fontColor(this.secondaryText())
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Text('查看')
        .fontSize(14)
        .fontColor(BLUE)
        .width(42)
        .textAlign(TextAlign.End)
    }
    .width('100%')
    .padding(18)
    .justifyContent(FlexAlign.SpaceBetween)
    .onClick(() => this.openProfileTarget(target))
  }

  @Builder
  SettingsRow(icon: IconName, title: string, description: string, disabled: boolean, onAction?: () => void) {
    Row({ space: 14 }) {
      this.IconBox(icon, 40, 30, BLUE)
      Column({ space: 4 }) {
        Text(title)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.primaryText())
        Text(description)
          .fontSize(13)
          .fontColor(this.secondaryText())
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Text(disabled ? '不可用' : '进入')
        .fontSize(14)
        .fontColor(disabled ? MUTED : BLUE)
        .width(58)
        .textAlign(TextAlign.End)
    }
    .width('100%')
    .padding(18)
    .justifyContent(FlexAlign.SpaceBetween)
    .backgroundColor(this.surface())
    .borderRadius(8)
    .shadow(this.cardShadow())
    .onClick(() => {
      if (onAction) {
        onAction();
      } else {
        this.toast(`${title}将在后续版本开放`);
      }
    })
  }

  @Builder
  SettingsToggleRow() {
    Row({ space: 14 }) {
      this.IconBox('gear', 40, 30, BLUE)
      Column({ space: 4 }) {
        Text('深色模式')
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.primaryText())
        Text('切换演示主题')
          .fontSize(13)
          .fontColor(this.secondaryText())
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Toggle({ type: ToggleType.Switch, isOn: this.darkMode })
        .selectedColor(BLUE)
        .onChange((isOn: boolean) => {
          this.darkMode = isOn;
          this.store.setDarkMode(isOn);
        })
    }
    .width('100%')
    .padding(18)
    .justifyContent(FlexAlign.SpaceBetween)
    .backgroundColor(this.surface())
    .borderRadius(8)
    .shadow(this.cardShadow())
  }

  @Builder
  ReminderToggleRow() {
    Row({ space: 14 }) {
      this.IconBox('bell', 40, 30, BLUE)
      Column({ space: 4 }) {
        Text('课前签到提醒')
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.primaryText())
        Text('课程开始前自动提醒，常异常课程提前更久')
          .fontSize(13)
          .fontColor(this.secondaryText())
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Toggle({ type: ToggleType.Switch, isOn: this.reminderEnabled })
        .selectedColor(BLUE)
        .onChange((isOn: boolean) => {
          this.reminderEnabled = isOn;
          this.store.setReminderEnabled(isOn);
          const ctx = getContext(this) as common.UIAbilityContext;
          if (isOn) {
            ReminderService.scheduleTodayReminders(this.store, ctx, this.now(), this.demoSignMode);
            this.toast('已开启课前提醒');
          } else {
            ReminderService.cancelAll(this.store);
            this.toast('已关闭课前提醒');
          }
        })
    }
    .width('100%')
    .padding(18)
    .justifyContent(FlexAlign.SpaceBetween)
    .backgroundColor(this.surface())
    .borderRadius(8)
    .shadow(this.cardShadow())
  }

  @Builder
  DemoSignWindowRow() {
    Row({ space: 14 }) {
      this.IconBox('clock', 40, 30, BLUE)
      Column({ space: 4 }) {
        Text('演示签到窗口')
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.primaryText())
        Text(this.demoSignMode ? `当前演示：${this.demoCourseName()}` : '使用真实时间判断签到窗口')
          .fontSize(13)
          .fontColor(this.secondaryText())
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Toggle({ type: ToggleType.Switch, isOn: this.demoSignMode })
        .selectedColor(BLUE)
        .onChange((isOn: boolean) => {
          this.demoSignMode = isOn;
          this.showAllRecords = false;
          const ctx = getContext(this) as common.UIAbilityContext;
          if (isOn) {
            // 随机选一节课作为演示（先确定课程，再用于通知和页面显示）
            this.demoCourseCache = null;
            const course = this.demoCourse();  // 先取出，避免后续随机不同课程
            // 演示模式下自动安排提醒以便观察通知效果
            ReminderService.scheduleTodayReminders(this.store, ctx, this.now(), true, course);
            this.toast('已开启演示签到窗口，课前提醒即将弹出');
          } else {
            this.demoCourseCache = null;
            // 取消演示提醒，之后按用户偏好重新安排
            ReminderService.cancelAll(this.store);
            if (this.store.isReminderEnabled() && this.loggedIn) {
              ReminderService.scheduleTodayReminders(this.store, ctx, this.now(), false);
            }
            this.toast('已恢复真实时间');
          }
        })
    }
    .width('100%')
    .padding(18)
    .justifyContent(FlexAlign.SpaceBetween)
    .backgroundColor(this.surface())
    .borderRadius(8)
    .shadow(this.cardShadow())
  }

  @Builder
  LocationStatusRow() {
    Row({ space: 14 }) {
      this.IconBox('house', 40, 30, BLUE)
      Column({ space: 4 }) {
        Text('设备定位检测')
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.primaryText())
        Text(this.locationStatusSubtitle())
          .fontSize(13)
          .fontColor(this.secondaryText())
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Column({ space: 6 }) {
        Button(this.locationChecking ? '检测中…' : '检测位置')
          .height(36)
          .fontSize(13)
          .padding({ left: 14, right: 14 })
          .backgroundColor(this.locationChecking ? '#A6B0C2' : BLUE)
          .fontColor(Color.White)
          .borderRadius(6)
          .enabled(!this.locationChecking)
          .onClick(() => this.handleLocationCheck())
        Button('查看地图')
          .height(36)
          .fontSize(13)
          .padding({ left: 14, right: 14 })
          .backgroundColor('#18B86B')
          .fontColor(Color.White)
          .borderRadius(6)
          .onClick(() => {
            router.pushUrl({ url: 'pages/MapPage' });
          })
      }
    }
    .width('100%')
    .padding(18)
    .justifyContent(FlexAlign.SpaceBetween)
    .backgroundColor(this.surface())
    .borderRadius(8)
    .shadow(this.cardShadow())
  }

  @Builder
  GeofenceInfoRow() {
    if (this.lastGeofenceResult) {
      Column({ space: 12 }) {
        Row({ space: 10 }) {
          Text(this.lastGeofenceResult.inside ? '✓' : '✗')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.lastGeofenceResult.inside ? GREEN : RED)
          Text(this.lastGeofenceResult.inside ? '已在签到区域内' : '不在签到区域内')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.lastGeofenceResult.inside ? GREEN : RED)
        }
        .width('100%')

        Divider()
          .strokeWidth(0.5)
          .color(LINE)

        Column({ space: 6 }) {
          this.LocationInfoItem('目标区域', this.lastGeofenceResult.targetName)
          this.LocationInfoItem('围栏半径', `${this.lastGeofenceResult.radiusMeters} 米`)
          if (this.lastGeofenceResult.distanceMeters >= 0) {
            this.LocationInfoItem('距离校区', LocationService.formatDistance(this.lastGeofenceResult.distanceMeters))
          }
          this.LocationInfoItem('您的定位', this.lastGeofenceResult.userAddress)
        }
        .width('100%')
      }
      .width('100%')
      .padding(18)
      .backgroundColor(this.surface())
      .borderRadius(8)
      .shadow(this.cardShadow())
    }
  }

  @Builder
  MockLocationRow() {
    Row({ space: 14 }) {
      this.IconBox('house', 40, 30, '#F5A623')
      Column({ space: 4 }) {
        Text('模拟位置')
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.primaryText())
        Text(this.mockMode === 0 ? '未启用模拟' : (this.mockMode === 1 ? '已开启：校内位置' : '已开启：校外位置'))
          .fontSize(13)
          .fontColor(this.secondaryText())
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Column({ space: 6 }) {
        Button('模拟校内')
          .height(36)
          .fontSize(13)
          .padding({ left: 14, right: 14 })
          .backgroundColor(this.mockMode === 1 ? '#F5A623' : '#EDEDED')
          .fontColor(this.mockMode === 1 ? Color.White : '#9DA3B0')
          .border({ width: this.mockMode === 1 ? 0 : 1, color: '#D0D5DD' })
          .borderRadius(6)
          .onClick(() => this.handleMockLocation(1))
        Button('模拟校外')
          .height(36)
          .fontSize(13)
          .padding({ left: 14, right: 14 })
          .backgroundColor(this.mockMode === -1 ? '#F05252' : '#EDEDED')
          .fontColor(this.mockMode === -1 ? Color.White : '#9DA3B0')
          .border({ width: this.mockMode === -1 ? 0 : 1, color: '#D0D5DD' })
          .borderRadius(6)
          .onClick(() => this.handleMockLocation(-1))
      }
    }
    .width('100%')
    .padding(18)
    .justifyContent(FlexAlign.SpaceBetween)
    .backgroundColor(this.surface())
    .borderRadius(8)
    .shadow(this.cardShadow())
  }

  @Builder
  LocationInfoItem(label: string, value: string) {
    Row({ space: 8 }) {
      Text(label)
        .fontSize(13)
        .fontColor(this.secondaryText())
        .width(72)
      Text(value)
        .fontSize(13)
        .fontColor(this.primaryText())
        .layoutWeight(1)
        .textAlign(TextAlign.Start)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
  }

  @Builder
  FaceDataSettingsCard() {
    Column({ space: 12 }) {
      Text('人脸与隐私')
        .fontSize(16)
        .fontColor(this.secondaryText())
        .width('100%')
      Row({ space: 14 }) {
        this.IconBox('shield', 40, 30, BLUE)
        Column({ space: 4 }) {
          Text('识别模式')
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.primaryText())
          Text(`${this.faceModeLabel}，沙箱保存混淆参考图`)
            .fontSize(13)
            .fontColor(this.secondaryText())
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        this.Pill(this.cameraReady ? '相机可用' : '等待授权', this.cameraReady ? GREEN : MUTED, this.cameraReady ? GREEN_SOFT : '#EEF2F8')
      }
      .width('100%')
      .padding(18)
      .justifyContent(FlexAlign.SpaceBetween)
      .backgroundColor(this.surface())
      .borderRadius(8)
      .shadow(this.cardShadow())

      Button('清除本机人脸数据')
        .height(50)
        .width('100%')
        .fontColor(RED)
        .backgroundColor(this.surface())
        .border({ width: 1, color: '#FFD0D0' })
        .borderRadius(8)
        .enabled(this.loggedIn && this.faceRegistered)
        .onClick(() => {
          this.clearLocalFaceData();
        })
    }
    .width('100%')
  }

  @Builder
  InputBlock(icon: IconName, label: string, placeholder: string, value: string, password: boolean, onChange?: (input: string) => void) {
    Column({ space: 8 }) {
      Text(label)
        .fontSize(16)
        .fontColor(this.primaryText())
        .width('100%')
      Row({ space: 10 }) {
        this.IconBox(icon, 32, 24, this.secondaryText())
        TextInput({ placeholder, text: value })
          .height(56)
          .fontSize(16)
          .backgroundColor(Color.Transparent)
          .layoutWeight(1)
          .type(password ? InputType.Password : InputType.Normal)
          .onChange((input: string) => {
            if (onChange) {
              onChange(input);
            } else {
              // 默认行为（兼容登录页面）
              if (password) {
                this.loginPassword = input;
              } else {
                this.loginStudentId = input;
              }
              this.loginError = '';
            }
          })
      }
      .height(56)
      .padding({ left: 14, right: 14 })
      .backgroundColor(this.surfaceAlt())
      .borderRadius(8)
    }
    .width('100%')
  }

  @Builder
  EmptyState(text: string) {
    Text(text)
      .fontSize(15)
      .fontColor(this.secondaryText())
      .textAlign(TextAlign.Center)
      .width('100%')
      .padding(24)
      .backgroundColor(this.surfaceAlt())
      .borderRadius(8)
  }

  private async login(): Promise<void> {
    if (this.loginStudentId.trim().length === 0 || this.loginPassword.trim().length === 0) {
      this.loginError = '学号或密码不能为空';
      return;
    }
    const account = AccountService.login(this.loginStudentId.trim(), this.loginPassword.trim());
    if (!account) {
      this.loginError = '学号或密码错误';
      return;
    }
    this.loggedIn = true;
    this.currentStudentId = account.studentId;
    this.faceRegistered = this.store.isFaceRegistered(account.studentId);
    this.user = this.withFaceState(account.user, this.faceRegistered);
    this.records = this.store.records(account.studentId);
    
    // 加载用户头像
    this.userAvatarPath = AccountService.getAvatarPath(account.studentId) || '';
    
    await this.store.setLoggedIn(true);
    await this.store.setCurrentStudentId(account.studentId);
    this.flowPage = 'main';
    this.currentTab = 'home';
    this.loadNotifications();
    this.loadBadges();
    if (BadgeService.checkLoginBadge(account.studentId)) {
      this.toast('解锁勋章：初来乍到');
    } else {
      this.toast('登录成功');
    }
  }

  private async register(): Promise<void> {
    // 验证输入
    if (this.registerStudentId.trim().length === 0) {
      this.registerError = '学号不能为空';
      return;
    }
    if (this.registerName.trim().length === 0) {
      this.registerError = '姓名不能为空';
      return;
    }
    if (this.registerClassName.trim().length === 0) {
      this.registerError = '班级不能为空';
      return;
    }
    if (this.registerAcademy.trim().length === 0) {
      this.registerError = '学院不能为空';
      return;
    }
    if (this.registerPassword.trim().length < 6) {
      this.registerError = '密码长度至少6位';
      return;
    }
    if (this.registerPassword !== this.registerConfirmPassword) {
      this.registerError = '两次输入的密码不一致';
      return;
    }

    // 学号格式验证（11位或12位数字）
    const studentIdRegex = /^\d{11,12}$/;
    if (!studentIdRegex.test(this.registerStudentId.trim())) {
      this.registerError = '学号必须是11位或12位数字';
      return;
    }

    // 调用注册服务
    const success = AccountService.register(
      this.registerStudentId.trim(),
      this.registerName.trim(),
      this.registerClassName.trim(),
      this.registerAcademy.trim(),
      this.registerPassword.trim()
    );

    if (!success) {
      this.registerError = '该学号已注册，请直接登录';
      return;
    }

    // 注册成功，自动登录
    this.loggedIn = true;
    this.currentStudentId = this.registerStudentId.trim();
    this.faceRegistered = false;
    
    const savedUser = AccountService.userByStudentId(this.currentStudentId);
    if (savedUser) {
      this.user = this.withFaceState(savedUser, false);
    }
    
    this.records = [];
    await this.store.setLoggedIn(true);
    await this.store.setCurrentStudentId(this.currentStudentId);
    
    // 清空注册表单
    this.registerStudentId = '';
    this.registerName = '';
    this.registerClassName = '';
    this.registerAcademy = '';
    this.registerPassword = '';
    this.registerConfirmPassword = '';
    this.registerError = '';
    
    this.flowPage = 'main';
    this.currentTab = 'home';
    this.loadNotifications();
    this.toast('注册成功，已自动登录');
  }

  private async selectAvatar(): Promise<void> {
    try {
      const photoSelectOptions: photoAccessHelper.PhotoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
      photoSelectOptions.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      photoSelectOptions.maxSelectNumber = 1;
      
      const photoPicker: photoAccessHelper.PhotoViewPicker = new photoAccessHelper.PhotoViewPicker();
      const result: photoAccessHelper.PhotoSelectResult = await photoPicker.select(photoSelectOptions);
      
      if (result.photoUris && result.photoUris.length > 0) {
        const avatarPath: string = result.photoUris[0];
        this.userAvatarPath = avatarPath;
        
        // 保存到账户
        if (this.loggedIn && this.currentStudentId) {
          AccountService.updateAvatar(this.currentStudentId, avatarPath);
          this.toast('头像更新成功');
        }
      }
    } catch (err) {
      console.error('选择头像失败:', err);
      this.toast('选择头像失败，请重试');
    }
  }

  private openLogin(): void {
    this.loginError = '';
    this.flowPage = 'login';
  }

  private openRegister(): void {
    this.registerError = '';
    this.registerStudentId = '';
    this.registerName = '';
    this.registerClassName = '';
    this.registerAcademy = '';
    this.registerPassword = '';
    this.registerConfirmPassword = '';
    this.flowPage = 'register';
  }

  private async logout(): Promise<void> {
    this.loggedIn = false;
    this.currentStudentId = '';
    this.faceRegistered = false;
    this.records = [];
    this.user = ANONYMOUS_USER;
    await this.store.resetSession();
    this.currentTab = 'home';
    this.flowPage = 'main';
    this.toast('已退出登录');
  }

  private async clearLocalFaceData(): Promise<void> {
    if (!this.loggedIn) {
      this.openLogin();
      return;
    }
    const profile = this.store.faceProfile(this.currentStudentId);
    if (profile && profile.referenceImagePath) {
      await FaceReferenceStore.clearReference(profile.referenceImagePath);
    }
    await this.store.clearFaceProfile(this.currentStudentId);
    this.faceRegistered = false;
    this.user = this.withFaceState(this.user, false);
    this.faceStageStatus = 'waitingPermission';
    this.toast('已清除本机人脸数据');
  }

  /**
   * 签到前校验地理围栏：检查用户是否在华南师范大学南海校区范围内
   * @returns true 表示通过校验可以签到，false 表示被拦截
   */
  private async checkLocationBeforeSign(): Promise<boolean> {
    // 模拟位置：直接使用模拟结果，跳过真实定位
    if (this.mockMode !== 0) {
      const result = this.mockMode === 1
        ? LocationService.mockInsideResult()
        : LocationService.mockOutsideResult();
      this.lastGeofenceResult = result;
      if (!result.inside) {
        promptAction.showDialog({
          title: '不在签到区域内（模拟位置）',
          message: `模拟位置不在签到范围内，无法签到。\n签到范围：${GEOFENCE_CENTER_NAME} 周边 ${GEOFENCE_RADIUS_METERS}米内`,
          buttons: [
            { text: '知道了', color: '#0B67D1' }
          ]
        });
        return false;
      }
      return true;
    }

    // 权限前置检查
    if (!this.locationPermissionGranted) {
      const context = getContext(this) as common.UIAbilityContext;
      const granted = await LocationService.requestLocationPermission(context);
      this.locationPermissionGranted = granted;
      if (!granted) {
        promptAction.showDialog({
          title: '位置权限未授权',
          message: `签到需要在${GEOFENCE_CENTER_NAME}范围内进行，请授权位置权限后重试。`,
          buttons: [
            { text: '我知道了', color: '#0B67D1' }
          ]
        });
        return false;
      }
    }

    this.locationChecking = true;
    const result = await LocationService.checkGeofence();
    this.lastGeofenceResult = result;
    this.locationChecking = false;

    if (!result.inside) {
      const distText = result.distanceMeters >= 0
        ? `（距校约 ${LocationService.formatDistance(result.distanceMeters)}）`
        : '';
      promptAction.showDialog({
        title: '不在签到区域内',
        message: `${result.hint}\n\n您的当前位置：${result.userAddress}\n签到范围：${GEOFENCE_CENTER_NAME} 周边 ${GEOFENCE_RADIUS_METERS}米内${distText}`,
        buttons: [
          { text: '知道了', color: '#0B67D1' }
        ]
      });
      return false;
    }

    return true;
  }

  private async handleHomeAction(): Promise<void> {
    if (!this.loggedIn) {
      this.openLogin();
      return;
    }
    if (!this.faceRegistered) {
      this.startEnrollFlow();
      return;
    }
    const course = CourseService.activeSignCourse(this.records, this.now());
    if (!course) {
      this.toast(this.todayCourses().length === 0 ? '今日无课程' : '当前不在签到时间内');
      return;
    }

    // 地理围栏校验
    if (!await this.checkLocationBeforeSign()) {
      return; // checkLocationBeforeSign 内部已显示提示
    }

    this.activeCourseId = course.courseId;
    this.startLivenessFlow();
  }

  private async handleCourseSignAction(course: Course): Promise<void> {
    const state = this.courseSignState(course);
    if (state.status === 'signed') {
      this.toast('今日该课程已签到');
      return;
    }
    if (!state.canSign) {
      this.toast(state.hint);
      return;
    }
    if (!this.loggedIn) {
      this.openLogin();
      return;
    }
    if (!this.faceRegistered) {
      this.startEnrollFlow();
      return;
    }

    // 地理围栏校验
    if (!await this.checkLocationBeforeSign()) {
      return;
    }

    this.activeCourseId = course.courseId;
    this.startLivenessFlow();
  }

  private startEnrollFlow(): void {
    this.flowMessage = '录入会拍摄一张清晰正脸照片，作为本机基准人脸图保存，可随时清除。';
    this.prepareFaceStage('enroll');
  }

  private startLivenessFlow(): void {
    this.livenessAction = '点击开始后将拉起系统活体检测';
    this.prepareFaceStage('liveness');
  }

  private async prepareFaceStage(stage: FlowPage): Promise<void> {
    if (!this.loggedIn) {
      this.openLogin();
      return;
    }
    if (stage !== 'enroll' && !this.faceRegistered) {
      this.toast('尚未录入人脸，请先完成录入');
      this.startEnrollFlow();
      return;
    }
    this.faceModeLabel = FaceService.modeLabel();
    this.flowPage = stage;
    if (stage === 'liveness') {
      this.cameraReady = false;
      this.cameraPreviewReady = false;
      this.faceStageStatus = 'cameraPreview';
      return;
    }
    const context = getContext(this) as common.UIAbilityContext;
    this.cameraReady = true;
    this.cameraPreviewReady = false;
    this.faceStageStatus = 'preparingCamera';
    const permission = await CameraPermissionService.requestCamera(context);
    if (permission === 'denied') {
      this.cameraReady = false;
      this.cameraPreviewReady = false;
      this.faceStageStatus = 'failed';
      this.flowMessage = '相机权限被拒绝，请授权后重试';
      this.recognitionMessage = '相机权限被拒绝，请授权后重试';
      return;
    }
    this.scheduleFacePreviewStart();
  }

  private returnFromFaceFlow(): void {
    this.stopFacePreview();
    this.flowPage = 'main';
    this.faceStageStatus = 'waitingPermission';
  }

  private faceStageLabel(): string {
    if (this.faceStageStatus === 'waitingPermission') {
      return '等待授权';
    }
    if (this.faceStageStatus === 'preparingCamera') {
      return '准备相机';
    }
    if (this.faceStageStatus === 'cameraPreview') {
      return '等待采集';
    }
    if (this.faceStageStatus === 'detecting') {
      return '检测中';
    }
    if (this.faceStageStatus === 'success') {
      return '检测成功';
    }
    if (this.faceStageStatus === 'failed') {
      return '检测失败';
    }
    return 'Demo 模式';
  }

  private faceStageLabelFor(stage: FlowPage): string {
    if (stage === 'liveness' && this.faceStageStatus === 'cameraPreview') {
      return '等待检测';
    }
    return this.faceStageLabel();
  }

  private faceStageModeText(stage: FlowPage): string {
    if (stage === 'liveness') {
      return 'SYSTEM LIVENESS';
    }
    return this.cameraReady ? 'SYSTEM CAMERA' : 'DEMO FALLBACK';
  }

  private faceStageColor(): string {
    if (this.faceStageStatus === 'success') {
      return GREEN;
    }
    if (this.faceStageStatus === 'failed') {
      return RED;
    }
    if (this.faceStageStatus === 'demoMode') {
      return '#6E7FA3';
    }
    return BLUE;
  }

  private faceActionEnabled(): boolean {
    return this.faceStageStatus !== 'preparingCamera' && this.faceStageStatus !== 'detecting';
  }

  private scheduleFacePreviewStart(): void {
    this.previewStartSerial += 1;
    const token = this.previewStartSerial;
    setTimeout(() => {
      this.startFacePreview(token);
    }, 800);
  }

  private async startFacePreview(token?: number): Promise<void> {
    const effectiveToken = token !== undefined ? token : this.previewStartSerial;
    if (this.flowPage !== 'enroll' && this.flowPage !== 'recognition') {
      return;
    }
    const context = getContext(this) as common.UIAbilityContext;

    // 阶段一：等待 XComponent surface ID 就绪（最多 12 次 × 250ms）
    let surfaceId = '';
    for (let retry = 0; retry < 12; retry++) {
      if (effectiveToken !== this.previewStartSerial) {
        return;
      }
      surfaceId = this.currentFaceSurfaceId();
      if (surfaceId && surfaceId.length > 0) {
        break;
      }
      this.faceStageStatus = 'preparingCamera';
      await this.delayMs(250);
    }
    if (!surfaceId || surfaceId.length === 0) {
      this.faceStageStatus = 'failed';
      this.cameraPreviewReady = false;
      this.cameraReady = false;
      this.flowMessage = '相机预览 surface 未就绪，请返回后重试';
      this.recognitionMessage = '相机预览 surface 未就绪，请返回后重试';
      return;
    }

    // 阶段二：启动前置相机预览（最多 3 次 × 400ms）
    for (let retry = 0; retry < 3; retry++) {
      if (effectiveToken !== this.previewStartSerial) {
        return;
      }
      const ready = await FaceCaptureService.startPreview(context, surfaceId);
      if (ready) {
        this.cameraPreviewReady = true;
        this.cameraReady = true;
        this.faceStageStatus = 'cameraPreview';
        return;
      }
      if (retry < 2) {
        this.faceStageStatus = 'preparingCamera';
        await this.delayMs(400);
      }
    }
    this.cameraPreviewReady = false;
    this.cameraReady = false;
    this.faceStageStatus = 'failed';
    this.flowMessage = '前置摄像头预览启动失败，请检查权限后重试';
    this.recognitionMessage = '前置摄像头预览启动失败，请检查权限后重试';
  }

  private delayMs(ms: number): Promise<void> {
    return new Promise<void>(resolve => setTimeout(resolve, ms));
  }

  private stopFacePreview(): void {
    this.previewStartSerial += 1;
    this.cameraPreviewReady = false;
    this.cameraReady = false;
    FaceCaptureService.releasePreview();
  }

  private currentFaceSurfaceId(): string {
    try {
      return this.facePreviewController.getXComponentSurfaceId();
    } catch (err) {
      return '';
    }
  }

  private async recordFailedAttendance(message: string, method: VerificationMethod = 'cameraMock'): Promise<void> {
    const course = this.activeCourseId.length > 0 ? CourseService.courseById(this.activeCourseId) : CourseService.activeSignCourse(this.records, this.now());
    if (!course || !this.loggedIn) {
      return;
    }
    const record = AttendanceService.createFailureRecord(this.user.userId, course, message, this.now(), method);
    this.records = [record, ...this.records];
    await this.store.saveRecords(this.currentStudentId, this.records);
    const notif = NotificationService.createSignFailedNotification(this.currentStudentId, course.courseName, course.courseId, message);
    NotificationService.addNotification(this.currentStudentId, notif);
    this.refreshNotificationState();
  }

  private async finishEnroll(): Promise<void> {
    this.faceStageStatus = 'detecting';
    const context = getContext(this) as common.UIAbilityContext;
    const surfaceId = this.currentFaceSurfaceId();
    if (!this.cameraPreviewReady || surfaceId.length === 0) {
      this.flowMessage = '相机预览尚未就绪，正在重试';
      await this.startFacePreview();
    }
    this.flowMessage = '正在拍摄并保存本机基准人脸图';
    const captureToken = this.armCaptureWatchdog('前置摄像头采集超时，请返回后重试。');
    const capture = await FaceCaptureService.captureFace(context, this.currentFaceSurfaceId());
    if (!this.isCurrentCaptureAttempt(captureToken)) {
      return;
    }
    this.clearCaptureWatchdog(captureToken);
    if (!capture) {
      this.faceStageStatus = 'failed';
      this.flowMessage = '未获取到人脸图像，请重新采集';
      return;
    }
    let referencePath = '';
    let digest = '';
    try {
      referencePath = await FaceReferenceStore.saveReference(context, this.currentStudentId, capture.buffer);
      digest = FaceReferenceStore.digest(referencePath);
    } catch (err) {
      this.faceStageStatus = 'failed';
      this.flowMessage = '本机参考图保存失败，请重试';
      return;
    }
    const result = await FaceService.enroll(this.currentStudentId, referencePath, digest);
    this.flowMessage = result.message;
    if (result.success) {
      this.faceStageStatus = 'success';
      this.faceRegistered = true;
      await this.store.setFaceRegistered(this.currentStudentId, true);
      if (result.profile) {
        await this.store.saveFaceProfile(this.currentStudentId, result.profile);
      }
      this.user = this.withFaceState(this.user, true);
      this.stopFacePreview();
      this.flowPage = 'main';
      if (BadgeService.checkFaceEnrolledBadge(this.currentStudentId)) {
        this.toast('解锁勋章：面貌一新');
      } else {
        this.toast('人脸录入成功');
      }
    } else {
      if (referencePath.length > 0) {
        await FaceReferenceStore.clearReference(referencePath);
      }
      this.faceStageStatus = 'failed';
    }
  }

  private async handleFaceStageAction(stage: FlowPage): Promise<void> {
    if (this.faceStageStatus === 'waitingPermission' || (this.faceStageStatus === 'failed' && !this.cameraReady)) {
      this.prepareFaceStage(stage);
      return;
    }
    try {
      if (stage === 'enroll') {
        await this.finishEnroll();
      } else if (stage === 'liveness') {
        await this.finishLiveness();
      } else if (stage === 'recognition') {
        await this.finishRecognition();
      }
    } catch (err) {
      console.error('Index', `faceStageAction ${stage} 异常: ${JSON.stringify(err)}`);
      this.faceStageStatus = 'failed';
      if (stage === 'recognition') {
        this.recognitionMessage = '操作异常，请返回重试';
      } else if (stage === 'enroll') {
        this.flowMessage = '操作异常，请返回重试';
      }
    }
  }

  private openProfileTarget(target: string): void {
    if (target === 'schedule') {
      this.refreshCourses();
      this.flowPage = 'schedule';
    } else if (target === 'privacy') {
      this.flowPage = 'privacy';
    } else if (target === 'badge') {
      if (!this.loggedIn) {
        this.toast('请先登录');
        return;
      }
      this.loadBadges();
      this.flowPage = 'badge';
    } else {
      this.toast('将在后续版本开放');
    }
  }

  private async finishLiveness(): Promise<void> {
    this.livenessSerial += 1;
    const token = this.livenessSerial;
    this.waitingLivenessResult = false;
    this.faceStageStatus = 'detecting';
    this.livenessAction = '正在请求相机权限并启动系统活体检测';
    const context = getContext(this) as common.UIAbilityContext;
    const permission = await CameraPermissionService.requestCamera(context);
    if (permission === 'denied') {
      this.faceStageStatus = 'failed';
      this.livenessAction = '相机权限被拒绝，无法启动活体检测';
      await this.recordFailedAttendance('相机权限被拒绝，无法启动活体检测', FaceService.runMode() === 'visionReady' ? 'face' : 'cameraMock');
      this.toast('请授权相机后重试');
      return;
    }
    this.livenessAction = '系统活体检测已启动，请按提示完成动作';
    this.waitingLivenessResult = true;
    const result = await FaceService.runLiveness();
    await this.handleLivenessResult(result, token, 'callback');
  }

  private async fetchLivenessResult(source: string): Promise<void> {
    if (!this.waitingLivenessResult || this.flowPage !== 'liveness') {
      return;
    }
    const token = this.livenessSerial;
    const result = await FaceService.readLivenessResult();
    await this.handleLivenessResult(result, token, source);
  }

  private async handleLivenessResult(result: FaceServiceResult, token: number, source: string): Promise<void> {
    if (!this.waitingLivenessResult || token !== this.livenessSerial || this.flowPage !== 'liveness') {
      return;
    }
    if (!result.success && source === 'pageShow' && result.message.indexOf('1008302004') >= 0) {
      this.livenessAction = '已返回 App，正在等待系统活体检测结果';
      return;
    }
    this.waitingLivenessResult = false;
    this.livenessSerial += 1;
    if (result.success) {
      this.faceStageStatus = 'success';
      this.livenessAction = `${result.message}（${source}）`;
      this.recognitionMessage = result.message;
      this.toast(result.message);
      await this.prepareFaceStage('recognition');
    } else {
      this.faceStageStatus = 'failed';
      this.livenessAction = result.message;
      await this.recordFailedAttendance(result.message, result.method);
      this.toast(result.message);
    }
  }

  private async finishRecognition(): Promise<void> {
    this.faceStageStatus = 'detecting';
    this.recognitionMessage = '正在拍摄并比对当前人脸';
    const context = getContext(this) as common.UIAbilityContext;
    const profile = this.store.faceProfile(this.currentStudentId);
    if (!profile || !profile.referenceImagePath) {
      this.faceStageStatus = 'failed';
      this.recognitionMessage = '未找到本机人脸参考图，请重新录入人脸';
      return;
    }
    let referencePixelMap: image.PixelMap | undefined;
    let capture: CapturedFaceImage | undefined;
    try {
      try {
        referencePixelMap = await FaceReferenceStore.loadReference(profile.referenceImagePath);
      } catch (err) {
        this.faceStageStatus = 'failed';
        this.recognitionMessage = '本机人脸参考图读取失败，请重新录入';
        return;
      }
      this.recognitionMessage = '请拍摄当前人脸用于和本地基准图比对';
      if (!this.cameraPreviewReady || this.currentFaceSurfaceId().length === 0) {
        this.recognitionMessage = '相机预览尚未就绪，正在重试';
        await this.startFacePreview();
        // 重试后重新检查：如果仍然未就绪则放弃本次拍摄
        if (!this.cameraPreviewReady) {
          this.faceStageStatus = 'failed';
          this.recognitionMessage = '相机预览启动失败，请返回后重试';
          return;
        }
      }
      const captureToken = this.armCaptureWatchdog('前置摄像头采集超时，请返回后重试。');
      capture = await FaceCaptureService.captureFace(context, this.currentFaceSurfaceId());
      if (!this.isCurrentCaptureAttempt(captureToken)) {
        return;
      }
      this.clearCaptureWatchdog(captureToken);
      if (!capture) {
        this.faceStageStatus = 'failed';
        this.recognitionMessage = '未获取到当前人脸图像，请重试';
        return;
      }
      const result = await FaceService.compare(this.currentStudentId, referencePixelMap, capture.pixelMap);
      if (!result.success) {
        this.faceStageStatus = 'failed';
        this.recognitionMessage = result.message;
        await this.recordFailedAttendance(result.message, result.method);
        return;
      }
      const course = this.activeCourseId.length > 0 ? CourseService.courseById(this.activeCourseId) : CourseService.activeSignCourse(this.records, this.now());
      if (!course) {
        this.toast('当前不在签到时间内');
        this.flowPage = 'main';
        return;
      }
      if (AttendanceService.hasSigned(this.records, course.courseId, AttendanceService.dateKey(this.now()))) {
        this.toast('今日该课程已签到');
        this.flowPage = 'main';
        return;
      }
      const state = AttendanceService.courseSignState(course, this.records, this.now());
      if (!state.canSign) {
        this.faceStageStatus = 'failed';
        const message = state.status === 'missed' ? '已超过签到窗口' : state.hint;
        const failRecord = AttendanceService.createFailureRecord(this.user.userId, course, message, this.now(), result.method, true);
        this.records = [failRecord, ...this.records];
        await this.store.saveRecords(this.currentStudentId, this.records);
        EntryFormAbility.updateForms(this.store);
        const failNotif = NotificationService.createSignFailedNotification(this.currentStudentId, course.courseName, course.courseId, message);
        NotificationService.addNotification(this.currentStudentId, failNotif);
        this.refreshNotificationState();
        this.toast(message);
        this.flowPage = 'main';
        return;
      }

      this.faceStageStatus = 'success';
      this.recognitionMessage = result.message;
      if (result.similarity !== undefined) {
        profile.lastSimilarity = result.similarity;
        await this.store.saveFaceProfile(this.currentStudentId, profile);
      }

      // 二次地理围栏校验：防止用户在活体检测后离开了校区
      if (this.lastGeofenceResult && !this.lastGeofenceResult.inside) {
        const recheckResult = await LocationService.checkGeofence();
        this.lastGeofenceResult = recheckResult;
        if (!recheckResult.inside) {
          this.faceStageStatus = 'failed';
          this.recognitionMessage = '签到失败：您已离开签到区域';
          const message = recheckResult.distanceMeters >= 0
            ? `不在签到区域内（距${GEOFENCE_CENTER_NAME}约 ${LocationService.formatDistance(recheckResult.distanceMeters)}）`
            : recheckResult.hint;
          const failRecord = AttendanceService.createFailureRecord(this.user.userId, course, message, this.now(), result.method, true);
          this.records = [failRecord, ...this.records];
          await this.store.saveRecords(this.currentStudentId, this.records);
          EntryFormAbility.updateForms(this.store);
          this.toast(message);
          this.flowPage = 'main';
          return;
        }
      }

      const record = AttendanceService.createSuccessRecord(this.user.userId, course, this.now(), result.method);
      record.message = result.message;
      this.records = [record, ...this.records];
      await this.store.saveRecords(this.currentStudentId, this.records);
      EntryFormAbility.updateForms(this.store);
      const successNotif = NotificationService.createSignSuccessNotification(this.currentStudentId, course.courseName, course.courseId);
      NotificationService.addNotification(this.currentStudentId, successNotif);
      this.refreshNotificationState();

      const unlockedBadges = BadgeService.checkSignBadges(this.currentStudentId, this.records, CourseService.all());
      if (unlockedBadges.length > 0) {
        this.loadBadges();
        const badgeNames: string[] = [];
        for (let i = 0; i < unlockedBadges.length; i++) {
          const b = BadgeService.loadBadges(this.currentStudentId).find((badge: BadgeItem) => badge.type === unlockedBadges[i]);
          if (b) {
            badgeNames.push(b.title);
          }
        }
        if (badgeNames.length > 0) {
          this.toast(`解锁勋章：${badgeNames.join('、')}`);
        } else {
          this.toast('签到成功');
        }
      } else {
        this.toast('签到成功');
      }

      this.activeCourseId = '';
      this.stopFacePreview();
      this.flowPage = 'main';
      this.currentTab = 'home';
    } finally {
      // 释放 PixelMap 原生资源，防止内存泄漏
      if (referencePixelMap) {
        try {
          referencePixelMap.release();
        } catch (err) {
        }
      }
      if (capture && capture.pixelMap) {
        try {
          capture.pixelMap.release();
        } catch (err) {
        }
      }
    }
  }

  private armCaptureWatchdog(message: string): number {
    this.captureAttemptSerial += 1;
    const token = this.captureAttemptSerial;
    setTimeout(() => {
      if (this.captureAttemptSerial === token && this.faceStageStatus === 'detecting') {
        this.captureAttemptSerial += 1;
        this.faceStageStatus = 'failed';
        if (this.flowPage === 'enroll') {
          this.flowMessage = message;
        } else {
          this.recognitionMessage = message;
        }
      }
    }, 20000);
    return token;
  }

  private clearCaptureWatchdog(token: number): void {
    if (this.captureAttemptSerial === token) {
      this.captureAttemptSerial += 1;
    }
  }

  private isCurrentCaptureAttempt(token: number): boolean {
    return this.captureAttemptSerial === token;
  }

  private withFaceState(user: User, faceRegistered: boolean): User {
    return {
      userId: user.userId,
      name: user.name,
      studentId: user.studentId,
      className: user.className,
      academy: user.academy,
      faceRegistered
    };
  }

  private todayCourses(): Course[] {
    return CourseService.today(this.now());
  }

  private refreshCourses(): void {
    this.allCourses = [...CourseService.all()];
    this.semesterLabel = CourseService.semesterLabel();
  }

  private filteredRecords(): AttendanceRecord[] {
    let records: AttendanceRecord[];
    if (this.recordFilter === 'today') {
      const today = AttendanceService.dateKey(this.now());
      records = this.records.filter((record: AttendanceRecord) => record.displayDate === today || record.time.indexOf('今天') === 0);
    } else if (this.recordFilter === 'week') {
      records = this.records.filter((record: AttendanceRecord) => record.displayDate === '本周' || record.displayDate === '昨天');
    } else {
      records = this.records.filter((record: AttendanceRecord) => record.displayDate !== AttendanceService.dateKey(this.now()) && record.displayDate !== '本周' && record.displayDate !== '昨天');
    }
    if (this.recordStatusFilter === 'success') {
      records = records.filter((record: AttendanceRecord) => record.status === 'success');
    } else if (this.recordStatusFilter === 'fail') {
      // 只显示真正的缺勤记录（排除后续签到成功的失败尝试）
      records = records.filter((record: AttendanceRecord) => {
        if (!this.isAbsenceRecord(record)) {
          return false;
        }
        const hasSuccess = this.records.some((r: AttendanceRecord) =>
          r.status === 'success' && r.courseId === record.courseId && r.displayDate === record.displayDate
        );
        return !hasSuccess;
      });
    }
    return records;
  }

  private isAbsenceRecord(record: AttendanceRecord): boolean {
    return AttendanceService.isAbsenceRecord(record);
  }

  private visibleRecords(): AttendanceRecord[] {
    const filtered = this.filteredRecords();
    return this.showAllRecords ? filtered : filtered.slice(0, 3);
  }

  private stats(): AttendanceStats {
    return AttendanceService.stats(this.records, CourseService.all(), this.now());
  }

  private now(): Date {
    return this.demoSignMode ? this.demoNow() : new Date();
  }

  private demoNow(): Date {
    const course = this.demoCourse();
    const base = new Date();
    const delta = (course.weekDay - base.getDay() + 7) % 7;
    const result = new Date(base.getFullYear(), base.getMonth(), base.getDate() + delta);
    const startMinutes = CourseService.toMinutes(course.startTime) + 5;
    result.setHours(Math.floor(startMinutes / 60), startMinutes % 60, 0, 0);
    return result;
  }

  private demoCourse(): Course {
    if (!this.demoCourseCache) {
      const allCourses = CourseService.all();
      const index = Math.floor(Math.random() * allCourses.length);
      this.demoCourseCache = allCourses[index];
    }
    return this.demoCourseCache;
  }

  private demoCourseName(): string {
    const course = this.demoCourse();
    return `${CourseService.weekdayLabel(course.weekDay)} ${course.courseName} ${course.startTime}`;
  }

  private locationStatusSubtitle(): string {
    if (this.locationChecking) {
      return '正在获取当前位置…';
    }
    if (!this.lastGeofenceResult) {
      return '点击按钮检测当前所在位置';
    }
    if (this.lastGeofenceResult.inside) {
      return `✓ 已在${GEOFENCE_CENTER_NAME}范围内`;
    }
    if (this.lastGeofenceResult.distanceMeters >= 0) {
      return `距${GEOFENCE_CENTER_NAME}约 ${LocationService.formatDistance(this.lastGeofenceResult.distanceMeters)}`;
    }
    return '定位失败，请确认位置服务已开启';
  }

  private async handleLocationCheck(): Promise<void> {
    this.locationChecking = true;
    try {
      const context = getContext(this) as common.UIAbilityContext;
      // 先检查权限
      if (!await LocationService.hasLocationPermission()) {
        const granted = await LocationService.requestLocationPermission(context);
        this.locationPermissionGranted = granted;
        if (!granted) {
          this.locationChecking = false;
          promptAction.showDialog({
            title: '位置权限未授权',
            message: '请在系统设置中为FaceCheck开启位置权限，以便验证签到区域。',
            buttons: [{ text: '知道了', color: '#0B67D1' }]
          });
          return;
        }
        this.locationPermissionGranted = true;
      }
      const result = await LocationService.checkGeofence();
      this.lastGeofenceResult = result;
      if (result.inside) {
        this.toast(`✓ 已在${GEOFENCE_CENTER_NAME}范围内，可以签到`);
      } else if (result.distanceMeters >= 0) {
        this.toast(`距${GEOFENCE_CENTER_NAME}约 ${LocationService.formatDistance(result.distanceMeters)}`);
      } else {
        this.toast('定位失败，请检查位置服务');
      }
    } catch (err) {
      this.toast('定位失败，请检查位置服务开关');
    } finally {
      this.locationChecking = false;
    }
  }

  /**
   * 开关模拟位置（仅用于测试）
   * @param mode 1=校内 -1=校外 0=关闭
   */
  private handleMockLocation(mode: number): void {
    if (this.mockMode === mode) {
      // 再次点击同一个按钮 → 关闭模拟
      this.mockMode = 0;
      this.lastGeofenceResult = null;
      this.toast('模拟位置已关闭');
      return;
    }
    this.mockMode = mode;
    const isInside = mode === 1;
    const result = isInside
      ? LocationService.mockInsideResult()
      : LocationService.mockOutsideResult();
    this.lastGeofenceResult = result;
    const label = isInside ? '校内' : '校外';
    this.toast(`模拟位置：${label}（${LocationService.formatDistance(result.distanceMeters)}）`);
  }

  private navIconName(tab: MainTab): IconName {
    if (tab === 'home') {
      return 'house';
    }
    if (tab === 'records') {
      return 'calendar-check';
    }
    if (tab === 'profile') {
      return 'person-circle';
    }
    return 'gear';
  }

  private homeTitle(): string {
    if (!this.loggedIn) {
      return '请先完成登录';
    }
    return this.faceRegistered ? '准备上课识别' : '当前状态：尚未录入人脸';
  }

  private homeDescription(): string {
    if (!this.loggedIn) {
      return '登录后即可查看课表、录入人脸并完成课堂签到。';
    }
    if (!this.faceRegistered) {
      return '为确保后续课程能够顺利进行无感签到，请先完成初始人脸信息采集。';
    }
    const course = CourseService.activeSignCourse(this.records, this.now());
    return course ? `下一节课：${course.courseName}，${course.classroom}，${course.startTime} 开始。` : '今日无课程，可以查看历史签到记录。';
  }

  private homeButtonText(): string {
    if (!this.loggedIn) {
      return '立即登录';
    }
    if (!this.faceRegistered) {
      return '开始人脸录入';
    }
    return CourseService.activeSignCourse(this.records, this.now()) ? '开始签到' : '当前不可签到';
  }

  private courseSignState(course: Course): CourseSignState {
    return AttendanceService.courseSignState(course, this.records, this.now());
  }

  // 计算某天课程的节次分段（用于课表单元格合并渲染，并确保相邻课程块颜色不重复）
  private scheduleDaySegments(day: number): ScheduleDaySegment[] {
    const courses = this.allCourses
      .filter((c: Course) => c.weekDay === day)
      .sort((a: Course, b: Course) => a.sectionStart - b.sectionStart);
    const segments: ScheduleDaySegment[] = [];
    let cursor = 1;
    for (const course of courses) {
      if (course.sectionStart > cursor) {
        const gapEnd = course.sectionStart - 1;
        segments.push({ type: 'gap', startSec: cursor, endSec: gapEnd, spanCount: gapEnd - cursor + 1 });
      }
      const endSec = Math.min(course.sectionEnd, 11);
      segments.push({ type: 'course', startSec: course.sectionStart, endSec: endSec, spanCount: endSec - course.sectionStart + 1, course });
      cursor = endSec + 1;
    }
    if (cursor <= 11) {
      segments.push({ type: 'gap', startSec: cursor, endSec: 11, spanCount: 11 - cursor + 1 });
    }
    // 解决相邻课程块颜色冲突
    const PAL = ['#0B67D1', '#C62828', '#047857', '#B45309', '#5B21B6',
      '#BE185D', '#0369A1', '#C2410C', '#065F46', '#831843',
      '#1E40AF', '#9D174D', '#0D9488', '#4338CA', '#A21CAF'];
    let prevColor = '';
    for (let i = 0; i < segments.length; i++) {
      if (segments[i].type === 'course' && segments[i].course) {
        const preferred = CourseService.courseColor(segments[i].course!.courseId);
        let resolved = preferred;
        if (preferred === prevColor) {
          for (const c of PAL) {
            if (c !== prevColor) {
              resolved = c;
              break;
            }
          }
        }
        segments[i].displayColor = resolved;
        segments[i].displayBgColor = CourseService.courseBgColorForHex(resolved);
        prevColor = resolved;
      }
    }
    return segments;
  }

  private iconCommands(name: IconName): string {
    if (name === 'house') {
      return 'M8.354 1.146a.5.5 0 0 0-.708 0l-6 6A.5.5 0 0 0 2 8h1v6.5A1.5 1.5 0 0 0 4.5 16h7a1.5 1.5 0 0 0 1.5-1.5V8h1a.5.5 0 0 0 .354-.854zM13 7.293V14.5a.5.5 0 0 1-.5.5h-7a.5.5 0 0 1-.5-.5V7.293l4-4z';
    }
    if (name === 'calendar-check') {
      return 'M10.854 7.146a.5.5 0 0 1 0 .708l-3 3a.5.5 0 0 1-.708 0l-1.5-1.5a.5.5 0 1 1 .708-.708L7.5 9.793l2.646-2.647a.5.5 0 0 1 .708 0M3.5 0a.5.5 0 0 1 .5.5V1h8V.5a.5.5 0 0 1 1 0V1h1a2 2 0 0 1 2 2v11a2 2 0 0 1-2 2H2a2 2 0 0 1-2-2V3a2 2 0 0 1 2-2h1V.5a.5.5 0 0 1 .5-.5M1 4v10a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1V4z';
    }
    if (name === 'person') {
      return 'M8 8a3 3 0 1 0 0-6 3 3 0 0 0 0 6m2-3a2 2 0 1 1-4 0 2 2 0 0 1 4 0m4 8c0 1-1 1-1 1H3s-1 0-1-1 1-4 6-4 6 3 6 4m-1-.004c-.001-.246-.154-.986-.832-1.664C11.516 10.68 10.289 10 8 10s-3.516.68-4.168 1.332c-.678.678-.83 1.418-.832 1.664z';
    }
    if (name === 'gear') {
      return 'M8 4.754a3.246 3.246 0 1 0 0 6.492 3.246 3.246 0 0 0 0-6.492M5.754 8a2.246 2.246 0 1 1 4.492 0 2.246 2.246 0 0 1-4.492 0M9.796 1.343c-.527-1.79-3.065-1.79-3.592 0l-.094.319a.873.873 0 0 1-1.255.52l-.292-.16c-1.64-.892-3.433.902-2.54 2.541l.159.292a.873.873 0 0 1-.52 1.255l-.319.094c-1.79.527-1.79 3.065 0 3.592l.319.094a.873.873 0 0 1 .52 1.255l-.16.292c-.892 1.64.902 3.433 2.541 2.54l.292-.159a.873.873 0 0 1 1.255.52l.094.319c.527 1.79 3.065 1.79 3.592 0l.094-.319a.873.873 0 0 1 1.255-.52l.292.16c1.64.893 3.434-.902 2.54-2.541l-.159-.292a.873.873 0 0 1 .52-1.255l.319-.094c1.79-.527 1.79-3.065 0-3.592l-.319-.094a.873.873 0 0 1-.52-1.255l.16-.292c.893-1.64-.902-3.433-2.541-2.54l-.292.159a.873.873 0 0 1-1.255-.52z';
    }
    if (name === 'bell') {
      return 'M8 16a2 2 0 0 0 1.985-1.75H6.015A2 2 0 0 0 8 16M8 1.918l-.797.161A4.002 4.002 0 0 0 4 6c0 .628-.134 2.197-.459 3.742-.16.767-.376 1.566-.663 2.258h10.244c-.287-.692-.502-1.49-.663-2.258C12.134 8.197 12 6.628 12 6a4.002 4.002 0 0 0-3.203-3.92zM14.22 12c.223.447.481.801.78 1H1c.299-.199.557-.553.78-1C2.68 10.2 3 6.88 3 6c0-2.42 1.72-4.44 4.005-4.901a1 1 0 1 1 1.99 0A5.002 5.002 0 0 1 13 6c0 .88.32 4.2 1.22 6';
    }
    if (name === 'book') {
      return 'M1 2.828c.885-.37 2.154-.769 3.388-.893 1.33-.134 2.458.063 3.112.656V14.5c-.654-.593-1.782-.79-3.112-.656-1.234.124-2.503.523-3.388.893zm7.5-.237c.654-.593 1.782-.79 3.112-.656 1.234.124 2.503.523 3.388.893v11.909c-.885-.37-2.154-.769-3.388-.893-1.33-.134-2.458.063-3.112.656zM8 1.783C7.015.936 5.587.81 4.287.94 2.934 1.077 1.642 1.48.744 1.85A1.11 1.11 0 0 0 0 2.877v11.798c0 .716.746 1.175 1.383.853.835-.421 2.03-.88 3.105-.987 1.2-.12 2.003.112 2.52.629.548.548 1.444.548 1.992 0 .517-.517 1.32-.748 2.52-.629 1.075.107 2.27.566 3.105.987.637.322 1.383-.137 1.383-.853V2.877c0-.466-.292-.883-.744-1.026-.898-.37-2.19-.773-3.543-.91-1.3-.131-2.728-.005-3.713.842z';
    }
    if (name === 'award') {
      return 'M9.669.864 8 0 6.331.864l-1.858.282-.842 1.68-1.337 1.32.307 1.854-.307 1.854 1.337 1.32.842 1.68 1.858.282L8 12l1.669-.864 1.858-.282.842-1.68 1.337-1.32-.307-1.854.307-1.854-1.337-1.32-.842-1.68zM8 9.5A3.5 3.5 0 1 1 8 2a3.5 3.5 0 0 1 0 7.5M4.5 12.5 3 16l5-2 5 2-1.5-3.5-2.116.321L8 13.5l-1.384-.679z';
    }
    if (name === 'shield') {
      return 'M5.338 1.59 8 0l2.662 1.59a6 6 0 0 0 2.91.766c.446 0 .77.396.697.836-.674 4.19-2.843 7.65-6.269 9.808-3.426-2.158-5.595-5.618-6.269-9.808a.72.72 0 0 1 .697-.836 6 6 0 0 0 2.91-.766M8 1.173 5.85 2.456a7 7 0 0 1-3.093.916c.685 3.64 2.578 6.593 5.243 8.472 2.665-1.879 4.558-4.832 5.243-8.472a7 7 0 0 1-3.093-.916z';
    }
    if (name === 'box-arrow-right') {
      return 'M10 12.5a.5.5 0 0 1-.5.5h-8a.5.5 0 0 1-.5-.5v-9a.5.5 0 0 1 .5-.5h8a.5.5 0 0 1 .5.5v2a.5.5 0 0 0 1 0v-2A1.5 1.5 0 0 0 9.5 2h-8A1.5 1.5 0 0 0 0 3.5v9A1.5 1.5 0 0 0 1.5 14h8a1.5 1.5 0 0 0 1.5-1.5v-2a.5.5 0 0 0-1 0zM15.854 8.354a.5.5 0 0 0 0-.708l-3-3a.5.5 0 0 0-.708.708L14.293 7.5H5.5a.5.5 0 0 0 0 1h8.793l-2.147 2.146a.5.5 0 0 0 .708.708z';
    }
    if (name === 'person-circle') {
      return 'M11 6a3 3 0 1 1-6 0 3 3 0 0 1 6 0M0 8a8 8 0 1 1 16 0A8 8 0 0 1 0 8m8-7a7 7 0 0 0-5.468 11.37C3.242 11.226 4.805 10 8 10s4.757 1.225 5.468 2.37A7 7 0 0 0 8 1';
    }
    if (name === 'lock') {
      return 'M8 1a2 2 0 0 1 2 2v4H6V3a2 2 0 0 1 2-2m3 6V3a3 3 0 0 0-6 0v4a2 2 0 0 0-2 2v5a2 2 0 0 0 2 2h6a2 2 0 0 0 2-2V9a2 2 0 0 0-2-2';
    }
    if (name === 'card') {
      return 'M14 3a1 1 0 0 1 1 1v1H1V4a1 1 0 0 1 1-1zM1 7h14v5a1 1 0 0 1-1 1H2a1 1 0 0 1-1-1zm1-5a2 2 0 0 0-2 2v8a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V4a2 2 0 0 0-2-2z';
    }
    if (name === 'chevron-right') {
      return 'M4.646 1.646a.5.5 0 0 1 .708 0l6 6a.5.5 0 0 1 0 .708l-6 6a.5.5 0 0 1-.708-.708L10.293 8 4.646 2.354a.5.5 0 0 1 0-.708';
    }
    if (name === 'camera') {
      return 'M10.5 8.5a2.5 2.5 0 1 1-5 0 2.5 2.5 0 0 1 5 0M2 4a2 2 0 0 0-2 2v6a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V6a2 2 0 0 0-2-2h-1.172a2 2 0 0 1-1.414-.586l-.828-.828A2 2 0 0 0 9.172 2H6.828a2 2 0 0 0-1.414.586l-.828.828A2 2 0 0 1 3.172 4z';
    }
    if (name === 'eye') {
      return 'M16 8s-3-5.5-8-5.5S0 8 0 8s3 5.5 8 5.5S16 8 16 8m-8 3.5a3.5 3.5 0 1 1 0-7 3.5 3.5 0 0 1 0 7';
    }
    if (name === 'check-circle') {
      return 'M8 15A7 7 0 1 1 8 1a7 7 0 0 1 0 14m3.354-8.646a.5.5 0 0 0-.708-.708L7 9.293 5.354 7.646a.5.5 0 1 0-.708.708l2 2a.5.5 0 0 0 .708 0z';
    }
    if (name === 'x-circle') {
      return 'M8 15A7 7 0 1 1 8 1a7 7 0 0 1 0 14M4.646 4.646a.5.5 0 0 0 0 .708L7.293 8l-2.647 2.646a.5.5 0 0 0 .708.708L8 8.707l2.646 2.647a.5.5 0 0 0 .708-.708L8.707 8l2.647-2.646a.5.5 0 0 0-.708-.708L8 7.293 5.354 4.646a.5.5 0 0 0-.708 0';
    }
    return 'M8 3.5a.5.5 0 0 1 .5.5v4l2.5 1.5a.5.5 0 0 1-.5.866l-2.75-1.65A.5.5 0 0 1 7.5 8V4A.5.5 0 0 1 8 3.5M8 16A8 8 0 1 0 8 0a8 8 0 0 0 0 16';
  }

  private openNotifications(): void {
    if (!this.loggedIn) {
      this.toast('请先登录');
      return;
    }
    this.loadNotifications();
    this.flowPage = 'notifications';
  }

  private openFeedback(): void {
    if (!this.loggedIn) {
      this.toast('请先登录');
      return;
    }
    this.loadFeedbacks();
    this.feedbackTab = 'list';
    this.flowPage = 'feedback';
  }

  private loadFeedbacks(): void {
    this.feedbacks = FeedbackService.loadFeedbacks(this.currentStudentId);
  }

  private openVersion(): void {
    this.versionTab = 'current';
    this.versionInfo = null;
    this.versionHasNew = false;
    this.flowPage = 'version';
  }

  private async checkUpdate(): Promise<void> {
    if (this.checkingUpdate) {
      return;
    }
    this.checkingUpdate = true;
    try {
      const info = await VersionService.checkUpdate();
      this.versionInfo = info;
      this.versionHasNew = info !== null;
      if (!info) {
        this.toast('当前已是最新版本');
      }
    } catch (err) {
      this.toast('检查更新失败，请稍后重试');
    } finally {
      this.checkingUpdate = false;
    }
  }

  private versionSubtitle(): string {
    if (this.versionHasNew && this.versionInfo) {
      return `发现新版本 v${this.versionInfo.latestVersion}`;
    }
    return `v${VersionService.getCurrentVersion()}`;
  }

  private toast(message: string): void {
    try {
      promptAction.showToast({ message, duration: 1800 });
    } catch (err) {
    }
  }

  private pageBg(): string {
    return this.darkMode ? DARK_BG : BG;
  }

  private surface(): string {
    return this.darkMode ? DARK_CARD : CARD;
  }

  private surfaceAlt(): string {
    return this.darkMode ? '#202C3F' : '#F0F4FA';
  }

  private primaryText(): string {
    return this.darkMode ? '#F6F8FC' : TEXT;
  }

  private secondaryText(): string {
    return this.darkMode ? '#B9C4D6' : MUTED;
  }

  private cardShadow(): ShadowOptions {
    return {
      radius: this.darkMode ? 0 : 18,
      color: '#140B4B1A',
      offsetX: 0,
      offsetY: 8
    };
  }

  // ========== 课程编辑/导入功能 ==========

  private showCourseActionDialog(course: Course): void {
    promptAction.showActionMenu({
      title: course.courseName,
      buttons: [
        { text: '编辑', color: '#2D89FF' },
        { text: '删除', color: '#E53935' },
        { text: '取消', color: '#888888' }
      ]
    }).then((selectResult: promptAction.ActionMenuSuccessResponse) => {
      if (selectResult.index === 0) {
        // 编辑
        this.editCourseId = course.courseId;
        this.editCourseName = course.courseName;
        this.editClassroom = course.classroom;
        this.editTeacher = course.teacher;
        this.editWeekDay = course.weekDay;
        this.editSectionStart = course.sectionStart;
        this.editSectionEnd = course.sectionEnd;
        this.editWeekRange = course.weekRange;
        this.editCourseType = course.type;
        this.editCourseError = '';
        this.flowPage = 'courseEdit';
      } else if (selectResult.index === 1) {
        // 删除
        CourseService.deleteCourse(course.courseId);
        this.refreshCourses();
        this.toast('课程已删除');
      }
    });
  }

  private resetCourseEditForm(): void {
    this.editCourseId = '';
    this.editCourseName = '';
    this.editClassroom = '';
    this.editTeacher = '';
    this.editWeekDay = 1;
    this.editSectionStart = 1;
    this.editSectionEnd = 2;
    this.editWeekRange = '1-16周';
    this.editCourseType = 'theory';
    this.editCourseError = '';
  }

  private startAddCourseFromBlank(day: number, sectionStart: number): void {
    this.resetCourseEditForm();
    this.editWeekDay = day;
    this.editSectionStart = sectionStart;
    this.editSectionEnd = Math.min(sectionStart, 11);
    this.editCourseError = '';
    this.flowPage = 'courseEdit';
  }

  private saveCourse(): void {
    if (this.editCourseName.trim().length === 0) {
      this.editCourseError = '课程名称不能为空';
      return;
    }
    if (this.editClassroom.trim().length === 0) {
      this.editCourseError = '教室不能为空';
      return;
    }
    if (this.editTeacher.trim().length === 0) {
      this.editCourseError = '教师不能为空';
      return;
    }
    if (this.editSectionStart > this.editSectionEnd) {
      this.editCourseError = '开始节次不能大于结束节次';
      return;
    }

    const startTime: string = SECTION_TIMES[this.editSectionStart]?.split('-')[0] || '08:30';
    const endTime: string = SECTION_TIMES[this.editSectionEnd]?.split('-')[1] || '09:15';
    const sectionStr: string = `${this.editSectionStart}-${this.editSectionEnd}节`;

    const course: Course = {
      courseId: this.editCourseId || `course-${Date.now()}`,
      courseName: this.editCourseName.trim(),
      classroom: this.editClassroom.trim(),
      teacher: this.editTeacher.trim(),
      weekDay: this.editWeekDay,
      section: sectionStr,
      sectionStart: this.editSectionStart,
      sectionEnd: this.editSectionEnd,
      startTime: startTime,
      endTime: endTime,
      weekRange: this.editWeekRange.trim(),
      type: this.editCourseType as 'theory' | 'lab' | 'practice'
    };

    if (this.editCourseId) {
      CourseService.updateCourse(this.editCourseId, course);
      this.toast('课程已更新');
    } else {
      CourseService.addCourse(course);
      this.toast('课程已添加');
    }
    this.refreshCourses();
    this.flowPage = 'schedule';
  }

  private importCoursesFromJson(): void {
    try {
      const parsed: Object = JSON.parse(this.importJsonText);
      if (!Array.isArray(parsed)) {
        this.importError = '导入数据必须是课程数组';
        return;
      }
      const courses: Course[] = (parsed as Course[]).filter((item: Course) => {
        return item.courseId && item.courseName && item.weekDay !== undefined;
      });
      if (courses.length === 0) {
        this.importError = '未找到有效的课程数据';
        return;
      }
      CourseService.saveCourses(courses);
      this.refreshCourses();
      this.toast(`成功导入 ${courses.length} 门课程`);
      this.flowPage = 'schedule';
    } catch (err) {
      this.importError = 'JSON 格式错误，请检查输入';
    }
  }

  @Builder
  CourseEditPage() {
    Column() {
      this.AuthHeader()
      Scroll() {
        Column({ space: 18 }) {
          Text(this.editCourseId ? '编辑课程' : '添加课程')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.primaryText())
            .width('100%')
          Text(`当前：${CourseService.semesterLabel()}`)
            .fontSize(14)
            .fontColor(this.secondaryText())
            .width('100%')

          this.InputBlock('book', '课程名称', '例如：数据结构', this.editCourseName, false, (input: string) => {
            this.editCourseName = input;
            this.editCourseError = '';
          })
          this.InputBlock('card', '教室', '例如：教A101', this.editClassroom, false, (input: string) => {
            this.editClassroom = input;
            this.editCourseError = '';
          })
          this.InputBlock('person-circle', '教师', '例如：张三', this.editTeacher, false, (input: string) => {
            this.editTeacher = input;
            this.editCourseError = '';
          })

          // 星期选择
          Column({ space: 8 }) {
            Text('上课星期')
              .fontSize(16)
              .fontColor(this.primaryText())
              .width('100%')
            Row({ space: 8 }) {
              ForEach([1, 2, 3, 4, 5, 6, 0], (day: number) => {
                Text(CourseService.weekdayLabel(day))
                  .fontSize(13)
                  .fontWeight(this.editWeekDay === day ? FontWeight.Bold : FontWeight.Normal)
                  .fontColor(this.editWeekDay === day ? '#FFFFFF' : this.secondaryText())
                  .textAlign(TextAlign.Center)
                  .width(40)
                  .height(36)
                  .backgroundColor(this.editWeekDay === day ? BLUE : this.surfaceAlt())
                  .borderRadius(8)
                  .onClick(() => {
                    this.editWeekDay = day;
                  })
              }, (day: number) => `${day}`)
            }
            .width('100%')
          }
          .width('100%')

          // 节次选择
          Column({ space: 8 }) {
            Text('开始节次')
              .fontSize(16)
              .fontColor(this.primaryText())
              .width('100%')
            Row({ space: 8 }) {
              ForEach([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11], (section: number) => {
                Text(`${section}`)
                  .fontSize(13)
                  .fontWeight(this.editSectionStart === section ? FontWeight.Bold : FontWeight.Normal)
                  .fontColor(this.editSectionStart === section ? '#FFFFFF' : this.secondaryText())
                  .textAlign(TextAlign.Center)
                  .width(36)
                  .height(36)
                  .backgroundColor(this.editSectionStart === section ? BLUE : this.surfaceAlt())
                  .borderRadius(8)
                  .onClick(() => {
                    this.editSectionStart = section;
                    if (this.editSectionEnd < section) {
                      this.editSectionEnd = section;
                    }
                  })
              }, (section: number) => `${section}`)
            }
            .width('100%')
          }
          .width('100%')

          Column({ space: 8 }) {
            Text('结束节次')
              .fontSize(16)
              .fontColor(this.primaryText())
              .width('100%')
            Row({ space: 8 }) {
              ForEach([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11], (section: number) => {
                Text(`${section}`)
                  .fontSize(13)
                  .fontWeight(this.editSectionEnd === section ? FontWeight.Bold : FontWeight.Normal)
                  .fontColor(this.editSectionEnd === section ? '#FFFFFF' : this.secondaryText())
                  .textAlign(TextAlign.Center)
                  .width(36)
                  .height(36)
                  .backgroundColor(this.editSectionEnd === section ? BLUE : this.surfaceAlt())
                  .borderRadius(8)
                  .onClick(() => {
                    this.editSectionEnd = section;
                  })
              }, (section: number) => `${section}`)
            }
            .width('100%')
          }
          .width('100%')

          this.InputBlock('award', '周次', '例如：1-16周', this.editWeekRange, false, (input: string) => {
            this.editWeekRange = input;
          })

          // 课程类型
          Column({ space: 8 }) {
            Text('课程类型')
              .fontSize(16)
              .fontColor(this.primaryText())
              .width('100%')
            Row({ space: 10 }) {
              ForEach(COURSE_TYPE_OPTIONS, (type: CourseTypeOption) => {
                Text(type.label)
                  .fontSize(14)
                  .fontWeight(this.editCourseType === type.value ? FontWeight.Bold : FontWeight.Normal)
                  .fontColor(this.editCourseType === type.value ? '#FFFFFF' : this.secondaryText())
                  .padding({ left: 16, right: 16, top: 8, bottom: 8 })
                  .backgroundColor(this.editCourseType === type.value ? BLUE : this.surfaceAlt())
                  .borderRadius(8)
                  .onClick(() => {
                    this.editCourseType = type.value;
                  })
              }, (type: CourseTypeOption) => type.value)
            }
          }
          .width('100%')

          if (this.editCourseError.length > 0) {
            Text(this.editCourseError)
              .fontSize(14)
              .fontColor(RED)
              .width('100%')
          }

          Button(this.editCourseId ? '保存修改' : '添加课程')
            .height(52)
            .width('100%')
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .backgroundColor(BLUE)
            .fontColor(Color.White)
            .borderRadius(8)
            .onClick(() => this.saveCourse())

          Button('取消')
            .height(48)
            .width('100%')
            .fontSize(16)
            .backgroundColor(this.surfaceAlt())
            .fontColor(this.secondaryText())
            .borderRadius(8)
            .onClick(() => {
              this.flowPage = 'schedule';
            })
        }
        .width('100%')
        .padding({ left: 24, right: 24, top: 20, bottom: 40 })
        .constraintSize({ maxWidth: 560 })
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.pageBg())
  }

  @Builder
  CourseImportPage() {
    Column() {
      this.AuthHeader()
      Scroll() {
        Column({ space: 18 }) {
          Text('导入课表')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.primaryText())
            .width('100%')

          Text('将课程 JSON 数组粘贴到下方：')
            .fontSize(14)
            .fontColor(this.secondaryText())
            .width('100%')

          TextArea({ text: this.importJsonText })
            .height(300)
            .fontSize(14)
            .backgroundColor(this.surfaceAlt())
            .borderRadius(8)
            .padding(12)
            .onChange((value: string) => {
              this.importJsonText = value;
              this.importError = '';
            })

          if (this.importError.length > 0) {
            Text(this.importError)
              .fontSize(14)
              .fontColor(RED)
              .width('100%')
          }

          Button('导入')
            .height(52)
            .width('100%')
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .backgroundColor(BLUE)
            .fontColor(Color.White)
            .borderRadius(8)
            .onClick(() => this.importCoursesFromJson())

          Button('重置为默认课表')
            .height(48)
            .width('100%')
            .fontSize(16)
            .backgroundColor(RED_SOFT)
            .fontColor(RED)
            .borderRadius(8)
            .onClick(() => {
              CourseService.resetToDefault();
              this.refreshCourses();
              this.toast('已重置为默认课表');
              this.flowPage = 'schedule';
            })

          Button('取消')
            .height(48)
            .width('100%')
            .fontSize(16)
            .backgroundColor(this.surfaceAlt())
            .fontColor(this.secondaryText())
            .borderRadius(8)
            .onClick(() => {
              this.flowPage = 'schedule';
            })

          Column({ space: 6 }) {
            Text('JSON 格式示例：')
              .fontSize(14)
              .fontColor(this.primaryText())
              .width('100%')
            Text(`[\n  {\n    "courseId": "course-1",\n    "courseName": "数据结构",\n    "classroom": "教A101",\n    "teacher": "张三",\n    "weekDay": 1,\n    "section": "1-2节",\n    "sectionStart": 1,\n    "sectionEnd": 2,\n    "startTime": "08:30",\n    "endTime": "10:05",\n    "weekRange": "1-16周",\n    "type": "theory"\n  }\n]`)
              .fontSize(11)
              .fontColor(this.secondaryText())
              .width('100%')
              .padding(10)
              .backgroundColor(this.surfaceAlt())
              .borderRadius(8)
          }
          .width('100%')
        }
        .width('100%')
        .padding({ left: 24, right: 24, top: 20, bottom: 40 })
        .constraintSize({ maxWidth: 560 })
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.pageBg())
  }

  @Builder
  NotificationsPage() {
    Column() {
      // Header
      Row({ space: 12 }) {
        Button() {
          Text('<')
            .fontSize(22)
            .fontColor(this.primaryText())
        }
        .width(44)
        .height(44)
        .backgroundColor('transparent')
        .onClick(() => {
          this.flowPage = 'main';
        })

        Text('通知中心')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.primaryText())
          .layoutWeight(1)

        if (this.notifications.length > 0) {
          Text('全部已读')
            .fontSize(14)
            .fontColor(BLUE)
            .onClick(() => {
              NotificationService.markAllAsRead(this.currentStudentId);
              this.refreshNotificationState();
              this.toast('已全部标记为已读');
            })
        }
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor(this.surface())

      // Actions
      if (this.notifications.length > 0) {
        Row() {
          Text(`${this.notificationUnreadCount} 条未读`)
            .fontSize(13)
            .fontColor(this.secondaryText())
          Blank()
          Text('清空全部')
            .fontSize(13)
            .fontColor(RED)
            .onClick(() => {
              NotificationService.clearAllNotifications(this.currentStudentId);
              this.refreshNotificationState();
              this.toast('已清空全部通知');
            })
        }
        .width('100%')
        .padding({ left: 24, right: 24, top: 12, bottom: 8 })
      }

      if (this.notifications.length === 0) {
        Column({ space: 12 }) {
          this.IconBox('bell', 64, 48, MUTED)
          Text('暂无通知')
            .fontSize(16)
            .fontColor(this.secondaryText())
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column({ space: 10 }) {
            ForEach(this.notifications, (item: NotificationItem) => {
              Column({ space: 6 }) {
                Row({ space: 10 }) {
                  Text(NotificationService.typeLabel(item.type))
                    .fontSize(11)
                    .fontColor(NotificationService.typeColor(item.type))
                    .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                    .backgroundColor(NotificationService.typeBgColor(item.type))
                    .borderRadius(4)

                  Text(item.title)
                    .fontSize(15)
                    .fontWeight(item.read ? FontWeight.Normal : FontWeight.Bold)
                    .fontColor(this.primaryText())
                    .layoutWeight(1)

                  if (!item.read) {
                    Row()
                      .width(8)
                      .height(8)
                      .backgroundColor(RED)
                      .borderRadius(4)
                  }
                }
                .width('100%')

                Text(item.content)
                  .fontSize(13)
                  .fontColor(this.secondaryText())
                  .width('100%')

                Text(NotificationService.formatTime(item.timestamp))
                  .fontSize(11)
                  .fontColor(MUTED)
                  .width('100%')
              }
              .width('100%')
              .padding(14)
              .backgroundColor(item.read ? this.surface() : BLUE_SOFT)
              .borderRadius(8)
              .shadow(this.cardShadow())
              .onClick(() => {
                if (!item.read) {
                  NotificationService.markAsRead(this.currentStudentId, item.id);
                  this.refreshNotificationState();
                }
              })
              .gesture(
                LongPressGesture({ duration: 500 })
                  .onAction(() => {
                    this.showNotificationActionDialog(item);
                  })
              )
            }, (item: NotificationItem) => item.id)
          }
          .width('100%')
          .padding({ left: 24, right: 24, top: 12, bottom: 40 })
          .constraintSize({ maxWidth: 980 })
        }
        .layoutWeight(1)
        .scrollable(ScrollDirection.Vertical)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.pageBg())
  }

  private showNotificationActionDialog(item: NotificationItem): void {
    const readLabel: string = item.read ? '标记为未读' : '标记为已读';
    promptAction.showActionMenu({
      title: item.title,
      buttons: [
        { text: readLabel, color: '#2D89FF' },
        { text: '删除', color: '#E53935' },
        { text: '取消', color: '#888888' }
      ]
    }).then((selectResult: promptAction.ActionMenuSuccessResponse) => {
      if (selectResult.index === 0) {
        if (item.read) {
          const allItems: NotificationItem[] = NotificationService.loadNotifications(this.currentStudentId);
          const updated: NotificationItem[] = [];
          for (let i = 0; i < allItems.length; i++) {
            if (allItems[i].id === item.id) {
              updated.push({
                id: allItems[i].id,
                type: allItems[i].type,
                title: allItems[i].title,
                content: allItems[i].content,
                timestamp: allItems[i].timestamp,
                read: false,
                studentId: allItems[i].studentId,
                courseId: allItems[i].courseId
              });
            } else {
              updated.push(allItems[i]);
            }
          }
          NotificationService.saveNotifications(this.currentStudentId, updated);
          this.toast('已标记为未读');
        } else {
          NotificationService.markAsRead(this.currentStudentId, item.id);
          this.toast('已标记为已读');
        }
        this.refreshNotificationState();
      } else if (selectResult.index === 1) {
        NotificationService.deleteNotification(this.currentStudentId, item.id);
        this.toast('通知已删除');
        this.refreshNotificationState();
      }
    });
  }

  @Builder
  BadgePage() {
    Column() {
      Row({ space: 12 }) {
        Button() {
          Text('<')
            .fontSize(22)
            .fontColor(this.primaryText())
        }
        .width(44)
        .height(44)
        .backgroundColor('transparent')
        .onClick(() => {
          this.flowPage = 'main';
        })

        Text('我的勋章')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.primaryText())
          .layoutWeight(1)
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor(this.surface())

      Scroll() {
        Column({ space: 16 }) {
          Column({ space: 6 }) {
            Text(`${this.badges.filter((b: BadgeItem) => b.unlocked).length} / ${this.badges.length}`)
              .fontSize(32)
              .fontWeight(FontWeight.Bold)
              .fontColor(BLUE)
            Text('已解锁勋章')
              .fontSize(14)
              .fontColor(this.secondaryText())
          }
          .width('100%')
          .padding({ top: 20, bottom: 10 })
          .alignItems(HorizontalAlign.Center)

          Column({ space: 10 }) {
            ForEach(this.badges, (badge: BadgeItem) => {
              Row({ space: 14 }) {
                Stack({ alignContent: Alignment.Center }) {
                  this.AppIcon(badge.icon as IconName, 28, badge.unlocked ? BLUE : MUTED)
                }
                .width(52)
                .height(52)
                .backgroundColor(badge.unlocked ? BLUE_SOFT : this.surfaceAlt())
                .borderRadius(12)

                Column({ space: 4 }) {
                  Row({ space: 8 }) {
                    Text(badge.title)
                      .fontSize(16)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(badge.unlocked ? this.primaryText() : MUTED)

                    if (badge.unlocked) {
                      Text('已解锁')
                        .fontSize(11)
                        .fontColor(GREEN)
                        .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                        .backgroundColor(GREEN_SOFT)
                        .borderRadius(4)
                    } else {
                      Text('未解锁')
                        .fontSize(11)
                        .fontColor(MUTED)
                        .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                        .backgroundColor(this.surfaceAlt())
                        .borderRadius(4)
                    }
                  }

                  Text(badge.description)
                    .fontSize(13)
                    .fontColor(this.secondaryText())
                    .width('100%')

                  if (!badge.unlocked && badge.progress !== undefined && badge.target !== undefined && badge.target > 1) {
                    Row({ space: 6 }) {
                      Row() {
                        Row()
                          .width(`${Math.min(100, Math.round((badge.progress / badge.target) * 100))}%`)
                          .height(4)
                          .backgroundColor(BLUE)
                          .borderRadius(2)
                      }
                      .width('100%')
                      .height(4)
                      .backgroundColor(this.surfaceAlt())
                      .borderRadius(2)
                    }
                    .width('100%')

                    Text(`${badge.progress} / ${badge.target}`)
                      .fontSize(11)
                      .fontColor(MUTED)
                      .width('100%')
                  }
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
              }
              .width('100%')
              .padding(14)
              .backgroundColor(this.surface())
              .borderRadius(8)
              .shadow(this.cardShadow())
              .opacity(badge.unlocked ? 1 : 0.7)
            }, (badge: BadgeItem) => badge.type)
          }
          .width('100%')
          .padding({ left: 24, right: 24, top: 12, bottom: 40 })
          .constraintSize({ maxWidth: 980 })
        }
        .width('100%')
      }
      .layoutWeight(1)
      .scrollable(ScrollDirection.Vertical)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.pageBg())
  }

  // ========== 反馈建议功能 ==========

  @Builder
  FeedbackPage() {
    Column() {
      // Header
      Row({ space: 12 }) {
        Button() {
          Text('<')
            .fontSize(22)
            .fontColor(this.primaryText())
        }
        .width(44)
        .height(44)
        .backgroundColor('transparent')
        .onClick(() => {
          this.flowPage = 'main';
        })

        Text('反馈建议')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.primaryText())
          .layoutWeight(1)

        // Tab 切换
        Row({ space: 4 }) {
          Text('历史记录')
            .fontSize(14)
            .fontWeight(this.feedbackTab === 'list' ? FontWeight.Bold : FontWeight.Normal)
            .fontColor(this.feedbackTab === 'list' ? '#FFFFFF' : this.secondaryText())
            .padding({ left: 14, right: 14, top: 6, bottom: 6 })
            .backgroundColor(this.feedbackTab === 'list' ? BLUE : this.surfaceAlt())
            .borderRadius(6)
            .onClick(() => {
              this.feedbackTab = 'list';
              this.feedbackError = '';
            })

          Text('写反馈')
            .fontSize(14)
            .fontWeight(this.feedbackTab === 'write' ? FontWeight.Bold : FontWeight.Normal)
            .fontColor(this.feedbackTab === 'write' ? '#FFFFFF' : this.secondaryText())
            .padding({ left: 14, right: 14, top: 6, bottom: 6 })
            .backgroundColor(this.feedbackTab === 'write' ? BLUE : this.surfaceAlt())
            .borderRadius(6)
            .onClick(() => {
              this.feedbackTab = 'write';
              this.feedbackError = '';
              this.resetFeedbackForm();
            })
        }
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor(this.surface())

      // Content
      if (this.feedbackTab === 'list') {
        this.FeedbackListPage()
      } else {
        this.FeedbackWritePage()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.pageBg())
  }

  @Builder
  FeedbackListPage() {
    if (this.feedbacks.length === 0) {
      Column({ space: 14 }) {
        Text('📋')
          .fontSize(48)
        Text('暂无反馈记录')
          .fontSize(17)
          .fontColor(this.primaryText())
          .fontWeight(FontWeight.Medium)
        Text('点击右上角"写反馈"开始提交')
          .fontSize(14)
          .fontColor(this.secondaryText())
        Button('立即反馈')
          .fontSize(15)
          .fontColor(Color.White)
          .backgroundColor(BLUE)
          .borderRadius(8)
          .height(42)
          .padding({ left: 24, right: 24 })
          .onClick(() => {
            this.feedbackTab = 'write';
            this.resetFeedbackForm();
          })
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else {
      Column() {
        Row() {
          Text(`共 ${this.feedbacks.length} 条反馈`)
            .fontSize(13)
            .fontColor(this.secondaryText())
          Blank()
          Text('清空全部')
            .fontSize(13)
            .fontColor(RED)
            .onClick(() => {
              FeedbackService.clearAllFeedbacks(this.currentStudentId);
              this.loadFeedbacks();
              this.toast('已清空全部反馈');
            })
        }
        .width('100%')
        .padding({ left: 24, right: 24, top: 14, bottom: 10 })

        Scroll() {
          Column({ space: 10 }) {
            ForEach(this.feedbacks, (item: FeedbackItem) => {
              Column({ space: 8 }) {
                Row({ space: 10 }) {
                  // 类型标签
                  Text(FeedbackService.typeLabel(item.type))
                    .fontSize(11)
                    .fontColor(FeedbackService.typeColor(item.type))
                    .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                    .backgroundColor(FeedbackService.typeBgColor(item.type))
                    .borderRadius(4)

                  Text(item.title)
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.primaryText())
                    .layoutWeight(1)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })

                  // 状态标签
                  Text(FeedbackService.statusLabel(item.status))
                    .fontSize(11)
                    .fontColor(FeedbackService.statusColor(item.status))
                    .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                    .backgroundColor(this.surfaceAlt())
                    .borderRadius(4)
                }
                .width('100%')

                Text(item.content)
                  .fontSize(13)
                  .fontColor(this.secondaryText())
                  .width('100%')
                  .maxLines(3)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })

                Row({ space: 12 }) {
                  Text(FeedbackService.formatTime(item.timestamp))
                    .fontSize(12)
                    .fontColor(MUTED)

                  if (item.contact.length > 0) {
                    Text(`联系方式：${item.contact}`)
                      .fontSize(12)
                      .fontColor(BLUE)
                  }
                }
                .width('100%')
              }
              .width('100%')
              .padding(14)
              .backgroundColor(this.surface())
              .borderRadius(8)
              .shadow(this.cardShadow())
            }, (item: FeedbackItem) => item.id)
          }
          .width('100%')
          .padding({ left: 24, right: 24, top: 8, bottom: 40 })
          .constraintSize({ maxWidth: 980 })
        }
        .width('100%')
        .layoutWeight(1)
      }
      .width('100%')
      .layoutWeight(1)
    }
  }

  @Builder
  FeedbackWritePage() {
    Column() {
      Scroll() {
        Column({ space: 18 }) {
          Text('提交反馈')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.primaryText())
            .width('100%')

          // 反馈类型
          Column({ space: 8 }) {
            Text('反馈类型')
              .fontSize(16)
              .fontColor(this.primaryText())
              .width('100%')
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(FEEDBACK_TYPE_OPTIONS, (opt: FeedbackTypeOption) => {
                Row({ space: 6 }) {
                  Text(opt.icon)
                    .fontSize(16)
                  Text(opt.label)
                    .fontSize(13)
                    .fontWeight(this.feedbackType === opt.value ? FontWeight.Bold : FontWeight.Normal)
                    .fontColor(this.feedbackType === opt.value ? '#FFFFFF' : this.secondaryText())
                }
                .padding({ left: 12, right: 12, top: 8, bottom: 8 })
                .backgroundColor(this.feedbackType === opt.value ? BLUE : this.surfaceAlt())
                .borderRadius(8)
                .onClick(() => {
                  this.feedbackType = opt.value;
                })
              }, (opt: FeedbackTypeOption) => opt.value)
            }
            .width('100%')
          }
          .width('100%')

          // 标题
          Column({ space: 8 }) {
            Text('标题')
              .fontSize(16)
              .fontColor(this.primaryText())
              .width('100%')
            TextInput({ text: this.feedbackTitle, placeholder: '一句话概括你的反馈（4-50字）' })
              .fontSize(15)
              .maxLength(50)
              .width('100%')
              .height(48)
              .backgroundColor(this.surfaceAlt())
              .borderRadius(8)
              .padding({ left: 14, right: 14 })
              .onChange((value: string) => {
                this.feedbackTitle = value;
              })
          }
          .width('100%')

          // 内容
          Column({ space: 8 }) {
            Text('详细描述')
              .fontSize(16)
              .fontColor(this.primaryText())
              .width('100%')
            TextArea({ text: this.feedbackContent, placeholder: this.currentPlaceholder() })
              .fontSize(15)
              .maxLength(500)
              .width('100%')
              .height(140)
              .backgroundColor(this.surfaceAlt())
              .borderRadius(8)
              .padding({ left: 14, right: 14, top: 12, bottom: 12 })
              .onChange((value: string) => {
                this.feedbackContent = value;
              })
            Text(`${this.feedbackContent.length}/500`)
              .fontSize(12)
              .fontColor(MUTED)
              .width('100%')
              .textAlign(TextAlign.End)
          }
          .width('100%')

          // 联系方式（可选）
          Column({ space: 8 }) {
            Text('联系方式（选填）')
              .fontSize(16)
              .fontColor(this.primaryText())
              .width('100%')
            TextInput({ text: this.feedbackContact, placeholder: '手机号/邮箱，方便我们回复你' })
              .fontSize(15)
              .maxLength(30)
              .width('100%')
              .height(48)
              .backgroundColor(this.surfaceAlt())
              .borderRadius(8)
              .padding({ left: 14, right: 14 })
              .onChange((value: string) => {
                this.feedbackContact = value;
              })
          }
          .width('100%')

          if (this.feedbackError.length > 0) {
            Text(this.feedbackError)
              .fontSize(14)
              .fontColor(RED)
              .width('100%')
          }

          // 提交按钮
          Button('提交反馈')
            .height(52)
            .width('100%')
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .backgroundColor(BLUE)
            .fontColor(Color.White)
            .borderRadius(8)
            .onClick(() => this.submitFeedback())
        }
        .width('100%')
        .padding({ left: 24, right: 24, top: 20, bottom: 40 })
        .constraintSize({ maxWidth: 560 })
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .layoutWeight(1)
  }

  @Builder
  VersionPage() {
    Column() {
      // Header
      Row({ space: 12 }) {
        Button() {
          Text('<')
            .fontSize(22)
            .fontColor(this.primaryText())
        }
        .width(44)
        .height(44)
        .backgroundColor('transparent')
        .onClick(() => {
          this.flowPage = 'main';
        })

        Text('版本更新')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.primaryText())
          .layoutWeight(1)
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor(this.surface())

      Scroll() {
        Column({ space: 20 }) {
          // 当前版本卡片
          Column({ space: 12 }) {
            Text('🚀')
              .fontSize(48)
            Text(`FaceCheck v${VersionService.getCurrentVersion()}`)
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.primaryText())
            Text('当前版本')
              .fontSize(14)
              .fontColor(this.secondaryText())

            if (this.versionHasNew && this.versionInfo) {
              Column({ space: 8 }) {
                Text(`发现新版本 v${this.versionInfo.latestVersion}`)
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(BLUE)
                Text(`发布时间：${VersionService.formatDate(this.versionInfo.publishDate)}`)
                  .fontSize(13)
                  .fontColor(this.secondaryText())
                Text(this.versionInfo.releaseNotes)
                  .fontSize(14)
                  .fontColor(this.primaryText())
                  .width('100%')
                  .textAlign(TextAlign.Center)

                Button('立即更新')
                  .height(48)
                  .width('80%')
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .backgroundColor(BLUE)
                  .fontColor(Color.White)
                  .borderRadius(8)
                  .margin({ top: 8 })
                  .onClick(() => {
                    this.toast('已跳转至下载页面（模拟）');
                  })

                Button('忽略此版本')
                  .height(40)
                  .width('60%')
                  .fontSize(14)
                  .backgroundColor('transparent')
                  .fontColor(this.secondaryText())
                  .onClick(() => {
                    if (this.versionInfo) {
                      VersionService.ignoreVersion(this.versionInfo.latestVersion);
                      this.versionHasNew = false;
                      this.toast('已忽略此版本');
                    }
                  })
              }
              .width('100%')
              .padding(16)
              .backgroundColor(this.surfaceAlt())
              .borderRadius(12)
              .margin({ top: 8 })
            }

            Button(this.checkingUpdate ? '检查中…' : '检查更新')
              .height(48)
              .width('80%')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .backgroundColor(BLUE)
              .fontColor(Color.White)
              .borderRadius(8)
              .enabled(!this.checkingUpdate)
              .margin({ top: 12 })
              .onClick(() => this.checkUpdate())
          }
          .width('100%')
          .padding(24)
          .backgroundColor(this.surface())
          .borderRadius(12)
          .alignItems(HorizontalAlign.Center)

          // Tab 切换
          Row({ space: 12 }) {
            Text('版本介绍')
              .fontSize(14)
              .fontWeight(this.versionTab === 'current' ? FontWeight.Bold : FontWeight.Normal)
              .fontColor(this.versionTab === 'current' ? '#FFFFFF' : this.secondaryText())
              .padding({ left: 14, right: 14, top: 6, bottom: 6 })
              .backgroundColor(this.versionTab === 'current' ? BLUE : this.surfaceAlt())
              .borderRadius(6)
              .onClick(() => {
                this.versionTab = 'current';
              })

            Text('历史版本')
              .fontSize(14)
              .fontWeight(this.versionTab === 'history' ? FontWeight.Bold : FontWeight.Normal)
              .fontColor(this.versionTab === 'history' ? '#FFFFFF' : this.secondaryText())
              .padding({ left: 14, right: 14, top: 6, bottom: 6 })
              .backgroundColor(this.versionTab === 'history' ? BLUE : this.surfaceAlt())
              .borderRadius(6)
              .onClick(() => {
                this.versionTab = 'history';
              })
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)

          // 内容区域
          if (this.versionTab === 'current') {
            this.VersionCurrentPage()
          } else {
            this.VersionHistoryPage()
          }
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 20, bottom: 40 })
        .constraintSize({ maxWidth: 560 })
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.pageBg())
  }

  @Builder
  VersionCurrentPage() {
    Column({ space: 16 }) {
      Text('本次更新内容')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.primaryText())
        .width('100%')

      if (VersionService.getUpdateLogs().length > 0) {
        Column({ space: 10 }) {
          Row({ space: 10 }) {
            Text(`v${VersionService.getUpdateLogs()[0].version}`)
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(BLUE)
            Text(VersionService.getUpdateLogs()[0].date)
              .fontSize(13)
              .fontColor(this.secondaryText())
            Blank()
            if (VersionService.getUpdateLogs()[0].force) {
              Text('强制更新')
                .fontSize(11)
                .fontColor(RED)
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                .backgroundColor(RED_SOFT)
                .borderRadius(4)
            }
          }
          .width('100%')

          Text(VersionService.getUpdateLogs()[0].title)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.primaryText())
            .width('100%')

          Column({ space: 8 }) {
            ForEach(VersionService.getUpdateLogs()[0].changes, (change: string, index: number) => {
              Row({ space: 8 }) {
                Text('•')
                  .fontSize(14)
                  .fontColor(BLUE)
                Text(change)
                  .fontSize(14)
                  .fontColor(this.primaryText())
                  .layoutWeight(1)
              }
              .width('100%')
            }, (change: string, index: number) => index.toString())
          }
          .width('100%')
        }
        .width('100%')
        .padding(16)
        .backgroundColor(this.surface())
        .borderRadius(12)
      }
    }
    .width('100%')
  }

  @Builder
  VersionHistoryPage() {
    Column({ space: 12 }) {
      Text('历史版本记录')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.primaryText())
        .width('100%')

      ForEach(VersionService.getUpdateLogs(), (log: UpdateLogItem, index: number) => {
        Column({ space: 8 }) {
          Row({ space: 10 }) {
            Text(`v${log.version}`)
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(BLUE)
            Text(log.date)
              .fontSize(13)
              .fontColor(this.secondaryText())
            Blank()
            if (index === 0) {
              Text('当前')
                .fontSize(11)
                .fontColor(GREEN)
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                .backgroundColor(GREEN_SOFT)
                .borderRadius(4)
            }
          }
          .width('100%')

          Text(log.title)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.primaryText())
            .width('100%')

          Column({ space: 6 }) {
            ForEach(log.changes, (change: string, cIdx: number) => {
              Row({ space: 8 }) {
                Text('•')
                  .fontSize(13)
                  .fontColor(BLUE)
                Text(change)
                  .fontSize(13)
                  .fontColor(this.secondaryText())
                  .layoutWeight(1)
              }
              .width('100%')
            }, (change: string, cIdx: number) => cIdx.toString())
          }
          .width('100%')
        }
        .width('100%')
        .padding(16)
        .backgroundColor(this.surface())
        .borderRadius(12)
      }, (log: UpdateLogItem, index: number) => log.version)
    }
    .width('100%')
  }

  private currentPlaceholder(): string {
    for (let i = 0; i < FEEDBACK_TYPE_OPTIONS.length; i++) {
      if (FEEDBACK_TYPE_OPTIONS[i].value === this.feedbackType) {
        return FEEDBACK_TYPE_OPTIONS[i].placeholder;
      }
    }
    return '请描述你的反馈内容…';
  }

  private resetFeedbackForm(): void {
    this.feedbackType = 'bug';
    this.feedbackTitle = '';
    this.feedbackContent = '';
    this.feedbackContact = '';
    this.feedbackError = '';
  }

  private submitFeedback(): void {
    // 校验
    const title: string = this.feedbackTitle.trim();
    const content: string = this.feedbackContent.trim();
    if (title.length < 2) {
      this.feedbackError = '标题至少需要2个字符';
      return;
    }
    if (content.length < 5) {
      this.feedbackError = '描述至少需要5个字符';
      return;
    }

    // 创建反馈
    const now: number = Date.now();
    const feedback: FeedbackItem = {
      id: `fb-${now}`,
      type: this.feedbackType as FeedbackType,
      title: title,
      content: content,
      contact: this.feedbackContact.trim(),
      timestamp: now,
      status: 'pending',
      studentId: this.currentStudentId
    };

    FeedbackService.addFeedback(this.currentStudentId, feedback);
    this.loadFeedbacks();
    this.toast('反馈已提交，感谢你的建议！');

    // 切换到列表页
    this.feedbackTab = 'list';
    this.resetFeedbackForm();
  }
}
