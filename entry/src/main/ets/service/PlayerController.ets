import media from '@ohos.multimedia.media';
import { Log } from '../common/Logger';
import { Song } from '../model/Types';
import { NeteaseApi } from './NeteaseApi';
import { PlayerStore, MODE_ORDER, MODE_REPEAT_ONE, MODE_SHUFFLE } from '../common/PlayerStore';
import { sessionManager, PlayerCommands } from './SessionManager';

class PlayerController implements PlayerCommands {
  private player: media.AVPlayer | null = null;
  private list: Song[] = [];
  private index: number = -1;
  private mode: number = MODE_ORDER;
  private time: number = 0;
  private duration: number = 0;

  async init(): Promise<void> {
    if (this.player !== null) {
      return;
    }
    try {
      this.player = await media.createAVPlayer();
      this.bindEvents();
      Log.info('avplayer created, state=' + this.player.state);
    } catch (e) {
      Log.error('createAVPlayer failed: ' + (e as Error).message);
    }
  }

  private bindEvents(): void {
    const p: media.AVPlayer | null = this.player;
    if (p === null) {
      return;
    }
    p.on('stateChange', (state: media.AVPlayerState) => {
      Log.info('state=' + state);
      if (state === 'initialized') {
        p.prepare();
      } else if (state === 'prepared') {
        AppStorage.setOrCreate(PlayerStore.LOADING, false);
        p.play();
      } else if (state === 'playing') {
        AppStorage.setOrCreate(PlayerStore.PLAYING, true);
        AppStorage.setOrCreate(PlayerStore.ERROR, '');
        sessionManager.startBackgroundTask();
        sessionManager.syncState(true, this.time, this.duration);
      } else if (state === 'paused') {
        AppStorage.setOrCreate(PlayerStore.PLAYING, false);
        sessionManager.syncState(false, this.time, this.duration);
      } else if (state === 'completed') {
        AppStorage.setOrCreate(PlayerStore.PLAYING, false);
        this.playNext(true);
      } else if (state === 'error') {
        AppStorage.setOrCreate(PlayerStore.PLAYING, false);
        AppStorage.setOrCreate(PlayerStore.LOADING, false);
      }
    });

    p.on('timeUpdate', (t: number) => {
      this.time = t;
      AppStorage.setOrCreate(PlayerStore.TIME, t);
    });

    p.on('durationUpdate', (d: number) => {
      this.duration = d;
      AppStorage.setOrCreate(PlayerStore.DURATION, d);
      if (this.index >= 0 && this.index < this.list.length) {
        sessionManager.setMeta(this.list[this.index], d);
      }
    });

    p.on('seekDone', (t: number) => {
      this.time = t;
      AppStorage.setOrCreate(PlayerStore.TIME, t);
    });

    p.on('error', (err: Error) => {
      const msg: string = '这首放不了（版权或网络）';
      Log.error('avplayer error: ' + (err as Error).message);
      AppStorage.setOrCreate(PlayerStore.ERROR, msg);
      AppStorage.setOrCreate(PlayerStore.LOADING, false);
      AppStorage.setOrCreate(PlayerStore.PLAYING, false);
    });
  }

  // 换一批歌并从 startIndex 开始播
  async playQueue(songs: Song[], startIndex: number): Promise<void> {
    if (songs.length === 0) {
      return;
    }
    this.list = songs;
    AppStorage.setOrCreate(PlayerStore.PLAYLIST, songs.slice());
    await this.loadIndex(startIndex);
  }

  // 往当前队列末尾追加，不打断播放
  appendQueue(songs: Song[]): void {
    if (songs.length === 0) {
      return;
    }
    for (let i = 0; i < songs.length; i++) {
      this.list.push(songs[i]);
    }
    AppStorage.setOrCreate(PlayerStore.PLAYLIST, this.list.slice());
  }

