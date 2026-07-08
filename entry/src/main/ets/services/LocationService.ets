import { common, abilityAccessCtrl, bundleManager, Permissions, PermissionRequestResult } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { geoLocationManager } from '@kit.LocationKit';
import {
  GeofenceCheckResult,
  GEOFENCE_CENTER_LAT,
  GEOFENCE_CENTER_LNG,
  GEOFENCE_CENTER_NAME,
  GEOFENCE_RADIUS_METERS,
  LocationResult
} from '../models/FaceCheckModels';

/**
 * 定位与地理围栏服务
 *
 * 核心功能：
 * 1. 检查/申请定位权限
 * 2. 获取当前设备位置
 * 3. 判断是否在华南师范大学南海校区围栏内
 * 4. 计算与目标区域的距离
 * 5. 逆地理编码（获取位置描述）
 */
export class LocationService {
  /** 单点定位请求，优先速度 */
  private static buildRequest(): geoLocationManager.SingleLocationRequest {
    return {
      locatingPriority: geoLocationManager.LocatingPriority.PRIORITY_LOCATING_SPEED,
      locatingTimeoutMs: 10000
    };
  }

  /**
   * 检查是否有定位权限（精准 + 模糊至少其一）
   */
  static async hasLocationPermission(): Promise<boolean> {
    const fineStatus = await LocationService.checkPermission('ohos.permission.LOCATION');
    const approxStatus = await LocationService.checkPermission('ohos.permission.APPROXIMATELY_LOCATION');
    return fineStatus === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED ||
      approxStatus === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
  }

  /**
   * 检查是否有精准定位权限
   */
  static async hasPreciseLocation(): Promise<boolean> {
    const status = await LocationService.checkPermission('ohos.permission.LOCATION');
    return status === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
  }

  /**
   * 申请定位权限
   */
  static requestLocationPermission(context: common.UIAbilityContext): Promise<boolean> {
    return new Promise<boolean>((resolve) => {
      const atManager = abilityAccessCtrl.createAtManager();
      atManager.requestPermissionsFromUser(context, [
        'ohos.permission.LOCATION',
        'ohos.permission.APPROXIMATELY_LOCATION'
      ]).then((data: PermissionRequestResult) => {
        const allGranted = data.authResults.every((code: number) => code === 0);
        resolve(allGranted);
      }).catch((err: BusinessError) => {
        console.error(`LocationService: 权限申请失败 code=${err.code} msg=${err.message}`);
        resolve(false);
      });
    });
  }

  /**
   * 获取当前设备位置
   * 返回 LocationResult 或 null（失败时）
   */
  static async getCurrentLocation(): Promise<LocationResult | null> {
    const request = LocationService.buildRequest();
    try {
      const location = await geoLocationManager.getCurrentLocation(request);
      console.info(`LocationService: 定位成功 lat=${location.latitude} lng=${location.longitude} accuracy=${location.accuracy}m source=${location.sourceType}`);
      return {
        latitude: location.latitude,
        longitude: location.longitude,
        accuracy: location.accuracy,
        sourceType: location.sourceType ?? 0,
        timestamp: Date.now()
      };
    } catch (err) {
      const error = err as BusinessError;
      console.error(`LocationService: 获取位置失败 code=${error.code} msg=${error.message}`);
      return null;
    }
  }

