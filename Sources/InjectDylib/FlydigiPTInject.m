// FlydigiPTInject.m
// Hệ thống Giả lập Cảm ứng Đa Điểm (Multi-Touch Synthesizer 60FPS) dành riêng cho Play Together VNG (Unity Engine)
// Hỗ trợ Flydigi Apex 5 & Direwolf qua 4 cổng: Bluetooth BLE, Bluetooth iOS (XInput/MFi), Cáp USB-C/OTG, và Đầu thu 2.4GHz Dongle.
// Đảm bảo:
// - Vừa gạt cần trái (L-Stick) chạy 360 độ + vừa xoay Camera (R-Stick) + vừa ấn nút A (Nhảy) / B (Câu cá) cùng lúc (Multi-touch độc lập).
// - Cơ chế 2 bước (Chạm tâm Joystick -> Kéo ra ngoài theo vector 60Hz -> Nhả về tâm) giúp Unity Virtual Joystick của Play Together VNG bắt dính 100%.
// - Tích hợp chế độ "Kéo chỉnh vị trí nút trực tiếp đè lên màn hình Game" để khớp mọi kích thước màn hình iPhone/iPad.

#import <UIKit/UIKit.h>
#import <GameController/GameController.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

// MARK: - 1. Subclass UITouch Đa Điểm Chuẩn Cho Unity Engine (Play Together VNG)

@interface FlydigiSynthesizedTouch : UITouch
@property (nonatomic, assign) CGPoint currentWindowLocation;
@property (nonatomic, assign) CGPoint prevWindowLocation;
@property (nonatomic, assign) UITouchPhase synthPhase;
@property (nonatomic, assign) NSTimeInterval synthTimestamp;
@property (nonatomic, weak) UIWindow *synthWindow;
@property (nonatomic, weak) UIView *synthView;
@property (nonatomic, assign) NSUInteger synthTapCount;
@property (nonatomic, copy) NSString *channelID;

- (instancetype)initWithChannel:(NSString *)channel
                         window:(UIWindow *)window
                           view:(UIView *)view
                          point:(CGPoint)point;
- (void)updateLocation:(CGPoint)newPoint phase:(UITouchPhase)newPhase;
@end

@implementation FlydigiSynthesizedTouch

- (instancetype)initWithChannel:(NSString *)channel
                         window:(UIWindow *)window
                           view:(UIView *)view
                          point:(CGPoint)point {
    self = [super init];
    if (self) {
        _channelID = [channel copy];
        _synthWindow = window;
        _synthView = view;
        _currentWindowLocation = point;
        _prevWindowLocation = point;
        _synthPhase = UITouchPhaseBegan;
        _synthTimestamp = [[NSProcessInfo processInfo] systemUptime];
        _synthTapCount = 1;
    }
    return self;
}

- (void)updateLocation:(CGPoint)newPoint phase:(UITouchPhase)newPhase {
    _prevWindowLocation = _currentWindowLocation;
    _currentWindowLocation = newPoint;
    _synthPhase = newPhase;
    _synthTimestamp = [[NSProcessInfo processInfo] systemUptime];
}

// Ghi đè toàn bộ phương thức mà UnityView (Play Together VNG) và UIKit gọi khi xử lý cảm ứng
- (CGPoint)locationInView:(UIView *)view {
    if (!view || !_synthWindow) return _currentWindowLocation;
    return [_synthWindow convertPoint:_currentWindowLocation toView:view];
}

- (CGPoint)previousLocationInView:(UIView *)view {
    if (!view || !_synthWindow) return _prevWindowLocation;
    return [_synthWindow convertPoint:_prevWindowLocation toView:view];
}

- (CGPoint)preciseLocationInView:(UIView *)view {
    return [self locationInView:view];
}

- (CGPoint)precisePreviousLocationInView:(UIView *)view {
    return [self previousLocationInView:view];
}

- (UITouchPhase)phase {
    return _synthPhase;
}

- (NSTimeInterval)timestamp {
    return _synthTimestamp;
}

- (UIWindow *)window {
    return _synthWindow;
}

- (UIView *)view {
    return _synthView;
}

- (NSUInteger)tapCount {
    return _synthTapCount;
}

- (UITouchType)type {
    return UITouchTypeDirect;
}

- (CGFloat)majorRadius {
    return 20.0;
}

- (CGFloat)force {
    return 1.0;
}

- (CGFloat)maximumPossibleForce {
    return 1.0;
}

@end

// MARK: - 2. Model Nút Ảo Hiển Thị & Kéo Thả Trực Tiếp Trong Game

@interface FlydigiNodeView : UIView
@property (nonatomic, copy) NSString *nodeID;
@property (nonatomic, copy) NSString *titleText;
@property (nonatomic, assign) BOOL isJoystick;
@property (nonatomic, assign) CGFloat joyRadius;
@property (nonatomic, strong) UIView *stickDotView;
@property (nonatomic, strong) UILabel *labelView;
@property (nonatomic, copy) void (^onPositionChanged)(NSString *nodeID, CGPoint newCenter);
- (void)setHighlightedState:(BOOL)highlighted stickVector:(CGPoint)vec;
@end

@implementation FlydigiNodeView

