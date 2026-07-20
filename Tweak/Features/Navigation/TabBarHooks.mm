#import "../../YTKACE.h"
#import "../../Runtime/Hooking.h"
#import "../../Runtime/Preferences.h"
#import "../../Settings/YTKACEDownloadsController.h"
#import "../../UI/Assets.h"

#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>

static IMP OriginalSetPivotRenderer;
static IMP OriginalPivotItemLayout;
static IMP OriginalPivotItemSetSelected;
static IMP OriginalPivotItemTraitChanged;
static IMP OriginalPivotBarLayout;
static IMP OriginalAppViewDidLoad;
static IMP OriginalBrowseViewDidLoad;
static IMP OriginalBrowseResponseViewDidLoad;
static IMP OriginalWrapperViewDidLoad;
static const void *YTKACEDownloadsAssociation = &YTKACEDownloadsAssociation;
static const void *YTKACETabAssociation = &YTKACETabAssociation;
static const void *YTKACETabSelectedAssociation = &YTKACETabSelectedAssociation;
static NSString * const YTKACEPivotIdentifier = @"FEYTKACE";
static BOOL YTKACEStartupApplied;

static id YTKACEValue(id receiver, NSString *selectorName) {
    SEL selector = NSSelectorFromString(selectorName);
    return receiver != nil && [receiver respondsToSelector:selector]
        ? ((id (*)(id, SEL))objc_msgSend)(receiver, selector)
        : nil;
}

static void YTKACESetValue(id receiver, NSString *selectorName, id value) {
    SEL selector = NSSelectorFromString(selectorName);
    if (receiver != nil && [receiver respondsToSelector:selector]) {
        ((void (*)(id, SEL, id))objc_msgSend)(receiver, selector, value);
    }
}

static id YTKACENew(NSString *className) {
    Class cls = NSClassFromString(className);
    return cls == Nil ? nil : [[cls alloc] init];
}

static id YTKACEMakePivotItem(void) {
    Class rendererClass = NSClassFromString(@"YTIPivotBarRenderer");
    SEL factory = NSSelectorFromString(@"pivotSupportedRenderersWithBrowseId:title:iconType:");
    if (rendererClass != Nil && [rendererClass respondsToSelector:factory]) {
        id renderer = ((id (*)(id, SEL, id, id, NSInteger))objc_msgSend)(
            rendererClass,
            factory,
            YTKACEPivotIdentifier,
            @"YTKACE",
            77
        );
        id item = YTKACEValue(renderer, @"pivotBarItemRenderer");
        if (item != nil) {
            YTKACESetValue(item, @"setPivotIdentifier:", YTKACEPivotIdentifier);
        }
        if (renderer != nil) {
            return renderer;
        }
    }
    id browseEndpoint = YTKACENew(@"YTIBrowseEndpoint");
    id command = YTKACENew(@"YTICommand");
    id itemRenderer = YTKACENew(@"YTIPivotBarItemRenderer");
    id supportedRenderer = YTKACENew(@"YTIPivotBarSupportedRenderers");
    Class formattedClass = NSClassFromString(@"YTIFormattedString");
    SEL formattedSelector = NSSelectorFromString(@"formattedStringWithString:");
    if (browseEndpoint == nil || command == nil || itemRenderer == nil ||
        supportedRenderer == nil || formattedClass == Nil ||
        ![formattedClass respondsToSelector:formattedSelector]) {
        return nil;
    }

    YTKACESetValue(browseEndpoint, @"setBrowseId:", YTKACEPivotIdentifier);
    YTKACESetValue(command, @"setBrowseEndpoint:", browseEndpoint);
    YTKACESetValue(itemRenderer, @"setPivotIdentifier:", YTKACEPivotIdentifier);
    YTKACESetValue(itemRenderer, @"setNavigationEndpoint:", command);
    id title = ((id (*)(id, SEL, id))objc_msgSend)(
        formattedClass,
        formattedSelector,
        @"YTKACE"
    );
    YTKACESetValue(itemRenderer, @"setTitle:", title);

    id icon = YTKACEValue(itemRenderer, @"icon");
    SEL iconSelector = NSSelectorFromString(@"setIconType:");
    if ([icon respondsToSelector:iconSelector]) {
        ((void (*)(id, SEL, NSInteger))objc_msgSend)(icon, iconSelector, 77);
    }
    YTKACESetValue(
        supportedRenderer,
        @"setPivotBarItemRenderer:",
        itemRenderer
    );
    return supportedRenderer;
}

