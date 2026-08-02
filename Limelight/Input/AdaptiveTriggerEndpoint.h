#import <Foundation/Foundation.h>

#import "AdaptiveTriggerDecoder.h"

@import GameController;

typedef NS_ENUM(NSUInteger, MLAdaptiveTriggerSide) {
    MLAdaptiveTriggerSideLeft,
    MLAdaptiveTriggerSideRight,
};

@protocol MLAdaptiveTriggerEndpoint <NSObject>

- (void)applyEffect:(MLAdaptiveTriggerEffect)effect side:(MLAdaptiveTriggerSide)side;
- (void)setOffForSide:(MLAdaptiveTriggerSide)side;
- (void)setBothOff;

@end

API_AVAILABLE(ios(15.4), tvos(15.4))
@interface MLAppleAdaptiveTriggerEndpoint : NSObject <MLAdaptiveTriggerEndpoint>

- (instancetype)initWithGamepad:(GCDualSenseGamepad *)gamepad;

@end

@protocol MLAdaptiveTriggerResolving <NSObject>

- (id<MLAdaptiveTriggerEndpoint>)endpointForControllerNumber:(uint16_t)number;

@end