- (instancetype)initWithNodeID:(NSString *)nodeID
                         title:(NSString *)title
                        center:(CGPoint)center
                        radius:(CGFloat)radius
                    isJoystick:(BOOL)isJoystick {
    CGRect frame = CGRectMake(center.x - radius, center.y - radius, radius * 2.0, radius * 2.0);
    self = [super initWithFrame:frame];
    if (self) {
        _nodeID = [nodeID copy];
        _titleText = [title copy];
        _isJoystick = isJoystick;
        _joyRadius = radius;

        self.backgroundColor = isJoystick
            ? [[UIColor cyanColor] colorWithAlphaComponent:0.15]
            : [[UIColor blackColor] colorWithAlphaComponent:0.45];
        self.layer.cornerRadius = radius;
        self.layer.borderWidth = isJoystick ? 2.0 : 1.8;
        self.layer.borderColor = isJoystick ? [UIColor cyanColor].CGColor : [UIColor yellowColor].CGColor;
        self.userInteractionEnabled = NO; // Mặc định khóa để xuyên cảm ứng vào game

        if (isJoystick) {
            _stickDotView = [[UIView alloc] initWithFrame:CGRectMake(radius - 12, radius - 12, 24, 24)];
            _stickDotView.backgroundColor = [[UIColor cyanColor] colorWithAlphaComponent:0.85];
            _stickDotView.layer.cornerRadius = 12;
            [self addSubview:_stickDotView];
        }

        _labelView = [[UILabel alloc] initWithFrame:self.bounds];
        _labelView.text = title;
        _labelView.textColor = [UIColor whiteColor];
        _labelView.font = [UIFont boldSystemFontOfSize:isJoystick ? 11 : 12];
        _labelView.textAlignment = NSTextAlignmentCenter;
        _labelView.numberOfLines = 2;
        [self addSubview:_labelView];

        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [self addGestureRecognizer:pan];
    }
    return self;
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    if (!self.userInteractionEnabled || !self.superview) return;
    CGPoint translation = [pan translationInView:self.superview];
    CGPoint newCenter = CGPointMake(self.center.x + translation.x, self.center.y + translation.y);
    CGRect bounds = self.superview.bounds;
    newCenter.x = MAX(24.0, MIN(bounds.size.width - 24.0, newCenter.x));
    newCenter.y = MAX(24.0, MIN(bounds.size.height - 24.0, newCenter.y));
    self.center = newCenter;
    [pan setTranslation:CGPointZero inView:self.superview];

    if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) {
        if (self.onPositionChanged) {
            self.onPositionChanged(self.nodeID, self.center);
        }
    }
}

- (void)setHighlightedState:(BOOL)highlighted stickVector:(CGPoint)vec {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.isJoystick) {
            CGFloat maxOff = self.joyRadius - 14.0;
            self.stickDotView.center = CGPointMake(self.joyRadius + vec.x * maxOff, self.joyRadius + vec.y * maxOff);
            self.layer.borderColor = highlighted ? [UIColor greenColor].CGColor : [UIColor cyanColor].CGColor;
        } else {
            self.backgroundColor = highlighted
                ? [[UIColor greenColor] colorWithAlphaComponent:0.75]
                : [[UIColor blackColor] colorWithAlphaComponent:0.45];
            self.layer.borderColor = highlighted ? [UIColor whiteColor].CGColor : [UIColor yellowColor].CGColor;
        }
    });
}

@end

// MARK: - 3. Bộ Điều Khiển Trung Tâm & Động Cơ Chạm 60FPS

@interface FlydigiOverlayController : NSObject <CBCentralManagerDelegate, CBPeripheralDelegate, UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UIButton *floatingToggleBtn;
@property (nonatomic, strong) UIView *connectionPanel;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UITableView *bleTableView;
@property (nonatomic, strong) UIButton *editLayoutBtn;
@property (nonatomic, strong) UIButton *showHideNodesBtn;

// Visual Overlay Nodes Container
@property (nonatomic, strong) NSMutableDictionary<NSString *, FlydigiNodeView *> *nodeViews;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSValue *> *nodePoints;
@property (nonatomic, assign) BOOL isEditingNodes;
@property (nonatomic, assign) BOOL areNodesVisible;

// Multi-Touch Engine State (60Hz CADisplayLink)
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, strong) NSMutableDictionary<NSString *, FlydigiSynthesizedTouch *> *activeTouches;
@property (nonatomic, assign) CGVector currentLeftStick;
@property (nonatomic, assign) CGVector currentRightStick;
@property (nonatomic, assign) CGPoint currentRightSwipePos;
@property (nonatomic, assign) CGFloat leftStickRadius;
@property (nonatomic, assign) CGFloat leftDeadzone;
@property (nonatomic, assign) CGFloat rightSensitivity;

// CoreBluetooth properties
@property (nonatomic, strong) CBCentralManager *centralManager;
@property (nonatomic, strong) NSMutableArray<CBPeripheral *> *discoveredPeripherals;
@property (nonatomic, strong) CBPeripheral *connectedBLEPeripheral;
@property (nonatomic, strong) NSMutableSet<NSString *> *blePressedButtons;

+ (instancetype)sharedInstance;
- (void)setupOverlay;
@end

@implementation FlydigiOverlayController

+ (instancetype)sharedInstance {
    static FlydigiOverlayController *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[FlydigiOverlayController alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _discoveredPeripherals = [NSMutableArray array];
        _activeTouches = [NSMutableDictionary dictionary];
        _nodeViews = [NSMutableDictionary dictionary];
        _nodePoints = [NSMutableDictionary dictionary];
        _blePressedButtons = [NSMutableSet set];
        _leftStickRadius = 78.0;
        _leftDeadzone = 0.12;
        _rightSensitivity = 1.45;
        _areNodesVisible = YES;
        _isEditingNodes = NO;
        [self loadDefaultOrSavedCoordinates];
    }
    return self;
}

