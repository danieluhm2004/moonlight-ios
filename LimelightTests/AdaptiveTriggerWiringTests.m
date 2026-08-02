#import <XCTest/XCTest.h>
#import <objc/runtime.h>

#import "AdaptiveTriggerEndpoint.h"
#import "../Limelight/Input/ControllerSupport.h"
#import "../Limelight/Stream/Connection.h"
#include "../moonlight-common/moonlight-common-c/src/Limelight.h"

@interface NSObject (MLAdaptiveTriggerWiringUnderTest)
- (void)setAdaptiveTriggers:(uint16_t)controllerNumber
                  eventFlags:(uint8_t)eventFlags
                    typeLeft:(uint8_t)typeLeft
                   typeRight:(uint8_t)typeRight
                 leftPayload:(NSData *)leftPayload
                rightPayload:(NSData *)rightPayload;
- (void)requestTerminalAdaptiveTriggerStop;
- (void)pauseAdaptiveTriggerEffectsForBackground;
- (void)resumeAdaptiveTriggerEffectsAfterForeground;
- (void)resetAdaptiveTriggerEffectsForControllerNumber:(uint16_t)controllerNumber;
- (CFTimeInterval)adaptiveTriggerMonotonicTimestamp;
- (void)emitAdaptiveTriggerDiagnostic:(NSString *)message;
- (void)initializeControllerHaptics:(Controller *)controller;
- (void)cleanupControllerHaptics:(Controller *)controller;
- (void)cleanupControllerMotion:(Controller *)controller;
- (void)cleanupControllerBattery:(Controller *)controller;
- (void)registerControllerCallbacks:(GCController *)controller;
- (void)unregisterControllerCallbacks:(GCController *)controller;
- (void)reportControllerArrival:(Controller *)controller;
- (void)updateAutoOnScreenControlMode;
- (void)applicationWillResignActive:(NSNotification *)notification;
- (void)applicationDidBecomeActive:(NSNotification *)notification;
@end

@interface MLAdaptiveTriggerEndpointSpy : NSObject <MLAdaptiveTriggerEndpoint>
@property(nonatomic) NSMutableArray<NSNumber *> *appliedSides;
@property(nonatomic) NSMutableArray<NSNumber *> *appliedKinds;
@property(nonatomic) NSMutableArray<NSNumber *> *offSides;
@property(nonatomic) NSMutableArray<NSNumber *> *mainThreadObservations;
@property(nonatomic) NSUInteger bothOffCount;
@property(nonatomic, copy) void (^onApply)(void);
@property(nonatomic, copy) void (^onBothOff)(void);
@end

@implementation MLAdaptiveTriggerEndpointSpy

- (instancetype)init
{
    self = [super init];
    if (self) {
        _appliedSides = [NSMutableArray array];
        _appliedKinds = [NSMutableArray array];
        _offSides = [NSMutableArray array];
        _mainThreadObservations = [NSMutableArray array];
    }
    return self;
}

- (void)applyEffect:(MLAdaptiveTriggerEffect)effect side:(MLAdaptiveTriggerSide)side
{
    if (self.onApply != nil) {
        self.onApply();
    }
    [self.appliedSides addObject:@(side)];
    [self.appliedKinds addObject:@(effect.kind)];
    [self.mainThreadObservations addObject:@([NSThread isMainThread])];
}

- (void)setOffForSide:(MLAdaptiveTriggerSide)side
{
    [self.offSides addObject:@(side)];
    [self.mainThreadObservations addObject:@([NSThread isMainThread])];
}

- (void)setBothOff
{
    if (self.onBothOff != nil) {
        self.onBothOff();
    }
    self.bothOffCount++;
    [self.mainThreadObservations addObject:@([NSThread isMainThread])];
}

@end

@interface MLAdaptiveTriggerControllerSupportSpy : ControllerSupport <MLAdaptiveTriggerResolving>
@property(nonatomic) id<MLAdaptiveTriggerEndpoint> resolvedEndpoint;
@property(nonatomic) NSMutableArray<NSNumber *> *resolvedControllerNumbers;
@property(nonatomic) NSMutableArray<NSNumber *> *resolverMainThreadObservations;
@property(nonatomic) NSMutableDictionary<NSNumber *, id<MLAdaptiveTriggerEndpoint>> *endpointsByControllerNumber;
@property(nonatomic) NSMutableArray<NSString *> *diagnosticMessages;
@property(nonatomic) NSMutableArray<NSNumber *> *monotonicTimestamps;
@end

@implementation MLAdaptiveTriggerControllerSupportSpy

- (void)initializeSpyCollections
{
    _resolvedControllerNumbers = [NSMutableArray array];
    _resolverMainThreadObservations = [NSMutableArray array];
    _endpointsByControllerNumber = [NSMutableDictionary dictionary];
    _diagnosticMessages = [NSMutableArray array];
    _monotonicTimestamps = [NSMutableArray array];
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self initializeSpyCollections];
    }
    return self;
}

- (instancetype)initWithConfig:(StreamConfiguration *)streamConfig delegate:(id<ControllerSupportDelegate>)delegate
{
    self = [super initWithConfig:streamConfig delegate:delegate];
    if (self) {
        [self initializeSpyCollections];
    }
    return self;
}

