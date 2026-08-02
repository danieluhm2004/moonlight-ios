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
@end

@interface MLAdaptiveTriggerEndpointSpy : NSObject <MLAdaptiveTriggerEndpoint>
@property(nonatomic) NSMutableArray<NSNumber *> *appliedSides;
@property(nonatomic) NSMutableArray<NSNumber *> *appliedKinds;
@property(nonatomic) NSMutableArray<NSNumber *> *offSides;
@property(nonatomic) NSMutableArray<NSNumber *> *mainThreadObservations;
@property(nonatomic) NSUInteger bothOffCount;
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
    self.bothOffCount++;
    [self.mainThreadObservations addObject:@([NSThread isMainThread])];
}

@end

@interface MLAdaptiveTriggerControllerSupportSpy : ControllerSupport <MLAdaptiveTriggerResolving>
@property(nonatomic) id<MLAdaptiveTriggerEndpoint> resolvedEndpoint;
@property(nonatomic) NSMutableArray<NSNumber *> *resolvedControllerNumbers;
@property(nonatomic) NSMutableArray<NSNumber *> *resolverMainThreadObservations;
@end

@implementation MLAdaptiveTriggerControllerSupportSpy

- (instancetype)init
{
    self = [super init];
    if (self) {
        _resolvedControllerNumbers = [NSMutableArray array];
        _resolverMainThreadObservations = [NSMutableArray array];
    }
    return self;
}

- (id<MLAdaptiveTriggerEndpoint>)endpointForControllerNumber:(uint16_t)number
{
    [self.resolvedControllerNumbers addObject:@(number)];
    [self.resolverMainThreadObservations addObject:@([NSThread isMainThread])];
    return self.resolvedEndpoint;
}

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
                              controllerNumber:7
                                    eventFlags:DS_EFFECT_LEFT_TRIGGER | DS_EFFECT_RIGHT_TRIGGER
                                      typeLeft:0x05
                                     typeRight:0x05
                                   leftPayload:off
                                  rightPayload:off
                                beforeDraining:nil];

    XCTAssertEqualObjects(support.resolvedControllerNumbers, (@[@7]));
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

@end
