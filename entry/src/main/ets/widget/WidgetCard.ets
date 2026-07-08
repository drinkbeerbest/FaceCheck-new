const localStorage = new LocalStorage();

@Entry(localStorage)
@Component
struct WidgetCard {
  @LocalStorageProp('todayCourseName') todayCourseName: string = '今日无课';
  @LocalStorageProp('todayCourseTime') todayCourseTime: string = '';
  @LocalStorageProp('todayCourseRoom') todayCourseRoom: string = '';
  @LocalStorageProp('rateText') rateText: string = '0%';
  @LocalStorageProp('successCount') successCount: number = 0;
  @LocalStorageProp('failCount') failCount: number = 0;
  @LocalStorageProp('signedToday') signedToday: number = 0;
  @LocalStorageProp('loggedIn') loggedIn: boolean = false;
  @LocalStorageProp('hasFace') hasFace: boolean = false;

  build() {
    Column() {
      Row() {
        Column() {
          Text('FaceCheck 今日考勤')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#0B67D1')
          Text(this.loggedIn ? (this.hasFace ? '已就绪 · 可签到' : '请先录入人脸') : '未登录')
            .fontSize(11)
            .fontColor('#697386')
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)

        Column() {
          Text(this.rateText)
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor('#18B86B')
          Text('出勤率')
            .fontSize(10)
            .fontColor('#697386')
        }
        .alignItems(HorizontalAlign.End)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)

      Divider()
        .margin({ top: 10, bottom: 10 })
        .color('#EEF2F8')

      Row() {
        Column() {
          Text(this.todayCourseName)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1A1A1A')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.todayCourseTime) {
            Text(`${this.todayCourseTime}  ${this.todayCourseRoom}`)
              .fontSize(11)
              .fontColor('#697386')
              .margin({ top: 4 })
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Button('去签到')
          .fontSize(12)
          .height(32)
          .backgroundColor('#0B67D1')
          .onClick(() => {
            postCardAction(this, {
              action: 'router',
              abilityName: 'EntryAbility',
              params: { target: 'sign' }
            });
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
  }
}
