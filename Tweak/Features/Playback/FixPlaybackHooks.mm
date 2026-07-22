#import "../../YTKACE.h"
#import "../../Runtime/Hooking.h"
#import "../../Runtime/Preferences.h"

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>

static NSString * const YTKACEFixPlaybackKey = @"kEnablefixvideoplayback";
static NSString * const kNeedsRefetch = @"YTKPlusNeedsRefetch";
static NSString * const kScrubBegan  = @"YTKPlusScrubBegan";

static BOOL FixOn(void) {
    return YTKACEFeatureEnabled(YTKACEFixPlaybackKey);
}

static IMP OrigIosguardEnable, OrigHasIosguardEnable;
static IMP OrigHeartbeatNonFatal, OrigHasHeartbeatNonFatal;
static IMP OrigReqIosguardAfter, OrigHasReqIosguardAfter;
static IMP OrigRequiresAtt, OrigHasRequiresAtt;
static IMP OrigStopHeartbeat, OrigHasStopHeartbeat;
static IMP OrigAuthMismatch, OrigHasAuthMismatch;
static IMP OrigHasPlayabilityStatus, OrigPlayabilityStatus;
static IMP OrigHaltIfNeeded, OrigTransitionIfNeeded, OrigHandleHBResp;
static IMP OrigHaltPlaybackWithError;
static IMP OrigSkipOnPlayabilityError, OrigHasSkipOnPlayabilityError;

static IMP OrigCannotPlay, OrigCannotPlayErr, OrigCannotPlayStatus;

static IMP OrigShowErrLong, OrigShowErrMsg, OrigUpdateErrState;

static IMP OrigWatchReset, OrigWatchResetStart;
static IMP OrigOverlayReset, OrigOverlayShowLoading;
static IMP OrigStallReset, OrigStallStartBuf, OrigStallInit;
static IMP OrigInlineReset;
static IMP OrigMainOverlayReset;

static IMP OrigMLEvInit1, OrigMLEvInit2, OrigMLEvInit3;
static IMP OrigMLPlayerItemSetState;
static IMP OrigHAMPlayerSetState;
static IMP OrigAVPlayerSetState, OrigAVPlayerFail, OrigAVPlayerSyncFail, OrigAVPlayerErrOccur;
static IMP OrigAVAssetPlayerSetState;
static IMP OrigHAMQPSetState, OrigHAMQPFail, OrigHAMQPPlayerItemFail, OrigHAMQPTrackFail;
static IMP OrigPostponeFmt;

static IMP OrigSVStateChanged, OrigSVFail;
static IMP OrigLPCRawMedia, OrigLPCLoadTrans, OrigLPCInitPlayback;

static IMP OrigIsWebMEnabled;
static IMP OrigABRInit, OrigABRPostpone, OrigABRStallLikely;

static IMP OrigSkipVideoErr, OrigSkipVideo, OrigHandlePlaybackErr;

static IMP OrigIsPlayable, OrigIsPlayableNowOrAfter, OrigStatus, OrigStatusString;
static IMP OrigErrorCode, OrigHasErrorCode, OrigHasErrorScreen, OrigErrorScreen;

static IMP OrigIsExpiredByMaxAge, OrigStreamsCloseExpiring;
static IMP OrigTimeUntilExpiry, OrigIsReuse;
static IMP OrigMLTimeToExpiry, OrigYTIExpiresIn;

static IMP OrigCacheKeyRelax, OrigStreamingWatchEnabled, OrigPlayerRespCacheToken;

static __weak id gCurrentController = nil;
static BOOL gIsRefetching = NO;
static NSTimeInterval gLastRefetchAt = 0.0;
static NSTimer *gProactiveTimer = nil;
static NSMutableDictionary<NSValue *, NSTimer *> *gTimersByController = nil;

static BOOL CallBool(IMP fn, id r, SEL s) {
    return fn && ((BOOL (*)(id, SEL))fn)(r, s);
}
static id CallObj(IMP fn, id r, SEL s) {
    return fn ? ((id (*)(id, SEL))fn)(r, s) : nil;
}
static long CallLong(IMP fn, id r, SEL s) {
    return fn ? ((long (*)(id, SEL))fn)(r, s) : 0;
}
static double CallDouble(IMP fn, id r, SEL s) {
    return fn ? ((double (*)(id, SEL))fn)(r, s) : 0.0;
}

static void InstallBool(NSString *cls, NSString *sel, IMP repl, IMP *orig) {
    if (!YTKACEInstallInstanceHook(cls, sel, repl, orig)) {
        YTKACEAddInstanceMethod(cls, sel, repl, "B@:");
    }
}
static void InstallObj(NSString *cls, NSString *sel, IMP repl, IMP *orig) {
    if (!YTKACEInstallInstanceHook(cls, sel, repl, orig)) {
        YTKACEAddInstanceMethod(cls, sel, repl, "@@:");
    }
}
static void InstallLong(NSString *cls, NSString *sel, IMP repl, IMP *orig) {
    if (!YTKACEInstallInstanceHook(cls, sel, repl, orig)) {
        YTKACEAddInstanceMethod(cls, sel, repl, "q@:");
    }
}
static void InstallDouble(NSString *cls, NSString *sel, IMP repl, IMP *orig) {
    if (!YTKACEInstallInstanceHook(cls, sel, repl, orig)) {
        YTKACEAddInstanceMethod(cls, sel, repl, "d@:");
    }
}

