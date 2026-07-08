import { MapComponent, mapCommon, map } from '@kit.MapKit';
import { AsyncCallback } from '@kit.BasicServicesKit';
import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import {
  GEOFENCE_CENTER_LAT,
  GEOFENCE_CENTER_LNG,
  GEOFENCE_CENTER_NAME,
  GEOFENCE_RADIUS_METERS,
  GeofenceCheckResult
} from '../models/FaceCheckModels';
import { LocationService } from '../services/LocationService';

@Entry
@Component
struct MapPage {
  private mapOptions: mapCommon.MapOptions = {
    position: {
      target: {
        latitude: GEOFENCE_CENTER_LAT,
        longitude: GEOFENCE_CENTER_LNG
      },
      zoom: 15
    },
    myLocationControlsEnabled: true,
    scaleControlsEnabled: true,
    zoomControlsEnabled: true
  };

  private mapCallback: AsyncCallback<map.MapComponentController> = async (err, mapController) => {
    if (!err) {
      this.mapController = mapController;
      // 地图加载完成后绘制围栏和分析位置
      mapController.getEventManager().on('mapLoad', () => {
        this.onMapReady();
      });
    }
  };

  private mapController?: map.MapComponentController;
  private schoolMarker?: map.Marker;
  private userMarker?: map.Marker;
  private fenceCircle?: map.MapCircle;
  @State private geofenceResult: GeofenceCheckResult | null = null;
  @State private isLocated: boolean = false;
  @State private isLocating: boolean = true;

  /**
   * 地图就绪后：绘制围栏圆圈 + 学校标记 + 尝试定位用户
   */
  private async onMapReady(): Promise<void> {
    await this.drawGeofenceCircle();
    await this.addSchoolMarker();
    await this.locateAndAddUserMarker();
  }

  /**
   * 绘制围栏圆圈
   */
  private async drawGeofenceCircle(): Promise<void> {
    if (!this.mapController) {
      return;
    }
    const circleOptions: mapCommon.MapCircleOptions = {
      center: {
        latitude: GEOFENCE_CENTER_LAT,
        longitude: GEOFENCE_CENTER_LNG
      },
      radius: GEOFENCE_RADIUS_METERS,
      fillColor: 0x300B67D1,      // 半透明蓝色填充
      strokeColor: 0xFF0B67D1,     // 蓝色描边
      strokeWidth: 3,
      visible: true,
      clickable: false,
      zIndex: 5
    };
    try {
      this.fenceCircle = await this.mapController.addCircle(circleOptions);
      console.info('MapPage: 围栏圆圈已绘制');
    } catch (err) {
      console.error(`MapPage: 绘制圆圈失败 ${JSON.stringify(err)}`);
    }
  }

  /**
   * 添加学校位置标记
   */
  private async addSchoolMarker(): Promise<void> {
    if (!this.mapController) {
      return;
    }
    const markerOptions: mapCommon.MarkerOptions = {
      position: {
        latitude: GEOFENCE_CENTER_LAT,
        longitude: GEOFENCE_CENTER_LNG
      },
      title: GEOFENCE_CENTER_NAME,
      snippet: `签到范围: ${GEOFENCE_RADIUS_METERS}米`,
      clickable: true
    };
    try {
      this.schoolMarker = await this.mapController.addMarker(markerOptions);
      this.schoolMarker?.setInfoWindowVisible(true);
      console.info('MapPage: 学校标记已添加');
    } catch (err) {
      console.error(`MapPage: 添加学校标记失败 ${JSON.stringify(err)}`);
    }
  }

  /**
   * 获取用户位置并在地图上显示
   */
  private async locateAndAddUserMarker(): Promise<void> {
    if (!this.mapController) {
      return;
    }
    this.isLocating = true;

    const result = await LocationService.checkGeofence();
    this.geofenceResult = result;

    if (result && result.distanceMeters >= 0) {
      this.isLocated = true;

      // 已有用户标记则先移除
      try {
        if (this.userMarker) {
          this.userMarker.remove();
        }
      } catch (err) {
        console.warn(`MapPage: 移除旧标记失败`);
      }

      const markerOptions: mapCommon.MarkerOptions = {
        position: {
          latitude: result.userLatitude,
          longitude: result.userLongitude
        },
        title: '我的位置',
        snippet: result.inside
          ? `已在签到区域内`
          : `距校区 ${LocationService.formatDistance(result.distanceMeters)}`,
        clickable: true
      };
      try {
        this.userMarker = await this.mapController.addMarker(markerOptions);
        this.userMarker?.setInfoWindowVisible(true);

        // 将地图视角调整到能同时看到学校和用户
        await this.mapController.animateCamera(
          map.newCameraPosition({
            target: {
              latitude: (result.userLatitude + GEOFENCE_CENTER_LAT) / 2,
              longitude: (result.userLongitude + GEOFENCE_CENTER_LNG) / 2
            },
            zoom: 13,
            tilt: 0,
            bearing: 0
          }),
          800
        );
        console.info('MapPage: 用户定位标记已添加');
      } catch (err) {
        console.error(`MapPage: 添加用户标记失败 ${JSON.stringify(err)}`);
      }
    } else {
      // 定位失败
      promptAction.showToast({
        message: '无法获取当前位置，请检查位置服务',
        duration: 2000
      });
    }
    this.isLocating = false;
  }