- (id<MLAdaptiveTriggerEndpoint>)endpointForControllerNumber:(uint16_t)number
{
    [self.resolvedControllerNumbers addObject:@(number)];
    [self.resolverMainThreadObservations addObject:@([NSThread isMainThread])];
    return self.endpointsByControllerNumber[@(number)] ?: self.resolvedEndpoint;
}

- (CFTimeInterval)adaptiveTriggerMonotonicTimestamp
{
    @synchronized (self.monotonicTimestamps) {
        if (self.monotonicTimestamps.count == 0) {
            return 0;
        }
        CFTimeInterval timestamp = self.monotonicTimestamps.firstObject.doubleValue;
        [self.monotonicTimestamps removeObjectAtIndex:0];
        return timestamp;
    }
}

- (void)emitAdaptiveTriggerDiagnostic:(NSString *)message
{
    [self.diagnosticMessages addObject:message];
}

- (void)initializeControllerHaptics:(Controller *)controller {}
- (void)cleanupControllerHaptics:(Controller *)controller {}
- (void)cleanupControllerMotion:(Controller *)controller {}
- (void)cleanupControllerBattery:(Controller *)controller {}
- (void)registerControllerCallbacks:(GCController *)controller {}
- (void)unregisterControllerCallbacks:(GCController *)controller {}
- (void)reportControllerArrival:(Controller *)controller {}
- (void)updateAutoOnScreenControlMode {}

@end

@interface MLConnectionCallbacksSpy : NSObject <ConnectionCallbacks>
@property(nonatomic) NSData *leftPayload;
@property(nonatomic) NSData *rightPayload;
@property(nonatomic) uint16_t controllerNumber;
@property(nonatomic) uint8_t eventFlags;
@property(nonatomic) uint8_t typeLeft;
@property(nonatomic) uint8_t typeRight;
@end

@implementation MLConnectionCallbacksSpy

- (void)setAdaptiveTriggers:(uint16_t)controllerNumber
                  eventFlags:(uint8_t)eventFlags
                    typeLeft:(uint8_t)typeLeft
                   typeRight:(uint8_t)typeRight
                 leftPayload:(NSData *)leftPayload
                rightPayload:(NSData *)rightPayload
{
    self.controllerNumber = controllerNumber;
    self.eventFlags = eventFlags;
    self.typeLeft = typeLeft;
    self.typeRight = typeRight;
    self.leftPayload = leftPayload;
    self.rightPayload = rightPayload;
}

- (void)connectionStarted {}
- (void)connectionTerminated:(int)errorCode {}
- (void)stageStarting:(const char *)stageName {}
- (void)stageComplete:(const char *)stageName {}
- (void)stageFailed:(const char *)stageName withError:(int)errorCode portTestFlags:(int)portTestFlags {}
- (void)launchFailed:(NSString *)message {}
- (void)rumble:(unsigned short)controllerNumber lowFreqMotor:(unsigned short)lowFreqMotor highFreqMotor:(unsigned short)highFreqMotor {}
- (void)connectionStatusUpdate:(int)status {}
- (void)setHdrMode:(bool)enabled {}
- (void)rumbleTriggers:(uint16_t)controllerNumber leftTrigger:(uint16_t)leftTrigger rightTrigger:(uint16_t)rightTrigger {}
- (void)setMotionEventState:(uint16_t)controllerNumber motionType:(uint8_t)motionType reportRateHz:(uint16_t)reportRateHz {}
- (void)setControllerLed:(uint16_t)controllerNumber r:(uint8_t)r g:(uint8_t)g b:(uint8_t)b {}
- (void)videoContentShown {}

@end

@interface MLNonDualSenseControllerStub : NSObject
@property(nonatomic) id extendedGamepad;
@end

@implementation MLNonDualSenseControllerStub
@end

@interface MLGamepadProfileStub : NSObject
@property(nonatomic) id buttonOptions;
@property(nonatomic) id buttonHome;
@end

@implementation MLGamepadProfileStub
@end

@interface MLControllerDeviceStub : NSObject
@property(nonatomic) MLGamepadProfileStub *extendedGamepad;
@property(nonatomic) GCControllerPlayerIndex playerIndex;
@end

@implementation MLControllerDeviceStub
@end

@interface AdaptiveTriggerWiringTests : XCTestCase
@end

@implementation AdaptiveTriggerWiringTests

- (void)waitForMainQueueAfterInvokingSupport:(ControllerSupport *)support
                            controllerNumber:(uint16_t)controllerNumber
                                  eventFlags:(uint8_t)eventFlags
                                    typeLeft:(uint8_t)typeLeft
                                   typeRight:(uint8_t)typeRight
                                 leftPayload:(const uint8_t [10])leftPayload
                                rightPayload:(const uint8_t [10])rightPayload
                              beforeDraining:(void (^)(void))beforeDraining
{
    XCTAssertTrue([NSThread isMainThread]);
    XCTAssertTrue([support respondsToSelector:@selector(setAdaptiveTriggers:eventFlags:typeLeft:typeRight:leftPayload:rightPayload:)],
                  @"ControllerSupport must expose the streamed adaptive-trigger selector");
    if (![support respondsToSelector:@selector(setAdaptiveTriggers:eventFlags:typeLeft:typeRight:leftPayload:rightPayload:)]) {
        return;
    }

    NSData *leftData = [NSData dataWithBytes:leftPayload length:10];
    NSData *rightData = [NSData dataWithBytes:rightPayload length:10];
    dispatch_semaphore_t returned = dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        [(id)support setAdaptiveTriggers:controllerNumber
                              eventFlags:eventFlags
                                typeLeft:typeLeft
                               typeRight:typeRight
                             leftPayload:leftData
                            rightPayload:rightData];
        dispatch_semaphore_signal(returned);
    });

    XCTAssertEqual(dispatch_semaphore_wait(returned,
                                           dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC)), 0);
    if (beforeDraining != nil) {
        beforeDraining();
    }

    XCTestExpectation *drained = [self expectationWithDescription:@"main queue drained"];
    dispatch_async(dispatch_get_main_queue(), ^{
        [drained fulfill];
    });
    [self waitForExpectations:@[drained] timeout:2.0];
}

