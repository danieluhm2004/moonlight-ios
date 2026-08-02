#include "AdaptiveTriggerDecoder.h"

#include <string.h>

#define ML_ADAPTIVE_TRIGGER_PAYLOAD_LENGTH 10
#define ML_ADAPTIVE_TRIGGER_ZONE_MASK 0x03FFu
#define ML_ADAPTIVE_TRIGGER_PACKED_MASK 0x3FFFFFFFu

static bool markMalformed(MLAdaptiveTriggerEffect *effect)
{
    effect->kind = MLAdaptiveTriggerMalformed;
    return false;
}

static bool bytesAreZero(const uint8_t *bytes, size_t length)
{
    for (size_t index = 0; index < length; index++) {
        if (bytes[index] != 0) {
            return false;
        }
    }

    return true;
}

static bool validatePositionProfile(uint16_t mask, uint32_t packed)
{
    if ((mask & ~ML_ADAPTIVE_TRIGGER_ZONE_MASK) != 0 ||
            (packed & ~ML_ADAPTIVE_TRIGGER_PACKED_MASK) != 0) {
        return false;
    }

    for (int index = 0; index < 10; index++) {
        uint32_t packedValue = (packed >> (3 * index)) & 0x07u;
        if ((mask & (1u << index)) == 0 && packedValue != 0) {
            return false;
        }
    }

    return true;
}

static void decodePositionProfile(uint16_t mask, uint32_t packed,
                                  MLAdaptiveTriggerEffect *effect)
{
    for (int index = 0; index < 10; index++) {
        effect->values[index] = (mask & (1u << index))
            ? (float)(((packed >> (3 * index)) & 0x07u) + 1u) / 8.0f
            : 0.0f;
    }
}

bool MLDecodeAdaptiveTrigger(uint8_t type, const uint8_t *payload,
                             size_t payload_length,
                             MLAdaptiveTriggerEffect *out_effect)
{
    if (out_effect == NULL) {
        return false;
    }

    memset(out_effect, 0, sizeof(*out_effect));

    if (payload == NULL || payload_length != ML_ADAPTIVE_TRIGGER_PAYLOAD_LENGTH) {
        return markMalformed(out_effect);
    }

    switch (type) {
        case 0x05:
            if (!bytesAreZero(payload, ML_ADAPTIVE_TRIGGER_PAYLOAD_LENGTH)) {
                return markMalformed(out_effect);
            }
            return true;

        case 0x21:
        case 0x26: {
            uint16_t mask = (uint16_t)payload[0] | ((uint16_t)payload[1] << 8);
            uint32_t packed = (uint32_t)payload[2]
                            | ((uint32_t)payload[3] << 8)
                            | ((uint32_t)payload[4] << 16)
                            | ((uint32_t)payload[5] << 24);
            bool reservedBytesAreZero = type == 0x21
                ? bytesAreZero(&payload[6], 4)
                : payload[6] == 0 && payload[7] == 0 && payload[9] == 0;

            if (!reservedBytesAreZero || !validatePositionProfile(mask, packed)) {
                return markMalformed(out_effect);
            }

            if (mask == 0 || (type == 0x26 && payload[8] == 0)) {
                return true;
            }

            out_effect->kind = type == 0x21
                ? MLAdaptiveTriggerFeedback
                : MLAdaptiveTriggerVibration;
            decodePositionProfile(mask, packed, out_effect);
            if (type == 0x26) {
                out_effect->frequency = (float)payload[8] / 255.0f;
            }
            return true;
        }

        case 0x25: {
            uint16_t mask = (uint16_t)payload[0] | ((uint16_t)payload[1] << 8);
            int start = -1;
            int end = -1;
            int setBitCount = 0;

            if ((mask & ~ML_ADAPTIVE_TRIGGER_ZONE_MASK) != 0 ||
                    payload[2] > 7 || !bytesAreZero(&payload[3], 7)) {
                return markMalformed(out_effect);
            }

            for (int index = 0; index < 10; index++) {
                if ((mask & (1u << index)) != 0) {
                    if (start < 0) {
                        start = index;
                    }
                    end = index;
                    setBitCount++;
                }
            }

            if (setBitCount != 2 || start < 2 || start > 7 ||
                    end <= start || end > 8) {
                return markMalformed(out_effect);
            }

            out_effect->kind = MLAdaptiveTriggerWeapon;
            out_effect->start_position = (float)start / 9.0f;
            out_effect->end_position = (float)end / 9.0f;
            out_effect->strength = (float)(payload[2] + 1u) / 8.0f;
            return true;
        }

        default:
            out_effect->kind = MLAdaptiveTriggerUnsupported;
            return false;
    }
}