- (void)loadDefaultOrSavedCoordinates {
    CGRect bounds = [UIScreen mainScreen].bounds;
    CGFloat w = MAX(bounds.size.width, bounds.size.height);
    CGFloat h = MIN(bounds.size.width, bounds.size.height);

    NSDictionary<NSString *, NSValue *> *defaults = @{
        @"L_STICK":    [NSValue valueWithCGPoint:CGPointMake(w * 0.16, h * 0.72)],
        @"R_STICK":    [NSValue valueWithCGPoint:CGPointMake(w * 0.62, h * 0.45)],
        @"BTN_A":      [NSValue valueWithCGPoint:CGPointMake(w * 0.88, h * 0.78)], // Nhảy (Jump)
        @"BTN_B":      [NSValue valueWithCGPoint:CGPointMake(w * 0.78, h * 0.82)], // Tương tác / Câu cá
        @"BTN_X":      [NSValue valueWithCGPoint:CGPointMake(w * 0.82, h * 0.62)], // Dùng công cụ
        @"BTN_Y":      [NSValue valueWithCGPoint:CGPointMake(w * 0.93, h * 0.48)], // Mở Balo
        @"BTN_RT":     [NSValue valueWithCGPoint:CGPointMake(w * 0.78, h * 0.82)], // Giật cần câu nhanh
        @"BTN_LT":     [NSValue valueWithCGPoint:CGPointMake(w * 0.72, h * 0.68)], // Gọi Xe / Ván trượt
        @"BTN_LB":     [NSValue valueWithCGPoint:CGPointMake(w * 0.10, h * 0.18)], // Bản đồ
        @"BTN_RB":     [NSValue valueWithCGPoint:CGPointMake(w * 0.86, h * 0.48)], // Đổi vật phẩm
        @"BTN_M1":     [NSValue valueWithCGPoint:CGPointMake(w * 0.78, h * 0.82)], // Phím lưng M1
        @"BTN_M2":     [NSValue valueWithCGPoint:CGPointMake(w * 0.88, h * 0.78)], // Phím lưng M2
        @"DPAD_UP":    [NSValue valueWithCGPoint:CGPointMake(w * 0.93, h * 0.28)], // Điện thoại
        @"DPAD_LEFT":  [NSValue valueWithCGPoint:CGPointMake(w * 0.25, h * 0.12)], // Biểu cảm
        @"DPAD_RIGHT": [NSValue valueWithCGPoint:CGPointMake(w * 0.33, h * 0.12)], // Chat nhanh
        @"DPAD_DOWN":  [NSValue valueWithCGPoint:CGPointMake(w * 0.70, h * 0.84)]  // Ngồi / Nằm
    };
    [_nodePoints addEntriesFromDictionary:defaults];

    // Đọc tọa độ đã lưu trong máy (nếu người dùng đã tự kéo chỉnh trước đó)
    NSDictionary *saved = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"Flydigi_InGame_SavedNodes_v2"];
    if ([saved isKindOfClass:[NSDictionary class]]) {
        for (NSString *key in saved) {
            NSDictionary *ptDict = saved[key];
            if ([ptDict isKindOfClass:[NSDictionary class]]) {
                CGFloat nx = [ptDict[@"nx"] doubleValue];
                CGFloat ny = [ptDict[@"ny"] doubleValue];
                if (nx > 0 && ny > 0) {
                    _nodePoints[key] = [NSValue valueWithCGPoint:CGPointMake(w * nx, h * ny)];
                }
            }
        }
    }
}

- (void)saveCurrentCoordinatesToDisk {
    CGRect bounds = [UIScreen mainScreen].bounds;
    CGFloat w = MAX(bounds.size.width, bounds.size.height);
    CGFloat h = MIN(bounds.size.width, bounds.size.height);
    NSMutableDictionary *toSave = [NSMutableDictionary dictionary];

    for (NSString *key in self.nodePoints) {
        CGPoint pt = [self.nodePoints[key] CGPointValue];
        toSave[key] = @{
            @"nx": @(pt.x / MAX(w, 1.0)),
            @"ny": @(pt.y / MAX(h, 1.0))
        };
    }
    [[NSUserDefaults standardUserDefaults] setObject:toSave forKey:@"Flydigi_InGame_SavedNodes_v2"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (UIWindow *)gameKeyWindow {
    for (UIWindow *win in [UIApplication sharedApplication].windows) {
        if (win.isKeyWindow) return win;
    }
    return [UIApplication sharedApplication].windows.firstObject;
}

- (UIView *)findGameTouchTargetViewInWindow:(UIWindow *)window atPoint:(CGPoint)point {
    // Tạm ẩn các view overlay để hitTest chạm đúng vào UnityView của Play Together VNG
    BOOL panelWasHidden = self.connectionPanel.hidden;
    self.connectionPanel.hidden = YES;
    self.floatingToggleBtn.hidden = YES;
    for (FlydigiNodeView *nv in self.nodeViews.allValues) {
        nv.hidden = YES;
    }

    UIView *hitView = [window hitTest:point withEvent:nil];

    self.connectionPanel.hidden = panelWasHidden;
    self.floatingToggleBtn.hidden = NO;
    for (FlydigiNodeView *nv in self.nodeViews.allValues) {
        nv.hidden = !self.areNodesVisible;
    }

    return hitView ?: window.rootViewController.view ?: window;
}

- (void)setupOverlay {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *keyWin = [self gameKeyWindow];
        if (!keyWin) return;

        if (@available(iOS 14.5, *)) {
            GCController.shouldMonitorBackgroundEvents = YES;
        }

        [self buildVisualMappingNodesInWindow:keyWin];

        // Nút nổi 🎮 Flydigi trên màn hình game (có thể kéo đi chỗ khác)
        self.floatingToggleBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        self.floatingToggleBtn.frame = CGRectMake(20, 32, 128, 34);
        self.floatingToggleBtn.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.78];
        self.floatingToggleBtn.layer.cornerRadius = 17.0;
        self.floatingToggleBtn.layer.borderColor = [UIColor orangeColor].CGColor;
        self.floatingToggleBtn.layer.borderWidth = 1.5;
        [self.floatingToggleBtn setTitle:@"🎮 Flydigi Menu" forState:UIControlStateNormal];
        self.floatingToggleBtn.titleLabel.font = [UIFont boldSystemFontOfSize:11];
        [self.floatingToggleBtn addTarget:self action:@selector(toggleConnectionPanel) forControlEvents:UIControlEventTouchUpInside];
        [keyWin addSubview:self.floatingToggleBtn];

        [self buildConnectionPanelInWindow:keyWin];

        // Khởi chạy vòng lặp 60FPS xử lý Joystick Trái (Di chuyển) & Phải (Camera)
        self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(step60FPSJoystickFrame)];
        [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];

        self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:dispatch_get_main_queue()];
        [self registerHardwareNotifications];
    });
}

