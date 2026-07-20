#import "NavigationVisibility.h"
#import "../../Runtime/Hooking.h"
#import "../../Runtime/Preferences.h"

#import <objc/message.h>
#import <objc/runtime.h>
#import <stdlib.h>

static IMP OriginalHeaderLogoLayout;
static IMP OriginalLogoViewLayout;
static IMP OriginalQTMButtonLayout;
static IMP OriginalYTImageViewLayout;
static NSMutableDictionary<NSString *, NSValue *> *YTKACENavigationOriginals;
static const void *YTKACENavigationHiddenAssociation = &YTKACENavigationHiddenAssociation;
static BOOL YTKACENavigationObserverInstalled;

static NSValue *YTKACENavigationIMPValue(IMP implementation) {
    return [NSValue value:&implementation withObjCType:@encode(IMP)];
}

static IMP YTKACENavigationIMP(NSValue *value) {
    IMP implementation = NULL;
    [value getValue:&implementation];
    return implementation;
}

static NSString *YTKACENavigationHookKey(Class cls, SEL selector) {
    return [NSString stringWithFormat:@"%@|%@",
            NSStringFromClass(cls), NSStringFromSelector(selector)];
}

static IMP YTKACENavigationOriginal(id receiver, SEL selector) {
    for (Class cls = object_getClass(receiver); cls != Nil; cls = class_getSuperclass(cls)) {
        NSValue *value = YTKACENavigationOriginals[
            YTKACENavigationHookKey(cls, selector)
        ];
        if (value != nil) return YTKACENavigationIMP(value);
    }
    return NULL;
}