  /**
   * 重新定位
   */
  private async refreshLocation(): Promise<void> {
    await this.locateAndAddUserMarker();
  }

  /**
   * 回到学校中心
   */
  private async goToSchoolCenter(): Promise<void> {
    if (!this.mapController) {
      return;
    }
    try {
      await this.mapController.animateCamera(
        map.newCameraPosition({
          target: {
            latitude: GEOFENCE_CENTER_LAT,
            longitude: GEOFENCE_CENTER_LNG
          },
          zoom: 15,
          tilt: 0,
          bearing: 0
        }),
        500
      );
    } catch (err) {
      console.error(`MapPage: 移动相机失败`);
    }
  }

  build() {
    Stack() {
      // 地图
      MapComponent({
        mapOptions: this.mapOptions,
        mapCallback: this.mapCallback
      })
        .width('100%')
        .height('100%')

      // 顶部栏
      Column() {
        Row() {
          Button() {
            Text('← 返回')
              .fontSize(16)
              .fontColor('#0B67D1')
              .fontWeight(FontWeight.Medium)
          }
          .height(40)
          .backgroundColor('#FFFFFF')
          .borderRadius(20)
          .padding({ left: 16, right: 16 })
          .shadow({ radius: 8, color: '#00000020', offsetY: 2 })
          .onClick(() => router.back())

          Blank()

          Row({ space: 8 }) {
            // 回到学校中心
            Button() {
              Text('校区中心')
                .fontSize(13)
                .fontColor('#FFFFFF')
            }
            .height(36)
            .backgroundColor('#0B67D1')
            .borderRadius(18)
            .padding({ left: 12, right: 12 })
            .onClick(() => this.goToSchoolCenter())

            // 重新定位
            Button() {
              Text(this.isLocating ? '定位中…' : '重新定位')
                .fontSize(13)
                .fontColor('#FFFFFF')
            }
            .height(36)
            .backgroundColor(this.isLocating ? '#A6B0C2' : '#18B86B')
            .borderRadius(18)
            .padding({ left: 12, right: 12 })
            .enabled(!this.isLocating)
            .onClick(() => this.refreshLocation())
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 40 })
      }
      .width('100%')
      .position({ x: 0, y: 0 })

      // 底部信息卡片
      Column() {
        if (this.geofenceResult) {
          Row() {
            Column({ space: 4 }) {
              Row({ space: 6 }) {
                Text(this.geofenceResult.inside ? '●' : '●')
                  .fontSize(10)
                  .fontColor(this.geofenceResult.inside ? '#18B86B' : '#F05252')
                Text(this.geofenceResult.inside ? '已在签到区域内' : '不在签到区域内')
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.geofenceResult.inside ? '#18B86B' : '#F05252')
              }

              if (this.geofenceResult.distanceMeters >= 0) {
                Text(`距${GEOFENCE_CENTER_NAME}：${LocationService.formatDistance(this.geofenceResult.distanceMeters)}`)
                  .fontSize(13)
                  .fontColor('#697386')
              }

              Text(`围栏半径：${GEOFENCE_RADIUS_METERS} 米`)
                .fontSize(13)
                .fontColor('#697386')
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
          }
          .width('100%')
          .padding(14)
          .backgroundColor('#FFFFFF')
          .borderRadius(12)
          .shadow({ radius: 12, color: '#00000018', offsetY: 4 })
        } else if (this.isLocating) {
          Row() {
            Text('正在定位…')
              .fontSize(14)
              .fontColor('#697386')
            LoadingProgress()
              .width(18)
              .height(18)
              .color('#0B67D1')
              .margin({ left: 8 })
          }
          .width('100%')
          .padding(14)
          .backgroundColor('#FFFFFF')
          .borderRadius(12)
          .shadow({ radius: 12, color: '#00000018', offsetY: 4 })
        } else {
          Row() {
            Text('定位失败')
              .fontSize(14)
              .fontColor('#F05252')
          }
          .width('100%')
          .padding(14)
          .backgroundColor('#FFFFFF')
          .borderRadius(12)
          .shadow({ radius: 12, color: '#00000018', offsetY: 4 })
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 24 })
      .position({ x: 0, y: '100%' })
      .translate({ y: '-100%' })

      // 图例
      Row({ space: 16 }) {
        Row({ space: 6 }) {
          Circle({ width: 10, height: 10 })
            .fill('#0B67D1')
          Text('签到范围')
            .fontSize(12)
            .fontColor('#FFFFFF')
        }
        Row({ space: 6 }) {
          Circle({ width: 10, height: 10 })
            .fill('#F05252')
          Text('学校位置')
            .fontSize(12)
            .fontColor('#FFFFFF')
        }
        if (this.isLocated) {
          Row({ space: 6 }) {
            Circle({ width: 10, height: 10 })
              .fill('#18B86B')
            Text('我的位置')
              .fontSize(12)
              .fontColor('#FFFFFF')
          }
        }
      }
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .backgroundColor('#000000AA')
      .borderRadius(16)
      .position({ x: 16, y: 100 })
    }
    .width('100%')
    .height('100%')
  }
}