- (void)buildVisualMappingNodesInWindow:(UIWindow *)keyWin {
    NSDictionary<NSString *, NSString *> *labels = @{
        @"L_STICK": @"L-Stick\nDi chuyển",
        @"R_STICK": @"R-Stick\nCamera",
        @"BTN_A": @"A\nNhảy",
        @"BTN_B": @"B\nCâu cá",
        @"BTN_X": @"X\nDùng đồ",
        @"BTN_Y": @"Y\nBalo",
        @"BTN_LT": @"LT\nGọi Xe",
        @"BTN_RT": @"RT\nGiật cá",
        @"BTN_LB": @"LB\nBản đồ",
        @"BTN_RB": @"RB\nĐổi đồ",
        @"DPAD_UP": @"↑\nĐ.Thoại",
        @"DPAD_LEFT": @"←\nEmote",
        @"DPAD_RIGHT": @"→\nChat",
        @"DPAD_DOWN": @"↓\nNgồi"
    };

    __weak typeof(self) weakSelf = self;
    for (NSString *nodeID in labels) {
        CGPoint pt = [self.nodePoints[nodeID] CGPointValue];
        BOOL isJoy = [nodeID isEqualToString:@"L_STICK"] || [nodeID isEqualToString:@"R_STICK"];
        CGFloat rad = [nodeID isEqualToString:@"L_STICK"] ? self.leftStickRadius : (isJoy ? 60.0 : 25.0);

        FlydigiNodeView *nv = [[FlydigiNodeView alloc] initWithNodeID:nodeID
                                                                title:labels[nodeID]
                                                               center:pt
                                                               radius:rad
                                                           isJoystick:isJoy];
        nv.alpha = 0.45;
        nv.onPositionChanged = ^(NSString *changedID, CGPoint newCenter) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            strongSelf.nodePoints[changedID] = [NSValue valueWithCGPoint:newCenter];
            [strongSelf saveCurrentCoordinatesToDisk];
        };
        [keyWin addSubview:nv];
        self.nodeViews[nodeID] = nv;
    }
}

