#import <XCTest/XCTest.h>

#import "AdaptiveTriggerEndpoint.h"

@interface NSObject (AdaptiveTriggerDiagnosticsTestAPI)

- (instancetype)initWithEndpoint:(id<MLAdaptiveTriggerEndpoint>)endpoint scheduler:(id)scheduler;
- (instancetype)initWithEndpointResolver:(id)resolver scheduler:(id)scheduler;
- (void)startDiagnosticSequence;
- (void)viewWillDisappear:(BOOL)animated;
- (void)applicationDidEnterBackground:(NSNotification *)notification;
- (void)controllerDidConnect:(NSNotification *)notification;
- (void)controllerDidDisconnect:(NSNotification *)notification;
- (UIAlertController *)adaptiveTriggerDiagnosticsUnavailableAlert;

@end

@interface MLDiagnosticScheduledBlock : NSObject

@property(nonatomic) NSTimeInterval delay;
@property(nonatomic, copy) dispatch_block_t block;
@property(nonatomic) BOOL cancelled;

@end

@implementation MLDiagnosticScheduledBlock
@end

@interface MLDiagnosticSchedulerSpy : NSObject

@property(nonatomic) NSMutableArray<MLDiagnosticScheduledBlock *> *scheduledBlocks;

- (void)runBlockAtIndex:(NSUInteger)index;

@end


@implementation MLDiagnosticSchedulerSpy

- (instancetype)init
{
    self = [super init];
    if (self) {
        _scheduledBlocks = [NSMutableArray array];
    }
    return self;
}

- (id)scheduleAfter:(NSTimeInterval)delay block:(dispatch_block_t)block
{
    MLDiagnosticScheduledBlock *scheduledBlock = [[MLDiagnosticScheduledBlock alloc] init];
    scheduledBlock.delay = delay;
    scheduledBlock.block = block;
    [self.scheduledBlocks addObject:scheduledBlock];
    return scheduledBlock;
}

- (void)cancelScheduledBlock:(MLDiagnosticScheduledBlock *)scheduledBlock
{
    scheduledBlock.cancelled = YES;
}

- (void)runBlockAtIndex:(NSUInteger)index
{
    MLDiagnosticScheduledBlock *scheduledBlock = self.scheduledBlocks[index];
    if (!scheduledBlock.cancelled) {
        scheduledBlock.block();
    }
}

@end

@interface MLRecordedTriggerOperation : NSObject

@property(nonatomic) BOOL isBothOff;
@property(nonatomic) BOOL isSideOff;
@property(nonatomic) MLAdaptiveTriggerSide side;
@property(nonatomic) MLAdaptiveTriggerEffect effect;

@end

@implementation MLRecordedTriggerOperation
@end

@interface MLDiagnosticEndpointSpy : NSObject <MLAdaptiveTriggerEndpoint>

@property(nonatomic) NSMutableArray<MLRecordedTriggerOperation *> *operations;

@end


@implementation MLDiagnosticEndpointSpy

- (instancetype)init
{
    self = [super init];
    if (self) {
        _operations = [NSMutableArray array];
    }
    return self;
}

- (void)applyEffect:(MLAdaptiveTriggerEffect)effect side:(MLAdaptiveTriggerSide)side
{
    MLRecordedTriggerOperation *operation = [[MLRecordedTriggerOperation alloc] init];
    operation.side = side;
    operation.effect = effect;
    [self.operations addObject:operation];
}

- (void)setOffForSide:(MLAdaptiveTriggerSide)side
{
    MLRecordedTriggerOperation *operation = [[MLRecordedTriggerOperation alloc] init];
    operation.isSideOff = YES;
    operation.side = side;
    [self.operations addObject:operation];
}

- (void)setBothOff
{
    MLRecordedTriggerOperation *operation = [[MLRecordedTriggerOperation alloc] init];
    operation.isBothOff = YES;
    [self.operations addObject:operation];
}

@end

@interface MLDiagnosticEndpointResolverSpy : NSObject

@property(nonatomic) id<MLAdaptiveTriggerEndpoint> endpoint;
@property(nonatomic) NSUInteger resolutionCount;

@end


@implementation MLDiagnosticEndpointResolverSpy

- (id<MLAdaptiveTriggerEndpoint>)connectedDualSenseEndpoint
{
    self.resolutionCount++;
    return self.endpoint;
}

@end

@interface AdaptiveTriggerDiagnosticsTests : XCTestCase
@end


@implementation AdaptiveTriggerDiagnosticsTests

- (id)newDiagnosticWithEndpoint:(MLDiagnosticEndpointSpy *)endpoint
                       scheduler:(MLDiagnosticSchedulerSpy *)scheduler
{
    Class diagnosticsClass = NSClassFromString(@"AdaptiveTriggerDiagnosticsViewController");
    XCTAssertNotNil(diagnosticsClass, @"Debug diagnostics controller must exist");
    if (diagnosticsClass == Nil) {
        return nil;
    }

    return [[diagnosticsClass alloc] initWithEndpoint:endpoint scheduler:scheduler];
}