  /**
   * 检查用户是否在华南师范大学南海校区地理围栏内
   */
  static async checkGeofence(): Promise<GeofenceCheckResult> {
    const location = await LocationService.getCurrentLocation();

    if (!location) {
      return {
        inside: false,
        userLatitude: 0,
        userLongitude: 0,
        userAddress: '无法获取位置信息',
        targetName: GEOFENCE_CENTER_NAME,
        targetLatitude: GEOFENCE_CENTER_LAT,
        targetLongitude: GEOFENCE_CENTER_LNG,
        distanceMeters: -1,
        radiusMeters: GEOFENCE_RADIUS_METERS,
        hint: '定位失败，请确认设备已开启位置服务并在室外环境下重试。'
      };
    }

    const distance = LocationService.calculateDistance(
      location.latitude, location.longitude,
      GEOFENCE_CENTER_LAT, GEOFENCE_CENTER_LNG
    );

    const inside = distance <= GEOFENCE_RADIUS_METERS;

    // 获取用户位置描述
    let userAddress = '';
    try {
      userAddress = await LocationService.reverseGeocode(location.latitude, location.longitude);
    } catch (err) {
      userAddress = `(${location.latitude.toFixed(4)}, ${location.longitude.toFixed(4)})`;
    }

    let hint: string;
    if (inside) {
      hint = `您已在${GEOFENCE_CENTER_NAME}范围内，可以进行签到。`;
    } else {
      if (distance < 1000) {
        hint = `您距离${GEOFENCE_CENTER_NAME}约 ${distance.toFixed(0)} 米，请靠近校区后再签到。`;
      } else {
        hint = `您不在${GEOFENCE_CENTER_NAME}区域内（距校区约 ${(distance / 1000).toFixed(1)} 公里），无法签到。`;
      }
    }

    return {
      inside,
      userLatitude: location.latitude,
      userLongitude: location.longitude,
      userAddress,
      targetName: GEOFENCE_CENTER_NAME,
      targetLatitude: GEOFENCE_CENTER_LAT,
      targetLongitude: GEOFENCE_CENTER_LNG,
      distanceMeters: Math.round(distance),
      radiusMeters: GEOFENCE_RADIUS_METERS,
      hint
    };
  }

  /**
   * 基于 Haversine 公式计算两点间球面距离（单位：米）
   */
  static calculateDistance(
    lat1: number, lng1: number,
    lat2: number, lng2: number
  ): number {
    const R = 6371000; // 地球半径（米）
    const toRad = (deg: number): number => deg * Math.PI / 180;

    const dLat = toRad(lat2 - lat1);
    const dLng = toRad(lng2 - lng1);
    const a = Math.sin(dLat / 2) ** 2 +
      Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) *
      Math.sin(dLng / 2) ** 2;
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
  }

  /**
   * 逆地理编码：将经纬度转换为可读地址
   */
  private static async reverseGeocode(latitude: number, longitude: number): Promise<string> {
    try {
      const request: geoLocationManager.ReverseGeoCodeRequest = {
        locale: 'zh',
        latitude,
        longitude,
        maxItems: 1
      };
      const results = await geoLocationManager.getAddressesFromLocation(request);
      if (results && results.length > 0) {
        const addr = results[0];
        const parts: string[] = [];
        if (addr.administrativeArea) {
          parts.push(addr.administrativeArea); // 省
        }
        if (addr.locality) {
          parts.push(addr.locality); // 市
        }
        if (addr.subLocality) {
          parts.push(addr.subLocality); // 区/县
        }
        return parts.length > 0 ? parts.join(' ') : `(${latitude.toFixed(4)}, ${longitude.toFixed(4)})`;
      }
    } catch (err) {
      console.error(`LocationService: 逆地理编码失败 ${JSON.stringify(err)}`);
    }
    return `(${latitude.toFixed(4)}, ${longitude.toFixed(4)})`;
  }

  /**
   * 格式化距离显示
   */
  static formatDistance(meters: number): string {
    if (meters < 0) {
      return '未知';
    }
    if (meters < 1000) {
      return `${meters} 米`;
    }
    return `${(meters / 1000).toFixed(2)} 公里`;
  }

  /**
   * 检查单个权限
   */
  private static async checkPermission(permission: Permissions): Promise<abilityAccessCtrl.GrantStatus> {
    const atManager = abilityAccessCtrl.createAtManager();
    let tokenId = 0;
    try {
      const bundleInfo = await bundleManager.getBundleInfoForSelf(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION
      );
      tokenId = bundleInfo.appInfo.accessTokenId;
    } catch (err) {
      console.error(`LocationService: 获取token失败 ${JSON.stringify(err)}`);
      return abilityAccessCtrl.GrantStatus.PERMISSION_DENIED;
    }
    try {
      return await atManager.checkAccessToken(tokenId, permission);
    } catch (err) {
      console.error(`LocationService: 检查权限失败 ${JSON.stringify(err)}`);
      return abilityAccessCtrl.GrantStatus.PERMISSION_DENIED;
    }
  }

  /**
   * 定位来源描述
   */
  static sourceTypeLabel(sourceType: number): string {
    switch (sourceType) {
      case 1:
        return 'GPS卫星定位';
      case 2:
        return '网络基站定位';
      default:
        return '未知来源';
    }
  }
}