- (void)buildConnectionPanelInWindow:(UIWindow *)keyWin {
    self.connectionPanel = [[UIView alloc] initWithFrame:CGRectMake(20, 74, 360, 290)];
    self.connectionPanel.backgroundColor = [[UIColor colorWithRed:0.05 green:0.08 blue:0.14 alpha:0.95] colorWithAlphaComponent:0.95];
    self.connectionPanel.layer.cornerRadius = 14.0;
    self.connectionPanel.layer.borderColor = [UIColor cyanColor].CGColor;
    self.connectionPanel.layer.borderWidth = 1.2;
    self.connectionPanel.hidden = YES;

    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 8, 336, 34)];
    self.statusLabel.numberOfLines = 2;
    self.statusLabel.font = [UIFont boldSystemFontOfSize:11];
    self.statusLabel.textColor = [UIColor greenColor];
    self.statusLabel.text = @"Trạng thái: Sẵn sàng nhận tay cầm (Bluetooth / BLE / Cáp USB / 2.4G)";
    [self.connectionPanel addSubview:self.statusLabel];

    UIButton *scanBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    scanBtn.frame = CGRectMake(12, 46, 162, 30);
    scanBtn.backgroundColor = [UIColor systemBlueColor];
    scanBtn.layer.cornerRadius = 8.0;
    [scanBtn setTitle:@"🔵 Quét Bluetooth BLE" forState:UIControlStateNormal];
    [scanBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    scanBtn.titleLabel.font = [UIFont boldSystemFontOfSize:11];
    [scanBtn addTarget:self action:@selector(startDirectBLEScan) forControlEvents:UIControlEventTouchUpInside];
    [self.connectionPanel addSubview:scanBtn];

    UIButton *usbBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    usbBtn.frame = CGRectMake(184, 46, 164, 30);
    usbBtn.backgroundColor = [UIColor systemOrangeColor];
    usbBtn.layer.cornerRadius = 8.0;
    [usbBtn setTitle:@"🔌 Nhận Cáp USB / 2.4G" forState:UIControlStateNormal];
    [usbBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    usbBtn.titleLabel.font = [UIFont boldSystemFontOfSize:11];
    [usbBtn addTarget:self action:@selector(rescanWiredAndSystemControllers) forControlEvents:UIControlEventTouchUpInside];
    [self.connectionPanel addSubview:usbBtn];

    // Hàng nút chỉnh vị trí nút đè trực tiếp trên màn hình Play Together VNG
    self.editLayoutBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.editLayoutBtn.frame = CGRectMake(12, 82, 185, 30);
    self.editLayoutBtn.backgroundColor = [UIColor systemGreenColor];
    self.editLayoutBtn.layer.cornerRadius = 8.0;
    [self.editLayoutBtn setTitle:@"🔓 Mở khóa Kéo chỉnh Nút" forState:UIControlStateNormal];
    [self.editLayoutBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    self.editLayoutBtn.titleLabel.font = [UIFont boldSystemFontOfSize:11];
    [self.editLayoutBtn addTarget:self action:@selector(toggleEditLayoutMode) forControlEvents:UIControlEventTouchUpInside];
    [self.connectionPanel addSubview:self.editLayoutBtn];

    self.showHideNodesBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.showHideNodesBtn.frame = CGRectMake(205, 82, 143, 30);
    self.showHideNodesBtn.backgroundColor = [UIColor darkGrayColor];
    self.showHideNodesBtn.layer.cornerRadius = 8.0;
    [self.showHideNodesBtn setTitle:@"👁 Ẩn/Hiện vòng nút" forState:UIControlStateNormal];
    [self.showHideNodesBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.showHideNodesBtn.titleLabel.font = [UIFont boldSystemFontOfSize:11];
    [self.showHideNodesBtn addTarget:self action:@selector(toggleNodesVisibility) forControlEvents:UIControlEventTouchUpInside];
    [self.connectionPanel addSubview:self.showHideNodesBtn];

    self.bleTableView = [[UITableView alloc] initWithFrame:CGRectMake(12, 120, 336, 158) style:UITableViewStylePlain];
    self.bleTableView.backgroundColor = [UIColor clearColor];
    self.bleTableView.dataSource = self;
    self.bleTableView.delegate = self;
    self.bleTableView.rowHeight = 34.0;
    [self.connectionPanel addSubview:self.bleTableView];

    [keyWin addSubview:self.connectionPanel];
}

- (void)toggleEditLayoutMode {
    self.isEditingNodes = !self.isEditingNodes;
    if (self.isEditingNodes) {
        self.areNodesVisible = YES;
        [self.editLayoutBtn setTitle:@"🔒 Khóa & Lưu vị trí Nút" forState:UIControlStateNormal];
        self.editLayoutBtn.backgroundColor = [UIColor systemYellowColor];
        self.statusLabel.text = @"Hãy dùng ngón tay kéo các nút A, B, L-Stick đè đúng lên nút của Play Together VNG!";
    } else {
        [self.editLayoutBtn setTitle:@"🔓 Mở khóa Kéo chỉnh Nút" forState:UIControlStateNormal];
        self.editLayoutBtn.backgroundColor = [UIColor systemGreenColor];
        [self saveCurrentCoordinatesToDisk];
        self.statusLabel.text = @"Đã khóa & lưu vị trí nút! Giờ bạn có thể bấm trên tay cầm để điều khiển.";
    }

    for (FlydigiNodeView *nv in self.nodeViews.allValues) {
        nv.hidden = !self.areNodesVisible;
        nv.userInteractionEnabled = self.isEditingNodes;
        nv.alpha = self.isEditingNodes ? 0.90 : 0.42;
    }
}

- (void)toggleNodesVisibility {
    self.areNodesVisible = !self.areNodesVisible;
    for (FlydigiNodeView *nv in self.nodeViews.allValues) {
        nv.hidden = !self.areNodesVisible;
    }
}

- (void)toggleConnectionPanel {
    self.connectionPanel.hidden = !self.connectionPanel.hidden;
    if (!self.connectionPanel.hidden) {
        [self importClipboardConfigIfAvailable];
        [self rescanWiredAndSystemControllers];
        [self startDirectBLEScan];
    }
}

// MARK: - 4. Động Cơ Bơm Sự Kiện Cảm Ứng Đa Điểm 60FPS Vào UnityView

- (void)sendTouchChannel:(NSString *)channel point:(CGPoint)point phase:(UITouchPhase)phase {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = [self gameKeyWindow];
        if (!window) return;

        FlydigiSynthesizedTouch *touch = self.activeTouches[channel];

        if (phase == UITouchPhaseBegan) {
            UIView *targetView = [self findGameTouchTargetViewInWindow:window atPoint:point];
            touch = [[FlydigiSynthesizedTouch alloc] initWithChannel:channel
                                                              window:window
                                                                view:targetView
                                                               point:point];
            self.activeTouches[channel] = touch;

            NSSet *touchSet = [NSSet setWithObject:touch];
            UIEvent *event = [self sharedTouchEvent];
            [targetView touchesBegan:touchSet withEvent:event];

            if ([targetView isKindOfClass:[UIControl class]]) {
                [(UIControl *)targetView sendActionsForControlEvents:UIControlEventTouchDown];
            }
        } else if (phase == UITouchPhaseMoved) {
            if (!touch) {
                // Nếu chưa có Began thì khởi tạo Began tại tâm trước
                [self sendTouchChannel:channel point:point phase:UITouchPhaseBegan];
                return;
            }
            [touch updateLocation:point phase:UITouchPhaseMoved];
            NSSet *touchSet = [NSSet setWithObject:touch];
            UIEvent *event = [self sharedTouchEvent];
            [touch.view touchesMoved:touchSet withEvent:event];
        } else if (phase == UITouchPhaseEnded || phase == UITouchPhaseCancelled) {
            if (!touch) return;
            [touch updateLocation:point phase:UITouchPhaseEnded];
            NSSet *touchSet = [NSSet setWithObject:touch];
            UIEvent *event = [self sharedTouchEvent];
            [touch.view touchesEnded:touchSet withEvent:event];

            if ([touch.view isKindOfClass:[UIControl class]]) {
                [(UIControl *)touch.view sendActionsForControlEvents:UIControlEventTouchUpInside];
            }
            [self.activeTouches removeObjectForKey:channel];
        }
    });
}

- (UIEvent *)sharedTouchEvent {
    UIApplication *app = [UIApplication sharedApplication];
    if ([app respondsToSelector:@selector(_touchesEvent)]) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        UIEvent *ev = [app performSelector:@selector(_touchesEvent)];
        #pragma clang diagnostic pop
        if (ev) return ev;
    }
    return nil;
}