- (Connection *)connectionWithCallbacks:(id<ConnectionCallbacks>)callbacks
{
    StreamConfiguration *configuration = [[StreamConfiguration alloc] init];
    configuration.host = @"127.0.0.1";
    configuration.appVersion = @"1.0";
    configuration.riKey = [NSMutableData dataWithLength:16];
    return [[Connection alloc] initWithConfig:configuration renderer:nil connectionCallbacks:callbacks];
}

- (void)drainMainQueue
{
    XCTestExpectation *drained = [self expectationWithDescription:@"main queue drained"];
    dispatch_async(dispatch_get_main_queue(), ^{
        [drained fulfill];
    });
    [self waitForExpectations:@[drained] timeout:2.0];
}

- (BOOL)requireLifecycleSelector:(SEL)selector onSupport:(ControllerSupport *)support
{
    BOOL responds = [support respondsToSelector:selector];
    XCTAssertTrue(responds, @"ControllerSupport must implement %@", NSStringFromSelector(selector));
    return responds;
}

- (BOOL)requireAdaptiveTriggerLifecycleStateOnSupport:(ControllerSupport *)support
{
    const char *names[] = {
        "_adaptiveTriggerStreamActive",
        "_adaptiveTriggerForegroundActive",
        "_adaptiveTriggerEffectsBySlot",
    };
    BOOL complete = YES;
    for (NSUInteger index = 0; index < sizeof(names) / sizeof(names[0]); index++) {
        BOOL exists = class_getInstanceVariable([ControllerSupport class], names[index]) != NULL;
        XCTAssertTrue(exists, @"ControllerSupport must own main-queue lifecycle field %s", names[index]);
        complete &= exists;
    }
    return complete;
}

- (void)testRegistersCallbackAndCopiesBorrowedPayloadsBeforeReturning
{
    MLConnectionCallbacksSpy *callbacks = [[MLConnectionCallbacksSpy alloc] init];
    Connection *connection = [self connectionWithCallbacks:callbacks];
    Ivar callbacksIvar = class_getInstanceVariable([Connection class], "_clCallbacks");
    XCTAssertNotEqual(callbacksIvar, NULL);
    if (callbacksIvar == NULL) {
        return;
    }

    uint8_t *connectionBytes = (__bridge void *)connection;
    CONNECTION_LISTENER_CALLBACKS *table = (void *)(connectionBytes + ivar_getOffset(callbacksIvar));
    XCTAssertNotEqual(table->setAdaptiveTriggers, NULL,
                      @"Connection must register the adaptive-trigger callback");
    if (table->setAdaptiveTriggers == NULL) {
        return;
    }

    const uint8_t expectedLeft[10] = { 0x24, 0, 0x80, 0x80, 0x03, 0, 0, 0, 0, 0 };
    const uint8_t expectedRight[10] = { 0x84, 0, 0x05, 0, 0, 0, 0, 0, 0, 0 };
    uint8_t *borrowedLeft = malloc(10);
    uint8_t *borrowedRight = malloc(10);
    memcpy(borrowedLeft, expectedLeft, 10);
    memcpy(borrowedRight, expectedRight, 10);

    table->setAdaptiveTriggers(3, DS_EFFECT_LEFT_TRIGGER | DS_EFFECT_RIGHT_TRIGGER,
                               0x21, 0x25, borrowedLeft, borrowedRight);
    memset(borrowedLeft, 0xA5, 10);
    memset(borrowedRight, 0x5A, 10);
    free(borrowedLeft);
    free(borrowedRight);

    XCTAssertEqual(callbacks.controllerNumber, 3);
    XCTAssertEqual(callbacks.eventFlags, DS_EFFECT_LEFT_TRIGGER | DS_EFFECT_RIGHT_TRIGGER);
    XCTAssertEqual(callbacks.typeLeft, 0x21);
    XCTAssertEqual(callbacks.typeRight, 0x25);
    XCTAssertEqualObjects(callbacks.leftPayload, [NSData dataWithBytes:expectedLeft length:10]);
    XCTAssertEqualObjects(callbacks.rightPayload, [NSData dataWithBytes:expectedRight length:10]);
}

