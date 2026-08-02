#if DEBUG

#import "AdaptiveTriggerDiagnosticsViewController.h"

#include <string.h>

@interface MLAdaptiveTriggerDiagnosticScheduler : NSObject <MLAdaptiveTriggerDiagnosticScheduling>
@end


API_AVAILABLE(ios(15.4), tvos(15.4))
@interface MLAdaptiveTriggerDiagnosticEndpointResolver : NSObject <MLAdaptiveTriggerDiagnosticEndpointResolving>
@end


@interface MLAdaptiveTriggerFixedEndpointResolver : NSObject <MLAdaptiveTriggerDiagnosticEndpointResolving>

- (instancetype)initWithEndpoint:(id<MLAdaptiveTriggerEndpoint>)endpoint;

@end


@implementation MLAdaptiveTriggerDiagnosticScheduler

- (id)scheduleAfter:(NSTimeInterval)delay block:(dispatch_block_t)block
{
    dispatch_block_t scheduledBlock = dispatch_block_create(0, block);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), scheduledBlock);
    return scheduledBlock;
}

- (void)cancelScheduledBlock:(id)scheduledBlock
{
    dispatch_block_cancel((dispatch_block_t)scheduledBlock);
}

@end


API_AVAILABLE(ios(15.4), tvos(15.4))
@implementation MLAdaptiveTriggerDiagnosticEndpointResolver

- (id<MLAdaptiveTriggerEndpoint>)connectedDualSenseEndpoint
{
    NSAssert([NSThread isMainThread], @"GameController diagnostics must remain on the main queue");
    for (GCController *controller in GCController.controllers) {
        GCExtendedGamepad *extendedGamepad = controller.extendedGamepad;
        if ([extendedGamepad isKindOfClass:[GCDualSenseGamepad class]]) {
            return [[MLAppleAdaptiveTriggerEndpoint alloc]
                    initWithGamepad:(GCDualSenseGamepad *)extendedGamepad];
        }
    }
    return nil;
}

@end


@implementation MLAdaptiveTriggerFixedEndpointResolver {
    id<MLAdaptiveTriggerEndpoint> _endpoint;
}

- (instancetype)initWithEndpoint:(id<MLAdaptiveTriggerEndpoint>)endpoint
{
    self = [super init];
    if (self) {
        _endpoint = endpoint;
    }
    return self;
}

- (id<MLAdaptiveTriggerEndpoint>)connectedDualSenseEndpoint
{
    return _endpoint;
}

@end

API_AVAILABLE(ios(15.4), tvos(15.4))
@implementation AdaptiveTriggerDiagnosticsViewController {
    id<MLAdaptiveTriggerEndpoint> _endpoint;
    id<MLAdaptiveTriggerDiagnosticEndpointResolving> _endpointResolver;
    id<MLAdaptiveTriggerDiagnosticScheduling> _scheduler;
    NSMutableArray<id> *_scheduledBlocks;
    UILabel *_statusLabel;
    UIButton *_runButton;
}

- (instancetype)init
{
    return [self
        initWithEndpointResolver:[[MLAdaptiveTriggerDiagnosticEndpointResolver alloc] init]
        scheduler:[[MLAdaptiveTriggerDiagnosticScheduler alloc] init]];
}

- (instancetype)initWithEndpoint:(id<MLAdaptiveTriggerEndpoint>)endpoint
                        scheduler:(id<MLAdaptiveTriggerDiagnosticScheduling>)scheduler
{
    return [self
        initWithEndpointResolver:[[MLAdaptiveTriggerFixedEndpointResolver alloc]
                                  initWithEndpoint:endpoint]
        scheduler:scheduler];
}

- (instancetype)initWithEndpointResolver:(id<MLAdaptiveTriggerDiagnosticEndpointResolving>)resolver
                                scheduler:(id<MLAdaptiveTriggerDiagnosticScheduling>)scheduler
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _endpointResolver = resolver;
        _scheduler = scheduler;
        _scheduledBlocks = [NSMutableArray array];
    }
    return self;
}

- (void)updateReadinessUI
{
    if (_runButton == nil || _scheduledBlocks.count != 0) {
        return;
    }

    _runButton.enabled = _endpoint != nil;
    _statusLabel.text = _endpoint != nil
        ? @"Connected DualSense ready"
        : @"Connect a physical DualSense controller first";
}

