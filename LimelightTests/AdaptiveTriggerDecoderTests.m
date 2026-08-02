#import <XCTest/XCTest.h>

#include <math.h>
#include <string.h>

#import "AdaptiveTriggerDecoder.h"

typedef struct {
    const char *identifier;
    uint8_t type;
    uint8_t payload[10];
    bool expected_return;
    MLAdaptiveTriggerKind expected_kind;
    float values[10];
    float start_position;
    float end_position;
    float strength;
    float frequency;
} MLDecoderVector;

@interface AdaptiveTriggerDecoderTests : XCTestCase
@end

@implementation AdaptiveTriggerDecoderTests

- (void)assertEffect:(const MLAdaptiveTriggerEffect *)effect
              matches:(const MLDecoderVector *)vector
{
    XCTAssertEqual(effect->kind, vector->expected_kind, @"vector %s kind", vector->identifier);
    for (NSUInteger index = 0; index < 10; index++) {
        XCTAssertEqualWithAccuracy(effect->values[index], vector->values[index], 1e-6,
                                   @"vector %s value[%lu]", vector->identifier,
                                   (unsigned long)index);
    }
    XCTAssertEqualWithAccuracy(effect->start_position, vector->start_position, 1e-6,
                               @"vector %s start", vector->identifier);
    XCTAssertEqualWithAccuracy(effect->end_position, vector->end_position, 1e-6,
                               @"vector %s end", vector->identifier);
    XCTAssertEqualWithAccuracy(effect->strength, vector->strength, 1e-6,
                               @"vector %s strength", vector->identifier);
    XCTAssertEqualWithAccuracy(effect->frequency, vector->frequency, 1e-6,
                               @"vector %s frequency", vector->identifier);
}

- (void)assertMalformedType:(uint8_t)type payload:(const uint8_t[10])payload
{
    MLAdaptiveTriggerEffect effect;
    memset(&effect, 0xA5, sizeof(effect));

    XCTAssertFalse(MLDecodeAdaptiveTrigger(type, payload, 10, &effect));
    XCTAssertEqual(effect.kind, MLAdaptiveTriggerMalformed);
    for (NSUInteger index = 0; index < 10; index++) {
        XCTAssertEqualWithAccuracy(effect.values[index], 0.0, 1e-6);
    }
    XCTAssertEqualWithAccuracy(effect.start_position, 0.0, 1e-6);
    XCTAssertEqualWithAccuracy(effect.end_position, 0.0, 1e-6);
    XCTAssertEqualWithAccuracy(effect.strength, 0.0, 1e-6);
    XCTAssertEqualWithAccuracy(effect.frequency, 0.0, 1e-6);
}