- (void)testDispatchesResolverAndEndpointOnlyOnMainQueue
{
    const uint8_t feedback[10] = { 0x24, 0, 0x80, 0x80, 0x03, 0, 0, 0, 0, 0 };
    const uint8_t off[10] = { 0 };
    MLAdaptiveTriggerEndpointSpy *endpoint = [[MLAdaptiveTriggerEndpointSpy alloc] init];
    MLAdaptiveTriggerControllerSupportSpy *support = [[MLAdaptiveTriggerControllerSupportSpy alloc] init];
    support.resolvedEndpoint = endpoint;

    [self waitForMainQueueAfterInvokingSupport:support
                              controllerNumber:2
                                    eventFlags:DS_EFFECT_LEFT_TRIGGER
                                      typeLeft:0x21
                                     typeRight:0x05
                                   leftPayload:feedback
                                  rightPayload:off
                                beforeDraining:^{
        XCTAssertEqual(support.resolvedControllerNumbers.count, 0u);
        XCTAssertEqual(endpoint.appliedSides.count, 0u);
    }];

    XCTAssertEqualObjects(support.resolvedControllerNumbers, (@[@2]));
    XCTAssertEqualObjects(support.resolverMainThreadObservations, (@[@YES]));
    XCTAssertEqualObjects(endpoint.mainThreadObservations, (@[@YES]));
}

- (void)testEventFlagsSelectSidesAndPreserveUnselectedSide
{
    const uint8_t feedback[10] = { 0x24, 0, 0x80, 0x80, 0x03, 0, 0, 0, 0, 0 };
    const uint8_t weapon[10] = { 0x84, 0, 0x05, 0, 0, 0, 0, 0, 0, 0 };
    const struct {
        uint8_t flags;
        NSArray<NSNumber *> *sides;
        NSArray<NSNumber *> *kinds;
    } vectors[] = {
        { DS_EFFECT_LEFT_TRIGGER, @[@(MLAdaptiveTriggerSideLeft)], @[@(MLAdaptiveTriggerFeedback)] },
        { DS_EFFECT_RIGHT_TRIGGER, @[@(MLAdaptiveTriggerSideRight)], @[@(MLAdaptiveTriggerWeapon)] },
        { DS_EFFECT_LEFT_TRIGGER | DS_EFFECT_RIGHT_TRIGGER,
          @[@(MLAdaptiveTriggerSideLeft), @(MLAdaptiveTriggerSideRight)],
          @[@(MLAdaptiveTriggerFeedback), @(MLAdaptiveTriggerWeapon)] },
    };

    for (NSUInteger index = 0; index < sizeof(vectors) / sizeof(vectors[0]); index++) {
        MLAdaptiveTriggerEndpointSpy *endpoint = [[MLAdaptiveTriggerEndpointSpy alloc] init];
        MLAdaptiveTriggerControllerSupportSpy *support = [[MLAdaptiveTriggerControllerSupportSpy alloc] init];
        support.resolvedEndpoint = endpoint;

        [self waitForMainQueueAfterInvokingSupport:support
                                  controllerNumber:1
                                        eventFlags:vectors[index].flags
                                          typeLeft:0x21
                                         typeRight:0x25
                                       leftPayload:feedback
                                      rightPayload:weapon
                                    beforeDraining:nil];

        XCTAssertEqualObjects(endpoint.appliedSides, vectors[index].sides);
        XCTAssertEqualObjects(endpoint.appliedKinds, vectors[index].kinds);
        XCTAssertEqual(endpoint.offSides.count, 0u);
    }
}

- (void)testMalformedAndUnsupportedSelectedSidesFailClosedWithoutChangingOppositeSide
{
    const uint8_t malformedFeedback[10] = { 0, 0, 0, 0, 0, 0, 1, 0, 0, 0 };
    const uint8_t ignoredValidWeapon[10] = { 0x84, 0, 0x05, 0, 0, 0, 0, 0, 0, 0 };
    MLAdaptiveTriggerEndpointSpy *endpoint = [[MLAdaptiveTriggerEndpointSpy alloc] init];
    MLAdaptiveTriggerControllerSupportSpy *support = [[MLAdaptiveTriggerControllerSupportSpy alloc] init];
    support.resolvedEndpoint = endpoint;

    [self waitForMainQueueAfterInvokingSupport:support
                              controllerNumber:0
                                    eventFlags:DS_EFFECT_LEFT_TRIGGER
                                      typeLeft:0x21
                                     typeRight:0x25
                                   leftPayload:malformedFeedback
                                  rightPayload:ignoredValidWeapon
                                beforeDraining:nil];

    XCTAssertEqualObjects(endpoint.offSides, (@[@(MLAdaptiveTriggerSideLeft)]));
    XCTAssertEqual(endpoint.appliedSides.count, 0u,
                   @"the unselected valid right side must retain its current state");

    endpoint = [[MLAdaptiveTriggerEndpointSpy alloc] init];
    support.resolvedEndpoint = endpoint;
    [self waitForMainQueueAfterInvokingSupport:support
                              controllerNumber:0
                                    eventFlags:DS_EFFECT_RIGHT_TRIGGER
                                      typeLeft:0x21
                                     typeRight:0x99
                                   leftPayload:ignoredValidWeapon
                                  rightPayload:malformedFeedback
                                beforeDraining:nil];
    XCTAssertEqualObjects(endpoint.offSides, (@[@(MLAdaptiveTriggerSideRight)]));
    XCTAssertEqual(endpoint.appliedSides.count, 0u);
}