- (void)cancelScheduledBlocksAndReleaseEndpoint
{
    for (id scheduledBlock in _scheduledBlocks) {
        [_scheduler cancelScheduledBlock:scheduledBlock];
    }
    [_scheduledBlocks removeAllObjects];
    [_endpoint setBothOff];
    _endpoint = nil;
}

- (void)refreshEndpointReadiness
{
    NSAssert([NSThread isMainThread], @"GameController diagnostics must remain on the main queue");
    id<MLAdaptiveTriggerEndpoint> endpoint = [_endpointResolver connectedDualSenseEndpoint];
    if (endpoint != _endpoint) {
        [self cancelScheduledBlocksAndReleaseEndpoint];
        _endpoint = endpoint;
    }
    [self updateReadinessUI];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = @"DualSense trigger diagnostics";
    self.view.backgroundColor = UIColor.blackColor;

    UILabel *instructionsLabel = [[UILabel alloc] init];
    instructionsLabel.translatesAutoresizingMaskIntoConstraints = NO;
    instructionsLabel.numberOfLines = 0;
    instructionsLabel.textAlignment = NSTextAlignmentCenter;
    instructionsLabel.text = @"Runs each local adaptive-trigger effect for two seconds. Closing this screen or backgrounding Moonlight releases both triggers.";
    [self.view addSubview:instructionsLabel];

    _statusLabel = [[UILabel alloc] init];
    _statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _statusLabel.numberOfLines = 0;
    _statusLabel.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:_statusLabel];

    _runButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _runButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_runButton setTitle:@"Run trigger sequence" forState:UIControlStateNormal];
    [_runButton addTarget:self action:@selector(startDiagnosticSequence)
         forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_runButton];

    [NSLayoutConstraint activateConstraints:@[
        [instructionsLabel.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:24.0],
        [instructionsLabel.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-24.0],
        [instructionsLabel.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:-60.0],
        [_statusLabel.leadingAnchor constraintEqualToAnchor:instructionsLabel.leadingAnchor],
        [_statusLabel.trailingAnchor constraintEqualToAnchor:instructionsLabel.trailingAnchor],
        [_statusLabel.topAnchor constraintEqualToAnchor:instructionsLabel.bottomAnchor constant:24.0],
        [_runButton.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_runButton.topAnchor constraintEqualToAnchor:_statusLabel.bottomAnchor constant:24.0],
    ]];

    [self refreshEndpointReadiness];

    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(applicationDidEnterBackground:)
               name:UIApplicationDidEnterBackgroundNotification
             object:nil];
    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(controllerDidConnect:)
               name:GCControllerDidConnectNotification
             object:nil];
    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(controllerDidDisconnect:)
               name:GCControllerDidDisconnectNotification
             object:nil];
}

static MLAdaptiveTriggerEffect uniformEffect(MLAdaptiveTriggerKind kind, float value)
{
    MLAdaptiveTriggerEffect effect;
    memset(&effect, 0, sizeof(effect));
    effect.kind = kind;
    for (NSUInteger index = 0; index < 10; index++) {
        effect.values[index] = value;
    }
    return effect;
}

static MLAdaptiveTriggerEffect weaponEffect(void)
{
    MLAdaptiveTriggerEffect effect;
    memset(&effect, 0, sizeof(effect));
    effect.kind = MLAdaptiveTriggerWeapon;
    effect.start_position = 0.25f;
    effect.end_position = 0.75f;
    effect.strength = 0.5f;
    return effect;
}

static MLAdaptiveTriggerEffect positionalFeedbackEffect(void)
{
    MLAdaptiveTriggerEffect effect;
    memset(&effect, 0, sizeof(effect));
    effect.kind = MLAdaptiveTriggerFeedback;
    const float values[10] = { 0.0f, 0.0f, 0.25f, 0.375f, 0.5f,
                               0.625f, 0.75f, 0.875f, 1.0f, 0.0f };
    memcpy(effect.values, values, sizeof(values));
    return effect;
}

static MLAdaptiveTriggerEffect positionalVibrationEffect(void)
{
    MLAdaptiveTriggerEffect effect;
    memset(&effect, 0, sizeof(effect));
    effect.kind = MLAdaptiveTriggerVibration;
    const float values[10] = { 0.0f, 0.0f, 0.25f, 0.5f, 0.75f,
                               1.0f, 0.75f, 0.5f, 0.25f, 0.0f };
    memcpy(effect.values, values, sizeof(values));
    effect.frequency = 0.5f;
    return effect;
}