- (void)assertApply:(MLRecordedTriggerOperation *)operation
               kind:(MLAdaptiveTriggerKind)kind
               side:(MLAdaptiveTriggerSide)side
{
    XCTAssertFalse(operation.isSideOff);
    XCTAssertFalse(operation.isBothOff);
    XCTAssertEqual(operation.effect.kind, kind);
    XCTAssertEqual(operation.side, side);
}

- (void)assertEffect:(MLAdaptiveTriggerEffect)effect
          hasValues:(const float[10])expectedValues
{
    for (NSUInteger index = 0; index < 10; index++) {
        XCTAssertEqualWithAccuracy(effect.values[index], expectedValues[index], 0.0001f);
    }
}

- (void)testRunsEveryEffectForTwoSecondsInTheRequiredOrder
{
    MLDiagnosticEndpointSpy *endpoint = [[MLDiagnosticEndpointSpy alloc] init];
    MLDiagnosticSchedulerSpy *scheduler = [[MLDiagnosticSchedulerSpy alloc] init];
    id diagnostics = [self newDiagnosticWithEndpoint:endpoint scheduler:scheduler];
    if (diagnostics == nil) {
        return;
    }

    [diagnostics startDiagnosticSequence];

    XCTAssertEqual(scheduler.scheduledBlocks.count, 6u);
    NSArray<NSNumber *> *expectedDelays = @[@2.0, @4.0, @6.0, @8.0, @10.0, @12.0];
    for (NSUInteger index = 0; index < expectedDelays.count; index++) {
        XCTAssertEqualWithAccuracy(scheduler.scheduledBlocks[index].delay,
                                   expectedDelays[index].doubleValue, 0.001);
    }

    for (NSUInteger index = 0; index < scheduler.scheduledBlocks.count; index++) {
        [scheduler runBlockAtIndex:index];
    }

    XCTAssertEqual(endpoint.operations.count, 14u);
    if (endpoint.operations.count != 14u) {
        return;
    }

    NSUInteger index = 0;
    MLRecordedTriggerOperation *operation = endpoint.operations[index++];
    [self assertApply:operation kind:MLAdaptiveTriggerFeedback side:MLAdaptiveTriggerSideLeft];
    for (NSUInteger valueIndex = 0; valueIndex < 10; valueIndex++) {
        XCTAssertEqualWithAccuracy(operation.effect.values[valueIndex], 0.25f, 0.0001f);
    }

    operation = endpoint.operations[index++];
    XCTAssertTrue(operation.isSideOff);
    XCTAssertEqual(operation.side, MLAdaptiveTriggerSideLeft);

    operation = endpoint.operations[index++];
    [self assertApply:operation kind:MLAdaptiveTriggerWeapon side:MLAdaptiveTriggerSideRight];
    XCTAssertEqualWithAccuracy(operation.effect.start_position, 0.25f, 0.0001f);
    XCTAssertEqualWithAccuracy(operation.effect.end_position, 0.75f, 0.0001f);
    XCTAssertEqualWithAccuracy(operation.effect.strength, 0.5f, 0.0001f);

    operation = endpoint.operations[index++];
    XCTAssertTrue(operation.isSideOff);
    XCTAssertEqual(operation.side, MLAdaptiveTriggerSideRight);

    for (MLAdaptiveTriggerSide side = MLAdaptiveTriggerSideLeft;
         side <= MLAdaptiveTriggerSideRight; side++) {
        operation = endpoint.operations[index++];
        [self assertApply:operation kind:MLAdaptiveTriggerVibration side:side];
        XCTAssertEqualWithAccuracy(operation.effect.frequency, 0.5f, 0.0001f);
        for (NSUInteger valueIndex = 0; valueIndex < 10; valueIndex++) {
            XCTAssertEqualWithAccuracy(operation.effect.values[valueIndex], 0.5f, 0.0001f);
        }
    }

    XCTAssertTrue(endpoint.operations[index++].isBothOff);

    const float positionalFeedbackValues[10] = {
        0.0f, 0.0f, 0.25f, 0.375f, 0.5f, 0.625f, 0.75f, 0.875f, 1.0f, 0.0f
    };
    for (MLAdaptiveTriggerSide side = MLAdaptiveTriggerSideLeft;
         side <= MLAdaptiveTriggerSideRight; side++) {
        operation = endpoint.operations[index++];
        [self assertApply:operation kind:MLAdaptiveTriggerFeedback side:side];
        [self assertEffect:operation.effect hasValues:positionalFeedbackValues];
    }

    const float positionalVibrationValues[10] = {
        0.0f, 0.0f, 0.25f, 0.5f, 0.75f, 1.0f, 0.75f, 0.5f, 0.25f, 0.0f
    };
    for (MLAdaptiveTriggerSide side = MLAdaptiveTriggerSideLeft;
         side <= MLAdaptiveTriggerSideRight; side++) {
        operation = endpoint.operations[index++];
        [self assertApply:operation kind:MLAdaptiveTriggerVibration side:side];
        [self assertEffect:operation.effect hasValues:positionalVibrationValues];
        XCTAssertEqualWithAccuracy(operation.effect.frequency, 0.5f, 0.0001f);
    }

    const float slopeValues[10] = {
        0.1f, 0.2f, 0.3f, 0.4f, 0.5f, 0.6f, 0.7f, 0.8f, 0.9f, 1.0f
    };
    for (MLAdaptiveTriggerSide side = MLAdaptiveTriggerSideLeft;
         side <= MLAdaptiveTriggerSideRight; side++) {
        operation = endpoint.operations[index++];
        [self assertApply:operation kind:MLAdaptiveTriggerFeedback side:side];
        [self assertEffect:operation.effect hasValues:slopeValues];
    }

    XCTAssertTrue(endpoint.operations[index++].isBothOff);
    XCTAssertEqual(index, endpoint.operations.count);
}

