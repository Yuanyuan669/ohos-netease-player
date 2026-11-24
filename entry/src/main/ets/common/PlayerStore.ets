import { Song } from '../model/Types';

// 播放状态放 AppStorage，组件用 @StorageLink 订阅。
// 不用 @Observed/@ObjectLink：控制器是组件树外的单例，改的是同一个对象引用，
// V1 的 @State 代理拦不到这种写入，只有 AppStorage.setOrCreate 能可靠触发刷新。
export class PlayerStore {
  static readonly NAME: string = 'np_name';
  static readonly AUTHOR: string = 'np_author';
  static readonly COVER: string = 'np_cover';
  static readonly TIME: string = 'np_time';
  static readonly DURATION: string = 'np_duration';
  static readonly PLAYING: string = 'np_playing';
  static readonly LOADING: string = 'np_loading';
  static readonly INDEX: string = 'np_index';
  static readonly MODE: string = 'np_mode';
  static readonly PLAYLIST: string = 'np_playlist';
  static readonly ERROR: string = 'np_error';

  static init(): void {
    const empty: Song[] = [];
    AppStorage.setOrCreate(PlayerStore.NAME, '');
    AppStorage.setOrCreate(PlayerStore.AUTHOR, '');
    AppStorage.setOrCreate(PlayerStore.COVER, '');
    AppStorage.setOrCreate(PlayerStore.TIME, 0);
    AppStorage.setOrCreate(PlayerStore.DURATION, 0);
    AppStorage.setOrCreate(PlayerStore.PLAYING, false);
    AppStorage.setOrCreate(PlayerStore.LOADING, false);
    AppStorage.setOrCreate(PlayerStore.INDEX, -1);
    AppStorage.setOrCreate(PlayerStore.MODE, 0);
    AppStorage.setOrCreate(PlayerStore.PLAYLIST, empty);
    AppStorage.setOrCreate(PlayerStore.ERROR, '');
  }
}

export const MODE_ORDER: number = 0;
export const MODE_REPEAT_ONE: number = 1;
export const MODE_SHUFFLE: number = 2;

export function modeLabel(mode: number): string {
  if (mode === MODE_REPEAT_ONE) {
    return '单曲循环';
  }
  if (mode === MODE_SHUFFLE) {
    return '随机播放';
  }
  return '顺序播放';
}

export function formatTime(ms: number): string {
  const total: number = Math.floor(ms / 1000);
  const m: number = Math.floor(total / 60);
  const s: number = total % 60;
  return (m < 10 ? '0' : '') + m + ':' + (s < 10 ? '0' : '') + s;
}
