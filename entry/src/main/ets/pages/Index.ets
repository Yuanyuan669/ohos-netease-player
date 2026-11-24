import router from '@ohos.router';
import { Playlist, Song } from '../model/Types';
import { NeteaseApi, PlaylistDetail } from '../service/NeteaseApi';
import { playerController } from '../service/PlayerController';
import { Log } from '../common/Logger';

const BRAND: string = '#EC4141';
const TEXT_MAIN: string = '#222222';
const TEXT_SUB: string = '#999999';
const DIVIDER: string = '#F2F2F2';

function playCount(n: number): string {
  if (n >= 100000000) {
    return (n / 100000000).toFixed(1) + '亿';
  }
  if (n >= 10000) {
    return Math.floor(n / 10000) + '万';
  }
  return '' + n;
}

@Entry
@Component
struct Index {
  @State tab: number = 0;
  @State recommend: Playlist[] = [];
  @State toplist: Playlist[] = [];
  @State loading: boolean = true;
  @State errText: string = '';
  @State inDetail: boolean = false;
  @State detailName: string = '';
  @State songs: Song[] = [];
  @State detailLoading: boolean = false;

  @StorageLink('np_name') npName: string = '';
  @StorageLink('np_author') npAuthor: string = '';
  @StorageLink('np_cover') npCover: string = '';
  @StorageLink('np_playing') npPlaying: boolean = false;
  @StorageLink('np_loading') npLoading: boolean = false;
  @StorageLink('np_error') npError: string = '';

  aboutToAppear(): void {
    this.reload();
  }

  onBackPress(): boolean {
    if (this.inDetail) {
      this.inDetail = false;
      return true;
    }
    return false;
  }

  async reload(): Promise<void> {
    this.loading = true;
    this.errText = '';
    const rec: Playlist[] = await NeteaseApi.recommend(12);
    const top: Playlist[] = await NeteaseApi.topList();
    this.recommend = rec;
    this.toplist = top;
    this.loading = false;
    if (rec.length === 0 && top.length === 0) {
      this.errText = '拿不到歌单，检查网络后重试';
    }
  }

  async openPlaylist(id: number): Promise<void> {
    this.detailLoading = true;
    this.inDetail = true;
    this.songs = [];
    this.detailName = '';
    const detail: PlaylistDetail | null = await NeteaseApi.playlistDetail(id);
    this.detailLoading = false;
    if (detail === null) {
      this.detailName = '加载失败';
      return;
    }
    this.detailName = detail.name;
    this.songs = detail.songs;
    if (detail.songs.length === 0) {
      this.detailName = detail.name + '（无曲目）';
    }
  }

  currentList(): Playlist[] {
    return this.tab === 0 ? this.recommend : this.toplist;
  }

  @Builder
  TabButton(label: string, index: number) {
    Text(label)
      .fontSize(15)
      .fontWeight(this.tab === index ? FontWeight.Bold : FontWeight.Normal)
      .fontColor(this.tab === index ? BRAND : TEXT_SUB)
      .padding({ left: 14, right: 14, top: 8, bottom: 8 })
      .onClick(() => {
        this.tab = index;
      })
  }