- (void)testDismissalCancelsOutstandingBlocksAndImmediatelyReleasesBothTriggers
{
    MLDiagnosticEndpointSpy *endpoint = [[MLDiagnosticEndpointSpy alloc] init];
    MLDiagnosticSchedulerSpy *scheduler = [[MLDiagnosticSchedulerSpy alloc] init];
    id diagnostics = [self newDiagnosticWithEndpoint:endpoint scheduler:scheduler];
    if (diagnostics == nil) {
        return;
    }

    [diagnostics startDiagnosticSequence];
    [diagnostics viewWillDisappear:NO];

    XCTAssertTrue(endpoint.operations.lastObject.isBothOff);
    for (MLDiagnosticScheduledBlock *scheduledBlock in scheduler.scheduledBlocks) {
        XCTAssertTrue(scheduledBlock.cancelled);
    }

    NSUInteger operationCount = endpoint.operations.count;
    for (NSUInteger index = 0; index < scheduler.scheduledBlocks.count; index++) {
        [scheduler runBlockAtIndex:index];
    }
    XCTAssertEqual(endpoint.operations.count, operationCount);
}

- (void)testBackgroundImmediatelyCancelsSequenceAndReleasesBothTriggers
{
    MLDiagnosticEndpointSpy *endpoint = [[MLDiagnosticEndpointSpy alloc] init];
    MLDiagnosticSchedulerSpy *scheduler = [[MLDiagnosticSchedulerSpy alloc] init];
    id diagnostics = [self newDiagnosticWithEndpoint:endpoint scheduler:scheduler];
    if (diagnostics == nil) {
        return;
    }

    [diagnostics startDiagnosticSequence];
    [diagnostics applicationDidEnterBackground:
        [NSNotification notificationWithName:UIApplicationDidEnterBackgroundNotification
                                      object:nil]];

    XCTAssertTrue(endpoint.operations.lastObject.isBothOff);
    for (MLDiagnosticScheduledBlock *scheduledBlock in scheduler.scheduledBlocks) {
        XCTAssertTrue(scheduledBlock.cancelled);
    }

    NSUInteger operationCount = endpoint.operations.count;
    for (NSUInteger index = 0; index < scheduler.scheduledBlocks.count; index++) {
        [scheduler runBlockAtIndex:index];
    }
    XCTAssertEqual(endpoint.operations.count, operationCount);
}

- (void)testBackgroundRemovesDiagnosticFromNavigationStack
{
    MLDiagnosticEndpointSpy *endpoint = [[MLDiagnosticEndpointSpy alloc] init];
    MLDiagnosticSchedulerSpy *scheduler = [[MLDiagnosticSchedulerSpy alloc] init];
    UIViewController *diagnostics = [self newDiagnosticWithEndpoint:endpoint scheduler:scheduler];
    if (diagnostics == nil) {
        return;
    }

    UIViewController *root = [[UIViewController alloc] init];
    UINavigationController *navigation =
        [[UINavigationController alloc] initWithRootViewController:root];
    [navigation pushViewController:diagnostics animated:NO];

    [(id)diagnostics applicationDidEnterBackground:
        [NSNotification notificationWithName:UIApplicationDidEnterBackgroundNotification
                                      object:nil]];

    XCTAssertEqual(navigation.topViewController, root);
    XCTAssertFalse([navigation.viewControllers containsObject:diagnostics]);
}

