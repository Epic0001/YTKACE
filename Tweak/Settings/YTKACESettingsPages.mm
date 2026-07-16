#import "YTKACESettingsPages.h"
#import "YTKACERootOptionsController.h"
#import "YTKACETabEditorController.h"
#import "../Runtime/Preferences.h"
#import "../UI/Assets.h"
#import "../UI/Notice.h"

#import <objc/runtime.h>
#import <objc/message.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

typedef UIViewController * _Nonnull (^YTKACEControllerBuilder)(void);
typedef void (^YTKACEAction)(UIViewController *controller);

static const void *YTKACEItemAssociation = &YTKACEItemAssociation;
static const void *YTKACEValueLabelAssociation = &YTKACEValueLabelAssociation;

static NSDictionary *YTKACEToggle(NSString *title,
                                   NSString *key,
                                   NSString *asset,
                                   NSString *symbol) {
    return @{
        @"type": @"toggle",
        @"title": title,
        @"key": key,
        @"asset": asset ?: @"",
        @"symbol": symbol ?: @""
    };
}

static NSDictionary *YTKACEToggleDetail(NSString *title,
                                         NSString *subtitle,
                                         NSString *key) {
    return @{
        @"type": @"toggle",
        @"title": title,
        @"subtitle": subtitle ?: @"",
        @"key": key,
        @"asset": @"",
        @"symbol": @""
    };
}

static NSDictionary *YTKACEPicker(NSString *title,
                                   NSString *key,
                                   NSArray<NSString *> *titles,
                                   NSArray *values,
                                   NSUInteger defaultIndex,
                                   NSString *asset,
                                   NSString *symbol) {
    return @{
        @"type": @"picker",
        @"title": title,
        @"key": key,
        @"titles": titles,
        @"values": values,
        @"default": @(defaultIndex),
        @"asset": asset ?: @"",
        @"symbol": symbol ?: @""
    };
}

static NSDictionary *YTKACEStepper(NSString *title,
                                    NSString *key,
                                    double minimum,
                                    double maximum,
                                    double step,
                                    double fallback) {
    return @{
        @"type": @"stepper",
        @"title": title,
        @"key": key,
        @"minimum": @(minimum),
        @"maximum": @(maximum),
        @"step": @(step),
        @"fallback": @(fallback)
    };
}

static NSDictionary *YTKACESegmented(NSString *title,
                                      NSString *key,
                                      NSArray<NSString *> *titles,
                                      NSArray *values,
                                      NSUInteger defaultIndex) {
    return @{
        @"type": @"segmented",
        @"title": title,
        @"key": key,
        @"titles": titles,
        @"values": values,
        @"default": @(defaultIndex)
    };
}

static NSDictionary *YTKACESlider(NSString *title,
                                   NSString *key,
                                   double minimum,
                                   double maximum,
                                   double fallback) {
    return @{
        @"type": @"slider",
        @"title": title,
        @"key": key,
        @"minimum": @(minimum),
        @"maximum": @(maximum),
        @"fallback": @(fallback)
    };
}

static NSDictionary *YTKACEText(NSString *text) {
    return @{
        @"type": @"text",
        @"title": text
    };
}

static NSDictionary *YTKACEActionDetail(NSString *title,
                                         NSString *subtitle,
                                         YTKACEAction action) {
    return @{
        @"type": @"action",
        @"title": title,
        @"subtitle": subtitle ?: @"",
        @"asset": @"",
        @"symbol": @"",
        @"action": [action copy]
    };
}

static UIColor *YTKACESettingsBackground(void) {
    return YTKACEFeatureEnabled(YTKACEOLEDKey)
        ? UIColor.blackColor
        : UIColor.systemBackgroundColor;
}

static UIColor *YTKACESettingsCellBackground(void) {
    return YTKACEFeatureEnabled(YTKACEOLEDKey)
        ? UIColor.blackColor
        : UIColor.systemBackgroundColor;
}

BOOL YTKACEPreferenceNeedsRestart(NSString *key) {
    return [@[
        YTKACEOLEDKey,
        @"kEnableUsePremiumLogo",
        @"kEnableHideYTLogo",
        @"kEnableiPadOSMode",
        @"kEnableDisableRTL",
        @"kEnableLegacyQSelection",
        @"kEnableHideStatusBar",
        @"kEnabledStartupPage",
        @"kEnablefixvideoplayback"
    ] containsObject:key];
}

void YTKACEShowRestartNotice(UIViewController *controller) {
    UIView *host = controller.navigationController.view ?: controller.view;
    UIView *old = [host viewWithTag:0x594B524E];
    [old removeFromSuperview];
    UILabel *notice = [UILabel new];
    notice.tag = 0x594B524E;
    notice.text = @"Restart YouTube to apply changes.";
    notice.textColor = UIColor.labelColor;
    notice.backgroundColor = [UIColor colorWithWhite:0.72 alpha:0.96];
    notice.font = [UIFont systemFontOfSize:13.0];
    notice.layer.cornerRadius = 8.0;
    notice.layer.masksToBounds = YES;
    notice.textAlignment = NSTextAlignmentLeft;
    notice.translatesAutoresizingMaskIntoConstraints = NO;
    [host addSubview:notice];
    UILayoutGuide *safe = host.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [notice.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:8.0],
        [notice.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-8.0],
        [notice.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-8.0],
        [notice.heightAnchor constraintEqualToConstant:48.0]
    ]];
    notice.alpha = 0.0;
    [UIView animateWithDuration:0.2 animations:^{ notice.alpha = 1.0; }];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.2 animations:^{ notice.alpha = 0.0; }
                         completion:^(__unused BOOL finished) { [notice removeFromSuperview]; }];
    });
}