- (void)testAbsentEndpointIsNoOp
{
    const uint8_t off[10] = { 0 };
    MLAdaptiveTriggerControllerSupportSpy *support = [[MLAdaptiveTriggerControllerSupportSpy alloc] init];
    support.resolvedEndpoint = nil;

    [self waitForMainQueueAfterInvokingSupport:support
                              controllerNumber:3
                                    eventFlags:DS_EFFECT_LEFT_TRIGGER | DS_EFFECT_RIGHT_TRIGGER
                                      typeLeft:0x05
                                     typeRight:0x05
                                   leftPayload:off
                                  rightPayload:off
                                beforeDraining:nil];

    XCTAssertEqualObjects(support.resolvedControllerNumbers, (@[@3]));
}

- (void)testProductionResolverRejectsAbsentAndNonDualSenseControllers
{
    ControllerSupport *support = [[ControllerSupport alloc] init];
    XCTAssertTrue([support conformsToProtocol:@protocol(MLAdaptiveTriggerResolving)]);
    XCTAssertTrue([support respondsToSelector:@selector(endpointForControllerNumber:)]);
    if (![support respondsToSelector:@selector(endpointForControllerNumber:)]) {
        return;
    }

    [support setValue:[NSMutableDictionary dictionary] forKey:@"_controllers"];
    XCTAssertNil([(id<MLAdaptiveTriggerResolving>)support endpointForControllerNumber:4]);

    Controller *controller = [[Controller alloc] init];
    MLNonDualSenseControllerStub *nonDualSense = [[MLNonDualSenseControllerStub alloc] init];
    nonDualSense.extendedGamepad = [[NSObject alloc] init];
    controller.gamepad = (id)nonDualSense;
    [support setValue:[@{@4: controller} mutableCopy] forKey:@"_controllers"];
    XCTAssertNil([(id<MLAdaptiveTriggerResolving>)support endpointForControllerNumber:4]);
}


#pragma mark - Lifecycle safety

- (void)testAdaptiveTriggerLifecycleStartsActiveAndAppliesFirstUpdate
{
    const uint8_t feedback[10] = { 0x24, 0, 0x80, 0x80, 0x03, 0, 0, 0, 0, 0 };
    const uint8_t off[10] = { 0 };
    MLAdaptiveTriggerEndpointSpy *endpoint = [[MLAdaptiveTriggerEndpointSpy alloc] init];
    MLAdaptiveTriggerControllerSupportSpy *support = [[MLAdaptiveTriggerControllerSupportSpy alloc] init];
    support.resolvedEndpoint = endpoint;

    if (![self requireAdaptiveTriggerLifecycleStateOnSupport:support]) {
        return;
    }
    XCTAssertTrue([[support valueForKey:@"_adaptiveTriggerStreamActive"] boolValue]);
    XCTAssertTrue([[support valueForKey:@"_adaptiveTriggerForegroundActive"] boolValue]);

    [self waitForMainQueueAfterInvokingSupport:support
                              controllerNumber:0
                                    eventFlags:DS_EFFECT_LEFT_TRIGGER
                                      typeLeft:0x21
                                     typeRight:0x05
                                   leftPayload:feedback
                                  rightPayload:off
                                beforeDraining:nil];

    XCTAssertEqualObjects(endpoint.appliedKinds, (@[@(MLAdaptiveTriggerFeedback)]));
}

- (void)testQueuedUpdateAfterTerminalStopCannotRestoreResistance
{
    const uint8_t feedback[10] = { 0x24, 0, 0x80, 0x80, 0x03, 0, 0, 0, 0, 0 };
    const uint8_t off[10] = { 0 };
    MLAdaptiveTriggerEndpointSpy *endpoint = [[MLAdaptiveTriggerEndpointSpy alloc] init];
    MLAdaptiveTriggerControllerSupportSpy *support = [[MLAdaptiveTriggerControllerSupportSpy alloc] init];
    support.endpointsByControllerNumber[@1] = endpoint;
    [support setValue:[@{@1: [NSObject new]} mutableCopy] forKey:@"_controllers"];
    NSData *feedbackData = [NSData dataWithBytes:feedback length:10];
    NSData *offData = [NSData dataWithBytes:off length:10];

    if (![self requireLifecycleSelector:@selector(requestTerminalAdaptiveTriggerStop) onSupport:support] ||
        ![self requireAdaptiveTriggerLifecycleStateOnSupport:support]) {
        return;
    }

    endpoint.onBothOff = ^{
        XCTAssertFalse([[support valueForKey:@"_adaptiveTriggerStreamActive"] boolValue]);
        XCTAssertFalse([[support valueForKey:@"_adaptiveTriggerForegroundActive"] boolValue]);
        XCTAssertEqual([[support valueForKey:@"_adaptiveTriggerEffectsBySlot"] count], 0u);
    };

    dispatch_semaphore_t returned = dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        [(id)support requestTerminalAdaptiveTriggerStop];
        [(id)support setAdaptiveTriggers:1
                              eventFlags:DS_EFFECT_LEFT_TRIGGER
                                typeLeft:0x21
                               typeRight:0x05
                             leftPayload:feedbackData
                            rightPayload:offData];
        dispatch_semaphore_signal(returned);
    });
    XCTAssertEqual(dispatch_semaphore_wait(returned,
                                           dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC)), 0);
    [self drainMainQueue];

    XCTAssertEqual(endpoint.bothOffCount, 1u);
    XCTAssertEqual(endpoint.appliedSides.count, 0u);
}

