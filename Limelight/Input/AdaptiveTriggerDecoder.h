#ifndef AdaptiveTriggerDecoder_h
#define AdaptiveTriggerDecoder_h

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    MLAdaptiveTriggerOff,
    MLAdaptiveTriggerFeedback,
    MLAdaptiveTriggerWeapon,
    MLAdaptiveTriggerVibration,
    MLAdaptiveTriggerUnsupported,
    MLAdaptiveTriggerMalformed,
} MLAdaptiveTriggerKind;

typedef struct {
    MLAdaptiveTriggerKind kind;
    float values[10];
    float start_position;
    float end_position;
    float strength;
    float frequency;
} MLAdaptiveTriggerEffect;

bool MLDecodeAdaptiveTrigger(uint8_t type, const uint8_t *payload,
                             size_t payload_length,
                             MLAdaptiveTriggerEffect *out_effect);

#ifdef __cplusplus
}
#endif

#endif /* AdaptiveTriggerDecoder_h */