static void YTKACEStorePickerValue(NSString *key, id value, NSUInteger index) {
    YTKACESetPreferenceObject(key, value);
    if ([key isEqualToString:@"kEnabledStartupPage"]) {
        NSArray *browseIDs = @[@"FEwhat_to_watch", @"FEexplore", @"FEsubscriptions",
                               @"FEshorts", @"FElibrary"];
        if (index < browseIDs.count) {
            YTKACESetPreferenceObject(@"kStartupPageID", browseIDs[index]);
        }
    }
}

static UIImage *YTKACEBlankChoiceIcon(void) {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(24.0, 24.0), NO, 0.0);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

void YTKACEPresentChoiceMenu(UIViewController *presenter,
                             UIView *sourceView,
                             NSString *title,
                             NSArray<NSString *> *titles,
                             NSArray *values,
                             NSString *key,
                             NSUInteger defaultIndex,
                             YTKACEChoiceHandler handler) {
    (void)title;
    id selected = YTKACEPreferenceObject(key);
    NSUInteger selectedIndex = [values indexOfObject:selected];
    if (selectedIndex == NSNotFound) {
        selectedIndex = MIN(defaultIndex, values.count - 1);
    }
    Class sheetClass = NSClassFromString(@"YTDefaultSheetController");
    Class actionClass = NSClassFromString(@"YTActionSheetAction");
    SEL makeSheet = NSSelectorFromString(
        @"sheetControllerWithMessage:subMessage:delegate:parentResponder:");
    SEL makeAction = NSSelectorFromString(@"actionWithTitle:iconImage:style:handler:");
    if (sheetClass != Nil && actionClass != Nil &&
        [sheetClass respondsToSelector:makeSheet] &&
        [actionClass respondsToSelector:makeAction]) {
        id sheet = ((id (*)(id, SEL, id, id, id, id))objc_msgSend)(
            sheetClass, makeSheet, nil, nil, nil, nil);
        UIImage *check = [[UIImage systemImageNamed:@"checkmark"]
            imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        UIImage *blank = YTKACEBlankChoiceIcon();
        [titles enumerateObjectsUsingBlock:^(NSString *choice, NSUInteger index, BOOL *stop) {
            (void)stop;
            dispatch_block_t selection = ^{
                YTKACEStorePickerValue(key, values[index], index);
                if (handler != nil) {
                    handler(index);
                }
            };
            id action = ((id (*)(id, SEL, id, id, NSInteger, id))objc_msgSend)(
                actionClass, makeAction, choice,
                index == selectedIndex ? check : blank, 0, selection);
            SEL addAction = NSSelectorFromString(@"addAction:");
            if ([sheet respondsToSelector:addAction]) {
                ((void (*)(id, SEL, id))objc_msgSend)(sheet, addAction, action);
            }
        }];
        if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad &&
            sourceView != nil &&
            [sheet respondsToSelector:NSSelectorFromString(@"presentFromView:animated:completion:")]) {
            ((void (*)(id, SEL, id, BOOL, id))objc_msgSend)(
                sheet, NSSelectorFromString(@"presentFromView:animated:completion:"),
                sourceView, YES, nil);
        } else if ([sheet respondsToSelector:
                    NSSelectorFromString(@"presentFromViewController:animated:completion:")]) {
            ((void (*)(id, SEL, id, BOOL, id))objc_msgSend)(
                sheet, NSSelectorFromString(@"presentFromViewController:animated:completion:"),
                presenter, YES, nil);
        }
        return;
    }
    YTKACEShowNotice(@"YouTube menu unavailable");
}

NSString *YTKACEPickerSummary(NSString *key,
                              NSArray<NSString *> *titles,
                              NSArray *values,
                              NSUInteger defaultIndex) {
    id selected = YTKACEPreferenceObject(key);
    NSUInteger index = [values indexOfObject:selected];
    if (index == NSNotFound || index >= titles.count) {
        index = MIN(defaultIndex, titles.count - 1);
    }
    return titles.count == 0 ? @"" : titles[index];
}

@interface YTKACEPickerController : UITableViewController
- (instancetype)initWithTitle:(NSString *)title
                           key:(NSString *)key
                        titles:(NSArray<NSString *> *)titles
                        values:(NSArray *)values
                  defaultIndex:(NSUInteger)defaultIndex;
@end

@implementation YTKACEPickerController {
    NSString *_preferenceKey;
    NSArray<NSString *> *_titles;
    NSArray *_values;
    NSUInteger _defaultIndex;
}