static BOOL H_IosguardEnable(id r, SEL s)    { return FixOn() ? NO  : CallBool(OrigIosguardEnable, r, s); }
static BOOL H_HasIosguardEnable(id r, SEL s) { return FixOn() ? NO  : CallBool(OrigHasIosguardEnable, r, s); }
static BOOL H_HeartbeatNonFatal(id r, SEL s) { return FixOn() ? YES : CallBool(OrigHeartbeatNonFatal, r, s); }
static BOOL H_HasHeartbeatNonFatal(id r, SEL s) { return FixOn() ? YES : CallBool(OrigHasHeartbeatNonFatal, r, s); }
static BOOL H_ReqIosguardAfter(id r, SEL s)  { return FixOn() ? NO  : CallBool(OrigReqIosguardAfter, r, s); }
static BOOL H_HasReqIosguardAfter(id r, SEL s) { return FixOn() ? NO : CallBool(OrigHasReqIosguardAfter, r, s); }
static BOOL H_RequiresAtt(id r, SEL s)       { return FixOn() ? NO  : CallBool(OrigRequiresAtt, r, s); }
static BOOL H_HasRequiresAtt(id r, SEL s)    { return FixOn() ? NO  : CallBool(OrigHasRequiresAtt, r, s); }
static BOOL H_StopHeartbeat(id r, SEL s)     { return FixOn() ? NO  : CallBool(OrigStopHeartbeat, r, s); }
static BOOL H_HasStopHeartbeat(id r, SEL s)  { return FixOn() ? NO  : CallBool(OrigHasStopHeartbeat, r, s); }
static BOOL H_AuthMismatch(id r, SEL s)      { return FixOn() ? NO  : CallBool(OrigAuthMismatch, r, s); }
static BOOL H_HasAuthMismatch(id r, SEL s)   { return FixOn() ? NO  : CallBool(OrigHasAuthMismatch, r, s); }
static BOOL H_HasPlayabilityStatus(id r, SEL s) { return FixOn() ? NO : CallBool(OrigHasPlayabilityStatus, r, s); }
static id   H_PlayabilityStatus(id r, SEL s) { return FixOn() ? nil : CallObj(OrigPlayabilityStatus, r, s); }

static void H_HaltIfNeeded(id r, SEL s) {
    if (FixOn()) return;
    if (OrigHaltIfNeeded) ((void (*)(id, SEL))OrigHaltIfNeeded)(r, s);
}
static void H_TransitionIfNeeded(id r, SEL s) {
    if (FixOn()) return;
    if (OrigTransitionIfNeeded) ((void (*)(id, SEL))OrigTransitionIfNeeded)(r, s);
}
static void H_HandleHBResp(id r, SEL s, id resp, id req) {
    if (FixOn()) return;
    if (OrigHandleHBResp) ((void (*)(id, SEL, id, id))OrigHandleHBResp)(r, s, resp, req);
}
static void H_HaltPlaybackWithError(id r, SEL s, id err, id ctl) {
    if (FixOn()) return;
    if (OrigHaltPlaybackWithError) ((void (*)(id, SEL, id, id))OrigHaltPlaybackWithError)(r, s, err, ctl);
}

static BOOL H_SkipOnPlayabilityError(id r, SEL s) { return FixOn() ? YES : CallBool(OrigSkipOnPlayabilityError, r, s); }
static BOOL H_HasSkipOnPlayabilityError(id r, SEL s) { return FixOn() ? YES : CallBool(OrigHasSkipOnPlayabilityError, r, s); }

static void H_CannotPlay(id r, SEL s) {
    if (FixOn()) return;
    if (OrigCannotPlay) ((void (*)(id, SEL))OrigCannotPlay)(r, s);
}
static void H_CannotPlayErr(id r, SEL s, id err) {
    if (FixOn()) return;
    if (OrigCannotPlayErr) ((void (*)(id, SEL, id))OrigCannotPlayErr)(r, s, err);
}
static void H_CannotPlayStatus(id r, SEL s, id st) {
    if (FixOn()) return;
    if (OrigCannotPlayStatus) ((void (*)(id, SEL, id))OrigCannotPlayStatus)(r, s, st);
}

static void H_ShowErrLong(id r, SEL s, id reason, id sub, id learn, BOOL a, BOOL b, BOOL c) {
    if (FixOn()) return;
    if (OrigShowErrLong) ((void (*)(id, SEL, id, id, id, BOOL, BOOL, BOOL))OrigShowErrLong)(r, s, reason, sub, learn, a, b, c);
}
static void H_ShowErrMsg(id r, SEL s, id msg, BOOL a, BOOL b, BOOL c) {
    if (FixOn()) return;
    if (OrigShowErrMsg) ((void (*)(id, SEL, id, BOOL, BOOL, BOOL))OrigShowErrMsg)(r, s, msg, a, b, c);
}
static void H_UpdateErrState(id r, SEL s, BOOL a, BOOL b, BOOL c) {
    if (FixOn()) return;
    if (OrigUpdateErrState) ((void (*)(id, SEL, BOOL, BOOL, BOOL))OrigUpdateErrState)(r, s, a, b, c);
}