- (void)testCanonicalVectorsAThroughP
{
    static const MLDecoderVector vectors[] = {
        { "A", 0x05, { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 },
          true, MLAdaptiveTriggerOff, { 0 }, 0, 0, 0, 0 },
        { "B", 0x21, { 0x24, 0x00, 0x80, 0x80, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00 },
          true, MLAdaptiveTriggerFeedback, { 0, 0, 3.0f / 8.0f, 0, 0, 1, 0, 0, 0, 0 }, 0, 0, 0, 0 },
        { "C", 0x21, { 0xF0, 0x03, 0x00, 0xD0, 0xB6, 0x2D, 0x00, 0x00, 0x00, 0x00 },
          true, MLAdaptiveTriggerFeedback, { 0, 0, 0, 0, 6.0f / 8.0f, 6.0f / 8.0f,
              6.0f / 8.0f, 6.0f / 8.0f, 6.0f / 8.0f, 6.0f / 8.0f }, 0, 0, 0, 0 },
        { "D", 0x21, { 0xFC, 0x03, 0x40, 0x34, 0xB6, 0x2D, 0x00, 0x00, 0x00, 0x00 },
          true, MLAdaptiveTriggerFeedback, { 0, 0, 2.0f / 8.0f, 3.0f / 8.0f,
              4.0f / 8.0f, 5.0f / 8.0f, 6.0f / 8.0f, 6.0f / 8.0f,
              6.0f / 8.0f, 6.0f / 8.0f }, 0, 0, 0, 0 },
        { "E", 0x25, { 0x84, 0x00, 0x05, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 },
          true, MLAdaptiveTriggerWeapon, { 0 }, 2.0f / 9.0f, 7.0f / 9.0f, 6.0f / 8.0f, 0 },
        { "F", 0x26, { 0xF8, 0x03, 0x00, 0xB6, 0x6D, 0x1B, 0x00, 0x00, 0x80, 0x00 },
          true, MLAdaptiveTriggerVibration, { 0, 0, 0, 4.0f / 8.0f, 4.0f / 8.0f,
              4.0f / 8.0f, 4.0f / 8.0f, 4.0f / 8.0f, 4.0f / 8.0f,
              4.0f / 8.0f }, 0, 0, 0, 128.0f / 255.0f },
        { "G", 0x25, { 0x04, 0x00, 0x05, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 },
          false, MLAdaptiveTriggerMalformed, { 0 }, 0, 0, 0, 0 },
        { "H", 0x26, { 0xF8, 0x03, 0x00, 0xB6, 0x6D, 0x1B, 0x00, 0x00, 0x00, 0x00 },
          true, MLAdaptiveTriggerOff, { 0 }, 0, 0, 0, 0 },
        { "I", 0x22, { 0x04, 0x01, 0x15, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 },
          false, MLAdaptiveTriggerUnsupported, { 0 }, 0, 0, 0, 0 },
        { "J", 0x99, { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 },
          false, MLAdaptiveTriggerUnsupported, { 0 }, 0, 0, 0, 0 },
        { "K", 0x00, { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 },
          false, MLAdaptiveTriggerUnsupported, { 0 }, 0, 0, 0, 0 },
        { "L", 0x21, { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 },
          true, MLAdaptiveTriggerOff, { 0 }, 0, 0, 0, 0 },
        { "M", 0x21, { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00 },
          false, MLAdaptiveTriggerMalformed, { 0 }, 0, 0, 0, 0 },
        { "N", 0x26, { 0xF8, 0x03, 0x00, 0xB6, 0x6D, 0x1B, 0x01, 0x00, 0x00, 0x00 },
          false, MLAdaptiveTriggerMalformed, { 0 }, 0, 0, 0, 0 },
        { "O", 0x25, { 0x84, 0x00, 0x85, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 },
          false, MLAdaptiveTriggerMalformed, { 0 }, 0, 0, 0, 0 },
        { "P", 0xFC, { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 },
          false, MLAdaptiveTriggerUnsupported, { 0 }, 0, 0, 0, 0 },
    };

    for (NSUInteger index = 0; index < sizeof(vectors) / sizeof(vectors[0]); index++) {
        const MLDecoderVector *vector = &vectors[index];
        MLAdaptiveTriggerEffect effect;
        memset(&effect, 0xA5, sizeof(effect));

        bool decoded = MLDecodeAdaptiveTrigger(vector->type, vector->payload, 10, &effect);

        XCTAssertEqual(decoded, vector->expected_return, @"vector %s return", vector->identifier);
        [self assertEffect:&effect matches:vector];
    }
}

- (void)testRejectsNilAndNonCanonicalPayloadLengths
{
    const uint8_t payload[11] = { 0 };
    MLAdaptiveTriggerEffect effect;

    memset(&effect, 0xA5, sizeof(effect));
    XCTAssertFalse(MLDecodeAdaptiveTrigger(0x05, NULL, 10, &effect));
    XCTAssertEqual(effect.kind, MLAdaptiveTriggerMalformed);
    XCTAssertEqualWithAccuracy(effect.values[0], 0.0, 1e-6);

    memset(&effect, 0xA5, sizeof(effect));
    XCTAssertFalse(MLDecodeAdaptiveTrigger(0x05, payload, 9, &effect));
    XCTAssertEqual(effect.kind, MLAdaptiveTriggerMalformed);
    XCTAssertEqualWithAccuracy(effect.values[0], 0.0, 1e-6);

    memset(&effect, 0xA5, sizeof(effect));
    XCTAssertFalse(MLDecodeAdaptiveTrigger(0x05, payload, 11, &effect));
    XCTAssertEqual(effect.kind, MLAdaptiveTriggerMalformed);
    XCTAssertEqualWithAccuracy(effect.values[0], 0.0, 1e-6);

    XCTAssertFalse(MLDecodeAdaptiveTrigger(0x05, payload, 10, NULL));
}

- (void)testRejectsInvalidMasksAndPackedValues
{
    const uint8_t highMaskBit[10] = { 0x00, 0x04, 0x00, 0x00, 0x00, 0x00, 0, 0, 0, 0 };
    const uint8_t highPackedBit[10] = { 0x00, 0x00, 0x00, 0x00, 0x00, 0x40, 0, 0, 0, 0 };
    const uint8_t inactivePackedZone[10] = { 0x04, 0x00, 0x00, 0x02, 0x00, 0x00, 0, 0, 0, 0 };

    [self assertMalformedType:0x21 payload:highMaskBit];
    [self assertMalformedType:0x26 payload:highMaskBit];
    [self assertMalformedType:0x21 payload:highPackedBit];
    [self assertMalformedType:0x26 payload:highPackedBit];
    [self assertMalformedType:0x21 payload:inactivePackedZone];
    [self assertMalformedType:0x26 payload:inactivePackedZone];
}