- (instancetype)initWithTitle:(NSString *)title
                           key:(NSString *)key
                        titles:(NSArray<NSString *> *)titles
                        values:(NSArray *)values
                  defaultIndex:(NSUInteger)defaultIndex {
    self = [super initWithStyle:UITableViewStylePlain];
    if (self != nil) {
        self.title = title;
        _preferenceKey = [key copy];
        _titles = [titles copy];
        _values = [values copy];
        _defaultIndex = defaultIndex;
    }
    return self;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:NO];
    YTKACEApplyAppearance(self);
    self.tableView.backgroundColor = YTKACESettingsBackground();
    [self.tableView reloadData];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView;
    (void)section;
    return (NSInteger)_titles.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"YTKACEPickerCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                      reuseIdentifier:identifier];
    }
    id selected = YTKACEPreferenceObject(_preferenceKey);
    NSUInteger selectedIndex = [_values indexOfObject:selected];
    if (selectedIndex == NSNotFound) {
        selectedIndex = MIN(_defaultIndex, _values.count - 1);
    }
    cell.textLabel.text = _titles[(NSUInteger)indexPath.row];
    cell.textLabel.font = [UIFont systemFontOfSize:17.0];
    cell.textLabel.textColor = UIColor.labelColor;
    cell.backgroundColor = YTKACESettingsCellBackground();
    cell.accessoryType = (NSUInteger)indexPath.row == selectedIndex
        ? UITableViewCellAccessoryCheckmark
        : UITableViewCellAccessoryNone;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    id value = _values[(NSUInteger)indexPath.row];
    YTKACEStorePickerValue(_preferenceKey, value, (NSUInteger)indexPath.row);
    [tableView reloadData];
}

@end

@interface YTKACEOptionsController : UITableViewController <UIDocumentPickerDelegate>
- (instancetype)initWithTitle:(NSString *)title
                      sections:(NSArray<NSArray<NSDictionary *> *> *)sections
                sectionTitles:(NSArray<NSString *> *)sectionTitles;
@end

@implementation YTKACEOptionsController {
    NSArray<NSArray<NSDictionary *> *> *_sections;
    NSArray<NSString *> *_sectionTitles;
}