- (void)testRunRefreshesEndpointWhenControllerConnectedAfterScreenOpened
{
    Class diagnosticsClass = NSClassFromString(@"AdaptiveTriggerDiagnosticsViewController");
    XCTAssertNotNil(diagnosticsClass);
    XCTAssertTrue([diagnosticsClass instancesRespondToSelector:
        @selector(initWithEndpointResolver:scheduler:)]);
    if (![diagnosticsClass instancesRespondToSelector:
            @selector(initWithEndpointResolver:scheduler:)]) {
        return;
    }

    MLDiagnosticEndpointResolverSpy *resolver = [[MLDiagnosticEndpointResolverSpy alloc] init];
    MLDiagnosticSchedulerSpy *scheduler = [[MLDiagnosticSchedulerSpy alloc] init];
    UIViewController *diagnostics =
        [[diagnosticsClass alloc] initWithEndpointResolver:resolver scheduler:scheduler];
    (void)diagnostics.view;

    MLDiagnosticEndpointSpy *connectedEndpoint = [[MLDiagnosticEndpointSpy alloc] init];
    resolver.endpoint = connectedEndpoint;
    [(id)diagnostics startDiagnosticSequence];

    XCTAssertGreaterThanOrEqual(resolver.resolutionCount, 2u);
    XCTAssertEqual(connectedEndpoint.operations.count, 1u);
    XCTAssertEqual(connectedEndpoint.operations.firstObject.effect.kind,
                   MLAdaptiveTriggerFeedback);
    XCTAssertEqual(connectedEndpoint.operations.firstObject.side,
                   MLAdaptiveTriggerSideLeft);
}

- (void)testDisconnectStopsSequenceAndReconnectMakesNextRunReady
{
    Class diagnosticsClass = NSClassFromString(@"AdaptiveTriggerDiagnosticsViewController");
    XCTAssertNotNil(diagnosticsClass);
    XCTAssertTrue([diagnosticsClass instancesRespondToSelector:
        @selector(initWithEndpointResolver:scheduler:)]);
    if (![diagnosticsClass instancesRespondToSelector:
            @selector(initWithEndpointResolver:scheduler:)]) {
        return;
    }

    MLDiagnosticEndpointSpy *firstEndpoint = [[MLDiagnosticEndpointSpy alloc] init];
    MLDiagnosticEndpointResolverSpy *resolver = [[MLDiagnosticEndpointResolverSpy alloc] init];
    resolver.endpoint = firstEndpoint;
    MLDiagnosticSchedulerSpy *scheduler = [[MLDiagnosticSchedulerSpy alloc] init];
    UIViewController *diagnostics =
        [[diagnosticsClass alloc] initWithEndpointResolver:resolver scheduler:scheduler];
    (void)diagnostics.view;
    [(id)diagnostics startDiagnosticSequence];

    resolver.endpoint = nil;
    [(id)diagnostics controllerDidDisconnect:
        [NSNotification notificationWithName:GCControllerDidDisconnectNotification
                                      object:nil]];

    XCTAssertTrue(firstEndpoint.operations.lastObject.isBothOff);
    for (MLDiagnosticScheduledBlock *scheduledBlock in scheduler.scheduledBlocks) {
        XCTAssertTrue(scheduledBlock.cancelled);
    }

    MLDiagnosticEndpointSpy *secondEndpoint = [[MLDiagnosticEndpointSpy alloc] init];
    resolver.endpoint = secondEndpoint;
    [(id)diagnostics controllerDidConnect:
        [NSNotification notificationWithName:GCControllerDidConnectNotification
                                      object:nil]];
    [(id)diagnostics startDiagnosticSequence];

    XCTAssertEqual(secondEndpoint.operations.count, 1u);
    XCTAssertEqual(secondEndpoint.operations.firstObject.effect.kind,
                   MLAdaptiveTriggerFeedback);
    XCTAssertEqual(secondEndpoint.operations.firstObject.side,
                   MLAdaptiveTriggerSideLeft);
}

- (void)testUnsupportedIOSDiagnosticActionProvidesAnExplanation
{
    Class settingsClass = NSClassFromString(@"SettingsViewController");
    XCTAssertNotNil(settingsClass);
    XCTAssertTrue([settingsClass instancesRespondToSelector:
        @selector(adaptiveTriggerDiagnosticsUnavailableAlert)]);
    if (![settingsClass instancesRespondToSelector:
            @selector(adaptiveTriggerDiagnosticsUnavailableAlert)]) {
        return;
    }

    id settings = [[settingsClass alloc] init];
    UIAlertController *alert = [settings adaptiveTriggerDiagnosticsUnavailableAlert];

    XCTAssertEqual(alert.preferredStyle, UIAlertControllerStyleAlert);
    XCTAssertEqualObjects(alert.title, @"DualSense diagnostics unavailable");
    XCTAssertTrue([alert.message containsString:@"iOS 15.4"]);
    XCTAssertEqual(alert.actions.count, 1u);
}

@end