- (void)testBackgroundUpdatesCacheOnlyAndForegroundReappliesLatestSelectedState
{
    const uint8_t feedback[10] = { 0x24, 0, 0x80, 0x80, 0x03, 0, 0, 0, 0, 0 };
    const uint8_t weapon[10] = { 0x84, 0, 0x05, 0, 0, 0, 0, 0, 0, 0 };
    const uint8_t off[10] = { 0 };
    MLAdaptiveTriggerEndpointSpy *endpoint = [[MLAdaptiveTriggerEndpointSpy alloc] init];
    MLAdaptiveTriggerControllerSupportSpy *support = [[MLAdaptiveTriggerControllerSupportSpy alloc] init];
    support.endpointsByControllerNumber[@2] = endpoint;
    [support setValue:[@{@2: [NSObject new]} mutableCopy] forKey:@"_controllers"];

    if (![self requireLifecycleSelector:@selector(pauseAdaptiveTriggerEffectsForBackground) onSupport:support] ||
        ![self requireLifecycleSelector:@selector(resumeAdaptiveTriggerEffectsAfterForeground) onSupport:support] ||
        ![self requireAdaptiveTriggerLifecycleStateOnSupport:support]) {
        return;
    }

    [self waitForMainQueueAfterInvokingSupport:support
                              controllerNumber:2
                                    eventFlags:DS_EFFECT_LEFT_TRIGGER
                                      typeLeft:0x21
                                     typeRight:0x05
                                   leftPayload:feedback
                                  rightPayload:off
                                beforeDraining:nil];
    XCTAssertEqualObjects(endpoint.appliedKinds, (@[@(MLAdaptiveTriggerFeedback)]));

    endpoint.onBothOff = ^{
        XCTAssertFalse([[support valueForKey:@"_adaptiveTriggerForegroundActive"] boolValue]);
        XCTAssertEqual([[support valueForKey:@"_adaptiveTriggerEffectsBySlot"] count], 1u);
    };
    [(id)support pauseAdaptiveTriggerEffectsForBackground];
    XCTAssertEqual(endpoint.bothOffCount, 1u);

    [self waitForMainQueueAfterInvokingSupport:support
                              controllerNumber:2
                                    eventFlags:DS_EFFECT_LEFT_TRIGGER
                                      typeLeft:0x25
                                     typeRight:0x05
                                   leftPayload:weapon
                                  rightPayload:off
                                beforeDraining:nil];
    XCTAssertEqual(endpoint.appliedKinds.count, 1u,
                   @"background callbacks may update cache but must not touch GameController");

    [(id)support resumeAdaptiveTriggerEffectsAfterForeground];
    XCTAssertEqualObjects(endpoint.appliedKinds,
                          (@[@(MLAdaptiveTriggerFeedback), @(MLAdaptiveTriggerWeapon)]));
    XCTAssertTrue([[support valueForKey:@"_adaptiveTriggerForegroundActive"] boolValue]);
}

- (void)testStreamViewControllerPausesOnResignActiveAndReappliesOnBecomeActive
{
    const uint8_t feedback[10] = { 0x24, 0, 0x80, 0x80, 0x03, 0, 0, 0, 0, 0 };
    const uint8_t off[10] = { 0 };
    MLAdaptiveTriggerEndpointSpy *endpoint = [[MLAdaptiveTriggerEndpointSpy alloc] init];
    MLAdaptiveTriggerControllerSupportSpy *support = [[MLAdaptiveTriggerControllerSupportSpy alloc] init];
    support.endpointsByControllerNumber[@0] = endpoint;
    [support setValue:[@{@0: [NSObject new]} mutableCopy] forKey:@"_controllers"];

    Class viewControllerClass = NSClassFromString(@"StreamFrameViewController");
    XCTAssertNotNil(viewControllerClass);
    id viewController = [[viewControllerClass alloc] init];
    [viewController setValue:support forKey:@"_controllerSupport"];

    NSNotification *resignNotification =
        [NSNotification notificationWithName:UIApplicationWillResignActiveNotification object:nil];
    [(id)viewController applicationWillResignActive:resignNotification];
    XCTAssertEqual(endpoint.bothOffCount, 1u);
    XCTAssertFalse([[support valueForKey:@"_adaptiveTriggerForegroundActive"] boolValue]);

    [self waitForMainQueueAfterInvokingSupport:support
                              controllerNumber:0
                                    eventFlags:DS_EFFECT_LEFT_TRIGGER
                                      typeLeft:0x21
                                     typeRight:0x05
                                   leftPayload:feedback
                                  rightPayload:off
                                beforeDraining:nil];
    XCTAssertEqual(endpoint.appliedKinds.count, 0u,
                   @"resign-active callbacks must update cache without touching GameController");

    NSNotification *activeNotification =
        [NSNotification notificationWithName:UIApplicationDidBecomeActiveNotification object:nil];
    [(id)viewController applicationDidBecomeActive:activeNotification];
    XCTAssertEqualObjects(endpoint.appliedKinds, (@[@(MLAdaptiveTriggerFeedback)]));
    XCTAssertTrue([[support valueForKey:@"_adaptiveTriggerForegroundActive"] boolValue]);
}

