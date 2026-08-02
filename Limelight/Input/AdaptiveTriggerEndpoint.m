#import "AdaptiveTriggerEndpoint.h"

#include <string.h>

API_AVAILABLE(ios(15.4), tvos(15.4))
@implementation MLAppleAdaptiveTriggerEndpoint {
    GCDualSenseGamepad *_gamepad;
}

- (instancetype)initWithGamepad:(GCDualSenseGamepad *)gamepad
{
    self = [super init];
    if (self) {
        _gamepad = gamepad;
    }
    return self;
}

- (GCDualSenseAdaptiveTrigger *)triggerForSide:(MLAdaptiveTriggerSide)side
{
    NSAssert([NSThread isMainThread], @"GameController access must remain on the main queue");
    return side == MLAdaptiveTriggerSideLeft ? _gamepad.leftTrigger : _gamepad.rightTrigger;
}

- (void)applyEffect:(MLAdaptiveTriggerEffect)effect side:(MLAdaptiveTriggerSide)side
{
    GCDualSenseAdaptiveTrigger *trigger = [self triggerForSide:side];
    switch (effect.kind) {
        case MLAdaptiveTriggerOff:
            [trigger setModeOff];
            break;

        case MLAdaptiveTriggerFeedback: {
            GCDualSenseAdaptiveTriggerPositionalResistiveStrengths strengths = {};
            memcpy(strengths.values, effect.values, sizeof(strengths.values));
            [trigger setModeFeedbackWithResistiveStrengths:strengths];
            break;
        }

        case MLAdaptiveTriggerWeapon:
            [trigger setModeWeaponWithStartPosition:effect.start_position
                                       endPosition:effect.end_position
                                resistiveStrength:effect.strength];
            break;

        case MLAdaptiveTriggerVibration: {
            GCDualSenseAdaptiveTriggerPositionalAmplitudes amplitudes = {};
            memcpy(amplitudes.values, effect.values, sizeof(amplitudes.values));
            [trigger setModeVibrationWithAmplitudes:amplitudes frequency:effect.frequency];
            break;
        }

        case MLAdaptiveTriggerUnsupported:
        case MLAdaptiveTriggerMalformed:
            [trigger setModeOff];
            break;
    }
}

- (void)setOffForSide:(MLAdaptiveTriggerSide)side
{
    [[self triggerForSide:side] setModeOff];
}

- (void)setBothOff
{
    [[self triggerForSide:MLAdaptiveTriggerSideLeft] setModeOff];
    [[self triggerForSide:MLAdaptiveTriggerSideRight] setModeOff];
}

@end
