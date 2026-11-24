import router from '@ohos.router';
import { Song } from '../model/Types';
import { playerController } from '../service/PlayerController';
import { formatTime, modeLabel } from '../common/PlayerStore';

const BRAND: string = '#EC4141';
const BG: string = '#161616';
const FG: string = '#FFFFFF';
const SUB: string = '#AAAAAA';

@Entry
@Component
struct PlayerPage {
  @State showList: boolean = false;

  @StorageLink('np_name') npName: string = '';
  @StorageLink('np_author') npAuthor: string = '';
  @StorageLink('np_cover') npCover: string = '';
  @StorageLink('np_time') npTime: number = 0;
  @StorageLink('np_duration') npDuration: number = 0;
  @StorageLink('np_playing') npPlaying: boolean = false;
  @StorageLink('np_loading') npLoading: boolean = false;
  @StorageLink('np_index') npIndex: number = -1;
  @StorageLink('np_mode') npMode: number = 0;
  @StorageLink('np_playlist') npList: Song[] = [];
  @StorageLink('np_error') npError: string = '';

  safeMax(): number {
    return this.npDuration > 0 ? this.npDuration : 1;
  }

  build() {    Column() {
      Row() {
        Text('‹')
          .fontSize(28)
          .fontColor(FG)
          .width(44)
          .onClick(() => {
            router.back();
          })
        Text(modeLabel(this.npMode))
          .fontSize(13)
          .fontColor(SUB)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Text('列表')
          .fontSize(14)
          .fontColor(this.showList ? BRAND : SUB)
          .width(44)
          .textAlign(TextAlign.End)
          .onClick(() => {
            this.showList = !this.showList;
          })
      }
      .width('100%')
      .padding({ left: 8, right: 12, top: 10, bottom: 6 })

      if (this.showList) {
        List() {
          ForEach(this.npList, (song: Song, idx: number) => {
            ListItem() {
              Row({ space: 10 }) {
                Text('' + (idx + 1))
                  .fontSize(12)
                  .fontColor(idx === this.npIndex ? BRAND : SUB)
                  .width(28)
                Column({ space: 2 }) {
                  Text(song.name)
                    .fontSize(14)
                    .fontColor(idx === this.npIndex ? BRAND : FG)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(song.author)
                    .fontSize(11)
                    .fontColor(SUB)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
              }
              .width('100%')
              .padding({ left: 12, right: 16, top: 9, bottom: 9 })
              .onClick(() => {
                playerController.loadIndex(idx);
              })
            }
          }, (song: Song) => '' + song.id)
        }
        .width('100%')
        .layoutWeight(1)
        .divider({ strokeWidth: 1, color: '#2A2A2A', startMargin: 50, endMargin: 16 })
      } else {
        Column({ space: 18 }) {
          Image(this.npCover)
            .width(240)
            .height(240)
            .borderRadius(120)
            .objectFit(ImageFit.Cover)
            .backgroundColor('#2A2A2A')
          Text(this.npName)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(FG)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .padding({ left: 32, right: 32 })
          Text(this.npAuthor)
            .fontSize(14)
            .fontColor(SUB)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .padding({ left: 32, right: 32 })
          if (this.npError.length > 0) {
            Text(this.npError)
              .fontSize(12)
              .fontColor(BRAND)
              .padding({ left: 32, right: 32 })
          }
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      }

      Column({ space: 4 }) {
        Slider({ value: this.npTime, min: 0, max: this.safeMax(), step: 1 })
          .width('100%')
          .selectedColor(BRAND)
          .trackColor('#3A3A3A')
          .blockColor(FG)
          .onChange((value: number, mode: SliderChangeMode) => {
            if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
              playerController.seek(value);
            }
          })
        Row() {
          Text(formatTime(this.npTime)).fontSize(11).fontColor(SUB)
          Blank()
          Text(this.npLoading ? '缓冲中…' : formatTime(this.npDuration)).fontSize(11).fontColor(SUB)
        }
        .width('100%')
        .padding({ left: 20, right: 20 })
      }
      .width('100%')

      Row() {
        Text(modeLabel(this.npMode))
          .fontSize(12)
          .fontColor(SUB)
          .width(64)
          .height(56)
          .textAlign(TextAlign.Center)
          .onClick(() => {
            playerController.cycleMode();
          })
        Text('‹‹')
          .fontSize(24)
          .fontColor(FG)
          .width(64)
          .height(56)
          .textAlign(TextAlign.Center)
          .onClick(() => {
            playerController.playPrevious();
          })
        Text(this.npPlaying ? '暂停' : '播放')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(FG)
          .width(76)
          .height(56)
          .textAlign(TextAlign.Center)
          .backgroundColor('#2A2A2A')
          .borderRadius(28)
          .onClick(() => {
            playerController.toggle();
          })
        Text('››')
          .fontSize(24)
          .fontColor(FG)
          .width(64)
          .height(56)
          .textAlign(TextAlign.Center)
          .onClick(() => {
            playerController.playNext(false);
          })
        Text('列表')
          .fontSize(12)
          .fontColor(this.showList ? BRAND : SUB)
          .width(64)
          .height(56)
          .textAlign(TextAlign.Center)
          .onClick(() => {
            this.showList = !this.showList;
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceEvenly)
      .padding({ top: 10, bottom: 24 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(BG)
  }
}