  async loadIndex(i: number): Promise<void> {
    if (i < 0 || i >= this.list.length) {
      return;
    }
    const p: media.AVPlayer | null = this.player;
    if (p === null) {
      await this.init();
    }
    const player: media.AVPlayer | null = this.player;
    if (player === null) {
      AppStorage.setOrCreate(PlayerStore.ERROR, '播放器初始化失败');
      return;
    }

    const song: Song = this.list[i];
    this.index = i;
    this.time = 0;
    this.duration = song.duration;

    AppStorage.setOrCreate(PlayerStore.INDEX, i);
    AppStorage.setOrCreate(PlayerStore.NAME, song.name);
    AppStorage.setOrCreate(PlayerStore.AUTHOR, song.author);
    AppStorage.setOrCreate(PlayerStore.COVER, song.cover);
    AppStorage.setOrCreate(PlayerStore.TIME, 0);
    AppStorage.setOrCreate(PlayerStore.DURATION, song.duration);
    AppStorage.setOrCreate(PlayerStore.LOADING, true);
    AppStorage.setOrCreate(PlayerStore.ERROR, '');

    try {
      await player.reset();
      player.url = NeteaseApi.streamUrl(song.id);
      Log.info('load ' + song.name + ' id=' + song.id);
    } catch (e) {
      Log.error('loadIndex failed: ' + (e as Error).message);
      AppStorage.setOrCreate(PlayerStore.LOADING, false);
      AppStorage.setOrCreate(PlayerStore.ERROR, '加载失败：' + (e as Error).message);
    }
  }

  play(): void {
    const p: media.AVPlayer | null = this.player;
    if (p === null) {
      return;
    }
    const s: string = p.state;
    if (s === 'paused' || s === 'prepared' || s === 'completed') {
      p.play();
    }
  }

  pause(): void {
    const p: media.AVPlayer | null = this.player;
    if (p !== null && p.state === 'playing') {
      p.pause();
    }
  }

  toggle(): void {
    const p: media.AVPlayer | null = this.player;
    if (p === null) {
      return;
    }
    if (p.state === 'playing') {
      p.pause();
    } else {
      this.play();
    }
  }

  playNext(auto: boolean): void {
    if (this.list.length === 0) {
      return;
    }
    if (auto && this.mode === MODE_REPEAT_ONE) {
      this.loadIndex(this.index);
      return;
    }
    let next: number = 0;
    if (this.mode === MODE_SHUFFLE) {
      next = Math.floor(Math.random() * this.list.length);
    } else {
      next = (this.index + 1) % this.list.length;
    }
    this.loadIndex(next);
  }

  playPrevious(): void {
    if (this.list.length === 0) {
      return;
    }
    let prev: number = 0;
    if (this.mode === MODE_SHUFFLE) {
      prev = Math.floor(Math.random() * this.list.length);
    } else {
      prev = (this.index - 1 + this.list.length) % this.list.length;
    }
    this.loadIndex(prev);
  }

  seek(time: number): void {
    const p: media.AVPlayer | null = this.player;
    if (p === null || this.duration <= 0) {
      return;
    }
    const target: number = Math.max(0, Math.min(time, this.duration));
    try {
      p.seek(target, media.SeekMode.SEEK_PREV_SYNC);
    } catch (e) {
      Log.warn('seek failed: ' + (e as Error).message);
    }
  }

  cycleMode(): number {
    if (this.mode === MODE_ORDER) {
      this.mode = MODE_REPEAT_ONE;
    } else if (this.mode === MODE_REPEAT_ONE) {
      this.mode = MODE_SHUFFLE;
    } else {
      this.mode = MODE_ORDER;
    }
    AppStorage.setOrCreate(PlayerStore.MODE, this.mode);
    return this.mode;
  }

  async destroy(): Promise<void> {
    const p: media.AVPlayer | null = this.player;
    if (p === null) {
      return;
    }
    this.player = null;
    try {
      await p.release();
    } catch (e) {
      Log.warn('avplayer release failed: ' + (e as Error).message);
    }
  }
}

export const playerController: PlayerController = new PlayerController();