// Vòng lặp 60FPS xử lý mượt mà Cần Gạt Trái (Di chuyển 360 độ) và Cần Gạt Phải (Vuốt xoay Camera)
- (void)step60FPSJoystickFrame {
    // 1. Xử lý Cần Gạt Trái (L_STICK) -> Di chuyển nhân vật trong Play Together VNG
    CGPoint leftCenter = [self.nodePoints[@"L_STICK"] CGPointValue];
    CGFloat lx = self.currentLeftStick.dx;
    CGFloat ly = self.currentLeftStick.dy; // dương là kéo xuống, âm là đẩy lên
    CGFloat magL = sqrt(lx * lx + ly * ly);

    FlydigiSynthesizedTouch *leftTouch = self.activeTouches[@"L_STICK"];
    FlydigiNodeView *leftNode = self.nodeViews[@"L_STICK"];

    if (magL > self.leftDeadzone) {
        CGPoint targetPt = CGPointMake(
            leftCenter.x + lx * self.leftStickRadius,
            leftCenter.y + ly * self.leftStickRadius
        );
        if (!leftTouch) {
            // Bước 1: Chạm đúng tâm cụm Joystick của Play Together để game bắt đầu nhận cần gạt
            [self sendTouchChannel:@"L_STICK" point:leftCenter phase:UITouchPhaseBegan];
        } else {
            // Bước 2: Kéo ngón tay ảo từ tâm ra góc nghiêng tương ứng
            [self sendTouchChannel:@"L_STICK" point:targetPt phase:UITouchPhaseMoved];
        }
        [leftNode setHighlightedState:YES stickVector:CGPointMake(lx, ly)];
    } else {
        if (leftTouch) {
            // Bước 3: Nhả ngón tay ảo về tâm khi buông cần gạt
            [self sendTouchChannel:@"L_STICK" point:leftCenter phase:UITouchPhaseEnded];
        }
        [leftNode setHighlightedState:NO stickVector:CGPointZero];
    }

    // 2. Xử lý Cần Gạt Phải (R_STICK) -> Vuốt xoay góc nhìn Camera liên tục
    CGPoint rightCenter = [self.nodePoints[@"R_STICK"] CGPointValue];
    CGFloat rx = self.currentRightStick.dx;
    CGFloat ry = self.currentRightStick.dy;
    CGFloat magR = sqrt(rx * rx + ry * ry);

    FlydigiSynthesizedTouch *rightTouch = self.activeTouches[@"R_STICK"];
    FlydigiNodeView *rightNode = self.nodeViews[@"R_STICK"];

    if (magR > 0.15) {
        if (!rightTouch) {
            self.currentRightSwipePos = rightCenter;
            [self sendTouchChannel:@"R_STICK" point:self.currentRightSwipePos phase:UITouchPhaseBegan];
        } else {
            CGFloat step = 7.5 * self.rightSensitivity;
            self.currentRightSwipePos = CGPointMake(
                self.currentRightSwipePos.x + rx * step,
                self.currentRightSwipePos.y + ry * step
            );
            // Nếu vuốt quá xa tâm thì nhả và bắt đầu chu kỳ vuốt mới để xoay 360 độ không giới hạn
            if (hypot(self.currentRightSwipePos.x - rightCenter.x, self.currentRightSwipePos.y - rightCenter.y) > 140.0) {
                [self sendTouchChannel:@"R_STICK" point:self.currentRightSwipePos phase:UITouchPhaseEnded];
            } else {
                [self sendTouchChannel:@"R_STICK" point:self.currentRightSwipePos phase:UITouchPhaseMoved];
            }
        }
        [rightNode setHighlightedState:YES stickVector:CGPointMake(rx, ry)];
    } else {
        if (rightTouch) {
            [self sendTouchChannel:@"R_STICK" point:self.currentRightSwipePos phase:UITouchPhaseEnded];
        }
        [rightNode setHighlightedState:NO stickVector:CGPointZero];
    }
}

// Xử lý nhấn/nhả các nút độc lập (A, B, X, Y, LT, RT, LB, RB, M1, M2, D-Pad)
- (void)triggerButtonChannel:(NSString *)channelID pressed:(BOOL)pressed {
    NSValue *val = self.nodePoints[channelID];
    if (!val) return;
    CGPoint pt = [val CGPointValue];

    FlydigiNodeView *nv = self.nodeViews[channelID];
    [nv setHighlightedState:pressed stickVector:CGPointZero];

    if (pressed) {
        [self sendTouchChannel:channelID point:pt phase:UITouchPhaseBegan];
    } else {
        [self sendTouchChannel:channelID point:pt phase:UITouchPhaseEnded];
    }
}

// MARK: - 5. Kết nối Cắm dây USB-C / OTG, 2.4GHz Dongle & Bluetooth MFi/XInput (GCController)

- (void)rescanWiredAndSystemControllers {
    [GCController startWirelessControllerDiscoveryWithCompletionHandler:^{}];
    NSArray<GCController *> *ctrls = [GCController controllers];
    if (ctrls.count > 0) {
        GCController *first = ctrls.firstObject;
        NSString *name = first.vendorName ?: @"Flydigi Controller";
        self.statusLabel.text = [NSString stringWithFormat:@"Đã kết nối: %@ (Sẵn sàng điều khiển)", name];
        self.floatingToggleBtn.layer.borderColor = [UIColor greenColor].CGColor;
        [self.floatingToggleBtn setTitle:@"🎮 Đã kết nối" forState:UIControlStateNormal];
        [self bindController:first];
    } else if ([GCKeyboard coalescedKeyboard] != nil) {
        self.statusLabel.text = @"Đã kết nối qua Đầu thu 2.4GHz / Cáp USB HID";
        self.floatingToggleBtn.layer.borderColor = [UIColor greenColor].CGColor;
        [self.floatingToggleBtn setTitle:@"🎮 USB / 2.4G" forState:UIControlStateNormal];
        [self bindUSBKeyboard];
    }
}

- (void)registerHardwareNotifications {
    [[NSNotificationCenter defaultCenter] addObserverForName:GCControllerDidConnectNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        [self rescanWiredAndSystemControllers];
    }];

    [[NSNotificationCenter defaultCenter] addObserverForName:GCKeyboardDidConnectNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        [self rescanWiredAndSystemControllers];
    }];

    [self rescanWiredAndSystemControllers];
}

