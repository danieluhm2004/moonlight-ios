#if DEBUG

#import <UIKit/UIKit.h>

#import "AdaptiveTriggerEndpoint.h"

@protocol MLAdaptiveTriggerDiagnosticScheduling <NSObject>

- (id)scheduleAfter:(NSTimeInterval)delay block:(dispatch_block_t)block;
- (void)cancelScheduledBlock:(id)scheduledBlock;

@end

@protocol MLAdaptiveTriggerDiagnosticEndpointResolving <NSObject>

- (id<MLAdaptiveTriggerEndpoint>)connectedDualSenseEndpoint;

@end

API_AVAILABLE(ios(15.4), tvos(15.4))
@interface AdaptiveTriggerDiagnosticsViewController : UIViewController

- (instancetype)initWithEndpoint:(id<MLAdaptiveTriggerEndpoint>)endpoint
                        scheduler:(id<MLAdaptiveTriggerDiagnosticScheduling>)scheduler;
- (instancetype)initWithEndpointResolver:(id<MLAdaptiveTriggerDiagnosticEndpointResolving>)resolver
                                scheduler:(id<MLAdaptiveTriggerDiagnosticScheduling>)scheduler;
- (void)startDiagnosticSequence;
- (void)dismissDiagnostics;
- (void)applicationDidEnterBackground:(NSNotification *)notification;

@end
#endif