- (void)testRejectsReservedBytesForEveryCanonicalType
{
    const uint8_t offReserved[10] = { 0x01, 0, 0, 0, 0, 0, 0, 0, 0, 0 };
    const uint8_t feedbackReserved[10] = { 0, 0, 0, 0, 0, 0, 0x01, 0, 0, 0 };
    const uint8_t weaponReserved[10] = { 0x84, 0, 0x05, 0x01, 0, 0, 0, 0, 0, 0 };
    const uint8_t vibrationReserved6[10] = { 0, 0, 0, 0, 0, 0, 0x01, 0, 0, 0 };
    const uint8_t vibrationReserved7[10] = { 0, 0, 0, 0, 0, 0, 0, 0x01, 0, 0 };
    const uint8_t vibrationReserved9[10] = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0x01 };

    [self assertMalformedType:0x05 payload:offReserved];
    [self assertMalformedType:0x21 payload:feedbackReserved];
    [self assertMalformedType:0x25 payload:weaponReserved];
    [self assertMalformedType:0x26 payload:vibrationReserved6];
    [self assertMalformedType:0x26 payload:vibrationReserved7];
    [self assertMalformedType:0x26 payload:vibrationReserved9];
}

- (void)testRejectsNonCanonicalWeaponProfiles
{
    const uint8_t oneBit[10] = { 0x04, 0x00, 0x05, 0, 0, 0, 0, 0, 0, 0 };
    const uint8_t threeBits[10] = { 0x1C, 0x00, 0x05, 0, 0, 0, 0, 0, 0, 0 };
    const uint8_t startBeforeTwo[10] = { 0x06, 0x00, 0x05, 0, 0, 0, 0, 0, 0, 0 };
    const uint8_t endAfterEight[10] = { 0x80, 0x02, 0x05, 0, 0, 0, 0, 0, 0, 0 };
    const uint8_t highStrengthBit[10] = { 0x84, 0x00, 0x08, 0, 0, 0, 0, 0, 0, 0 };
    const uint8_t highMaskBit[10] = { 0x04, 0x04, 0x05, 0, 0, 0, 0, 0, 0, 0 };

    [self assertMalformedType:0x25 payload:oneBit];
    [self assertMalformedType:0x25 payload:threeBits];
    [self assertMalformedType:0x25 payload:startBeforeTwo];
    [self assertMalformedType:0x25 payload:endAfterEight];
    [self assertMalformedType:0x25 payload:highStrengthBit];
    [self assertMalformedType:0x25 payload:highMaskBit];
}

- (void)testDeterministicFuzzAcrossAllTypes
{
    uint32_t state = 0xC0DEC0DEu;

    for (NSUInteger round = 0; round < 16; round++) {
        for (NSUInteger type = 0; type <= UINT8_MAX; type++) {
            uint8_t payload[10];
            for (NSUInteger index = 0; index < sizeof(payload); index++) {
                state = state * 1664525u + 1013904223u;
                payload[index] = (uint8_t)(state >> 24);
            }

            MLAdaptiveTriggerEffect effect;
            memset(&effect, 0xA5, sizeof(effect));
            bool decoded = MLDecodeAdaptiveTrigger((uint8_t)type, payload, sizeof(payload), &effect);

            XCTAssertGreaterThanOrEqual(effect.kind, MLAdaptiveTriggerOff);
            XCTAssertLessThanOrEqual(effect.kind, MLAdaptiveTriggerMalformed);
            if (decoded) {
                XCTAssertTrue(effect.kind == MLAdaptiveTriggerOff ||
                              effect.kind == MLAdaptiveTriggerFeedback ||
                              effect.kind == MLAdaptiveTriggerWeapon ||
                              effect.kind == MLAdaptiveTriggerVibration);
            } else {
                XCTAssertTrue(effect.kind == MLAdaptiveTriggerUnsupported ||
                              effect.kind == MLAdaptiveTriggerMalformed);
            }

            for (NSUInteger index = 0; index < 10; index++) {
                XCTAssertTrue(isfinite(effect.values[index]));
                XCTAssertGreaterThanOrEqual(effect.values[index], 0.0f);
                XCTAssertLessThanOrEqual(effect.values[index], 1.0f);
            }
            const float scalarValues[] = {
                effect.start_position,
                effect.end_position,
                effect.strength,
                effect.frequency,
            };
            for (NSUInteger index = 0; index < sizeof(scalarValues) / sizeof(scalarValues[0]); index++) {
                XCTAssertTrue(isfinite(scalarValues[index]));
                XCTAssertGreaterThanOrEqual(scalarValues[index], 0.0f);
                XCTAssertLessThanOrEqual(scalarValues[index], 1.0f);
            }
        }
    }
}

@end