static id YTKACEMakeBrowsePivotItem(NSString *browseID,
                                    NSString *title,
                                    NSInteger iconType) {
    Class rendererClass = NSClassFromString(@"YTIPivotBarRenderer");
    SEL factory = NSSelectorFromString(@"pivotSupportedRenderersWithBrowseId:title:iconType:");
    if (rendererClass != Nil && [rendererClass respondsToSelector:factory]) {
        id renderer = ((id (*)(id, SEL, id, id, NSInteger))objc_msgSend)(
            rendererClass, factory, browseID, title, iconType
        );
        id item = YTKACEValue(renderer, @"pivotBarItemRenderer");
        if (item != nil) {
            YTKACESetValue(item, @"setPivotIdentifier:", browseID);
        }
        if (renderer != nil) {
            return renderer;
        }
    }
    id browseEndpoint = YTKACENew(@"YTIBrowseEndpoint");
    id command = YTKACENew(@"YTICommand");
    id itemRenderer = YTKACENew(@"YTIPivotBarItemRenderer");
    id supportedRenderer = YTKACENew(@"YTIPivotBarSupportedRenderers");
    Class formattedClass = NSClassFromString(@"YTIFormattedString");
    SEL formattedSelector = NSSelectorFromString(@"formattedStringWithString:");
    if (browseEndpoint == nil || command == nil || itemRenderer == nil ||
        supportedRenderer == nil || formattedClass == Nil ||
        ![formattedClass respondsToSelector:formattedSelector]) {
        return nil;
    }
    YTKACESetValue(browseEndpoint, @"setBrowseId:", browseID);
    YTKACESetValue(command, @"setBrowseEndpoint:", browseEndpoint);
    YTKACESetValue(itemRenderer, @"setPivotIdentifier:", browseID);
    YTKACESetValue(itemRenderer, @"setNavigationEndpoint:", command);
    id icon = YTKACEValue(itemRenderer, @"icon");
    SEL setIconType = NSSelectorFromString(@"setIconType:");
    if ([icon respondsToSelector:setIconType]) {
        ((void (*)(id, SEL, NSInteger))objc_msgSend)(icon, setIconType, iconType);
    }
    id formatted = ((id (*)(id, SEL, id))objc_msgSend)(
        formattedClass, formattedSelector, title
    );
    YTKACESetValue(itemRenderer, @"setTitle:", formatted);
    YTKACESetValue(supportedRenderer, @"setPivotBarItemRenderer:", itemRenderer);
    return supportedRenderer;
}

static NSInteger YTKACEInteger(id receiver, NSString *selectorName) {
    SEL selector = NSSelectorFromString(selectorName);
    return receiver != nil && [receiver respondsToSelector:selector]
        ? ((NSInteger (*)(id, SEL))objc_msgSend)(receiver, selector)
        : 0;
}

static id YTKACEMakeOrderedCreateItem(id source) {
    id iconOnly = YTKACEValue(source, @"pivotBarIconOnlyItemRenderer");
    if (iconOnly == nil) {
        iconOnly = source;
    }
    NSString *pivotIdentifier = YTKACEValue(iconOnly, @"pivotIdentifier");
    id navigationEndpoint = YTKACEValue(iconOnly, @"navigationEndpoint");
    id sourceIcon = YTKACEValue(iconOnly, @"icon");
    NSInteger iconType = YTKACEInteger(sourceIcon, @"iconType");
    Class rendererClass = NSClassFromString(@"YTIPivotBarRenderer");
    SEL factory = NSSelectorFromString(@"pivotSupportedRenderersWithBrowseId:title:iconType:");
    if (rendererClass != Nil && [rendererClass respondsToSelector:factory]) {
        id converted = ((id (*)(id, SEL, id, id, NSInteger))objc_msgSend)(
            rendererClass,
            factory,
            pivotIdentifier ?: @"FEuploads",
            @"Create",
            iconType
        );
        id convertedItem = YTKACEValue(converted, @"pivotBarItemRenderer");
        if (convertedItem != nil) {
            YTKACESetValue(convertedItem,
                           @"setPivotIdentifier:",
                           pivotIdentifier ?: @"FEuploads");
            if (navigationEndpoint != nil) {
                YTKACESetValue(convertedItem,
                               @"setNavigationEndpoint:",
                               navigationEndpoint);
            }
            return converted;
        }
    }
    id itemRenderer = YTKACENew(@"YTIPivotBarItemRenderer");
    id supportedRenderer = YTKACENew(@"YTIPivotBarSupportedRenderers");
    Class formattedClass = NSClassFromString(@"YTIFormattedString");
    SEL formattedSelector = NSSelectorFromString(@"formattedStringWithString:");
    if (itemRenderer == nil || supportedRenderer == nil ||
        formattedClass == Nil || ![formattedClass respondsToSelector:formattedSelector]) {
        return source;
    }
    YTKACESetValue(itemRenderer,
                   @"setPivotIdentifier:",
                   pivotIdentifier ?: @"FEuploads");
    YTKACESetValue(itemRenderer, @"setNavigationEndpoint:", navigationEndpoint);
    id destinationIcon = YTKACEValue(itemRenderer, @"icon");
    SEL setIconType = NSSelectorFromString(@"setIconType:");
    if ([destinationIcon respondsToSelector:setIconType]) {
        ((void (*)(id, SEL, NSInteger))objc_msgSend)(
            destinationIcon,
            setIconType,
            iconType
        );
    }
    id title = ((id (*)(id, SEL, id))objc_msgSend)(
        formattedClass,
        formattedSelector,
        @"Create"
    );
    YTKACESetValue(itemRenderer, @"setTitle:", title);
    YTKACESetValue(supportedRenderer, @"setPivotBarItemRenderer:", itemRenderer);
    return supportedRenderer;
}

