import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { AttendanceService } from '../main/ets/services/AttendanceService';
import { AccountService } from '../main/ets/services/AccountService';
import { CourseService } from '../main/ets/services/CourseService';
import { FaceDemoService } from '../main/ets/services/FaceDemoService';
import { FaceService } from '../main/ets/services/FaceService';
import { DEMO_USER } from '../main/ets/models/FaceCheckModels';

export default function localUnitTest() {
  describe('localUnitTest', () => {
    // Defines a test suite. Two parameters are supported: test suite name and test suite function.
    beforeAll(() => {
      // Presets an action, which is performed only once before all test cases of the test suite start.
      // This API supports only one parameter: preset action function.
    });
    beforeEach(() => {
      // Presets an action, which is performed before each unit test case starts.
      // The number of execution times is the same as the number of test cases defined by **it**.
      // This API supports only one parameter: preset action function.
    });
    afterEach(() => {
      // Presets a clear action, which is performed after each unit test case ends.
      // The number of execution times is the same as the number of test cases defined by **it**.
      // This API supports only one parameter: clear action function.
    });
    afterAll(() => {
      // Presets a clear action, which is performed after all test cases of the test suite end.
      // This API supports only one parameter: clear action function.
    });
    it('assertContain', 0, () => {
      // Defines a test case. This API supports three parameters: test case name, filter parameter, and test case function.
      let a = 'abc';
      let b = 'b';
      // Defines a variety of assertion methods, which are used to declare expected boolean conditions.
      expect(a).assertContain(b);
      expect(a).assertEqual(a);
    });

    it('courseDataProvidesDemoSchedule', 0, () => {
      const allCourses = CourseService.all();
      const course = CourseService.courseById('course-data-structure');
      expect(allCourses.length > 0).assertTrue();
      if (!course) {
        expect(false).assertTrue();
        return;
      }
      expect(course.courseName).assertEqual('数据结构与算法');
      expect(course.sectionStart).assertEqual(1);
      expect(CourseService.weekdayLabel(5)).assertEqual('周五');
    });

    it('accountLoginValidatesTwoDemoStudents', 0, () => {
      const dq = AccountService.login('202440011987', 'root');
      const root = AccountService.login('202440011111', 'root');
      if (!dq || !root) {
        expect(false).assertTrue();
        return;
      }
      expect(dq.user.name).assertEqual('戴奇威');
      expect(root.user.name).assertEqual('root');
      expect(AccountService.login('202440011111', 'wrong') === undefined).assertTrue();
    });

    it('attendanceRecordPreventsDuplicateSignIn', 0, () => {
      const course = CourseService.courseById('course-data-structure');
      if (!course) {
        expect(false).assertTrue();
        return;
      }
      const now = new Date(2026, 5, 5, 9, 30);
      const record = AttendanceService.createSuccessRecord(DEMO_USER.userId, course, now);
      expect(record.status).assertEqual('success');
      expect(AttendanceService.hasSigned([record], course.courseId, AttendanceService.dateKey(now))).assertTrue();
    });

    it('courseSignStateFollowsTenMinuteWindow', 0, () => {
      const course = CourseService.courseById('course-data-structure');
      if (!course) {
        expect(false).assertTrue();
        return;
      }
      expect(AttendanceService.courseSignState(course, [], new Date(2026, 5, 5, 8, 20)).label).assertEqual('未开始签到');
      expect(AttendanceService.courseSignState(course, [], new Date(2026, 5, 5, 8, 35)).label).assertEqual('开始签到');
      expect(AttendanceService.courseSignState(course, [], new Date(2026, 5, 5, 8, 41)).label).assertEqual('未签到');
    });

    it('faceDemoServiceReturnsSuccessfulFlowResults', 0, () => {
      expect(FaceDemoService.enroll().success).assertTrue();
      expect(FaceDemoService.liveness().success).assertTrue();
      expect(FaceDemoService.compare().success).assertTrue();
    });

    it('faceServiceCreatesSafePlaceholderProfile', 0, async () => {
      FaceService.useVisionReady(false);
      const result = await FaceService.enroll('202440011987');
      expect(result.success).assertTrue();
      expect(result.method).assertEqual('cameraMock');
      if (!result.profile) {
        expect(false).assertTrue();
        return;
      }
      expect(result.profile.studentId).assertEqual('202440011987');
      expect(result.profile.provider).assertEqual('cameraMock');
      expect(result.profile.templateDigest.indexOf('fc-') === 0).assertTrue();
      FaceService.useVisionReady(true);
    });

    it('faceServiceVisionEnrollCreatesLocalReferenceProfileOnly', 0, async () => {
      FaceService.useVisionReady(true);
      const result = await FaceService.enroll('202440011987', '/data/storage/el2/base/files/face_refs/202440011987.fcimg', 'img-demo');
      expect(result.success).assertTrue();
      expect(result.method).assertEqual('face');
      if (!result.profile) {
        expect(false).assertTrue();
        return;
      }
      expect(result.profile.referenceImagePath).assertEqual('/data/storage/el2/base/files/face_refs/202440011987.fcimg');
      expect(result.profile.templateDigest).assertEqual('img-demo');
      expect(result.profile.qualityScore).assertEqual(0);
    });

    it('faceServiceLivenessDoesNotProvideCompareImageInDemoMode', 0, async () => {
      FaceService.useVisionReady(false);
      const result = await FaceService.runLiveness();
      expect(result.success).assertTrue();
      expect(result.pixelMap === undefined).assertTrue();
      FaceService.useVisionReady(true);
    });

    it('faceServiceUsesDemoBackupWhenSelected', 0, async () => {
      FaceService.useVisionReady(false);
      const result = await FaceService.compare('202440011987');
      expect(FaceService.runMode()).assertEqual('demoSafe');
      expect(result.success).assertTrue();
      expect(result.method).assertEqual('cameraMock');
      FaceService.useVisionReady(true);
    });

    it('attendanceFailureRecordKeepsReasonAndMethod', 0, () => {
      const course = CourseService.courseById('course-data-structure');
      if (!course) {
        expect(false).assertTrue();
        return;
      }
      const record = AttendanceService.createFailureRecord(DEMO_USER.userId, course, '未授权摄像头，无法完成刷脸签到', new Date(2026, 5, 5, 8, 36));
      expect(record.status).assertEqual('fail');
      expect(record.verificationMethod).assertEqual('cameraMock');
      expect(record.message).assertEqual('未授权摄像头，无法完成刷脸签到');
    });
  });
}