static MLAdaptiveTriggerEffect slopeEffect(void)
{
    MLAdaptiveTriggerEffect effect;
    memset(&effect, 0, sizeof(effect));
    effect.kind = MLAdaptiveTriggerFeedback;
    for (NSUInteger index = 0; index < 10; index++) {
        effect.values[index] = (float)(index + 1) / 10.0f;
    }
    return effect;
}

- (void)applyEffectToBothSides:(MLAdaptiveTriggerEffect)effect
{
    [_endpoint applyEffect:effect side:MLAdaptiveTriggerSideLeft];
    [_endpoint applyEffect:effect side:MLAdaptiveTriggerSideRight];
}

- (void)scheduleAfter:(NSTimeInterval)delay block:(dispatch_block_t)block
{
    __weak typeof(self) weakSelf = self;
    id scheduledBlock = [_scheduler scheduleAfter:delay block:^{
        typeof(self) strongSelf = weakSelf;
        if (strongSelf == nil || strongSelf->_endpoint == nil) {
            return;
        }
        block();
    }];
    [_scheduledBlocks addObject:scheduledBlock];
}

- (void)startDiagnosticSequence
{
    NSAssert([NSThread isMainThread], @"Trigger diagnostics must remain on the main queue");
    [self refreshEndpointReadiness];
    if (_endpoint == nil) {
        return;
    }

    if (_scheduledBlocks.count != 0) {
        return;
    }

    _runButton.enabled = NO;
    _statusLabel.text = @"L2 Feedback 0.25";
    [_endpoint applyEffect:uniformEffect(MLAdaptiveTriggerFeedback, 0.25f)
                      side:MLAdaptiveTriggerSideLeft];

    __weak typeof(self) weakSelf = self;
    [self scheduleAfter:2.0 block:^{
        typeof(self) self = weakSelf;
        [self->_endpoint setOffForSide:MLAdaptiveTriggerSideLeft];
        self->_statusLabel.text = @"R2 Weapon 0.25..0.75";
        [self->_endpoint applyEffect:weaponEffect() side:MLAdaptiveTriggerSideRight];
    }];
    [self scheduleAfter:4.0 block:^{
        typeof(self) self = weakSelf;
        [self->_endpoint setOffForSide:MLAdaptiveTriggerSideRight];
        self->_statusLabel.text = @"Both Vibration 0.5 / 0.5";
        MLAdaptiveTriggerEffect vibration = uniformEffect(MLAdaptiveTriggerVibration, 0.5f);
        vibration.frequency = 0.5f;
        [self applyEffectToBothSides:vibration];
    }];
    [self scheduleAfter:6.0 block:^{
        typeof(self) self = weakSelf;
        [self->_endpoint setBothOff];
        self->_statusLabel.text = @"Positional Feedback";
        [self applyEffectToBothSides:positionalFeedbackEffect()];
    }];
    [self scheduleAfter:8.0 block:^{
        typeof(self) self = weakSelf;
        self->_statusLabel.text = @"Positional Vibration";
        [self applyEffectToBothSides:positionalVibrationEffect()];
    }];
    [self scheduleAfter:10.0 block:^{
        typeof(self) self = weakSelf;
        self->_statusLabel.text = @"Slope";
        [self applyEffectToBothSides:slopeEffect()];
    }];
    [self scheduleAfter:12.0 block:^{
        typeof(self) self = weakSelf;
        [self->_endpoint setBothOff];
        self->_statusLabel.text = @"Sequence complete — both triggers Off";
        [self->_scheduledBlocks removeAllObjects];
        self->_runButton.enabled = YES;
    }];
}

- (void)stopDiagnosticSequence
{
    NSAssert([NSThread isMainThread], @"Trigger diagnostics must remain on the main queue");
    [self cancelScheduledBlocksAndReleaseEndpoint];
    [self updateReadinessUI];
}

- (void)controllerDidConnect:(NSNotification *)notification
{
    (void)notification;
    [self refreshEndpointReadiness];
}

- (void)controllerDidDisconnect:(NSNotification *)notification
{
    (void)notification;
    [self refreshEndpointReadiness];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self stopDiagnosticSequence];
    [super viewWillDisappear:animated];
}

- (void)dismissDiagnostics
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)applicationDidEnterBackground:(NSNotification *)notification
{
    (void)notification;
    [self stopDiagnosticSequence];
    if (self.navigationController.viewControllers.firstObject != self) {
        [self.navigationController popViewControllerAnimated:NO];
    }
    else {
        [self dismissViewControllerAnimated:NO completion:nil];
    }
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self stopDiagnosticSequence];
}

@end
#endif