static void H_WatchReset(id r, SEL s, id vc, long st) {
    if (FixOn() && st == 7) return;
    if (OrigWatchReset) ((void (*)(id, SEL, id, long))OrigWatchReset)(r, s, vc, st);
}
static void H_WatchResetStart(id r, SEL s, id a, id b, id c, id d, BOOL e) {
    if (FixOn()) return;
    if (OrigWatchResetStart) ((void (*)(id, SEL, id, id, id, id, BOOL))OrigWatchResetStart)(r, s, a, b, c, d, e);
}
static void H_OverlayReset(id r, SEL s, id vc, long st) {
    if (FixOn() && st == 7) return;
    if (OrigOverlayReset) ((void (*)(id, SEL, id, long))OrigOverlayReset)(r, s, vc, st);
}
static void H_OverlayShowLoading(id r, SEL s, BOOL flag) {
    if (FixOn() && gIsRefetching) return;
    if (OrigOverlayShowLoading) ((void (*)(id, SEL, BOOL))OrigOverlayShowLoading)(r, s, flag);
}
static void H_StallReset(id r, SEL s, id vc, long st) {
    if (FixOn() && st == 7) return;
    if (OrigStallReset) ((void (*)(id, SEL, id, long))OrigStallReset)(r, s, vc, st);
}
static void H_StallStartBuf(id r, SEL s, double thresh, long reason) {
    if (FixOn()) return;
    if (OrigStallStartBuf) ((void (*)(id, SEL, double, long))OrigStallStartBuf)(r, s, thresh, reason);
}
static id H_StallInit(id r, SEL s, id player, double join, double buf) {
    if (FixOn()) { join = 15.0; buf = 15.0; }
    if (OrigStallInit) return ((id (*)(id, SEL, id, double, double))OrigStallInit)(r, s, player, join, buf);
    return r;
}
static void H_InlineReset(id r, SEL s, id vc, long st) {
    if (OrigInlineReset) ((void (*)(id, SEL, id, long))OrigInlineReset)(r, s, vc, st);
}
static void H_MainOverlayReset(id r, SEL s, id vc, long st) {
    if (FixOn() && st == 7) return;
    if (OrigMainOverlayReset) ((void (*)(id, SEL, id, long))OrigMainOverlayReset)(r, s, vc, st);
}

static id H_MLEvInit1(id r, SEL s, long st, long prev, double t) {
    if (FixOn() && st == 8) st = 3;
    if (OrigMLEvInit1) return ((id (*)(id, SEL, long, long, double))OrigMLEvInit1)(r, s, st, prev, t);
    return r;
}
static id H_MLEvInit2(id r, SEL s, long st, long prev, double t, id ann, long stop) {
    if (FixOn() && st == 8) st = 3;
    if (OrigMLEvInit2) return ((id (*)(id, SEL, long, long, double, id, long))OrigMLEvInit2)(r, s, st, prev, t, ann, stop);
    return r;
}
static id H_MLEvInit3(id r, SEL s, long st, long prev, double t, id ann, long stop, BOOL seek) {
    if (FixOn() && st == 8) st = 3;
    if (OrigMLEvInit3) return ((id (*)(id, SEL, long, long, double, id, long, BOOL))OrigMLEvInit3)(r, s, st, prev, t, ann, stop, seek);
    return r;
}

static void H_MLPlayerItemSetState(id r, SEL s, long st) {
    if (FixOn() && st == 8) return;
    if (OrigMLPlayerItemSetState) ((void (*)(id, SEL, long))OrigMLPlayerItemSetState)(r, s, st);
}
static void H_HAMPlayerSetState(id r, SEL s, long st) {
    if (FixOn() && st == 8) return;
    if (OrigHAMPlayerSetState) ((void (*)(id, SEL, long))OrigHAMPlayerSetState)(r, s, st);
}
static void H_AVPlayerSetState(id r, SEL s, long st) {
    if (FixOn() && st == 8) return;
    if (OrigAVPlayerSetState) ((void (*)(id, SEL, long))OrigAVPlayerSetState)(r, s, st);
}
static void H_AVPlayerFail(id r, SEL s, id err) {
    if (FixOn()) return;
    if (OrigAVPlayerFail) ((void (*)(id, SEL, id))OrigAVPlayerFail)(r, s, err);
}
static void H_AVPlayerSyncFail(id r, SEL s, id err, id fid, BOOL retry) {
    if (FixOn()) return;
    if (OrigAVPlayerSyncFail) ((void (*)(id, SEL, id, id, BOOL))OrigAVPlayerSyncFail)(r, s, err, fid, retry);
}
static void H_AVPlayerErrOccur(id r, SEL s, id err) {
    if (FixOn()) return;
    if (OrigAVPlayerErrOccur) ((void (*)(id, SEL, id))OrigAVPlayerErrOccur)(r, s, err);
}
static void H_AVAssetPlayerSetState(id r, SEL s, long st) {
    if (FixOn() && st == 8) return;
    if (OrigAVAssetPlayerSetState) ((void (*)(id, SEL, long))OrigAVAssetPlayerSetState)(r, s, st);
}
static void H_HAMQPSetState(id r, SEL s, long st) {
    if (FixOn() && st == 8) return;
    if (OrigHAMQPSetState) ((void (*)(id, SEL, long))OrigHAMQPSetState)(r, s, st);
}
static void H_HAMQPFail(id r, SEL s, id err) {
    if (FixOn()) return;
    if (OrigHAMQPFail) ((void (*)(id, SEL, id))OrigHAMQPFail)(r, s, err);
}

static void H_HAMQPPlayerItemFail(id r, SEL s, id item, NSError *err) {
    if (FixOn()) {
        NSInteger code = 0;
        @try { code = err.code; } @catch (__unused id e) {}
        if (code == 0x77 || code == 0x193) {
            if (!gIsRefetching) {
                gLastRefetchAt = 0.0;
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:kNeedsRefetch object:nil];
                });
            }
            return;
        }
    }
    if (OrigHAMQPPlayerItemFail) ((void (*)(id, SEL, id, id))OrigHAMQPPlayerItemFail)(r, s, item, err);
}

static void H_HAMQPTrackFail(id r, SEL s, id track, id err) {
    if (FixOn()) return;
    if (OrigHAMQPTrackFail) ((void (*)(id, SEL, id, id))OrigHAMQPTrackFail)(r, s, track, err);
}

