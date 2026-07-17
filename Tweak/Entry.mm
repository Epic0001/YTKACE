#import "YTKACE.h"
#import "Features/Downloads/DownloadLog.h"
#import "Runtime/Preferences.h"

#import <UIKit/UIKit.h>

#ifndef YTKACE_COMBINED_SABR
#define YTKACE_COMBINED_SABR 0
#endif

NSString * const YTKACEVersion = @"0.6.3";

static void YTKACEInstallModules(void) {
    YTKACEInstallSideloadCompatibilityHooks();
    YTKACEInstallCastCompatibilityHooks();
    YTKACEInstallAdsHooks();
    YTKACEInstallSponsorBlockHooks();
    YTKACEInstallOLEDHooks();
    YTKACEInstallPremiumLogoHooks();
    YTKACEInstallBackgroundPlaybackHooks();
    YTKACEInstallSpeedHooks();
    YTKACEInstallLoopHooks();
    YTKACEInstallPiPHooks();
    YTKACEInstallDownloadHooks();
    YTKACEInstallDoubleTapHooks();
    YTKACEInstallFixPlaybackHooks();
    YTKACEInstallStreamingHooks();
    YTKACEInstallShortsHooks();
    YTKACEInstallTabBarHooks();
    YTKACEInstallNavigationBehaviorHooks();
    YTKACEInstallPlayerGestureHooks();
    YTKACEInstallOverlayVisibilityHooks();
    YTKACEInstallContentVisibilityHooks();
    YTKACEInstallNavigationVisibilityHooks();
    YTKACEInstallMiscellaneousHooks();
    YTKACEInstallCopyCommentHooks();
    YTKACEInstallSettingsEntryHooks();
}

__attribute__((constructor))
static void YTKACEEntryPoint(void) {
    @autoreleasepool {
        YTKACEClearDownloadLog();
        YTKACERegisterDefaults();
        YTKACEScheduleFirstLaunch();
        YTKACEInstallModules();
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            YTKACEInstallModules();
        });
    }
}
