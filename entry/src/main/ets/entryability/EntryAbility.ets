import UIAbility from '@ohos.app.ability.UIAbility';
import AbilityConstant from '@ohos.app.ability.AbilityConstant';
import Want from '@ohos.app.ability.Want';
import window from '@ohos.window';
import { Log } from '../common/Logger';
import { PlayerStore } from '../common/PlayerStore';
import { sessionManager } from '../service/SessionManager';
import { playerController } from '../service/PlayerController';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    Log.info('netease onCreate');
    PlayerStore.init();
    playerController.init();
    sessionManager.init(this.context, playerController);
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index').then(() => {
      Log.info('content loaded');
    }).catch((e: Error) => {
      Log.error('loadContent failed: ' + e.message);
    });
  }

  onWindowStageDestroy(): void {
    Log.info('windowStage destroy');
  }

  onDestroy(): void {
    Log.info('netease onDestroy');
    playerController.destroy();
    sessionManager.destroy();
  }
}