- (void)bindController:(GCController *)controller {
    GCExtendedGamepad *pad = controller.extendedGamepad;
    if (!pad) return;
    __weak typeof(self) weakSelf = self;

    // Gạt cần trái -> Cập nhật vector cho vòng lặp 60FPS
    pad.leftThumbstick.valueChangedHandler = ^(GCControllerDirectionPad * _Nonnull dpad, float xValue, float yValue) {
        weakSelf.currentLeftStick = CGVectorMake(xValue, -yValue);
    };

    // Gạt cần phải -> Cập nhật vector xoay Camera 60FPS
    pad.rightThumbstick.valueChangedHandler = ^(GCControllerDirectionPad * _Nonnull dpad, float xValue, float yValue) {
        weakSelf.currentRightStick = CGVectorMake(xValue, -yValue);
    };

    // Các phím hành động độc lập (Ấn giữ & Nhả)
    pad.buttonA.valueChangedHandler = ^(GCControllerButtonInput * _Nonnull button, float value, BOOL pressed) {
        [weakSelf triggerButtonChannel:@"BTN_A" pressed:pressed];
    };
    pad.buttonB.valueChangedHandler = ^(GCControllerButtonInput * _Nonnull button, float value, BOOL pressed) {
        [weakSelf triggerButtonChannel:@"BTN_B" pressed:pressed];
    };
    pad.buttonX.valueChangedHandler = ^(GCControllerButtonInput * _Nonnull button, float value, BOOL pressed) {
        [weakSelf triggerButtonChannel:@"BTN_X" pressed:pressed];
    };
    pad.buttonY.valueChangedHandler = ^(GCControllerButtonInput * _Nonnull button, float value, BOOL pressed) {
        [weakSelf triggerButtonChannel:@"BTN_Y" pressed:pressed];
    };
    pad.leftTrigger.pressedChangedHandler = ^(GCControllerButtonInput * _Nonnull button, float value, BOOL pressed) {
        [weakSelf triggerButtonChannel:@"BTN_LT" pressed:pressed];
    };
    pad.rightTrigger.pressedChangedHandler = ^(GCControllerButtonInput * _Nonnull button, float value, BOOL pressed) {
        [weakSelf triggerButtonChannel:@"BTN_RT" pressed:pressed];
    };
    pad.leftShoulder.pressedChangedHandler = ^(GCControllerButtonInput * _Nonnull button, float value, BOOL pressed) {
        [weakSelf triggerButtonChannel:@"BTN_LB" pressed:pressed];
    };
    pad.rightShoulder.pressedChangedHandler = ^(GCControllerButtonInput * _Nonnull button, float value, BOOL pressed) {
        [weakSelf triggerButtonChannel:@"BTN_RB" pressed:pressed];
    };
    pad.dpad.up.pressedChangedHandler = ^(GCControllerButtonInput * _Nonnull button, float value, BOOL pressed) {
        [weakSelf triggerButtonChannel:@"DPAD_UP" pressed:pressed];
    };
    pad.dpad.left.pressedChangedHandler = ^(GCControllerButtonInput * _Nonnull button, float value, BOOL pressed) {
        [weakSelf triggerButtonChannel:@"DPAD_LEFT" pressed:pressed];
    };
    pad.dpad.right.pressedChangedHandler = ^(GCControllerButtonInput * _Nonnull button, float value, BOOL pressed) {
        [weakSelf triggerButtonChannel:@"DPAD_RIGHT" pressed:pressed];
    };
    pad.dpad.down.pressedChangedHandler = ^(GCControllerButtonInput * _Nonnull button, float value, BOOL pressed) {
        [weakSelf triggerButtonChannel:@"DPAD_DOWN" pressed:pressed];
    };
}

- (void)bindUSBKeyboard {
    GCKeyboardInput *kb = [GCKeyboard coalescedKeyboard].keyboardInput;
    if (!kb) return;
    __weak typeof(self) weakSelf = self;
    kb.keyChangedHandler = ^(GCKeyboardInput * _Nonnull keyboard, GCControllerButtonInput * _Nonnull key, GCKeyCode keyCode, BOOL pressed) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        CGVector vec = strongSelf.currentLeftStick;
        if (keyCode == GCKeyCodeKeyW) vec.dy = pressed ? -1.0 : 0.0;
        else if (keyCode == GCKeyCodeKeyS) vec.dy = pressed ? 1.0 : 0.0;
        else if (keyCode == GCKeyCodeKeyA) vec.dx = pressed ? -1.0 : 0.0;
        else if (keyCode == GCKeyCodeKeyD) vec.dx = pressed ? 1.0 : 0.0;
        strongSelf.currentLeftStick = vec;

        if (keyCode == GCKeyCodeSpacebar) [strongSelf triggerButtonChannel:@"BTN_A" pressed:pressed];
        else if (keyCode == GCKeyCodeKeyE || keyCode == GCKeyCodeReturnOrEnter) [strongSelf triggerButtonChannel:@"BTN_B" pressed:pressed];
        else if (keyCode == GCKeyCodeKeyQ) [strongSelf triggerButtonChannel:@"BTN_X" pressed:pressed];
        else if (keyCode == GCKeyCodeTab) [strongSelf triggerButtonChannel:@"BTN_Y" pressed:pressed];
    };
}

// MARK: - 6. Kết nối Bluetooth BLE Trực tiếp (CoreBluetooth) & Giải mã gói HID Flydigi