static BOOL H_PostponeFmt(id r, SEL s) { return FixOn() ? NO : CallBool(OrigPostponeFmt, r, s); }

static void H_SVStateChanged(id r, SEL s, long from, long to, BOOL init, id seek, long stop) {
    if (FixOn() && stop == 8) return;
    if (OrigSVStateChanged) ((void (*)(id, SEL, long, long, BOOL, id, long))OrigSVStateChanged)(r, s, from, to, init, seek, stop);
}
static void H_SVFail(id r, SEL s, id err) {
    if (FixOn()) return;
    if (OrigSVFail) ((void (*)(id, SEL, id))OrigSVFail)(r, s, err);
}

static void H_LPCRawMedia(id self, SEL sel, id sv, long from, long to, id mp) {
    if (OrigLPCRawMedia) ((void (*)(id, SEL, id, long, long, id))OrigLPCRawMedia)(self, sel, sv, from, to, mp);
    if (FixOn() && to == 6) {
        __weak id weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(8.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            id strong = weakSelf;
            if (!strong) return;
            id seq = [strong valueForKey:@"videoSequencer"];
            id active = [seq valueForKey:@"activeVideoController"];
            if (!active) active = [seq valueForKey:@"contentVideoController"];
            if (!active) return;
            long rms = 0;
            SEL rmsSel = NSSelectorFromString(@"rawMediaState");
            if ([active respondsToSelector:rmsSel]) {
                rms = ((long (*)(id, SEL))objc_msgSend)(active, rmsSel);
            }
            if (rms == 6) {
                gLastRefetchAt = 0.0;
                gIsRefetching = NO;
                [[NSNotificationCenter defaultCenter] postNotificationName:kNeedsRefetch object:nil];
            }
        });
    }
}

static void H_YTKPRegisterNotifications(id self, SEL _cmd);
static void H_YTKPStartProactiveTimer(id self, SEL _cmd);

static void H_LPCLoadTrans(id self, SEL sel, id trans, id cfg, double t) {
    gLastRefetchAt = 0.0;
    gIsRefetching = NO;
    [gProactiveTimer invalidate];
    gProactiveTimer = nil;
    gCurrentController = self;
    if (OrigLPCLoadTrans) ((void (*)(id, SEL, id, id, double))OrigLPCLoadTrans)(self, sel, trans, cfg, t);
    H_YTKPRegisterNotifications(self, NULL);
    H_YTKPStartProactiveTimer(self, NULL);
}

static void H_LPCInitPlayback(id self, SEL sel) {
    if (OrigLPCInitPlayback) ((void (*)(id, SEL))OrigLPCInitPlayback)(self, sel);
    gCurrentController = self;
    H_YTKPRegisterNotifications(self, NULL);
    H_YTKPStartProactiveTimer(self, NULL);
}

static void H_YTKPRegisterNotifications(id self, SEL _cmd) {
    (void)_cmd;
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc removeObserver:self name:kNeedsRefetch object:nil];
    [nc removeObserver:self name:kScrubBegan  object:nil];
    [nc addObserver:self selector:NSSelectorFromString(@"ytkplus_handleRefetch:")
               name:kNeedsRefetch object:nil];
    [nc addObserver:self selector:NSSelectorFromString(@"ytkplus_handleScrubBegan:")
               name:kScrubBegan  object:nil];
}

static void H_YTKPStartProactiveTimer(id self, SEL _cmd) {
    (void)_cmd;
    [gProactiveTimer invalidate];
    gProactiveTimer = nil;
    __weak id weakSelf = self;
    gProactiveTimer = [NSTimer scheduledTimerWithTimeInterval:45.0
                                                      repeats:YES
                                                        block:^(NSTimer * _Nonnull timer) {
        id strong = weakSelf;
        if (!strong || strong != gCurrentController) {
            [timer invalidate];
            return;
        }
        gLastRefetchAt = 0.0;
        [[NSNotificationCenter defaultCenter] postNotificationName:kNeedsRefetch object:nil];
    }];
}