- (void)testInvalidControllerSlotsCannotGrowCacheDiagnosticsOrReachEndpoint
{
    const uint8_t malformed[10] = { 0, 0, 0, 0, 0, 0, 1, 0, 0, 0 };
    const uint8_t off[10] = { 0 };
    NSData *malformedData = [NSData dataWithBytes:malformed length:10];
    NSData *offData = [NSData dataWithBytes:off length:10];
    MLAdaptiveTriggerEndpointSpy *endpoint = [[MLAdaptiveTriggerEndpointSpy alloc] init];
    MLAdaptiveTriggerControllerSupportSpy *support = [[MLAdaptiveTriggerControllerSupportSpy alloc] init];
    support.resolvedEndpoint = endpoint;

    for (uint16_t controllerNumber = 4; controllerNumber < 1028; controllerNumber++) {
        [(id)support setAdaptiveTriggers:controllerNumber
                              eventFlags:DS_EFFECT_LEFT_TRIGGER
                                typeLeft:0x21
                               typeRight:0x05
                             leftPayload:malformedData
                            rightPayload:offData];
    }
    [self drainMainQueue];

    XCTAssertEqual([[support valueForKey:@"_adaptiveTriggerEffectsBySlot"] count], 0u);
    XCTAssertEqual([[support valueForKey:@"_adaptiveTriggerDiagnosticStateByKey"] count], 0u);
    XCTAssertEqual(support.diagnosticMessages.count, 0u);
    XCTAssertEqual(support.resolvedControllerNumbers.count, 0u);
    XCTAssertEqual(endpoint.appliedSides.count, 0u);
    XCTAssertEqual(endpoint.offSides.count, 0u);
}

- (void)testDisconnectTurnsBothTriggersOffBeforeControllerDictionaryRemoval
{
    const uint8_t feedback[10] = { 0x24, 0, 0x80, 0x80, 0x03, 0, 0, 0, 0, 0 };
    const uint8_t off[10] = { 0 };
    MLAdaptiveTriggerEndpointSpy *endpoint = [[MLAdaptiveTriggerEndpointSpy alloc] init];
    StreamConfiguration *configuration = [[StreamConfiguration alloc] init];
    MLAdaptiveTriggerControllerSupportSpy *support =
        [[MLAdaptiveTriggerControllerSupportSpy alloc] initWithConfig:configuration delegate:nil];
    [self addTeardownBlock:^{ [support cleanup]; }];
    support.endpointsByControllerNumber[@3] = endpoint;
    MLControllerDeviceStub *device = [[MLControllerDeviceStub alloc] init];
    device.extendedGamepad = [[MLGamepadProfileStub alloc] init];
    device.playerIndex = 3;
    Controller *controller = [[Controller alloc] init];
    controller.playerIndex = 3;
    controller.gamepad = (id)device;
    [support setValue:[@{@3: controller} mutableCopy] forKey:@"_controllers"];
    [support setValue:@(1 << 3) forKey:@"_controllerNumbers"];

    if (![self requireAdaptiveTriggerLifecycleStateOnSupport:support]) {
        return;
    }

    [self waitForMainQueueAfterInvokingSupport:support
                              controllerNumber:3
                                    eventFlags:DS_EFFECT_LEFT_TRIGGER
                                      typeLeft:0x21
                                     typeRight:0x05
                                   leftPayload:feedback
                                  rightPayload:off
                                beforeDraining:nil];

    endpoint.onBothOff = ^{
        NSDictionary *controllers = [support valueForKey:@"_controllers"];
        XCTAssertNotNil(controllers[@3], @"disconnect cleanup must run before slot removal");
    };
    [[NSNotificationCenter defaultCenter] postNotificationName:GCControllerDidDisconnectNotification
                                                        object:device];
    XCTAssertEqual(endpoint.bothOffCount, 1u);
    XCTAssertNil([[support valueForKey:@"_controllers"] objectForKey:@3]);
    XCTAssertNil([[support valueForKey:@"_adaptiveTriggerEffectsBySlot"] objectForKey:@3]);
}

