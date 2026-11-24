import avSession from '@ohos.multimedia.avsession';
import backgroundTaskManager from '@ohos.resourceschedule.backgroundTaskManager';
import wantAgent from '@ohos.app.ability.wantAgent';
import common from '@ohos.app.ability.common';
import Want from '@ohos.app.ability.Want';
import { Log } from '../common/Logger';
import { Song } from '../model/Types';

// 由 PlayerController 实现。SessionManager 只依赖这个接口，不反向 import 控制器，
// 避免两个模块互相 import 造成的初始化顺序问题。
export interface PlayerCommands {
  play(): void;
  pause(): void;
  playNext(auto: boolean): void;
  playPrevious(): void;
  seek(time: number): void;
}

export class SessionManager {
  private session: avSession.AVSession | null = null;
  private context: common.UIAbilityContext | null = null;
  private cmds: PlayerCommands | null = null;
  private bgRunning: boolean = false;

  async init(context: common.UIAbilityContext, cmds: PlayerCommands): Promise<void> {
    this.context = context;
    this.cmds = cmds;
    try {
      this.session = await avSession.createAVSession(context, 'neteasePlayer', 'audio');
      await this.session.activate();
      this.registerCommands();
      Log.info('avsession ready');
    } catch (e) {
      Log.warn('avsession init failed: ' + (e as Error).message);
    }
  }

  private registerCommands(): void {
    const s: avSession.AVSession | null = this.session;
    if (s === null) {
      return;
    }
    try {
      s.on('play', () => {
        const c: PlayerCommands | null = this.cmds;
        if (c !== null) {
          c.play();
        }
      });
      s.on('pause', () => {
        const c: PlayerCommands | null = this.cmds;
        if (c !== null) {
          c.pause();
        }
      });
      s.on('playNext', () => {
        const c: PlayerCommands | null = this.cmds;
        if (c !== null) {
          c.playNext(false);
        }
      });
      s.on('playPrevious', () => {
        const c: PlayerCommands | null = this.cmds;
        if (c !== null) {
          c.playPrevious();
        }
      });
      s.on('seek', (time: number) => {
        const c: PlayerCommands | null = this.cmds;
        if (c !== null && time > 0) {
          c.seek(time);
        }
      });
    } catch (e) {
      Log.warn('avsession register commands failed: ' + (e as Error).message);
    }
  }

  async setMeta(song: Song, duration: number): Promise<void> {
    const s: avSession.AVSession | null = this.session;
    if (s === null) {
      return;
    }
    const meta: avSession.AVMetadata = {
      assetId: '' + song.id,
      title: song.name,
      artist: song.author,
      mediaImage: song.cover,
      duration: duration
    };
    try {
      await s.setAVMetadata(meta);
    } catch (e) {
      Log.warn('setAVMetadata failed: ' + (e as Error).message);
    }
  }

  async syncState(playing: boolean, time: number, duration: number): Promise<void> {
    const s: avSession.AVSession | null = this.session;
    if (s === null) {
      return;
    }
    const pos: avSession.PlaybackPosition = {
      elapsedTime: time,
      updateTime: Date.now()
    };
    const state: avSession.AVPlaybackState = {
      state: playing ? avSession.PlaybackState.PLAYBACK_STATE_PLAY : avSession.PlaybackState.PLAYBACK_STATE_PAUSE,
      speed: 1,
      position: pos,
      duration: duration
    };
    try {
      await s.setAVPlaybackState(state);
    } catch (e) {
      Log.warn('setAVPlaybackState failed: ' + (e as Error).message);
    }
  }

  async startBackgroundTask(): Promise<void> {
    const ctx: common.UIAbilityContext | null = this.context;
    if (ctx === null || this.bgRunning) {
      return;
    }
    const want: Want = {
      bundleName: ctx.abilityInfo.bundleName,
      abilityName: ctx.abilityInfo.name
    };
    const info: wantAgent.WantAgentInfo = {
      wants: [want],
      actionType: wantAgent.OperationType.START_ABILITY,
      requestCode: 100,
      actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
    };
    try {
      const agent = await wantAgent.getWantAgent(info);
      await backgroundTaskManager.startBackgroundRunning(ctx,
        backgroundTaskManager.BackgroundMode.AUDIO_PLAYBACK, agent);
      this.bgRunning = true;
      Log.info('background task started');
    } catch (e) {
      Log.warn('startBackgroundRunning failed: ' + (e as Error).message);
    }
  }

  async stopBackgroundTask(): Promise<void> {
    const ctx: common.UIAbilityContext | null = this.context;
    if (ctx === null || !this.bgRunning) {
      return;
    }
    try {
      await backgroundTaskManager.stopBackgroundRunning(ctx);
      this.bgRunning = false;
    } catch (e) {
      Log.warn('stopBackgroundRunning failed: ' + (e as Error).message);
    }
  }

  async destroy(): Promise<void> {
    await this.stopBackgroundTask();
    const s: avSession.AVSession | null = this.session;
    if (s !== null) {
      try {
        await s.destroy();
      } catch (e) {
        Log.warn('avsession destroy failed: ' + (e as Error).message);
      }
    }
    this.session = null;
  }
}

export const sessionManager: SessionManager = new SessionManager();
