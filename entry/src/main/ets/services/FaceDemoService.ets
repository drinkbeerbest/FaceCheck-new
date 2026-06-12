import { FaceDemoResult } from '../models/FaceCheckModels';

export class FaceDemoService {
  static enroll(): FaceDemoResult {
    // TODO: Replace this demo branch with Huawei Face Detector feature extraction.
    // Reference: core-vision-face-detector in HarmonyOS guides.
    return {
      success: true,
      message: '人脸特征分析完成，样本已加密保存到本地'
    };
  }

  static liveness(): FaceDemoResult {
    // TODO: Replace this demo branch with Interactive Liveness action detection.
    return {
      success: true,
      message: '眨眼动作检测通过'
    };
  }

  static compare(): FaceDemoResult {
    // TODO: Replace this demo branch with Huawei Face Comparator.
    return {
      success: true,
      message: '人脸匹配成功'
    };
  }
}