static void YTKACESetNavigationHidden(UIView *view, BOOL hidden) {
    if (view == nil ||
        [view.accessibilityLabel hasPrefix:@"YTKACE"] ||
        [view.accessibilityIdentifier hasPrefix:@"YTKACE"]) {
        return;
    }
    NSNumber *baseline = objc_getAssociatedObject(
        view,
        YTKACENavigationHiddenAssociation
    );
    if (hidden) {
        if (baseline == nil) {
            objc_setAssociatedObject(view,
                                     YTKACENavigationHiddenAssociation,
                                     @(view.hidden),
                                     OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        view.hidden = YES;
        view.userInteractionEnabled = NO;
    } else if (baseline != nil) {
        view.hidden = baseline.boolValue;
        view.userInteractionEnabled = YES;
        objc_setAssociatedObject(view,
                                 YTKACENavigationHiddenAssociation,
                                 nil,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

static id YTKACENotificationButton(id receiver, SEL selector) {
    IMP original = YTKACENavigationOriginal(receiver, selector);
    id value = original == NULL
        ? nil
        : ((id (*)(id, SEL))original)(receiver, selector);
    if ([value isKindOfClass:UIView.class]) {
        YTKACESetNavigationHidden(
            value,
            YTKACEFeatureEnabled(@"kEnableHideNotificationBill")
        );
    }
    return value;
}

static BOOL YTKACEHideNotificationButton(id receiver, SEL selector) {
    IMP original = YTKACENavigationOriginal(receiver, selector);
    BOOL hidden = original == NULL
        ? NO
        : ((BOOL (*)(id, SEL))original)(receiver, selector);
    return hidden || YTKACEFeatureEnabled(@"kEnableHideNotificationBill");
}

static void YTKACESetHideNotificationButton(id receiver,
                                             SEL selector,
                                             BOOL hidden) {
    IMP original = YTKACENavigationOriginal(receiver, selector);
    if (original != NULL) {
        ((void (*)(id, SEL, BOOL))original)(
            receiver,
            selector,
            hidden || YTKACEFeatureEnabled(@"kEnableHideNotificationBill")
        );
    }
}

static void YTKACEInstallNavigationMethodHooks(void) {
    if (YTKACENavigationOriginals != nil) return;
    YTKACENavigationOriginals = [NSMutableDictionary dictionary];
    NSDictionary<NSString *, NSValue *> *replacements = @{
        @"notificationButton": YTKACENavigationIMPValue((IMP)YTKACENotificationButton),
        @"newNotificationButton": YTKACENavigationIMPValue((IMP)YTKACENotificationButton),
        @"hideNotificationButton": YTKACENavigationIMPValue((IMP)YTKACEHideNotificationButton),
        @"setHideNotificationButton:": YTKACENavigationIMPValue((IMP)YTKACESetHideNotificationButton)
    };
    int count = objc_getClassList(NULL, 0);
    if (count <= 0) return;
    Class *classes = (Class *)calloc((size_t)count, sizeof(Class));
    count = objc_getClassList(classes, count);
    for (int index = 0; index < count; index++) {
        Class cls = classes[index];
        unsigned int methodCount = 0;
        Method *methods = class_copyMethodList(cls, &methodCount);
        for (unsigned int methodIndex = 0; methodIndex < methodCount; methodIndex++) {
            Method method = methods[methodIndex];
            SEL selector = method_getName(method);
            NSValue *replacement = replacements[NSStringFromSelector(selector)];
            if (replacement == nil) continue;
            IMP original = method_getImplementation(method);
            IMP hook = YTKACENavigationIMP(replacement);
            if (original == hook) continue;
            YTKACENavigationOriginals[YTKACENavigationHookKey(cls, selector)] =
                YTKACENavigationIMPValue(original);
            method_setImplementation(method, hook);
        }
        free(methods);
    }
    free(classes);
}

static BOOL YTKACENavigationShouldHide(UIView *view) {
    NSString *token = [[NSString stringWithFormat:@"%@ %@ %@",
                        NSStringFromClass(view.class),
                        view.accessibilityIdentifier ?: @"",
                        view.accessibilityLabel ?: @""] lowercaseString];
    if (YTKACEFeatureEnabled(@"kEnableHideAccount") &&
        ([token containsString:@"account"] ||
         [token containsString:@"avatar"] ||
         [token containsString:@"profile"])) {
        return YES;
    }
    if (YTKACEFeatureEnabled(@"kEnableHideSearch") &&
        [token containsString:@"search"]) {
        return YES;
    }
    if (YTKACEFeatureEnabled(@"kEnableHideCastButton") &&
        ([token containsString:@"cast"] ||
         [token containsString:@"airplay"] ||
         [token containsString:@"routebutton"])) {
        return YES;
    }
    if (YTKACEFeatureEnabled(@"kEnableHideNotificationBill") &&
        ([token containsString:@"notification"] ||
         [token containsString:@"bell"])) {
        return YES;
    }
    return NO;
}

static void YTKACEApplyNavigationTree(UIView *view) {
    YTKACESetNavigationHidden(view, YTKACENavigationShouldHide(view));
    for (UIView *subview in view.subviews) {
        YTKACEApplyNavigationTree(subview);
    }
}

static void YTKACEApplyNavigationWindows(void) {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class] ||
            scene.activationState != UISceneActivationStateForegroundActive) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            if (!window.hidden) YTKACEApplyNavigationTree(window);
        }
    }
}

static UIView *YTKACENavigationValue(id owner, NSString *name) {
    SEL selector = NSSelectorFromString(name);
    if ([owner respondsToSelector:selector]) {
        id value = ((id (*)(id, SEL))objc_msgSend)(owner, selector);
        if ([value isKindOfClass:UIView.class]) return value;
    }
    @try {
        id value = [owner valueForKey:name];
        return [value isKindOfClass:UIView.class] ? value : nil;
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static void YTKACEApplyNavigationSelectors(id owner) {
    NSDictionary<NSString *, NSArray<NSString *> *> *groups = @{
        @"kEnableHideNotificationBill": @[
            @"notificationButton", @"newNotificationButton",
            @"notificationBellButton", @"notificationBellView"
        ],
        @"kEnableHideSearch": @[@"searchButton"],
        @"kEnableHideCastButton": @[@"castButton"],
        @"kEnableHideAccount": @[@"accountButton", @"avatarButton"]
    };
    for (NSString *key in groups) {
        BOOL hidden = YTKACEFeatureEnabled(key);
        for (NSString *name in groups[key]) {
            YTKACESetNavigationHidden(YTKACENavigationValue(owner, name), hidden);
        }
    }
}

void YTKACEApplyRightNavigationVisibility(UIView *view) {
    YTKACEApplyNavigationSelectors(view);
    YTKACEApplyNavigationTree(view);
}

static void YTKACEHeaderLogoLayout(UIView *receiver, SEL selector) {
    if (OriginalHeaderLogoLayout != NULL) {
        ((void (*)(id, SEL))OriginalHeaderLogoLayout)(receiver, selector);
    }
    YTKACESetNavigationHidden(
        receiver,
        YTKACEFeatureEnabled(@"kEnableHideYTLogo")
    );
}

static void YTKACELogoViewLayout(UIView *receiver, SEL selector) {
    if (OriginalLogoViewLayout != NULL) {
        ((void (*)(id, SEL))OriginalLogoViewLayout)(receiver, selector);
    }
    YTKACESetNavigationHidden(
        receiver,
        YTKACEFeatureEnabled(@"kEnableHideYTLogo")
    );
}

static void YTKACEQTMButtonLayout(UIView *receiver, SEL selector) {
    if (OriginalQTMButtonLayout != NULL) {
        ((void (*)(id, SEL))OriginalQTMButtonLayout)(receiver, selector);
    }
    NSString *label = receiver.accessibilityLabel.lowercaseString;
    if ([label isEqualToString:@"notifications"] ||
        [label isEqualToString:@"notification"]) {
        YTKACESetNavigationHidden(
            receiver,
            YTKACEFeatureEnabled(@"kEnableHideNotificationBill")
        );
    } else if ([label isEqualToString:@"search"] ||
               [receiver.accessibilityIdentifier
                   isEqualToString:@"id.ui.navigation.search.button"]) {
        YTKACESetNavigationHidden(
            receiver,
            YTKACEFeatureEnabled(@"kEnableHideSearch")
        );
    }
}

static void YTKACEYTImageViewLayout(UIView *receiver, SEL selector) {
    if (OriginalYTImageViewLayout != NULL) {
        ((void (*)(id, SEL))OriginalYTImageViewLayout)(receiver, selector);
    }
    NSString *label = receiver.accessibilityLabel;
    if ([receiver.accessibilityIdentifier isEqualToString:@"id.youtube.logo"] ||
        (label.length != 0 &&
         [label caseInsensitiveCompare:@"YouTube"] == NSOrderedSame)) {
        YTKACESetNavigationHidden(
            receiver,
            YTKACEFeatureEnabled(@"kEnableHideYTLogo")
        );
    }
}

void YTKACEInstallNavigationVisibilityHooks(void) {
    YTKACEInstallNavigationMethodHooks();
    YTKACEInstallInstanceHook(@"YTHeaderLogoView",
                              @"layoutSubviews",
                              (IMP)YTKACEHeaderLogoLayout,
                              &OriginalHeaderLogoLayout);
    YTKACEInstallInstanceHook(@"YTLogoView",
                              @"layoutSubviews",
                              (IMP)YTKACELogoViewLayout,
                              &OriginalLogoViewLayout);
    YTKACEInstallInstanceHook(@"YTQTMButton",
                              @"layoutSubviews",
                              (IMP)YTKACEQTMButtonLayout,
                              &OriginalQTMButtonLayout);
    YTKACEInstallInstanceHook(@"YTImageView",
                              @"layoutSubviews",
                              (IMP)YTKACEYTImageViewLayout,
                              &OriginalYTImageViewLayout);
    YTKACEApplyNavigationWindows();
    if (!YTKACENavigationObserverInstalled) {
        YTKACENavigationObserverInstalled = YES;
        [NSNotificationCenter.defaultCenter
            addObserverForName:UIApplicationDidBecomeActiveNotification
            object:nil queue:NSOperationQueue.mainQueue
            usingBlock:^(__unused NSNotification *notification) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                    (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        YTKACEApplyNavigationWindows();
                    });
            }];
    }
}