static NSString *YTKACEBrowseIdentifier(UIViewController *controller) {
    id endpoint = YTKACEValue(controller, @"navigationEndpoint");
    if (endpoint == nil) {
        endpoint = YTKACEValue(controller, @"navEndpoint");
    }
    if (endpoint == nil) {
        @try {
            endpoint = [controller valueForKey:@"_navEndpoint"];
        } @catch (__unused NSException *exception) {
        }
    }
    id browseEndpoint = YTKACEValue(endpoint, @"browseEndpoint");
    if (browseEndpoint == nil &&
        [endpoint respondsToSelector:NSSelectorFromString(@"browseId")]) {
        browseEndpoint = endpoint;
    }
    return YTKACEValue(browseEndpoint, @"browseId");
}

static void YTKACEAttachDownloads(UIViewController *controller) {
    if (!YTKACEMasterEnabled() ||
        ![YTKACEBrowseIdentifier(controller) isEqualToString:YTKACEPivotIdentifier] ||
        objc_getAssociatedObject(controller, YTKACEDownloadsAssociation) != nil) {
        return;
    }
    YTKACEDownloadsController *downloads = [YTKACEDownloadsController new];
    [controller addChildViewController:downloads];
    downloads.view.frame = controller.view.bounds;
    downloads.view.autoresizingMask = UIViewAutoresizingFlexibleWidth |
        UIViewAutoresizingFlexibleHeight;
    [controller.view addSubview:downloads.view];
    [downloads didMoveToParentViewController:controller];
    objc_setAssociatedObject(controller,
                             YTKACEDownloadsAssociation,
                             downloads,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void YTKACETryAttachDownloads(UIViewController *controller) {
    YTKACEAttachDownloads(controller);
    if (objc_getAssociatedObject(controller, YTKACEDownloadsAssociation) == nil) {
        dispatch_async(dispatch_get_main_queue(), ^{
            YTKACEAttachDownloads(controller);
        });
    }
}

static void YTKACEAppViewDidLoad(UIViewController *receiver, SEL selector) {
    if (OriginalAppViewDidLoad != NULL) {
        ((void (*)(id, SEL))OriginalAppViewDidLoad)(receiver, selector);
    }
    YTKACETryAttachDownloads(receiver);
}

static void YTKACEBrowseViewDidLoad(UIViewController *receiver, SEL selector) {
    if (OriginalBrowseViewDidLoad != NULL) {
        ((void (*)(id, SEL))OriginalBrowseViewDidLoad)(receiver, selector);
    }
    YTKACETryAttachDownloads(receiver);
}

static void YTKACEBrowseResponseViewDidLoad(UIViewController *receiver,
                                            SEL selector) {
    if (OriginalBrowseResponseViewDidLoad != NULL) {
        ((void (*)(id, SEL))OriginalBrowseResponseViewDidLoad)(receiver, selector);
    }
    YTKACETryAttachDownloads(receiver);
}

static void YTKACEWrapperViewDidLoad(UIViewController *receiver, SEL selector) {
    if (OriginalWrapperViewDidLoad != NULL) {
        ((void (*)(id, SEL))OriginalWrapperViewDidLoad)(receiver, selector);
    }
    YTKACETryAttachDownloads(receiver);
}

static id YTKACETabValue(id receiver, NSArray<NSString *> *selectors) {
    for (NSString *name in selectors) {
        SEL selector = NSSelectorFromString(name);
        if ([receiver respondsToSelector:selector]) {
            id value = ((id (*)(id, SEL))objc_msgSend)(receiver, selector);
            if (value != nil) {
                return value;
            }
        }
    }
    return nil;
}

static NSString *YTKACETabToken(id item) {
    for (NSString *selectorName in @[
        @"pivotIdentifier",
        @"tabIdentifier",
        @"browseId"
    ]) {
        id value = YTKACETabValue(item, @[selectorName]);
        if ([value isKindOfClass:NSString.class] && [value length] != 0) {
            return [value lowercaseString];
        }
    }
    NSArray<NSString *> *activeRenderers =
        YTKACEInteger(item, @"hasPivotBarItemRenderer") != 0
            ? @[@"pivotBarItemRenderer"]
            : (YTKACEInteger(item, @"hasPivotBarIconOnlyItemRenderer") != 0
                ? @[@"pivotBarIconOnlyItemRenderer"]
                : @[@"pivotBarItemRenderer", @"pivotBarIconOnlyItemRenderer"]);
    for (NSString *rendererName in activeRenderers) {
        id nested = YTKACETabValue(item, @[rendererName]);
        if (nested != nil && nested != item) {
            NSString *token = YTKACETabToken(nested);
            if (token.length != 0) {
                return token;
            }
        }
    }
    id renderer = YTKACETabValue(item, @[@"renderer"]);
    if (renderer != nil && renderer != item) {
        NSString *token = YTKACETabToken(renderer);
        if (token.length != 0) {
            return token;
        }
    }
    id endpoint = YTKACETabValue(item, @[@"navigationEndpoint", @"endpoint"]);
    id browseEndpoint = YTKACETabValue(endpoint, @[@"browseEndpoint"]);
    id browseID = YTKACETabValue(browseEndpoint ?: endpoint, @[@"browseId"]);
    if ([browseID isKindOfClass:NSString.class] && [browseID length] != 0) {
        return [browseID lowercaseString];
    }
    id identifier = YTKACETabValue(item, @[@"identifier"]);
    return [identifier isKindOfClass:NSString.class]
        ? [identifier lowercaseString]
        : @"";
}

static NSString *YTKACEHideKeyForToken(NSString *token) {
    if ([token containsString:@"uc-9-kytw8zkzndhqj6fgpwq"] ||
        [token containsString:@"music_home"]) {
        return @"kHideMusic";
    }
    if ([token containsString:@"uc4r8dwomoi7cawx8_ljqhig"] ||
        [token containsString:@"trending_live"]) {
        return @"kHideLive";
    }
    if ([token containsString:@"ucopncn46ubxvtpkmrmu4abg"] ||
        [token containsString:@"gaming"]) {
        return @"kHideGaming";
    }
    if ([token containsString:@"ucyfdidrxb8qhf0nx7iooyw"] ||
        [token containsString:@"news"]) {
        return @"kHideNews";
    }
    if ([token containsString:@"ucegdi0xixxz-qjofpf4jskw"] ||
        [token containsString:@"sports"]) {
        return @"kHideSports";
    }
    if ([token containsString:@"short"]) {
        return @"kHideShorts";
    }
    if ([token containsString:@"subscription"]) {
        return @"kHideSubscriptions";
    }
    if ([token containsString:@"library"] ||
        [token containsString:@"you_tab"] ||
        [token isEqualToString:@"you"]) {
        return @"kHideLibrary";
    }
    if ([token containsString:@"create"] ||
        [token containsString:@"upload"] ||
        [token containsString:@"plus"]) {
        return @"kHideCreate";
    }
    if ([token containsString:@"home"] ||
        [token containsString:@"what_to_watch"]) {
        return @"kHideHome";
    }
    return nil;
}

static NSString *YTKACECanonicalTabToken(NSString *token) {
    if ([token containsString:@"uc-9-kytw8zkzndhqj6fgpwq"] ||
        [token containsString:@"music_home"]) {
        return @"music";
    }
    if ([token containsString:@"uc4r8dwomoi7cawx8_ljqhig"] ||
        [token containsString:@"trending_live"]) {
        return @"live";
    }
    if ([token containsString:@"ucopncn46ubxvtpkmrmu4abg"] ||
        [token containsString:@"gaming"]) {
        return @"gaming";
    }
    if ([token containsString:@"ucyfdidrxb8qhf0nx7iooyw"] ||
        [token containsString:@"news"]) {
        return @"news";
    }
    if ([token containsString:@"ucegdi0xixxz-qjofpf4jskw"] ||
        [token containsString:@"sports"]) {
        return @"sports";
    }
    if ([token containsString:@"short"] || [token containsString:@"reel"]) {
        return @"shorts";
    }
    if ([token containsString:@"subscription"]) {
        return @"subscriptions";
    }
    if ([token containsString:@"library"] ||
        [token containsString:@"you_tab"] ||
        [token isEqualToString:@"you"]) {
        return @"you";
    }
    if ([token containsString:@"create"] ||
        [token containsString:@"upload"] ||
        [token containsString:@"plus"]) {
        return @"create";
    }
    if ([token containsString:@"home"] ||
        [token containsString:@"what_to_watch"]) {
        return @"home";
    }
    return token;
}

static NSArray *YTKACETabItems(id renderer, NSString **setterName) {
    NSArray<NSString *> *getters = @[
        @"itemsArray",
        @"items",
        @"pivotBarItemsArray",
        @"pivotBarItems"
    ];
    NSArray<NSString *> *setters = @[
        @"setItemsArray:",
        @"setItems:",
        @"setPivotBarItemsArray:",
        @"setPivotBarItems:"
    ];
    for (NSUInteger index = 0; index < getters.count; index++) {
        id value = YTKACETabValue(renderer, @[getters[index]]);
        if ([value isKindOfClass:NSArray.class]) {
            if (setterName != NULL) {
                *setterName = setters[index];
            }
            return value;
        }
    }
    return nil;
}

static NSInteger YTKACETabOrderIndex(NSString *token, NSArray *order) {
    NSString *canonical = YTKACECanonicalTabToken(token);
    for (NSUInteger index = 0; index < order.count; index++) {
        id value = order[index];
        if ([value isKindOfClass:NSString.class] &&
            ([canonical isEqualToString:[value lowercaseString]] ||
             [token containsString:[value lowercaseString]])) {
            return (NSInteger)index;
        }
    }
    return NSIntegerMax;
}

static void YTKACEApplyTabName(id item, NSString *token) {
    NSDictionary *names =
        [NSUserDefaults.standardUserDefaults dictionaryForKey:@"YTKACETabNames"];
    NSString *replacement = names[token] ?: names[YTKACECanonicalTabToken(token)];
    if (![replacement isKindOfClass:NSString.class] || replacement.length == 0) {
        return;
    }
    id target = YTKACETabValue(item, @[
        @"pivotBarItemRenderer",
        @"pivotBarIconOnlyItemRenderer"
    ]) ?: item;
    Class formattedClass = NSClassFromString(@"YTIFormattedString");
    SEL formattedSelector = NSSelectorFromString(@"formattedStringWithString:");
    id value = replacement;
    if (formattedClass != Nil && [formattedClass respondsToSelector:formattedSelector]) {
        value = ((id (*)(id, SEL, id))objc_msgSend)(
            formattedClass,
            formattedSelector,
            replacement
        );
    }
    SEL selector = NSSelectorFromString(@"setTitle:");
    if ([target respondsToSelector:selector]) {
        ((void (*)(id, SEL, id))objc_msgSend)(target, selector, value);
    }
}

static BOOL YTKACEIsDownloadTab(id item) {
    NSString *token = YTKACETabToken(item);
    if ([token containsString:@"ytkace"]) {
        return YES;
    }
    NSString *description = [[item description] lowercaseString];
    return [description containsString:@"feytkace"] ||
        [description containsString:@"ytkace"];
}

static void YTKACESetPivotRenderer(id receiver, SEL selector, id renderer) {
    if (renderer != nil) {
        NSString *setterName = nil;
        NSArray *items = YTKACETabItems(renderer, &setterName);
        if (items != nil) {
            NSMutableArray *filtered = [NSMutableArray array];
            BOOL hasDownloadTab = NO;
            for (id item in items) {
                id candidate = item;
                NSString *token = YTKACETabToken(candidate);
                if (YTKACEIsDownloadTab(candidate)) {
                    BOOL duplicate = hasDownloadTab;
                    hasDownloadTab = YES;
                    if (!duplicate && YTKACEMasterEnabled() &&
                        ![NSUserDefaults.standardUserDefaults boolForKey:@"kHideYTKACETab"]) {
                        [filtered addObject:candidate];
                    }
                    continue;
                }
                NSString *hideKey = YTKACEHideKeyForToken(token);
                if (YTKACEMasterEnabled() && hideKey != nil &&
                    [NSUserDefaults.standardUserDefaults boolForKey:hideKey]) {
                    continue;
                }
                if (YTKACEMasterEnabled() &&
                    [YTKACECanonicalTabToken(token) isEqualToString:@"create"]) {
                    candidate = YTKACEMakeOrderedCreateItem(candidate);
                    token = @"create";
                }
                if (YTKACEMasterEnabled()) {
                    YTKACEApplyTabName(candidate, token);
                }
                [filtered addObject:candidate];
            }

            NSArray<NSDictionary *> *extraTabs = @[
                @{@"token": @"music", @"id": @"UC-9-kyTW8ZkZNDHQJ6FgpwQ",
                  @"title": @"Music", @"key": @"kHideMusic", @"icon": @1001},
                @{@"token": @"live", @"id": @"UC4R8DWoMoI7CAwX8_LjQHig",
                  @"title": @"Live", @"key": @"kHideLive", @"icon": @1002},
                @{@"token": @"gaming", @"id": @"UCOpNcN46UbXVtpKMrmU4Abg",
                  @"title": @"Gaming", @"key": @"kHideGaming", @"icon": @1003},
                @{@"token": @"news", @"id": @"UCYfdidRxbB8Qhf0Nx7ioOYw",
                  @"title": @"News", @"key": @"kHideNews", @"icon": @1004},
                @{@"token": @"sports", @"id": @"UCEgdi0XIXXZ-qJOFPf4JSKw",
                  @"title": @"Sports", @"key": @"kHideSports", @"icon": @1005}
            ];
            NSMutableSet<NSString *> *present = [NSMutableSet set];
            for (id item in filtered) {
                [present addObject:YTKACECanonicalTabToken(YTKACETabToken(item))];
            }
            NSDictionary *customNames =
                [NSUserDefaults.standardUserDefaults dictionaryForKey:@"YTKACETabNames"];
            for (NSDictionary *entry in extraTabs) {
                NSString *token = entry[@"token"];
                if ([NSUserDefaults.standardUserDefaults boolForKey:entry[@"key"]] ||
                    [present containsObject:token]) {
                    continue;
                }
                NSString *title = customNames[token] ?: entry[@"title"];
                id item = YTKACEMakeBrowsePivotItem(entry[@"id"],
                                                     title,
                                                     [entry[@"icon"] integerValue]);
                if (item != nil) {
                    [filtered addObject:item];
                    [present addObject:token];
                }
            }

            if (YTKACEMasterEnabled() && !hasDownloadTab &&
                ![NSUserDefaults.standardUserDefaults boolForKey:@"kHideYTKACETab"]) {
                id downloadItem = YTKACEMakePivotItem();
                if (downloadItem != nil) {
                    [filtered addObject:downloadItem];
                }
            }

            NSArray *order =
                [NSUserDefaults.standardUserDefaults arrayForKey:@"kTabOrder"];
            if (YTKACEMasterEnabled() && order.count != 0) {
                [filtered sortUsingComparator:^NSComparisonResult(id left, id right) {
                    NSInteger leftIndex =
                        YTKACETabOrderIndex(YTKACETabToken(left), order);
                    NSInteger rightIndex =
                        YTKACETabOrderIndex(YTKACETabToken(right), order);
                    if (leftIndex == rightIndex) {
                        return NSOrderedSame;
                    }
                    return leftIndex < rightIndex
                        ? NSOrderedAscending
                        : NSOrderedDescending;
                }];
            }

            SEL setter = NSSelectorFromString(setterName);
            if ([items isKindOfClass:NSMutableArray.class]) {
                [(NSMutableArray *)items setArray:filtered];
            } else if ([renderer respondsToSelector:setter]) {
                ((void (*)(id, SEL, id))objc_msgSend)(renderer, setter, filtered);
            }
        }
    }

    if (OriginalSetPivotRenderer != NULL) {
        ((void (*)(id, SEL, id))OriginalSetPivotRenderer)(
            receiver, selector, renderer
        );
    }
}

static void YTKACESetLabelsHidden(UIView *view, BOOL hidden) {
    for (UIView *subview in view.subviews) {
        if ([subview isKindOfClass:UILabel.class]) {
            subview.hidden = hidden;
        }
        YTKACESetLabelsHidden(subview, hidden);
    }
}

static UILabel *YTKACEFindNativeLabel(UIView *view) {
    if ([view isKindOfClass:UILabel.class]) {
        return view.tag == 0x59414347 ? nil : (UILabel *)view;
    }
    for (UIView *subview in view.subviews) {
        UILabel *label = YTKACEFindNativeLabel(subview);
        if (label != nil) {
            return label;
        }
    }
    return nil;
}

static UIImageView *YTKACEFindImageView(UIView *view) {
    if ([view isKindOfClass:UIImageView.class]) {
        return view.tag == 0x59414345 ? nil : (UIImageView *)view;
    }
    for (UIView *subview in view.subviews) {
        UIImageView *imageView = YTKACEFindImageView(subview);
        if (imageView != nil) {
            return imageView;
        }
    }
    return nil;
}

static BOOL YTKACEViewIsVisible(UIView *view) {
    if (view.window == nil) {
        return NO;
    }
    for (UIView *current = view; current != nil; current = current.superview) {
        if (current.hidden || current.alpha < 0.01) {
            return NO;
        }
    }
    return YES;
}

static UIView *YTKACEFindDownloadsRoot(UIView *view) {
    if ([view.accessibilityIdentifier isEqualToString:@"YTKACEDownloadsRoot"]) {
        return view;
    }
    for (UIView *subview in view.subviews) {
        UIView *result = YTKACEFindDownloadsRoot(subview);
        if (result != nil) {
            return result;
        }
    }
    return nil;
}

static BOOL YTKACEDownloadsAreVisible(void) {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) {
            continue;
        }
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            UIView *root = YTKACEFindDownloadsRoot(window);
            if (root != nil && YTKACEViewIsVisible(root)) {
                return YES;
            }
        }
    }
    return NO;
}