- (void)startDirectBLEScan {
    if (self.centralManager.state != CBManagerStatePoweredOn) {
        self.statusLabel.text = @"Hãy bật Bluetooth trên máy để quét BLE.";
        return;
    }
    [self.discoveredPeripherals removeAllObjects];
    [self.bleTableView reloadData];
    [self.centralManager scanForPeripheralsWithServices:nil options:@{CBCentralManagerScanOptionAllowDuplicatesKey: @NO}];
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    if (central.state == CBManagerStatePoweredOn) {
        [self startDirectBLEScan];
    }
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI {
    NSString *name = peripheral.name;
    if (!name || name.length == 0) return;
    if (![self.discoveredPeripherals containsObject:peripheral]) {
        [self.discoveredPeripherals addObject:peripheral];
        [self.bleTableView reloadData];
    }
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    [self.centralManager stopScan];
    self.connectedBLEPeripheral = peripheral;
    peripheral.delegate = self;
    self.statusLabel.text = [NSString stringWithFormat:@"Đã kết nối BLE: %@", peripheral.name];
    self.floatingToggleBtn.layer.borderColor = [UIColor greenColor].CGColor;
    [self.floatingToggleBtn setTitle:@"🎮 BLE Online" forState:UIControlStateNormal];
    [peripheral discoverServices:nil];
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    for (CBService *svc in peripheral.services) {
        [peripheral discoverCharacteristics:nil forService:svc];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    for (CBCharacteristic *ch in service.characteristics) {
        if ((ch.properties & CBCharacteristicPropertyNotify) || (ch.properties & CBCharacteristicPropertyIndicate)) {
            [peripheral setNotifyValue:YES forCharacteristic:ch];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    NSData *data = characteristic.value;
    if (!data || data.length < 6) return;
    const uint8_t *bytes = (const uint8_t *)data.bytes;
    NSUInteger len = data.length;
    NSUInteger offset = ((bytes[0] == 0x01 || bytes[0] == 0xA1 || bytes[0] == 0xFE) && len >= 8) ? 1 : 0;

    float lx = ((float)bytes[offset] - 128.0f) / 127.0f;
    float ly = ((float)bytes[offset + 1] - 128.0f) / 127.0f;
    float rx = ((float)bytes[offset + 2] - 128.0f) / 127.0f;
    float ry = ((float)bytes[offset + 3] - 128.0f) / 127.0f;

    self.currentLeftStick = CGVectorMake(lx, ly);
    self.currentRightStick = CGVectorMake(rx, ry);

    uint8_t btn1 = bytes[offset + 4];
    uint8_t btn2 = (len > offset + 5) ? bytes[offset + 5] : 0;

    NSDictionary<NSString *, NSNumber *> *buttonStates = @{
        @"BTN_A":  @((btn1 & 0x01) != 0),
        @"BTN_B":  @((btn1 & 0x02) != 0),
        @"BTN_X":  @(((btn1 & 0x04) != 0) || ((btn1 & 0x08) != 0)),
        @"BTN_Y":  @((btn1 & 0x10) != 0),
        @"BTN_LB": @((btn1 & 0x40) != 0),
        @"BTN_RB": @((btn1 & 0x80) != 0),
        @"BTN_LT": @((btn2 & 0x01) != 0),
        @"BTN_RT": @((btn2 & 0x02) != 0)
    };

    // Chỉ bắn sự kiện Began/Ended khi trạng thái nút thực sự thay đổi (Edge Detection)
    for (NSString *chID in buttonStates) {
        BOOL isNowPressed = [buttonStates[chID] boolValue];
        BOOL wasPressed = [self.blePressedButtons containsObject:chID];
        if (isNowPressed && !wasPressed) {
            [self.blePressedButtons addObject:chID];
            [self triggerButtonChannel:chID pressed:YES];
        } else if (!isNowPressed && wasPressed) {
            [self.blePressedButtons removeObject:chID];
            [self triggerButtonChannel:chID pressed:NO];
        }
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.discoveredPeripherals.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"BLECell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellId];
        cell.backgroundColor = [UIColor clearColor];
        cell.textLabel.textColor = [UIColor whiteColor];
        cell.textLabel.font = [UIFont boldSystemFontOfSize:12];
    }
    CBPeripheral *p = self.discoveredPeripherals[indexPath.row];
    cell.textLabel.text = [NSString stringWithFormat:@"🔗 %@ (Chạm để kết nối)", p.name ?: @"Thiết bị BLE"];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    CBPeripheral *p = self.discoveredPeripherals[indexPath.row];
    self.statusLabel.text = [NSString stringWithFormat:@"Đang kết nối tới %@...", p.name];
    [self.centralManager connectPeripheral:p options:nil];
}

- (void)importClipboardConfigIfAvailable {
    NSString *clip = [UIPasteboard generalPasteboard].string;
    if (![clip hasPrefix:@"FLYDIGI_PT_CFG:"]) return;
    NSString *jsonStr = [clip substringFromIndex:[@"FLYDIGI_PT_CFG:" length]];
    NSData *data = [jsonStr dataUsingEncoding:NSUTF8StringEncoding];
    if (!data) return;

    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![dict isKindOfClass:[NSDictionary class]]) return;

    CGRect bounds = [UIScreen mainScreen].bounds;
    CGFloat w = MAX(bounds.size.width, bounds.size.height);
    CGFloat h = MIN(bounds.size.width, bounds.size.height);

    if (dict[@"leftInnerDeadzone"]) self.leftDeadzone = [dict[@"leftInnerDeadzone"] doubleValue];
    if (dict[@"leftDragRadius"]) self.leftStickRadius = [dict[@"leftDragRadius"] doubleValue];
    if (dict[@"rightSensitivityX"]) self.rightSensitivity = [dict[@"rightSensitivityX"] doubleValue];
    NSArray *mappings = dict[@"mappings"];
    for (NSDictionary *m in mappings) {
        NSString *itemId = m[@"id"];
        CGFloat nx = [m[@"normalizedX"] doubleValue];
        CGFloat ny = [m[@"normalizedY"] doubleValue];
        CGPoint pt = CGPointMake(w * nx, h * ny);
        if (itemId) {
            self.nodePoints[itemId] = [NSValue valueWithCGPoint:pt];
            FlydigiNodeView *nv = self.nodeViews[itemId];
            if (nv) nv.center = pt;
        }
    }
    [self saveCurrentCoordinatesToDisk];
}

@end

__attribute__((constructor))
static void FlydigiPTInjectInit(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[FlydigiOverlayController sharedInstance] setupOverlay];
    });
}