  @Builder
  PlaylistRow(item: Playlist) {
    Row({ space: 12 }) {
      Image(item.cover)
        .width(56)
        .height(56)
        .borderRadius(6)
        .objectFit(ImageFit.Cover)
        .backgroundColor(DIVIDER)
      Column({ space: 4 }) {
        Text(item.name)
          .fontSize(15)
          .fontColor(TEXT_MAIN)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(item.trackCount + ' 首 · 播放 ' + playCount(item.playCount))
          .fontSize(12)
          .fontColor(TEXT_SUB)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
    .onClick(() => {
      this.openPlaylist(item.id);
    })
  }

  @Builder
  SongRow(song: Song, idx: number) {
    Row({ space: 12 }) {
      Text('' + (idx + 1))
        .fontSize(13)
        .fontColor(TEXT_SUB)
        .width(28)
      Column({ space: 3 }) {
        Text(song.name)
          .fontSize(15)
          .fontColor(TEXT_MAIN)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(song.author)
          .fontSize(12)
          .fontColor(TEXT_SUB)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 10, bottom: 10 })
    .onClick(() => {
      playerController.playQueue(this.songs, idx);
    })
  }

  @Builder
  PlayerBar() {
    Row({ space: 10 }) {
      Image(this.npCover)
        .width(42)
        .height(42)
        .borderRadius(21)
        .objectFit(ImageFit.Cover)
        .backgroundColor(DIVIDER)
      Column({ space: 2 }) {
        Text(this.npName)
          .fontSize(14)
          .fontColor('#FFFFFF')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.npLoading ? '缓冲中…' : this.npAuthor)
          .fontSize(11)
          .fontColor('#BBBBBB')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text(this.npPlaying ? '暂停' : '播放')
        .fontSize(13)
        .fontColor('#FFFFFF')
        .width(44)
        .textAlign(TextAlign.Center)
        .onClick(() => {
          playerController.toggle();
        })
      Text('»')
        .fontSize(18)
        .fontColor('#FFFFFF')
        .width(36)
        .textAlign(TextAlign.Center)
        .onClick(() => {
          playerController.playNext(false);
        })
    }
    .width('100%')
    .height(60)
    .padding({ left: 12, right: 8 })
    .backgroundColor('#1A1A1A')
    .onClick(() => {
      router.pushUrl({ url: 'pages/PlayerPage' }).catch((e: Error) => {
        Log.warn('push PlayerPage failed: ' + e.message);
      });
    })
  }

  build() {
    Column() {
      if (!this.inDetail) {
        Row() {
          Text('云音乐')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(TEXT_MAIN)
            .layoutWeight(1)
          Text('刷新')
            .fontSize(13)
            .fontColor(BRAND)
            .onClick(() => {
              this.reload();
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 8 })

        Row() {
          this.TabButton('推荐歌单', 0)
          this.TabButton('排行榜', 1)
        }
        .width('100%')

        if (this.loading) {
          Column() {
            LoadingProgress().width(40).height(40).color(BRAND)
            Text('加载中…').fontSize(13).fontColor(TEXT_SUB).margin({ top: 10 })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else if (this.errText.length > 0) {
          Column({ space: 14 }) {
            Text(this.errText).fontSize(14).fontColor(TEXT_SUB)
            Button('重试')
              .fontSize(14)
              .backgroundColor(BRAND)
              .onClick(() => {
                this.reload();
              })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          List() {
            ForEach(this.currentList(), (item: Playlist) => {
              ListItem() {
                this.PlaylistRow(item)
              }
            }, (item: Playlist) => '' + item.id)
          }
          .width('100%')
          .layoutWeight(1)
          .divider({ strokeWidth: 1, color: DIVIDER, startMargin: 84, endMargin: 16 })
        }
      } else {
        Row({ space: 10 }) {
          Text('‹')
            .fontSize(26)
            .fontColor(TEXT_MAIN)
            .width(36)
            .onClick(() => {
              this.inDetail = false;
            })
          Text(this.detailName)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(TEXT_MAIN)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          if (this.songs.length > 0) {
            Text('播放全部')
              .fontSize(13)
              .fontColor('#FFFFFF')
              .backgroundColor(BRAND)
              .borderRadius(14)
              .padding({ left: 12, right: 12, top: 6, bottom: 6 })
              .onClick(() => {
                playerController.playQueue(this.songs, 0);
              })
          }
        }
        .width('100%')
        .padding({ left: 8, right: 16, top: 10, bottom: 10 })

        if (this.detailLoading) {
          Column() {
            LoadingProgress().width(40).height(40).color(BRAND)
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else if (this.songs.length === 0) {
          Column() {
            Text('该歌单没有可播放的曲目（均为版权受限）')
              .fontSize(13)
              .fontColor(TEXT_SUB)
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          List() {
            ForEach(this.songs, (song: Song, idx: number) => {
              ListItem() {
                this.SongRow(song, idx)
              }
            }, (song: Song) => '' + song.id)
          }
          .width('100%')
          .layoutWeight(1)
          .divider({ strokeWidth: 1, color: DIVIDER, startMargin: 56, endMargin: 16 })
        }
      }

      if (this.npError.length > 0) {
        Text(this.npError)
          .fontSize(12)
          .fontColor('#FFFFFF')
          .backgroundColor('#C0392B')
          .width('100%')
          .padding({ left: 16, right: 16, top: 6, bottom: 6 })
      }

      if (this.npName.length > 0) {
        this.PlayerBar()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }
}