static void H_YTKPHandleRefetch(id self, SEL _cmd, NSNotification *note) {
    (void)_cmd; (void)note;
    if (self != gCurrentController) return;
    if (gIsRefetching) return;
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    if (now - gLastRefetchAt < 20.0) return;

    id seq = [self valueForKey:@"videoSequencer"];
    id active = [seq valueForKey:@"activeVideoController"];
    if (!active) active = [seq valueForKey:@"contentVideoController"];
    if (!active) return;

    gIsRefetching = YES;
    gLastRefetchAt = now;

    __weak id weakSelf = self;
    __weak id weakActive = active;

    dispatch_async(dispatch_get_main_queue(), ^{
        id strong = weakSelf;
        id activeStrong = weakActive;
        if (!strong || !activeStrong) { gIsRefetching = NO; return; }

        UIView *snapshot = nil;
        SEL prvSel = NSSelectorFromString(@"playerRenderingView");
        if ([activeStrong respondsToSelector:prvSel]) {
            UIView *v = ((id (*)(id, SEL))objc_msgSend)(activeStrong, prvSel);
            if (v && v.superview) {
                snapshot = [v snapshotViewAfterScreenUpdates:NO];
                if (snapshot) {
                    snapshot.frame = v.frame;
                    [v.superview addSubview:snapshot];
                    [v.superview bringSubviewToFront:snapshot];
                }
            }
        }

        Class RCtx = NSClassFromString(@"MLPlayerReloadContext");
        id ctx = nil;
        if (RCtx) {
            ctx = [RCtx alloc];
            SEL initSel = NSSelectorFromString(@"initWithStartPlayback:refreshStreamingData:");
            if ([ctx respondsToSelector:initSel]) {
                ctx = ((id (*)(id, SEL, BOOL, BOOL))objc_msgSend)(ctx, initSel, YES, YES);
            }
        }

        SEL reqReloadSel = NSSelectorFromString(@"singleVideoController:requiresReloadWithContext:");
        SEL reloadPlayerSel = NSSelectorFromString(@"reloadPlayerWithContext:");
        SEL fetchSel = NSSelectorFromString(@"fetchPlayerDataAndResolveVideo");
        if ([strong respondsToSelector:reqReloadSel]) {
            ((void (*)(id, SEL, id, id))objc_msgSend)(strong, reqReloadSel, activeStrong, ctx);
        } else if ([activeStrong respondsToSelector:reloadPlayerSel]) {
            ((void (*)(id, SEL, id))objc_msgSend)(activeStrong, reloadPlayerSel, ctx);
        } else if ([strong respondsToSelector:fetchSel]) {
            ((void (*)(id, SEL))objc_msgSend)(strong, fetchSel);
        }

        if (snapshot) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                [UIView animateWithDuration:0.2 animations:^{
                    snapshot.alpha = 0.0;
                } completion:^(BOOL finished) {
                    (void)finished;
                    [snapshot removeFromSuperview];
                }];
            });
        }

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            gIsRefetching = NO;
            id s = weakSelf;
            if (s) {
                SEL playSel = NSSelectorFromString(@"play");
                if ([s respondsToSelector:playSel]) {
                    ((void (*)(id, SEL))objc_msgSend)(s, playSel);
                }
            }
        });
    });
}

static void H_YTKPHandleScrubBegan(id self, SEL _cmd, NSNotification *note) {
    (void)_cmd; (void)note;
    if (self != gCurrentController) return;
    SEL pauseSel = NSSelectorFromString(@"pauseWithStoppageReason:");
    if ([self respondsToSelector:pauseSel]) {
        ((void (*)(id, SEL, long))objc_msgSend)(self, pauseSel, 0);
    }
}

static BOOL H_IsWebMEnabled(id r, SEL s) { return FixOn() ? NO : CallBool(OrigIsWebMEnabled, r, s); }

static id H_ABRInit(id r, SEL s,
                    id ctx, id cfg, id cache, id ns, id ra, id rp,
                    id pd, id dd, BOOL postpone, id itag) {
    if (FixOn()) postpone = NO;
    if (OrigABRInit) {
        return ((id (*)(id, SEL, id, id, id, id, id, id, id, id, BOOL, id))OrigABRInit)(
            r, s, ctx, cfg, cache, ns, ra, rp, pd, dd, postpone, itag);
    }
    return r;
}
static BOOL H_ABRPostpone(id r, SEL s) { return FixOn() ? NO : CallBool(OrigABRPostpone, r, s); }
static BOOL H_ABRStallLikely(id r, SEL s) {
    if (OrigABRStallLikely) ((void (*)(id, SEL))OrigABRStallLikely)(r, s);
    return FixOn() ? NO : NO;
}

static void H_SkipVideoErr(id r, SEL s, id err) {
    if (FixOn()) return;
    if (OrigSkipVideoErr) ((void (*)(id, SEL, id))OrigSkipVideoErr)(r, s, err);
}
static void H_SkipVideo(id r, SEL s) {
    if (FixOn()) return;
    if (OrigSkipVideo) ((void (*)(id, SEL))OrigSkipVideo)(r, s);
}
static void H_HandlePlaybackErr(id r, SEL s, id err) {
    if (FixOn()) return;
    if (OrigHandlePlaybackErr) ((void (*)(id, SEL, id))OrigHandlePlaybackErr)(r, s, err);
}

static BOOL H_IsPlayable(id r, SEL s)              { return FixOn() ? YES : CallBool(OrigIsPlayable, r, s); }
static BOOL H_IsPlayableNowOrAfter(id r, SEL s)    { return FixOn() ? YES : CallBool(OrigIsPlayableNowOrAfter, r, s); }
static long H_Status(id r, SEL s)                  { return FixOn() ? 1   : CallLong(OrigStatus, r, s); }
static id   H_StatusString(id r, SEL s)            { return FixOn() ? @"OK" : CallObj(OrigStatusString, r, s); }
static long H_ErrorCode(id r, SEL s)               { return FixOn() ? 0   : CallLong(OrigErrorCode, r, s); }
static BOOL H_HasErrorCode(id r, SEL s)            { return FixOn() ? NO  : CallBool(OrigHasErrorCode, r, s); }
static BOOL H_HasErrorScreen(id r, SEL s)          { return FixOn() ? NO  : CallBool(OrigHasErrorScreen, r, s); }
static id   H_ErrorScreen(id r, SEL s)             { return FixOn() ? nil : CallObj(OrigErrorScreen, r, s); }

static BOOL H_IsExpiredByMaxAge(id r, SEL s)       { return FixOn() ? YES : CallBool(OrigIsExpiredByMaxAge, r, s); }
static BOOL H_StreamsCloseExpiring(id r, SEL s)    { return FixOn() ? YES : CallBool(OrigStreamsCloseExpiring, r, s); }
static long H_TimeUntilExpiry(id r, SEL s)         { return FixOn() ? 0   : CallLong(OrigTimeUntilExpiry, r, s); }
static BOOL H_IsReuse(id r, SEL s)                 { return FixOn() ? NO  : CallBool(OrigIsReuse, r, s); }