- (void)testSlotReassignmentDoesNotReplayPreviousControllersCachedEffect
{
    const uint8_t feedback[10] = { 0x24, 0, 0x80, 0x80, 0x03, 0, 0, 0, 0, 0 };
    const uint8_t off[10] = { 0 };
    MLAdaptiveTriggerEndpointSpy *oldEndpoint = [[MLAdaptiveTriggerEndpointSpy alloc] init];
    MLAdaptiveTriggerEndpointSpy *newEndpoint = [[MLAdaptiveTriggerEndpointSpy alloc] init];
    StreamConfiguration *configuration = [[StreamConfiguration alloc] init];
    MLAdaptiveTriggerControllerSupportSpy *support =
        [[MLAdaptiveTriggerControllerSupportSpy alloc] initWithConfig:configuration delegate:nil];
    [self addTeardownBlock:^{ [support cleanup]; }];
    support.endpointsByControllerNumber[@0] = oldEndpoint;
    MLControllerDeviceStub *oldDevice = [[MLControllerDeviceStub alloc] init];
    oldDevice.extendedGamepad = [[MLGamepadProfileStub alloc] init];
    oldDevice.playerIndex = 0;
    Controller *oldController = [[Controller alloc] init];
    oldController.playerIndex = 0;
    oldController.gamepad = (id)oldDevice;
    [support setValue:[@{@0: oldController} mutableCopy] forKey:@"_controllers"];
    [support setValue:@1 forKey:@"_controllerNumbers"];

    if (![self requireLifecycleSelector:@selector(resumeAdaptiveTriggerEffectsAfterForeground) onSupport:support]) {
        return;
    }

    [self waitForMainQueueAfterInvokingSupport:support
                              controllerNumber:0
                                    eventFlags:DS_EFFECT_LEFT_TRIGGER
                                      typeLeft:0x21
                                     typeRight:0x05
                                   leftPayload:feedback
                                  rightPayload:off
                                beforeDraining:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:GCControllerDidDisconnectNotification
                                                        object:oldDevice];

    support.endpointsByControllerNumber[@0] = newEndpoint;
    MLControllerDeviceStub *newDevice = [[MLControllerDeviceStub alloc] init];
    newDevice.extendedGamepad = [[MLGamepadProfileStub alloc] init];
    [[NSNotificationCenter defaultCenter] postNotificationName:GCControllerDidConnectNotification
                                                        object:newDevice];
    [(id)support resumeAdaptiveTriggerEffectsAfterForeground];

    XCTAssertEqual(oldEndpoint.bothOffCount, 1u);
    XCTAssertEqual(newEndpoint.bothOffCount, 1u);
    XCTAssertEqual(newEndpoint.appliedSides.count, 0u);
    Controller *assignedController = [[support valueForKey:@"_controllers"] objectForKey:@0];
    XCTAssertEqualObjects(assignedController.gamepad, (id)newDevice);
}

- (void)testRepeatedTerminalStopIsIdempotentAndNeverReactivatesStream
{
    MLAdaptiveTriggerEndpointSpy *endpoint = [[MLAdaptiveTriggerEndpointSpy alloc] init];
    MLAdaptiveTriggerControllerSupportSpy *support = [[MLAdaptiveTriggerControllerSupportSpy alloc] init];
    support.endpointsByControllerNumber[@0] = endpoint;
    [support setValue:[@{@0: [NSObject new]} mutableCopy] forKey:@"_controllers"];

    if (![self requireLifecycleSelector:@selector(requestTerminalAdaptiveTriggerStop) onSupport:support] ||
        ![self requireLifecycleSelector:@selector(resumeAdaptiveTriggerEffectsAfterForeground) onSupport:support] ||
        ![self requireAdaptiveTriggerLifecycleStateOnSupport:support]) {
        return;
    }

    [(id)support requestTerminalAdaptiveTriggerStop];
    [self drainMainQueue];
    [(id)support requestTerminalAdaptiveTriggerStop];
    [self drainMainQueue];
    [(id)support resumeAdaptiveTriggerEffectsAfterForeground];

    XCTAssertEqual(endpoint.bothOffCount, 2u);
    XCTAssertFalse([[support valueForKey:@"_adaptiveTriggerStreamActive"] boolValue]);
    XCTAssertFalse([[support valueForKey:@"_adaptiveTriggerForegroundActive"] boolValue]);
}

- (void)testMalformedDiagnosticIsRateLimitedAndContainsOnlyAllowlistedContext
{
    const uint8_t malformed[10] = { 0, 0, 0, 0, 0, 0, 1, 0, 0, 0 };
    const uint8_t off[10] = { 0 };
    MLAdaptiveTriggerEndpointSpy *endpoint = [[MLAdaptiveTriggerEndpointSpy alloc] init];
    MLAdaptiveTriggerControllerSupportSpy *support = [[MLAdaptiveTriggerControllerSupportSpy alloc] init];
    support.resolvedEndpoint = endpoint;
    [support.monotonicTimestamps addObjectsFromArray:@[@1.0, @1.25, @2.0, @2.25, @7.0, @7.25]];

    for (NSUInteger occurrence = 0; occurrence < 3; occurrence++) {
        [self waitForMainQueueAfterInvokingSupport:support
                                  controllerNumber:3
                                        eventFlags:DS_EFFECT_LEFT_TRIGGER
                                          typeLeft:0x21
                                         typeRight:0x05
                                       leftPayload:malformed
                                      rightPayload:off
                                    beforeDraining:nil];
    }

    XCTAssertEqual(support.diagnosticMessages.count, 2u,
                   @"identical errors must emit at most once per five seconds");
    XCTAssertEqualObjects(support.diagnosticMessages.firstObject,
                          @"Adaptive trigger controller=3 side=left type=0x21 result=malformed callback=1.000000 apply=1.250000 payload=ce07fb09 occurrence=1");
    XCTAssertEqualObjects(support.diagnosticMessages.lastObject,
                          @"Adaptive trigger controller=3 side=left type=0x21 result=malformed callback=7.000000 apply=7.250000 payload=ce07fb09 occurrence=3");
    for (NSString *message in support.diagnosticMessages) {
        XCTAssertEqual([message rangeOfString:@"mac" options:NSCaseInsensitiveSearch].location, NSNotFound);
        XCTAssertEqual([message rangeOfString:@"user" options:NSCaseInsensitiveSearch].location, NSNotFound);
        XCTAssertLessThan(message.length, 220u);
    }
}

@end