- (instancetype)initWithTitle:(NSString *)title
                      sections:(NSArray<NSArray<NSDictionary *> *> *)sections
                sectionTitles:(NSArray<NSString *> *)sectionTitles {
    self = [super initWithStyle:UITableViewStylePlain];
    if (self != nil) {
        self.title = title;
        _sections = [sections copy];
        _sectionTitles = [sectionTitles copy];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.cellLayoutMarginsFollowReadableWidth = NO;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.separatorInset = UIEdgeInsetsMake(0.0, 16.0, 0.0, 16.0);
    self.tableView.rowHeight = 40.0;
    if (@available(iOS 15.0, *)) {
        self.tableView.sectionHeaderTopPadding = 0.0;
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:NO];
    YTKACEApplyAppearance(self);
    self.tableView.backgroundColor = YTKACESettingsBackground();
    [self.tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    (void)tableView;
    return (NSInteger)_sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView;
    return (NSInteger)_sections[(NSUInteger)section].count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    (void)tableView;
    if ((NSUInteger)section >= _sectionTitles.count) {
        return nil;
    }
    NSString *title = _sectionTitles[(NSUInteger)section];
    return title.length == 0 ? nil : title;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    (void)tableView;
    NSString *title = (NSUInteger)section < _sectionTitles.count
        ? _sectionTitles[(NSUInteger)section]
        : @"";
    return title.length == 0 ? 18.0 : 38.0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    (void)tableView;
    NSDictionary *item = _sections[(NSUInteger)indexPath.section][(NSUInteger)indexPath.row];
    NSString *type = item[@"type"];
    if ([type isEqualToString:@"text"]) {
        return 92.0;
    }
    if ([type isEqualToString:@"slider"]) {
        return 58.0;
    }
    return [item[@"subtitle"] length] == 0 ? 40.0 : 56.0;
}

- (void)tableView:(UITableView *)tableView
willDisplayHeaderView:(UIView *)view
        forSection:(NSInteger)section {
    (void)tableView;
    (void)section;
    if ([view isKindOfClass:UITableViewHeaderFooterView.class]) {
        UITableViewHeaderFooterView *header = (UITableViewHeaderFooterView *)view;
        header.textLabel.font = [UIFont systemFontOfSize:11.0 weight:UIFontWeightRegular];
        header.textLabel.textColor = UIColor.secondaryLabelColor;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *item = _sections[(NSUInteger)indexPath.section][(NSUInteger)indexPath.row];
    NSString *type = item[@"type"];
    UITableViewCellStyle style = [type isEqualToString:@"picker"]
        ? UITableViewCellStyleValue1
        : ([item[@"subtitle"] length] == 0 ? UITableViewCellStyleDefault : UITableViewCellStyleSubtitle);
    NSString *identifier = [NSString stringWithFormat:@"YTKACEOption-%ld", (long)style];
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:style reuseIdentifier:identifier];
    }

    cell.textLabel.text = item[@"title"];
    cell.detailTextLabel.text = item[@"subtitle"];
    cell.textLabel.font = [UIFont systemFontOfSize:17.0];
    cell.detailTextLabel.font = [UIFont systemFontOfSize:12.0];
    cell.textLabel.numberOfLines = 1;
    cell.detailTextLabel.numberOfLines = 2;
    cell.textLabel.textColor = UIColor.labelColor;
    cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
    cell.backgroundColor = YTKACESettingsCellBackground();
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.accessoryView = nil;
    cell.imageView.image = nil;

    if ([type isEqualToString:@"toggle"]) {
        UISwitch *toggle = [UISwitch new];
        toggle.transform = CGAffineTransformMakeScale(0.95, 0.95);
        toggle.onTintColor = UIColor.systemBlueColor;
        id stored = YTKACEPreferenceObject(item[@"key"]);
        toggle.on = [stored respondsToSelector:@selector(boolValue)] && [stored boolValue];
        objc_setAssociatedObject(toggle,
                                 YTKACEItemAssociation,
                                 item,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [toggle addTarget:self
                   action:@selector(toggleChanged:)
         forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = toggle;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    } else if ([type isEqualToString:@"segmented"]) {
        UISegmentedControl *control = [[UISegmentedControl alloc] initWithItems:item[@"titles"]];
        id selected = YTKACEPreferenceObject(item[@"key"]);
        NSUInteger selectedIndex = [item[@"values"] indexOfObject:selected];
        control.selectedSegmentIndex = selectedIndex == NSNotFound
            ? [item[@"default"] unsignedIntegerValue]
            : selectedIndex;
        control.frame = CGRectMake(0.0, 0.0, 76.0, 28.0);
        objc_setAssociatedObject(control,
                                 YTKACEItemAssociation,
                                 item,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [control addTarget:self
                    action:@selector(segmentChanged:)
          forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = control;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    } else if ([type isEqualToString:@"stepper"]) {
        double stored = [YTKACEPreferenceObject(item[@"key"]) doubleValue];
        double value = stored > 0.0 ? stored : [item[@"fallback"] doubleValue];
        cell.textLabel.text = [NSString stringWithFormat:@"Seconds: %.0f", value];
        UIStepper *stepper = [UIStepper new];
        stepper.minimumValue = [item[@"minimum"] doubleValue];
        stepper.maximumValue = [item[@"maximum"] doubleValue];
        stepper.stepValue = [item[@"step"] doubleValue];
        stepper.value = value;
        objc_setAssociatedObject(stepper,
                                 YTKACEItemAssociation,
                                 item,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(stepper,
                                 YTKACEValueLabelAssociation,
                                 cell,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [stepper addTarget:self
                    action:@selector(stepperChanged:)
          forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = stepper;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    } else if ([type isEqualToString:@"slider"]) {
        double stored = [YTKACEPreferenceObject(item[@"key"]) doubleValue];
        double value = stored > 0.0 ? stored : [item[@"fallback"] doubleValue];
        UIView *accessory = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, 158.0, 46.0)];
        UISlider *slider = [[UISlider alloc] initWithFrame:CGRectMake(0.0, 0.0, 158.0, 30.0)];
        slider.minimumValue = [item[@"minimum"] floatValue];
        slider.maximumValue = [item[@"maximum"] floatValue];
        slider.value = (float)value;
        UILabel *valueLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.0, 28.0, 158.0, 14.0)];
        valueLabel.font = [UIFont systemFontOfSize:10.0];
        valueLabel.textColor = UIColor.tertiaryLabelColor;
        valueLabel.textAlignment = NSTextAlignmentRight;
        valueLabel.text = [NSString stringWithFormat:@"%.0f seconds", value];
        objc_setAssociatedObject(slider, YTKACEItemAssociation, item, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(slider, YTKACEValueLabelAssociation, valueLabel, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [slider addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
        [accessory addSubview:slider];
        [accessory addSubview:valueLabel];
        cell.accessoryView = accessory;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    } else if ([type isEqualToString:@"picker"]) {
        cell.detailTextLabel.text = YTKACEPickerSummary(
            item[@"key"],
            item[@"titles"],
            item[@"values"],
            [item[@"default"] unsignedIntegerValue]
        );
        cell.detailTextLabel.textColor = UIColor.systemBlueColor;
        cell.accessoryType = UITableViewCellAccessoryNone;
    } else if ([type isEqualToString:@"text"]) {
        cell.textLabel.font = [UIFont systemFontOfSize:10.0];
        cell.textLabel.textColor = UIColor.secondaryLabelColor;
        cell.textLabel.numberOfLines = 0;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    } else {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    return cell;
}

- (void)segmentChanged:(UISegmentedControl *)sender {
    NSDictionary *item = objc_getAssociatedObject(sender, YTKACEItemAssociation);
    NSArray *values = item[@"values"];
    if ((NSUInteger)sender.selectedSegmentIndex < values.count) {
        YTKACESetPreferenceObject(item[@"key"], values[(NSUInteger)sender.selectedSegmentIndex]);
        if (YTKACEPreferenceNeedsRestart(item[@"key"])) {
            YTKACEShowRestartNotice(self);
        }
    }
}

- (void)toggleChanged:(UISwitch *)sender {
    NSDictionary *item = objc_getAssociatedObject(sender, YTKACEItemAssociation);
    NSString *key = item[@"key"];
    YTKACESetPreference(key, sender.isOn);
    if ([key isEqualToString:@"kEnablefixvideoplayback"] && sender.isOn) {
        NSString *message = @"✅ Playback recovery hooks will install on next launch.\n\n"
            @"📍 What this does:\n• Forces iOS guard attestation off\n• Marks heartbeat policy errors non-fatal\n• Swallows halt / cannot-play / error-overlay paths\n• Forces skip-on-playability-error\n\n"
            @"📍 When to use it:\nEnable if videos error out mid-playback, show \"an error occurred,\" or get killed by heartbeat / attestation failures.\n\n"
            @"⚠️ Restart YouTube for the hooks to take effect. Leave off if playback already works — it bypasses server-side stop signals and can mask real issues.";
        if (!YTKACEShowYouTubeDialog(@"Fix Playback & Account Recovery", message)) {
            YTKACEShowNotice(@"Playback recovery guidance unavailable");
        }
    }
    if ([key isEqualToString:YTKACEOLEDKey]) {
        YTKACEApplyAppearance(self);
        self.tableView.backgroundColor = YTKACESettingsBackground();
        [self.tableView reloadData];
    }
    if (YTKACEPreferenceNeedsRestart(key)) {
        YTKACEShowRestartNotice(self);
    }
}

- (void)stepperChanged:(UIStepper *)sender {
    NSDictionary *item = objc_getAssociatedObject(sender, YTKACEItemAssociation);
    UITableViewCell *cell = objc_getAssociatedObject(sender, YTKACEValueLabelAssociation);
    YTKACESetPreferenceObject(item[@"key"], @(sender.value));
    cell.textLabel.text = [NSString stringWithFormat:@"Seconds: %.0f", sender.value];
}

- (void)sliderChanged:(UISlider *)sender {
    NSDictionary *item = objc_getAssociatedObject(sender, YTKACEItemAssociation);
    UILabel *label = objc_getAssociatedObject(sender, YTKACEValueLabelAssociation);
    double value = round(sender.value / 5.0) * 5.0;
    YTKACESetPreferenceObject(item[@"key"], @(value));
    label.text = [NSString stringWithFormat:@"%.0f seconds", value];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *item = _sections[(NSUInteger)indexPath.section][(NSUInteger)indexPath.row];
    NSString *type = item[@"type"];
    UIViewController *controller = nil;
    if ([type isEqualToString:@"controller"]) {
        YTKACEControllerBuilder builder = item[@"builder"];
        controller = builder();
    } else if ([type isEqualToString:@"picker"]) {
        UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
        YTKACEPresentChoiceMenu(self, cell, item[@"title"], item[@"titles"],
            item[@"values"], item[@"key"],
            [item[@"default"] unsignedIntegerValue], ^(__unused NSUInteger index) {
                [self.tableView reloadRowsAtIndexPaths:@[indexPath]
                                      withRowAnimation:UITableViewRowAnimationNone];
                if (YTKACEPreferenceNeedsRestart(item[@"key"])) {
                    YTKACEShowRestartNotice(self);
                }
            });
    } else if ([type isEqualToString:@"action"]) {
        YTKACEAction action = item[@"action"];
        action(self);
    }
    if (controller != nil) {
        [self.navigationController pushViewController:controller animated:YES];
    }
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller
didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    (void)controller;
    NSURL *source = urls.firstObject;
    if (source == nil) {
        return;
    }
    BOOL scoped = [source startAccessingSecurityScopedResource];
    NSURL *directory = [[YTKACEApplicationSupportDirectory()
        URLByAppendingPathComponent:@"Downloads"
                        isDirectory:YES]
        URLByAppendingPathComponent:@"Video"
                        isDirectory:YES];
    [NSFileManager.defaultManager createDirectoryAtURL:directory
                           withIntermediateDirectories:YES
                                            attributes:nil
                                                 error:nil];
    NSURL *destination = [directory URLByAppendingPathComponent:source.lastPathComponent];
    [NSFileManager.defaultManager removeItemAtURL:destination error:nil];
    NSError *error = nil;
    [NSFileManager.defaultManager copyItemAtURL:source toURL:destination error:&error];
    if (scoped) {
        [source stopAccessingSecurityScopedResource];
    }
    [self showResult:error == nil ? @"Imported" : @"Import Failed"
              message:error.localizedDescription];
}

- (void)showResult:(NSString *)title message:(NSString *)message {
    NSString *notice = message.length != 0
        ? [NSString stringWithFormat:@"%@\n%@", title, message] : title;
    YTKACEShowNotice(notice);
}

@end

static YTKACEOptionsController *YTKACEPage(NSString *title,
                                           NSArray *sections,
                                           NSArray *sectionTitles) {
    return [[YTKACEOptionsController alloc] initWithTitle:title
                                                 sections:sections
                                           sectionTitles:sectionTitles];
}

static NSArray<NSString *> *YTKACEQualityTitles(void) {
    return @[@"Auto", @"2160p60", @"2160p", @"1440p60", @"1440p", @"1080p60",
             @"1080p", @"720p60", @"720p", @"480p", @"360p", @"240p", @"144p"];
}

static NSArray *YTKACEQualityValues(void) {
    return @[@0, @1, @2, @3, @4, @5, @6, @7, @8, @9, @10, @11, @12];
}

UIViewController *YTKACEMakeStartupPickerController(void) {
    return [[YTKACEPickerController alloc]
        initWithTitle:@"Startup Page"
                   key:@"kEnabledStartupPage"
                titles:@[@"Home", @"Explore", @"Subscriptions", @"Shorts", @"You"]
                values:@[@0, @1, @2, @3, @4]
          defaultIndex:0];
}

UIViewController *YTKACEMakeWiFiQualityController(void) {
    return [[YTKACEPickerController alloc] initWithTitle:@"Wi-Fi Quality"
                                                    key:@"wiFiPlaybackIndex"
                                                 titles:YTKACEQualityTitles()
                                                 values:YTKACEQualityValues()
                                           defaultIndex:0];
}

UIViewController *YTKACEMakeCellularQualityController(void) {
    return [[YTKACEPickerController alloc] initWithTitle:@"Cellular Quality"
                                                    key:@"celluarPlaybackIndex"
                                                 titles:YTKACEQualityTitles()
                                                 values:YTKACEQualityValues()
                                           defaultIndex:0];
}

UIViewController *YTKACEMakePlayerControlsController(void) {
    YTKACEAction backup = ^(UIViewController *controller) {
        NSDictionary *payload = @{
            @"YTKACEEnabled": @(YTKACEMasterEnabled()),
            @"YTKPlus": [NSUserDefaults.standardUserDefaults dictionaryForKey:@"YTKPlus"] ?: @{}
        };
        NSURL *url = [YTKACEApplicationSupportDirectory()
            URLByAppendingPathComponent:@"SettingsBackup.plist"];
        BOOL saved = [payload writeToURL:url atomically:YES];
        [(YTKACEOptionsController *)controller showResult:saved ? @"Backup Saved" : @"Backup Failed"
                                                   message:saved ? url.lastPathComponent : nil];
    };
    YTKACEAction restore = ^(UIViewController *controller) {
        NSURL *url = [YTKACEApplicationSupportDirectory()
            URLByAppendingPathComponent:@"SettingsBackup.plist"];
        NSDictionary *payload = [NSDictionary dictionaryWithContentsOfURL:url];
        NSDictionary *legacy = payload[@"YTKPlus"];
        if ([legacy isKindOfClass:NSDictionary.class]) {
            [NSUserDefaults.standardUserDefaults setObject:legacy forKey:@"YTKPlus"];
            [legacy enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
                (void)stop;
                [NSUserDefaults.standardUserDefaults setObject:value forKey:key];
            }];
        }
        if ([payload[@"YTKACEEnabled"] respondsToSelector:@selector(boolValue)]) {
            [NSUserDefaults.standardUserDefaults setBool:[payload[@"YTKACEEnabled"] boolValue]
                                                  forKey:YTKACEMasterEnabledKey];
        }
        [(YTKACEOptionsController *)controller showResult:payload != nil ? @"Settings Restored" : @"No Backup"
                                                   message:nil];
    };
    YTKACEAction importMedia = ^(UIViewController *controller) {
        UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc]
            initForOpeningContentTypes:@[UTTypeMovie, UTTypeAudio]
                              asCopy:YES];
        picker.delegate = (id<UIDocumentPickerDelegate>)controller;
        [controller presentViewController:picker animated:YES completion:nil];
    };
    YTKACEAction clearCache = ^(UIViewController *controller) {
        NSURL *cache = [YTKACEApplicationSupportDirectory()
            URLByAppendingPathComponent:@"Cache"
                            isDirectory:YES];
        [NSFileManager.defaultManager removeItemAtURL:cache error:nil];
        [(YTKACEOptionsController *)controller showResult:@"Cache Cleared" message:nil];
    };
    return YTKACEPage(@"Player Controls", @[
        @[
            YTKACEToggle(@"Enable Download Feature", YTKACEDownloadKey, @"", @""),
            YTKACEToggle(@"Enable PiP", YTKACEPiPKey, @"", @""),
            YTKACEToggle(@"Add Loop Toggle", YTKACELoopKey, @"", @""),
            YTKACEToggle(@"Play in Background", YTKACEBackgroundPlaybackKey, @"", @""),
            YTKACEToggle(@"Remove Advertisements", YTKACENoAdsKey, @"", @"")
        ],
        @[
            YTKACEToggle(@"Playback Speed toggles", YTKACESpeedKey, @"", @""),
            YTKACEToggleDetail(@"🔧 Fix Playback & Account Recovery",
                @"🧰 Fixes playback guidance for sideloaded apps.",
                @"kEnablefixvideoplayback")
        ],
        @[
            YTKACEToggle(@"SponsorBlock", YTKACESponsorBlockKey, @"", @""),
            YTKACESegmented(@"Sponsor Behavior", @"sbSkipMode", @[@"Skip", @"Ask"], @[@0, @1], 0),
            YTKACEToggle(@"Play audio notification on skip", @"AudioNotificationOnSkip", @"", @"")
        ],
        @[
            YTKACEActionDetail(@"Create Backup", @"Exports all downloaded videos and audios to the Files app.", backup),
            YTKACEActionDetail(@"Restore Backup", @"Restore backups directly from the Files app.", restore)
        ],
        @[YTKACEActionDetail(@"Import Media", @"Import videos and audios into YTKACE. Multiple files including thumbnails or artwork can be selected from Files.", importMedia)],
        @[
            YTKACEPicker(@"Clear on Startup", @"clearonstartup", @[@"Off", @"On"], @[@NO, @YES], 0, @"", @""),
            YTKACEActionDetail(@"Clear Cache", @"Remove downloaded cache files.", clearCache)
        ]
    ], @[@"OVERLAY PLAYER", @"PLAYBACK", @"SPONSORBLOCK", @"BACKUP & RESTORE", @"IMPORT MEDIA", @"CLEAR CACHE"]);
}

UIViewController *YTKACEMakeTabBarOptionsController(void) {
    return [YTKACETabEditorController new];
}

UIViewController *YTKACEMakeOverlayOptionsController(void) {
    return YTKACEPage(@"Overlay", @[
        @[
            YTKACEToggle(@"Hide Suggested Videos", @"kEnableHideSuggestedVideo", @"", @""),
            YTKACEToggle(@"Hide Comments", @"kEnableHideComments", @"", @""),
            YTKACEToggle(@"Hide Comment Previews", @"kEnableHideCommentReview", @"", @""),
            YTKACEToggle(@"Hide Comment Guidelines", @"kEnableHideCommentGuidlines", @"", @"")
        ],
        @[
            YTKACEToggle(@"Show Status Bar in Overlay", @"kEnableShowStatusBarInOverlay", @"", @""),
            YTKACEToggle(@"Disable Double Tap", @"kEnableDisableDoubleTap", @"", @""),
            YTKACEToggle(@"Disable Continue Watching", @"kEnableDisableContinueWatching", @"", @""),
            YTKACEToggle(@"Hide Quick Actions", @"kEnableHideOverlayQuickAction", @"", @"")
        ],
        @[
            YTKACEToggle(@"Always Show Play/Pause Button", @"kEnableShowOverlaySmart", @"", @""),
            YTKACEToggle(@"Always Show All Controls", @"kEnableShowMediaController", @"", @""),
            YTKACEToggle(@"Hide Dark Overlay Background", @"kEnableHideDarkOverlayBackground", @"", @""),
            YTKACEToggle(@"Keep Captions On", @"kEnableKeepCaptionOn", @"", @""),
            YTKACEToggle(@"Keep Progress Bar Visible", @"kEnableShowProgressBar", @"", @"")
        ],
        @[
            YTKACEToggle(@"Disable Previous & Next", @"kEnableDisablePreviousNextButton", @"", @""),
            YTKACEToggle(@"Compact Previous & Next", @"kEnablePreviousNextButtonPadding", @"", @""),
            YTKACEToggle(@"Hide Previous & Next", @"kEnableHidePreviousNextButton", @"", @"")
        ],
        @[
            YTKACEToggle(@"Hide Info Card", @"kEnableHideInfoCard", @"", @""),
            YTKACEToggle(@"Hide Watermark", @"kEnableHideWaterMark", @"", @""),
            YTKACEToggle(@"Hide Autoplay Button", @"kEnableHideAutoplayToggle", @"", @""),
            YTKACEToggle(@"Hide Captions Button", @"kEnableHideCaptionsToggle", @"", @""),
            YTKACEToggle(@"Hide Play/Pause", @"kEnableHidePlayPuase", @"", @""),
            YTKACEToggle(@"Hide More/Gear Icon", @"kEnableHideMoreGearIcon", @"", @""),
            YTKACEToggle(@"Hide Cast Button", @"kEnableHideCastButtonOverlay", @"", @""),
            YTKACEToggle(@"Hide Endscreen Videos", @"kEnableHideEndScreenVideos", @"", @""),
            YTKACEToggle(@"Hide Related Videos", @"kEnableHideRelatedVideos", @"", @"")
        ]
    ], @[@"VIDEO PLAYER", @"OVERLAY", @"OVERLAY CONTROLLER", @"PREVIOUS & NEXT BUTTONS", @"HIDE ITEMS"]);
}

UIViewController *YTKACEMakeStreamingOptionsController(void) {
    return YTKACEPage(@"Streaming", @[
        @[YTKACEToggle(@"Enable Legacy Quality Mode", @"kEnableLegacyQSelection", @"", @"")],
        @[
            YTKACEToggle(@"Custom Skip Duration", @"kEnableCustomDoubleTapToSkipDuration", @"", @""),
            YTKACEStepper(@"Seconds: 10", @"kEnableCustomDoubleTapToSkipChnges", 5.0, 60.0, 5.0, 10.0)
        ],
        @[
            YTKACEToggle(@"Disable Autoplay Videos", @"kEnableDisableAutoplayVideos", @"", @""),
            YTKACEToggle(@"Play HD Videos over 3G/4G/5G", @"kEnablePlayHDVideosOverCellur", @"", @"")
        ]
    ], @[@"", @"DOUBLE TAP OPTIONS", @"STREAMING"]);
}

UIViewController *YTKACEMakeNavigationOptionsController(void) {
    return YTKACEPage(@"Navigation Bar", @[
        @[YTKACEToggle(@"Hide Status Bar", @"kEnableHideStatusBar", @"", @"")],
        @[
            YTKACEToggle(@"Use Premium Logo", @"kEnableUsePremiumLogo", @"", @""),
            YTKACEToggle(@"Cast Confirmation", @"kEnableCastconfirm", @"", @"")
        ],
        @[
            YTKACEToggle(@"Hide YouTube Logo", @"kEnableHideYTLogo", @"", @""),
            YTKACEToggle(@"Hide Notifications", @"kEnableHideNotificationBill", @"", @""),
            YTKACEToggle(@"Hide Account", @"kEnableHideAccount", @"", @""),
            YTKACEToggle(@"Hide Search", @"kEnableHideSearch", @"", @""),
            YTKACEToggle(@"Hide Cast Button", @"kEnableHideCastButton", @"", @"")
        ]
    ], @[@"STATUS BAR", @"", @"HIDE ITEMS"]);
}

UIViewController *YTKACEMakeShortsOptionsController(void) {
    return YTKACEPage(@"Shorts", @[
        @[
            YTKACEToggle(@"Enable Bottom Progress Bar", @"shortsProgress", @"", @""),
            YTKACEToggle(@"Auto Skip Shorts", @"autoSkipShorts", @"", @"")
        ],
        @[
            YTKACEToggle(@"Hide Shorts from Feed", @"kEnableHideYTShorts", @"", @""),
            YTKACEToggle(@"Hide Pause Card", @"kEnableBlockShortsOverlays", @"", @"")
        ]
    ], @[@"SHORTS", @"HIDE ELEMENTS"]);
}

UIViewController *YTKACEMakeMiscOptionsController(void) {
    return YTKACEPage(@"Miscellaneous", @[
        @[
            YTKACEToggle(@"Enable iPadOS Mode", @"kEnableiPadOSMode", @"", @""),
            YTKACEToggle(@"Disable Drag & Drop", @"kEnableDisableDragDrop", @"", @"")
        ],
        @[
            YTKACEToggle(@"Hide Search History", @"kEnableNoSearchedHistory", @"", @""),
            YTKACEToggle(@"Hide Topic Section", @"kEnableNoTopics", @"", @""),
            YTKACEToggle(@"Hide Premium Popup", @"kEnableNoPremiumpopup", @"", @""),
            YTKACEToggle(@"Hide YouTube Update Popup", @"kEnableNoYTUpdate", @"", @""),
            YTKACEToggle(@"Enable Mini Player for All Videos", @"kEnableMiniPlayerAllVideos", @"", @""),
            YTKACEToggle(@"Hide HUD Alerts", @"kEnableHideHudeAlerts", @"", @""),
            YTKACEToggle(@"Hide Paid Promotion Notice", @"kEnableNoPaidPromotion", @"", @""),
            YTKACEToggle(@"Disable RTL Languages", @"kEnableDisableRTL", @"", @""),
            YTKACEToggle(@"OLED Dark Mode", YTKACEOLEDKey, @"", @""),
            YTKACEToggle(@"Bypass Age Restriction", @"kEnableAgeRestriction", @"", @""),
            YTKACEToggle(@"Disable Captions", @"kEnableDisableCaptions", @"", @"")
        ]
    ], @[@"IPAD MODE", @"MISCELLANEOUS"]);
}

UIViewController *YTKACEMakeGestureOptionsController(void) {
    NSArray *sideTitles = @[@"Left Side", @"Right Side", @"Disabled"];
    NSArray *sideValues = @[@0, @1, @2];
    return YTKACEPage(@"Gestures", @[
        @[
            YTKACEPicker(@"Brightness", @"kBrightnessSide", sideTitles, sideValues, 2, @"", @""),
            YTKACEPicker(@"Volume", @"kVolumeSide", sideTitles, sideValues, 2, @"", @""),
            YTKACEText(@"Set which side controls brightness and volume.\n\nTips:\n1. In portrait mode, swipe down on either side of the player.\n2. In fullscreen, swipe from the bottom area due to YouTube’s gesture handling.")
        ],
        @[
            YTKACEToggle(@"Hold to Seek", @"kEnableHoldToSeek", @"", @""),
            YTKACESlider(@"Seek Duration", @"kSeekDuration", 5.0, 60.0, 10.0)
        ]
    ], @[@"VOLUME & BRIGHTNESS GESTURES", @"SEEK SETTINGS"]);
}

UIViewController *YTKACEMakeCreditsController(void) {
    UILabel *label = [UILabel new];
    label.text = @"YTKACE\nClean-room implementation\nMIT licensed code\nBuilt by Epic";
    label.numberOfLines = 0;
    label.textAlignment = NSTextAlignmentCenter;
    label.textColor = UIColor.secondaryLabelColor;
    UIViewController *controller = [UIViewController new];
    controller.title = @"Credits";
    controller.view.backgroundColor = YTKACESettingsBackground();
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [controller.view addSubview:label];
    [NSLayoutConstraint activateConstraints:@[
        [label.centerXAnchor constraintEqualToAnchor:controller.view.centerXAnchor],
        [label.centerYAnchor constraintEqualToAnchor:controller.view.centerYAnchor],
        [label.leadingAnchor constraintGreaterThanOrEqualToAnchor:controller.view.leadingAnchor constant:24.0],
        [label.trailingAnchor constraintLessThanOrEqualToAnchor:controller.view.trailingAnchor constant:-24.0]
    ]];
    return controller;
}