static double H_MLTimeToExpiry(id r, SEL s) {
    double v = CallDouble(OrigMLTimeToExpiry, r, s);
    if (FixOn() && v < 3600.0) v = 3600.0;
    return v;
}
static long H_YTIExpiresIn(id r, SEL s) {
    long v = CallLong(OrigYTIExpiresIn, r, s);
    if (FixOn() && v < 0xe10) v = 0xe10;
    return v;
}

static BOOL H_CacheKeyRelax(id r, SEL s)           { return FixOn() ? YES : CallBool(OrigCacheKeyRelax, r, s); }
static BOOL H_StreamingWatchEnabled(id r, SEL s)   { return FixOn() ? YES : CallBool(OrigStreamingWatchEnabled, r, s); }
static id   H_PlayerRespCacheToken(id r, SEL s)    { return FixOn() ? nil : CallObj(OrigPlayerRespCacheToken, r, s); }

void YTKACEInstallFixPlaybackHooks(void) {

    InstallBool(@"YTIIosPlayerAttestationConfig", @"iosguardEnable",     (IMP)H_IosguardEnable,    &OrigIosguardEnable);
    InstallBool(@"YTIIosPlayerAttestationConfig", @"hasIosguardEnable",  (IMP)H_HasIosguardEnable, &OrigHasIosguardEnable);

    InstallBool(@"YTIIosPlayerConfig", @"heartbeatPolicyErrorIsNonFatal",         (IMP)H_HeartbeatNonFatal,    &OrigHeartbeatNonFatal);
    InstallBool(@"YTIIosPlayerConfig", @"hasHeartbeatPolicyErrorIsNonFatal",      (IMP)H_HasHeartbeatNonFatal, &OrigHasHeartbeatNonFatal);
    InstallBool(@"YTIIosPlayerConfig", @"requestIosguardDataAfterPlaybackStarts", (IMP)H_ReqIosguardAfter,     &OrigReqIosguardAfter);
    InstallBool(@"YTIIosPlayerConfig", @"hasRequestIosguardDataAfterPlaybackStarts",(IMP)H_HasReqIosguardAfter,&OrigHasReqIosguardAfter);

    InstallBool(@"YTIHeartbeatAttestationConfig", @"requiresAttestation",    (IMP)H_RequiresAtt,    &OrigRequiresAtt);
    InstallBool(@"YTIHeartbeatAttestationConfig", @"hasRequiresAttestation", (IMP)H_HasRequiresAtt, &OrigHasRequiresAtt);

    InstallBool(@"YTIHeartbeatResponse", @"stopHeartbeat",          (IMP)H_StopHeartbeat,    &OrigStopHeartbeat);
    InstallBool(@"YTIHeartbeatResponse", @"hasStopHeartbeat",       (IMP)H_HasStopHeartbeat, &OrigHasStopHeartbeat);
    InstallBool(@"YTIHeartbeatResponse", @"authenticationMismatch", (IMP)H_AuthMismatch,     &OrigAuthMismatch);
    InstallBool(@"YTIHeartbeatResponse", @"hasAuthenticationMismatch",(IMP)H_HasAuthMismatch,&OrigHasAuthMismatch);
    InstallBool(@"YTIHeartbeatResponse", @"hasPlayabilityStatus",   (IMP)H_HasPlayabilityStatus, &OrigHasPlayabilityStatus);
    InstallObj (@"YTIHeartbeatResponse", @"playabilityStatus",      (IMP)H_PlayabilityStatus,    &OrigPlayabilityStatus);

    YTKACEInstallInstanceHook(@"YTSingleVideoHeartbeatController", @"haltIfNeeded",              (IMP)H_HaltIfNeeded,       &OrigHaltIfNeeded);
    YTKACEInstallInstanceHook(@"YTSingleVideoHeartbeatController", @"transitionIfNeeded",        (IMP)H_TransitionIfNeeded, &OrigTransitionIfNeeded);
    YTKACEInstallInstanceHook(@"YTSingleVideoHeartbeatController", @"handleResponse:forRequest:",(IMP)H_HandleHBResp,       &OrigHandleHBResp);
    YTKACEInstallInstanceHook(@"YTPlaybackHeartbeatController",
                              @"haltPlaybackWithError:forHeartbeatController:",
                              (IMP)H_HaltPlaybackWithError, &OrigHaltPlaybackWithError);

    InstallBool(@"YTIPlayabilityErrorSkipConfig", @"skipOnPlayabilityError",    (IMP)H_SkipOnPlayabilityError,    &OrigSkipOnPlayabilityError);
    InstallBool(@"YTIPlayabilityErrorSkipConfig", @"hasSkipOnPlayabilityError", (IMP)H_HasSkipOnPlayabilityError, &OrigHasSkipOnPlayabilityError);

    YTKACEInstallInstanceHook(@"MDXPlaybackController", @"playerCannotPlayThisVideo",                       (IMP)H_CannotPlay,       &OrigCannotPlay);
    YTKACEInstallInstanceHook(@"MDXPlaybackController", @"playerCannotPlayThisVideoWithError:",             (IMP)H_CannotPlayErr,    &OrigCannotPlayErr);
    YTKACEInstallInstanceHook(@"MDXPlaybackController", @"playerCannotPlayThisVideoWithPlayabilityStatus:", (IMP)H_CannotPlayStatus, &OrigCannotPlayStatus);

    YTKACEInstallInstanceHook(@"YTErrorPlayerOverlayView",
        @"showErrorWithReason:subreason:learnMore:allowTapToRetry:showTapToRetryMessage:showErrorBackground:",
        (IMP)H_ShowErrLong, &OrigShowErrLong);
    YTKACEInstallInstanceHook(@"YTErrorPlayerOverlayView",
        @"showErrorWithMessage:allowTapToRetry:showTapToRetryMessage:showErrorBackground:",
        (IMP)H_ShowErrMsg, &OrigShowErrMsg);
    YTKACEInstallInstanceHook(@"YTErrorPlayerOverlayView",
        @"updateStateForNewErrorWithAllowTapToRetry:showTapToRetryMessage:showErrorBackground:",
        (IMP)H_UpdateErrState, &OrigUpdateErrState);

    YTKACEInstallInstanceHook(@"YTWatchPlaybackController", @"playerViewController:willResetToState:", (IMP)H_WatchReset, &OrigWatchReset);
    YTKACEInstallInstanceHook(@"YTWatchPlaybackController",
        @"resetPlayerViewControllerStartPlayback:latencyLogger:playerThumbnailView:slimVideoTitle:disableReportingWatchTimeAsFinal:",
        (IMP)H_WatchResetStart, &OrigWatchResetStart);
    YTKACEInstallInstanceHook(@"YTPlayerOverlayManager", @"playerViewController:willResetToState:", (IMP)H_OverlayReset, &OrigOverlayReset);
    YTKACEInstallInstanceHook(@"YTPlayerOverlayManager", @"resetContentOverlayAndShowLoading:",     (IMP)H_OverlayShowLoading, &OrigOverlayShowLoading);
    YTKACEInstallInstanceHook(@"YTPlayerStallController", @"playerViewController:willResetToState:", (IMP)H_StallReset,   &OrigStallReset);
    YTKACEInstallInstanceHook(@"YTPlayerStallController", @"startBufferingTimerWithThreshold:stallReason:", (IMP)H_StallStartBuf, &OrigStallStartBuf);
    YTKACEInstallInstanceHook(@"YTPlayerStallController", @"initWithPlayer:joinStallThreshold:bufferingStallThreshold:", (IMP)H_StallInit, &OrigStallInit);
    YTKACEInstallInstanceHook(@"YTInlinePlayerViewController", @"playerViewController:willResetToState:", (IMP)H_InlineReset, &OrigInlineReset);
    YTKACEInstallInstanceHook(@"YTMainAppVideoPlayerOverlayViewController", @"playerViewController:willResetToState:", (IMP)H_MainOverlayReset, &OrigMainOverlayReset);

    YTKACEInstallInstanceHook(@"MLPlayerStateChangeEvent", @"initWithState:previousState:absoluteTime:", (IMP)H_MLEvInit1, &OrigMLEvInit1);
    YTKACEInstallInstanceHook(@"MLPlayerStateChangeEvent",
        @"initWithState:previousState:absoluteTime:seekAnnotations:stoppageReason:", (IMP)H_MLEvInit2, &OrigMLEvInit2);
    YTKACEInstallInstanceHook(@"MLPlayerStateChangeEvent",
        @"initWithState:previousState:absoluteTime:seekAnnotations:stoppageReason:playerInitiatedSeek:", (IMP)H_MLEvInit3, &OrigMLEvInit3);

    YTKACEInstallInstanceHook(@"MLPlayerItem",       @"setState:", (IMP)H_MLPlayerItemSetState, &OrigMLPlayerItemSetState);
    YTKACEInstallInstanceHook(@"MLHAMPlayer",        @"setState:", (IMP)H_HAMPlayerSetState,    &OrigHAMPlayerSetState);
    YTKACEInstallInstanceHook(@"MLAVPlayer",         @"setState:", (IMP)H_AVPlayerSetState,     &OrigAVPlayerSetState);
    YTKACEInstallInstanceHook(@"MLAVPlayer",         @"failWithError:", (IMP)H_AVPlayerFail,    &OrigAVPlayerFail);
    YTKACEInstallInstanceHook(@"MLAVPlayer",         @"syncFailWithError:failureID:forceAttemptRetry:", (IMP)H_AVPlayerSyncFail, &OrigAVPlayerSyncFail);
    YTKACEInstallInstanceHook(@"MLAVPlayer",         @"playerViewErrorDidOccur:", (IMP)H_AVPlayerErrOccur, &OrigAVPlayerErrOccur);
    YTKACEInstallInstanceHook(@"MLAVAssetPlayer",    @"setState:", (IMP)H_AVAssetPlayerSetState,&OrigAVAssetPlayerSetState);
    YTKACEInstallInstanceHook(@"MLHAMQueuePlayer",   @"setState:", (IMP)H_HAMQPSetState,        &OrigHAMQPSetState);
    YTKACEInstallInstanceHook(@"MLHAMQueuePlayer",   @"failWithError:", (IMP)H_HAMQPFail,       &OrigHAMQPFail);
    YTKACEInstallInstanceHook(@"MLHAMQueuePlayer",   @"playerItem:didFailWithError:", (IMP)H_HAMQPPlayerItemFail, &OrigHAMQPPlayerItemFail);
    YTKACEInstallInstanceHook(@"MLHAMQueuePlayer",   @"trackRenderer:didFailWithError:", (IMP)H_HAMQPTrackFail,   &OrigHAMQPTrackFail);
    InstallBool(@"MLHAMQueuePlayer", @"_postponePreferredFormatFiltering", (IMP)H_PostponeFmt, &OrigPostponeFmt);

    YTKACEInstallInstanceHook(@"YTSingleVideoController",
        @"stateDidChangeFromState:toState:playerInitiated:lastSeekSource:stoppageReason:", (IMP)H_SVStateChanged, &OrigSVStateChanged);
    YTKACEInstallInstanceHook(@"YTSingleVideoController", @"failWithError:", (IMP)H_SVFail, &OrigSVFail);

    YTKACEInstallInstanceHook(@"YTLocalPlaybackController",
        @"singleVideo:rawMediaStateDidChangeFromState:toState:mediaPlayerInitiatedSeek:",
        (IMP)H_LPCRawMedia, &OrigLPCRawMedia);
    YTKACEInstallInstanceHook(@"YTLocalPlaybackController",
        @"loadWithPlayerTransition:playbackConfig:initialTime:",
        (IMP)H_LPCLoadTrans, &OrigLPCLoadTrans);
    YTKACEInstallInstanceHook(@"YTLocalPlaybackController", @"initializePlayback",
        (IMP)H_LPCInitPlayback, &OrigLPCInitPlayback);

    YTKACEAddInstanceMethod(@"YTLocalPlaybackController", @"ytkplus_registerNotifications", (IMP)H_YTKPRegisterNotifications, "v@:");
    YTKACEAddInstanceMethod(@"YTLocalPlaybackController", @"ytkplus_startProactiveTimer",   (IMP)H_YTKPStartProactiveTimer,   "v@:");
    YTKACEAddInstanceMethod(@"YTLocalPlaybackController", @"ytkplus_handleRefetch:",        (IMP)H_YTKPHandleRefetch,         "v@:@");
    YTKACEAddInstanceMethod(@"YTLocalPlaybackController", @"ytkplus_handleScrubBegan:",     (IMP)H_YTKPHandleScrubBegan,      "v@:@");

    InstallBool(@"YTUserDefaults", @"isWebMEnabled", (IMP)H_IsWebMEnabled, &OrigIsWebMEnabled);
    YTKACEInstallInstanceHook(@"HAMDefaultABRPolicy",
        @"initWithContext:config:cache:networkStatsProvider:readaheadPolicy:loadRetryPolicy:policyDelegate:defaultDelegate:postponePreferredFormatFiltering:itagAllowList:",
        (IMP)H_ABRInit, &OrigABRInit);
    InstallBool(@"HAMDefaultABRPolicy", @"postponePreferredFormatFiltering", (IMP)H_ABRPostpone,    &OrigABRPostpone);
    InstallBool(@"HAMDefaultABRPolicy", @"stallLikely",                      (IMP)H_ABRStallLikely, &OrigABRStallLikely);

    YTKACEInstallInstanceHook(@"YTPlaybackErrorController", @"skipVideoWithError:",   (IMP)H_SkipVideoErr,       &OrigSkipVideoErr);
    YTKACEInstallInstanceHook(@"YTPlaybackErrorController", @"skipVideo",             (IMP)H_SkipVideo,          &OrigSkipVideo);
    YTKACEInstallInstanceHook(@"YTPlaybackErrorController", @"handlePlaybackError:",  (IMP)H_HandlePlaybackErr,  &OrigHandlePlaybackErr);

    InstallBool(@"YTIPlayabilityStatus", @"isPlayable",                    (IMP)H_IsPlayable,              &OrigIsPlayable);
    InstallBool(@"YTIPlayabilityStatus", @"isPlayableNowOrAfterUserAction",(IMP)H_IsPlayableNowOrAfter,    &OrigIsPlayableNowOrAfter);
    InstallLong(@"YTIPlayabilityStatus", @"status",                        (IMP)H_Status,                  &OrigStatus);
    InstallObj (@"YTIPlayabilityStatus", @"statusString",                  (IMP)H_StatusString,            &OrigStatusString);
    InstallLong(@"YTIPlayabilityStatus", @"errorCode",                     (IMP)H_ErrorCode,               &OrigErrorCode);
    InstallBool(@"YTIPlayabilityStatus", @"hasErrorCode",                  (IMP)H_HasErrorCode,            &OrigHasErrorCode);
    InstallBool(@"YTIPlayabilityStatus", @"hasErrorScreen",                (IMP)H_HasErrorScreen,          &OrigHasErrorScreen);
    InstallObj (@"YTIPlayabilityStatus", @"errorScreen",                   (IMP)H_ErrorScreen,             &OrigErrorScreen);

    InstallBool(@"YTPlayerResponse", @"isExpiredByMaxAgeSeconds",              (IMP)H_IsExpiredByMaxAge,     &OrigIsExpiredByMaxAge);
    InstallBool(@"YTPlayerResponse", @"areStreamsCloseToExpiringIfPlaybackStartsNow", (IMP)H_StreamsCloseExpiring, &OrigStreamsCloseExpiring);
    InstallLong(@"YTPlayerResponse", @"timeUntilStreamingDataExpirySeconds",   (IMP)H_TimeUntilExpiry,       &OrigTimeUntilExpiry);
    InstallBool(@"YTPlayerResponse", @"isReuse",                               (IMP)H_IsReuse,               &OrigIsReuse);
    InstallDouble(@"MLStreamingData", @"timeToExpiry",       (IMP)H_MLTimeToExpiry, &OrigMLTimeToExpiry);
    InstallLong  (@"YTIStreamingData", @"expiresInSeconds",  (IMP)H_YTIExpiresIn,   &OrigYTIExpiresIn);

    InstallBool(@"YTPlaybackRequest", @"enablePlayerResponseCacheKeyRelaxation", (IMP)H_CacheKeyRelax,          &OrigCacheKeyRelax);
    InstallBool(@"YTPlaybackRequest", @"streamingWatchEnabled",                  (IMP)H_StreamingWatchEnabled,  &OrigStreamingWatchEnabled);
    InstallObj (@"YTPlaybackRequest", @"playerResponseCacheToken",               (IMP)H_PlayerRespCacheToken,   &OrigPlayerRespCacheToken);
}