static void YTKACERestorePivotItem(UIView *view,
                                   UILabel *nativeLabel,
                                   BOOL hideLabel) {
    [[view viewWithTag:0x59414347] removeFromSuperview];
    [[view viewWithTag:0x59414345] removeFromSuperview];
    objc_setAssociatedObject(view,
                             YTKACETabAssociation,
                             nil,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(view,
                             YTKACETabSelectedAssociation,
                             nil,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (nativeLabel != nil) {
        nativeLabel.hidden = hideLabel;
        nativeLabel.alpha = 1.0;
    }
    UIImageView *nativeImageView = YTKACEFindImageView(view);
    if (nativeImageView != nil) {
        nativeImageView.hidden = NO;
    }
}

static void YTKACEApplyDownloadIcon(UIView *view) {
    UILabel *nativeLabel = YTKACEFindNativeLabel(view);
    NSString *token = YTKACETabToken(view);
    NSString *text = nativeLabel.text ?: @"";
    BOOL exactIdentifier = [token isEqualToString:@"feytkace"];
    BOOL exactLabel = [text caseInsensitiveCompare:@"YTKACE"] == NSOrderedSame;
    BOOL associated = [objc_getAssociatedObject(
        view,
        YTKACETabAssociation
    ) boolValue];
    BOOL definiteOther = (token.length != 0 && !exactIdentifier) ||
        (text.length != 0 && !exactLabel);
    BOOL hideLabel = YTKACEFeatureEnabled(@"kHideTabLabels");
    if (definiteOther) {
        YTKACERestorePivotItem(view, nativeLabel, hideLabel);
        return;
    }
    BOOL recognized = exactIdentifier || exactLabel || associated;
    if (!recognized) {
        return;
    }
    objc_setAssociatedObject(view,
                             YTKACETabAssociation,
                             @YES,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    UIColor *tabColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traits) {
        return traits.userInterfaceStyle == UIUserInterfaceStyleDark
            ? UIColor.whiteColor
            : UIColor.blackColor;
    }];
    UILabel *label = (UILabel *)[view viewWithTag:0x59414347];
    if (nativeLabel != nil) {
        nativeLabel.text = @"";
        nativeLabel.hidden = YES;
        nativeLabel.alpha = 0.0;
    }
    if (label == nil) {
        label = [[UILabel alloc] initWithFrame:CGRectZero];
        label.tag = 0x59414347;
        label.text = @"YTKACE";
        label.font = nativeLabel.font ?: [UIFont systemFontOfSize:10.0];
        label.textAlignment = NSTextAlignmentCenter;
        label.autoresizingMask = UIViewAutoresizingFlexibleWidth |
            UIViewAutoresizingFlexibleTopMargin;
        [view addSubview:label];
    }
    label.textColor = tabColor;
    label.hidden = hideLabel;
    label.alpha = 1.0;
    BOOL selected = [objc_getAssociatedObject(
        view,
        YTKACETabSelectedAssociation
    ) boolValue];
    SEL selectedSelector = NSSelectorFromString(@"isSelected");
    if ([view respondsToSelector:selectedSelector]) {
        selected = selected ||
            ((BOOL (*)(id, SEL))objc_msgSend)(view, selectedSelector);
    }
    selected = selected ||
        ((view.accessibilityTraits & UIAccessibilityTraitSelected) != 0) ||
        YTKACEDownloadsAreVisible();
    UIImage *image = selected
        ? YTKACEAssetImage(@"dwn_library_fill_24_pt_3x_Normal",
                           @"arrow.down.square.fill")
        : YTKACEAssetImage(@"dwn_library_outline_24_pt_3x_Normal",
                           @"arrow.down.square");
    UIImageView *imageView = (UIImageView *)[view viewWithTag:0x59414345];
    if (imageView == nil) {
        imageView = [[UIImageView alloc] initWithFrame:CGRectZero];
        imageView.tag = 0x59414345;
        imageView.contentMode = UIViewContentModeScaleAspectFit;
        imageView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
            UIViewAutoresizingFlexibleRightMargin |
            UIViewAutoresizingFlexibleBottomMargin;
        [view addSubview:imageView];
    }
    UIImageView *nativeImageView = YTKACEFindImageView(view);
    if (nativeImageView != nil && nativeImageView != imageView) {
        nativeImageView.hidden = YES;
    }
    imageView.image = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    imageView.tintColor = tabColor;
    imageView.hidden = NO;
    CGFloat size = 24.0;
    imageView.frame = CGRectMake(
        (CGRectGetWidth(view.bounds) - size) * 0.5,
        4.0,
        size,
        size
    );
    label.frame = CGRectMake(0.0,
                             MAX(0.0, CGRectGetHeight(view.bounds) - 16.0),
                             CGRectGetWidth(view.bounds),
                             14.0);
}

static BOOL YTKACEContainsCreateText(NSString *value) {
    NSString *text = value.lowercaseString;
    return [text containsString:@"create"] ||
        [text containsString:@"upload"] ||
        [text containsString:@"add video"];
}

static void YTKACEHideCreateViews(UIView *view) {
    BOOL hideCreate = [NSUserDefaults.standardUserDefaults boolForKey:@"kHideCreate"];
    for (UIView *subview in view.subviews) {
        NSString *label = subview.accessibilityLabel;
        NSString *identifier = subview.accessibilityIdentifier;
        NSString *className = NSStringFromClass(subview.class);
        if (hideCreate &&
            (YTKACEContainsCreateText(label) ||
             YTKACEContainsCreateText(identifier) ||
             YTKACEContainsCreateText(className))) {
            subview.hidden = YES;
            subview.userInteractionEnabled = NO;
        }
        YTKACEHideCreateViews(subview);
    }
}

static void YTKACEPivotBarLayout(UIView *receiver, SEL selector) {
    if (OriginalPivotBarLayout != NULL) {
        ((void (*)(id, SEL))OriginalPivotBarLayout)(receiver, selector);
    }
    YTKACEHideCreateViews(receiver);
    NSInteger startup = [NSUserDefaults.standardUserDefaults
        integerForKey:@"kEnabledStartupPage"];
    SEL select = NSSelectorFromString(@"selectItemWithPivotIdentifier:");
    if (!YTKACEStartupApplied && startup > 0 && startup < 5 &&
        [receiver respondsToSelector:select]) {
        NSArray<NSString *> *identifiers = @[
            @"FEwhat_to_watch",
            @"FEexplore",
            @"FEsubscriptions",
            @"FEshorts",
            @"FElibrary"
        ];
        ((void (*)(id, SEL, id))objc_msgSend)(
            receiver,
            select,
            identifiers[(NSUInteger)startup]
        );
        YTKACEStartupApplied = YES;
    }
}

static void YTKACEPivotItemLayout(UIView *receiver, SEL selector) {
    if (OriginalPivotItemLayout != NULL) {
        ((void (*)(id, SEL))OriginalPivotItemLayout)(receiver, selector);
    }
    YTKACESetLabelsHidden(
        receiver,
        YTKACEFeatureEnabled(@"kHideTabLabels")
    );
    YTKACEApplyDownloadIcon(receiver);
}

static void YTKACEPivotItemSetSelected(UIView *receiver,
                                       SEL selector,
                                       BOOL selected) {
    if (OriginalPivotItemSetSelected != NULL) {
        ((void (*)(id, SEL, BOOL))OriginalPivotItemSetSelected)(
            receiver, selector, selected
        );
    }
    if ([objc_getAssociatedObject(receiver, YTKACETabAssociation) boolValue]) {
        objc_setAssociatedObject(receiver,
                                 YTKACETabSelectedAssociation,
                                 @(selected),
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    YTKACEApplyDownloadIcon(receiver);
    dispatch_async(dispatch_get_main_queue(), ^{
        YTKACEApplyDownloadIcon(receiver);
    });
}

static void YTKACEPivotItemTraitChanged(UIView *receiver,
                                        SEL selector,
                                        UITraitCollection *previous) {
    if (OriginalPivotItemTraitChanged != NULL) {
        ((void (*)(id, SEL, id))OriginalPivotItemTraitChanged)(
            receiver, selector, previous
        );
    }
    YTKACEApplyDownloadIcon(receiver);
}

void YTKACEInstallTabBarHooks(void) {
    YTKACEInstallInstanceHook(@"YTPivotBarView",
                              @"setRenderer:",
                              (IMP)YTKACESetPivotRenderer,
                              &OriginalSetPivotRenderer);
    YTKACEInstallInstanceHook(@"YTPivotBarItemView",
                              @"layoutSubviews",
                              (IMP)YTKACEPivotItemLayout,
                              &OriginalPivotItemLayout);
    YTKACEInstallInstanceHook(@"YTPivotBarItemView",
                              @"setSelected:",
                              (IMP)YTKACEPivotItemSetSelected,
                              &OriginalPivotItemSetSelected);
    YTKACEInstallInstanceHook(@"YTPivotBarItemView",
                              @"traitCollectionDidChange:",
                              (IMP)YTKACEPivotItemTraitChanged,
                              &OriginalPivotItemTraitChanged);
    YTKACEInstallInstanceHook(@"YTPivotBarView",
                              @"layoutSubviews",
                              (IMP)YTKACEPivotBarLayout,
                              &OriginalPivotBarLayout);
    YTKACEInstallInstanceHook(@"YTAppViewController",
                              @"viewDidLoad",
                              (IMP)YTKACEAppViewDidLoad,
                              &OriginalAppViewDidLoad);
    YTKACEInstallInstanceHook(@"YTBrowseViewController",
                              @"viewDidLoad",
                              (IMP)YTKACEBrowseViewDidLoad,
                              &OriginalBrowseViewDidLoad);
    YTKACEInstallInstanceHook(@"YTBrowseResponseViewController",
                              @"viewDidLoad",
                              (IMP)YTKACEBrowseResponseViewDidLoad,
                              &OriginalBrowseResponseViewDidLoad);
    YTKACEInstallInstanceHook(@"YTWrapperFlatViewController",
                              @"viewDidLoad",
                              (IMP)YTKACEWrapperViewDidLoad,
                              &OriginalWrapperViewDidLoad);
}
