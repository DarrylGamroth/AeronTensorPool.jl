/* Generated SBE (Simple Binary Encoding) message codec */

#ifndef _SHM_TENSORPOOL_CONTROL_SHMPOOLANNOUNCE_H_
#define _SHM_TENSORPOOL_CONTROL_SHMPOOLANNOUNCE_H_

#include <errno.h>
#if !defined(__STDC_LIMIT_MACROS)
#define __STDC_LIMIT_MACROS 1
#endif
#include <limits.h>
#define SBE_FLOAT_NAN NAN
#define SBE_DOUBLE_NAN NAN
#include <math.h>
#include <stdbool.h>
#include <stdint.h>
#include <string.h>

#include "progressUnit.h"
#include "responseCode.h"
#include "regionType.h"
#include "messageHeader.h"
#include "mode.h"
#include "dtype.h"
#include "groupSizeEncoding.h"
#include "varAsciiEncoding.h"
#include "varDataEncoding.h"
#include "bool.h"
#include "frameProgressState.h"
#include "clockDomain.h"
#include "majorOrder.h"

#ifdef __cplusplus
#define SBE_ONE_DEF inline
#else
#define SBE_ONE_DEF static inline
#endif

/*
 * Define some byte ordering macros
 */
#if defined(WIN32) || defined(_WIN32)
    #define SBE_BIG_ENDIAN_ENCODE_16(v) _byteswap_ushort(v)
    #define SBE_BIG_ENDIAN_ENCODE_32(v) _byteswap_ulong(v)
    #define SBE_BIG_ENDIAN_ENCODE_64(v) _byteswap_uint64(v)
    #define SBE_LITTLE_ENDIAN_ENCODE_16(v) (v)
    #define SBE_LITTLE_ENDIAN_ENCODE_32(v) (v)
    #define SBE_LITTLE_ENDIAN_ENCODE_64(v) (v)
#elif __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
    #define SBE_BIG_ENDIAN_ENCODE_16(v) __builtin_bswap16(v)
    #define SBE_BIG_ENDIAN_ENCODE_32(v) __builtin_bswap32(v)
    #define SBE_BIG_ENDIAN_ENCODE_64(v) __builtin_bswap64(v)
    #define SBE_LITTLE_ENDIAN_ENCODE_16(v) (v)
    #define SBE_BIG_ENDIAN_ENCODE_32(v) __builtin_bswap32(v)
    #define SBE_BIG_ENDIAN_ENCODE_64(v) __builtin_bswap64(v)
    #define SBE_LITTLE_ENDIAN_ENCODE_16(v) (v)
    #define SBE_LITTLE_ENDIAN_ENCODE_32(v) (v)
    #define SBE_LITTLE_ENDIAN_ENCODE_64(v) (v)
#elif __BYTE_ORDER__ == __ORDER_BIG_ENDIAN__
    #define SBE_LITTLE_ENDIAN_ENCODE_16(v) __builtin_bswap16(v)
    #define SBE_LITTLE_ENDIAN_ENCODE_32(v) __builtin_bswap32(v)
    #define SBE_LITTLE_ENDIAN_ENCODE_64(v) __builtin_bswap64(v)
    #define SBE_BIG_ENDIAN_ENCODE_16(v) (v)
    #define SBE_BIG_ENDIAN_ENCODE_32(v) (v)
    #define SBE_BIG_ENDIAN_ENCODE_64(v) (v)
#else
    #error "Byte Ordering of platform not determined. Set __BYTE_ORDER__ manually before including this file."
#endif

#if !defined(SBE_BOUNDS_CHECK_EXPECT)
#  if defined(SBE_NO_BOUNDS_CHECK)
#    define SBE_BOUNDS_CHECK_EXPECT(exp, c) (false)
#  elif defined(_MSC_VER)
#    define SBE_BOUNDS_CHECK_EXPECT(exp, c) (exp)
#  else 
#    define SBE_BOUNDS_CHECK_EXPECT(exp, c) (__builtin_expect(exp, c))
#  endif

#endif

#define SBE_NULLVALUE_INT8 INT8_MIN
#define SBE_NULLVALUE_INT16 INT16_MIN
#define SBE_NULLVALUE_INT32 INT32_MIN
#define SBE_NULLVALUE_INT64 INT64_MIN
#define SBE_NULLVALUE_UINT8 UINT8_MAX
#define SBE_NULLVALUE_UINT16 UINT16_MAX
#define SBE_NULLVALUE_UINT32 UINT32_MAX
#define SBE_NULLVALUE_UINT64 UINT64_MAX

#define E100 -50100 // E_BUF_SHORT
#define E103 -50103 // VAL_UNKNOWN_ENUM
#define E104 -50104 // I_OUT_RANGE_NUM
#define E105 -50105 // I_OUT_RANGE_NUM
#define E106 -50106 // I_OUT_RANGE_NUM
#define E107 -50107 // BUF_SHORT_FLYWEIGHT
#define E108 -50108 // BUF_SHORT_NXT_GRP_IND
#define E109 -50109 // STR_TOO_LONG_FOR_LEN_TYP
#define E110 -50110 // CNT_OUT_RANGE

#ifndef SBE_STRERROR_DEFINED
#define SBE_STRERROR_DEFINED
SBE_ONE_DEF const char *sbe_strerror(const int errnum)
{
    switch (errnum)
    {
        case E100:
            return "buffer too short";
        case E103:
            return "unknown value for enum";
        case E104:
            return "index out of range";
        case E105:
            return "index out of range";
        case E106:
            return "length too large";
        case E107:
            return "buffer too short for flyweight";
        case E108:
            return "buffer too short to support next group index";
        case E109:
            return "std::string too long for length type";
        case E110:
            return "count outside of allowed range";
        default:
            return "unknown error";
    }
}
#endif

struct shm_tensorpool_control_shmPoolAnnounce
{
    char *buffer;
    uint64_t buffer_length;
    uint64_t offset;
    uint64_t position;
    uint64_t acting_block_length;
    uint64_t acting_version;
};

enum shm_tensorpool_control_shmPoolAnnounce_meta_attribute
{
    shm_tensorpool_control_shmPoolAnnounce_meta_attribute_EPOCH,
    shm_tensorpool_control_shmPoolAnnounce_meta_attribute_TIME_UNIT,
    shm_tensorpool_control_shmPoolAnnounce_meta_attribute_SEMANTIC_TYPE,
    shm_tensorpool_control_shmPoolAnnounce_meta_attribute_PRESENCE
};

union shm_tensorpool_control_shmPoolAnnounce_float_as_uint
{
    float fp_value;
    uint32_t uint_value;
};

union shm_tensorpool_control_shmPoolAnnounce_double_as_uint
{
    double fp_value;
    uint64_t uint_value;
};

struct shm_tensorpool_control_shmPoolAnnounce_string_view
{
    const char* data;
    size_t length;
};

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmPoolAnnounce_sbe_position(
    const struct shm_tensorpool_control_shmPoolAnnounce *const codec)
{
    return codec->position;
}

SBE_ONE_DEF bool shm_tensorpool_control_shmPoolAnnounce_set_sbe_position(
    struct shm_tensorpool_control_shmPoolAnnounce *const codec,
    const uint64_t position)
{
    if (SBE_BOUNDS_CHECK_EXPECT((position > codec->buffer_length), false))
    {
        errno = E100;
        return false;
    }
    codec->position = position;

    return true;
}

SBE_ONE_DEF uint64_t *shm_tensorpool_control_shmPoolAnnounce_sbe_position_ptr(
    struct shm_tensorpool_control_shmPoolAnnounce *const codec)
{
    return &codec->position;
}

SBE_ONE_DEF struct shm_tensorpool_control_shmPoolAnnounce *shm_tensorpool_control_shmPoolAnnounce_reset(
    struct shm_tensorpool_control_shmPoolAnnounce *const codec,
    char *buffer,
    const uint64_t offset,
    const uint64_t buffer_length,
    const uint64_t acting_block_length,
    const uint64_t acting_version)
{
    codec->buffer = buffer;
    codec->offset = offset;
    codec->buffer_length = buffer_length;
    codec->acting_block_length = acting_block_length;
    codec->acting_version = acting_version;
    if (!shm_tensorpool_control_shmPoolAnnounce_set_sbe_position(codec, offset + acting_block_length))
    {
        return NULL;
    }

    return codec;
}

SBE_ONE_DEF struct shm_tensorpool_control_shmPoolAnnounce *shm_tensorpool_control_shmPoolAnnounce_copy(
    struct shm_tensorpool_control_shmPoolAnnounce *const codec,
    const struct shm_tensorpool_control_shmPoolAnnounce *const other)
{
     codec->buffer = other->buffer;
     codec->offset = other->offset;
     codec->buffer_length = other->buffer_length;
     codec->acting_block_length = other->acting_block_length;
     codec->acting_version = other->acting_version;
     codec->position = other->position;

     return codec;
}

SBE_ONE_DEF uint16_t shm_tensorpool_control_shmPoolAnnounce_sbe_block_length(void)
{
    return (uint16_t)35;
}

#define SHM_TENSORPOOL_CONTROL_SHM_POOL_ANNOUNCE_SBE_TEMPLATE_ID (uint16_t)1

SBE_ONE_DEF uint16_t shm_tensorpool_control_shmPoolAnnounce_sbe_template_id(void)
{
    return (uint16_t)1;
}

SBE_ONE_DEF uint16_t shm_tensorpool_control_shmPoolAnnounce_sbe_schema_id(void)
{
    return (uint16_t)900;
}

SBE_ONE_DEF uint16_t shm_tensorpool_control_shmPoolAnnounce_sbe_schema_version(void)
{
    return (uint16_t)1;
}

SBE_ONE_DEF const char* shm_tensorpool_control_shmPoolAnnounce_sbe_semantic_version(void)
{
    return "1.1";
}

SBE_ONE_DEF const char *shm_tensorpool_control_shmPoolAnnounce_sbe_semantic_type(void)
{
    return "";
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmPoolAnnounce_offset(
    const struct shm_tensorpool_control_shmPoolAnnounce *const codec)
{
    return codec->offset;
}

SBE_ONE_DEF struct shm_tensorpool_control_shmPoolAnnounce *shm_tensorpool_control_shmPoolAnnounce_wrap_and_apply_header(
    struct shm_tensorpool_control_shmPoolAnnounce *const codec,
    char *buffer,
    const uint64_t offset,
    const uint64_t buffer_length,
    struct shm_tensorpool_control_messageHeader *const hdr)
{
    shm_tensorpool_control_messageHeader_wrap(
        hdr, buffer + offset, 0, shm_tensorpool_control_messageHeader_sbe_schema_version(), buffer_length);

    shm_tensorpool_control_messageHeader_set_blockLength(hdr, shm_tensorpool_control_shmPoolAnnounce_sbe_block_length());
    shm_tensorpool_control_messageHeader_set_templateId(hdr, shm_tensorpool_control_shmPoolAnnounce_sbe_template_id());
    shm_tensorpool_control_messageHeader_set_schemaId(hdr, shm_tensorpool_control_shmPoolAnnounce_sbe_schema_id());
    shm_tensorpool_control_messageHeader_set_version(hdr, shm_tensorpool_control_shmPoolAnnounce_sbe_schema_version());

    shm_tensorpool_control_shmPoolAnnounce_reset(
        codec,
        buffer + offset + shm_tensorpool_control_messageHeader_encoded_length(),
        0,
        buffer_length - shm_tensorpool_control_messageHeader_encoded_length(),
        shm_tensorpool_control_shmPoolAnnounce_sbe_block_length(),
        shm_tensorpool_control_shmPoolAnnounce_sbe_schema_version());

    return codec;
}

SBE_ONE_DEF struct shm_tensorpool_control_shmPoolAnnounce *shm_tensorpool_control_shmPoolAnnounce_wrap_for_encode(
    struct shm_tensorpool_control_shmPoolAnnounce *const codec,
    char *buffer,
    const uint64_t offset,
    const uint64_t buffer_length)
{
    return shm_tensorpool_control_shmPoolAnnounce_reset(
        codec,
        buffer,
        offset,
        buffer_length,
        shm_tensorpool_control_shmPoolAnnounce_sbe_block_length(),
        shm_tensorpool_control_shmPoolAnnounce_sbe_schema_version());
}

SBE_ONE_DEF struct shm_tensorpool_control_shmPoolAnnounce *shm_tensorpool_control_shmPoolAnnounce_wrap_for_decode(
    struct shm_tensorpool_control_shmPoolAnnounce *const codec,
    char *buffer,
    const uint64_t offset,
    const uint64_t acting_block_length,
    const uint64_t acting_version,
    const uint64_t buffer_length)
{
    return shm_tensorpool_control_shmPoolAnnounce_reset(
        codec,
        buffer,
        offset,
        buffer_length,
        acting_block_length,
        acting_version);
}

SBE_ONE_DEF struct shm_tensorpool_control_shmPoolAnnounce *shm_tensorpool_control_shmPoolAnnounce_sbe_rewind(
    struct shm_tensorpool_control_shmPoolAnnounce *const codec)
{
    return shm_tensorpool_control_shmPoolAnnounce_wrap_for_decode(
        codec,
        codec->buffer,
        codec->offset,
        codec->acting_block_length,
        codec->acting_version,
        codec->buffer_length);
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmPoolAnnounce_encoded_length(
    const struct shm_tensorpool_control_shmPoolAnnounce *const codec)
{
    return shm_tensorpool_control_shmPoolAnnounce_sbe_position(codec) - codec->offset;
}

SBE_ONE_DEF const char *shm_tensorpool_control_shmPoolAnnounce_buffer(
    const struct shm_tensorpool_control_shmPoolAnnounce *const codec)
{
    return codec->buffer;
}

SBE_ONE_DEF char *shm_tensorpool_control_shmPoolAnnounce_mut_buffer(
    struct shm_tensorpool_control_shmPoolAnnounce *const codec)
{
    return codec->buffer;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmPoolAnnounce_buffer_length(
    const struct shm_tensorpool_control_shmPoolAnnounce *const codec)
{
    return codec->buffer_length;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmPoolAnnounce_acting_version(
    const struct shm_tensorpool_control_shmPoolAnnounce *const codec)
{
    return codec->acting_version;
}

SBE_ONE_DEF const char *shm_tensorpool_control_shmPoolAnnounce_streamId_meta_attribute(
    const enum shm_tensorpool_control_shmPoolAnnounce_meta_attribute attribute)
{
    switch (attribute)
    {
        case shm_tensorpool_control_shmPoolAnnounce_meta_attribute_EPOCH: return "";
        case shm_tensorpool_control_shmPoolAnnounce_meta_attribute_TIME_UNIT: return "";
        case shm_tensorpool_control_shmPoolAnnounce_meta_attribute_SEMANTIC_TYPE: return "";
        case shm_tensorpool_control_shmPoolAnnounce_meta_attribute_PRESENCE: return "required";
    }

    return "";
}

SBE_ONE_DEF uint16_t shm_tensorpool_control_shmPoolAnnounce_streamId_id(void)
{
    return 1;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmPoolAnnounce_streamId_since_version(void)
{
    return 0;
}

SBE_ONE_DEF bool shm_tensorpool_control_shmPoolAnnounce_streamId_in_acting_version(
    const struct shm_tensorpool_control_shmPoolAnnounce *const codec)
{
#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wtautological-compare"
#endif
    return codec->acting_version >= shm_tensorpool_control_shmPoolAnnounce_streamId_since_version();
#if defined(__clang__)
#pragma clang diagnostic pop
#endif
}

SBE_ONE_DEF size_t shm_tensorpool_control_shmPoolAnnounce_streamId_encoding_offset(void)
{
    return 0;
}

SBE_ONE_DEF uint32_t shm_tensorpool_control_shmPoolAnnounce_streamId_null_value(void)
{
    return SBE_NULLVALUE_UINT32;
}

SBE_ONE_DEF uint32_t shm_tensorpool_control_shmPoolAnnounce_streamId_min_value(void)
{
    return UINT32_C(0x0);
}

SBE_ONE_DEF uint32_t shm_tensorpool_control_shmPoolAnnounce_streamId_max_value(void)
{
    return UINT32_C(0xfffffffe);
}

SBE_ONE_DEF size_t shm_tensorpool_control_shmPoolAnnounce_streamId_encoding_length(void)
{
    return 4;
}

SBE_ONE_DEF uint32_t shm_tensorpool_control_shmPoolAnnounce_streamId(
    const struct shm_tensorpool_control_shmPoolAnnounce *const codec)
{
    uint32_t val;
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
#endif
    memcpy(&val, codec->buffer + codec->offset + 0, sizeof(uint32_t));
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic pop
#endif
    return SBE_LITTLE_ENDIAN_ENCODE_32(val);
}

SBE_ONE_DEF struct shm_tensorpool_control_shmPoolAnnounce *shm_tensorpool_control_shmPoolAnnounce_set_streamId(
    struct shm_tensorpool_control_shmPoolAnnounce *const codec,
    const uint32_t value)
{
    uint32_t val = SBE_LITTLE_ENDIAN_ENCODE_32(value);
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
#endif
    memcpy(codec->buffer + codec->offset + 0, &val, sizeof(uint32_t));
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic pop
#endif
    return codec;
}

SBE_ONE_DEF const char *shm_tensorpool_control_shmPoolAnnounce_producerId_meta_attribute(
    const enum shm_tensorpool_control_shmPoolAnnounce_meta_attribute attribute)
{
    switch (attribute)
    {
        case shm_tensorpool_control_shmPoolAnnounce_meta_attribute_EPOCH: return "";
        case shm_tensorpool_control_shmPoolAnnounce_meta_attribute_TIME_UNIT: return "";
        case shm_tensorpool_control_shmPoolAnnounce_meta_attribute_SEMANTIC_TYPE: return "";
        case shm_tensorpool_control_shmPoolAnnounce_meta_attribute_PRESENCE: return "required";
    }

    return "";
}

SBE_ONE_DEF uint16_t shm_tensorpool_control_shmPoolAnnounce_producerId_id(void)
{
    return 2;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmPoolAnnounce_producerId_since_version(void)
{
    return 0;
}

SBE_ONE_DEF bool shm_tensorpool_control_shmPoolAnnounce_producerId_in_acting_version(
    const struct shm_tensorpool_control_shmPoolAnnounce *const codec)
{
#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wtautological-compare"
#endif
    return codec->acting_version >= shm_tensorpool_control_shmPoolAnnounce_producerId_since_version();
#if defined(__clang__)
#pragma clang diagnostic pop
#endif
}

SBE_ONE_DEF size_t shm_tensorpool_control_shmPoolAnnounce_producerId_encoding_offset(void)
{
    return 4;
}

SBE_ONE_DEF uint32_t shm_tensorpool_control_shmPoolAnnounce_producerId_null_value(void)
{
    return SBE_NULLVALUE_UINT32;
}

SBE_ONE_DEF uint32_t shm_tensorpool_control_shmPoolAnnounce_producerId_min_value(void)
{
    return UINT32_C(0x0);
}

SBE_ONE_DEF uint32_t shm_tensorpool_control_shmPoolAnnounce_producerId_max_value(void)
{
    return UINT32_C(0xfffffffe);
}

SBE_ONE_DEF size_t shm_tensorpool_control_shmPoolAnnounce_producerId_encoding_length(void)
{
    return 4;
}

SBE_ONE_DEF uint32_t shm_tensorpool_control_shmPoolAnnounce_producerId(
    const struct shm_tensorpool_control_shmPoolAnnounce *const codec)
{
    uint32_t val;
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
#endif
    memcpy(&val, codec->buffer + codec->offset + 4, sizeof(uint32_t));
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic pop
#endif
    return SBE_LITTLE_ENDIAN_ENCODE_32(val);
}

SBE_ONE_DEF struct shm_tensorpool_control_shmPoolAnnounce *shm_tensorpool_control_shmPoolAnnounce_set_producerId(
    struct shm_tensorpool_control_shmPoolAnnounce *const codec,
    const uint32_t value)
{
    uint32_t val = SBE_LITTLE_ENDIAN_ENCODE_32(value);
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
#endif
    memcpy(codec->buffer + codec->offset + 4, &val, sizeof(uint32_t));
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic pop
#endif
    return codec;
}

SBE_ONE_DEF const char *shm_tensorpool_control_shmPoolAnnounce_epoch_meta_attribute(
    const enum shm_tensorpool_control_shmPoolAnnounce_meta_attribute attribute)
{
    switch (attribute)
    {
        case shm_tensorpool_control_shmPoolAnnounce_meta_attribute_EPOCH: return "";
        case shm_tensorpool_control_shmPoolAnnounce_meta_attribute_TIME_UNIT: return "";
        case shm_tensorpool_control_shmPoolAnnounce_meta_attribute_SEMANTIC_TYPE: return "";
        case shm_tensorpool_control_shmPoolAnnounce_meta_attribute_PRESENCE: return "required";
    }

    return "";
}

SBE_ONE_DEF uint16_t shm_tensorpool_control_shmPoolAnnounce_epoch_id(void)
{
    return 3;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmPoolAnnounce_epoch_since_version(void)
{
    return 0;
}

SBE_ONE_DEF bool shm_tensorpool_control_shmPoolAnnounce_epoch_in_acting_version(
    const struct shm_tensorpool_control_shmPoolAnnounce *const codec)
{
#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wtautological-compare"
#endif
    return codec->acting_version >= shm_tensorpool_control_shmPoolAnnounce_epoch_since_version();
#if defined(__clang__)
#pragma clang diagnostic pop
#endif
}

SBE_ONE_DEF size_t shm_tensorpool_control_shmPoolAnnounce_epoch_encoding_offset(void)
{
    return 8;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmPoolAnnounce_epoch_null_value(void)
{
    return SBE_NULLVALUE_UINT64;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmPoolAnnounce_epoch_min_value(void)
{
    return UINT64_C(0x0);
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmPoolAnnounce_epoch_max_value(void)
{
    return UINT64_C(0xfffffffffffffffe);
}

SBE_ONE_DEF size_t shm_tensorpool_control_shmPoolAnnounce_epoch_encoding_length(void)
{
    return 8;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmPoolAnnounce_epoch(
    const struct shm_tensorpool_control_shmPoolAnnounce *const codec)
{
    uint64_t val;
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
#endif
    memcpy(&val, codec->buffer + codec->offset + 8, sizeof(uint64_t));
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic pop
#endif
    return SBE_LITTLE_ENDIAN_ENCODE_64(val);
}

SBE_ONE_DEF struct shm_tensorpool_control_shmPoolAnnounce *shm_tensorpool_control_shmPoolAnnounce_set_epoch(
    struct shm_tensorpool_control_shmPoolAnnounce *const codec,
    const uint64_t value)
{
    uint64_t val = SBE_LITTLE_ENDIAN_ENCODE_64(value);
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
#endif
    memcpy(codec->buffer + codec->offset + 8, &val, sizeof(uint64_t));
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic pop
#endif
    return codec;
}

SBE_ONE_DEF const char *shm_tensorpool_control_shmPoolAnnounce_announceTimestampNs_meta_attribute(
    const enum shm_tensorpool_control_shmPoolAnnounce_meta_attribute attribute)
{
    switch (attribute)
    {
        case shm_tensorpool_control_shmPoolAnnounce_meta_attribute_EPOCH: return "";
        case shm_tensorpool_control_shmPoolAnnounce_meta_attribute_TIME_UNIT: return "";
        case shm_tensorpool_control_shmPoolAnnounce_meta_attribute_SEMANTIC_TYPE: return "";
        case shm_tensorpool_control_shmPoolAnnounce_meta_attribute_PRESENCE: return "required";
    }

    return "";
}

SBE_ONE_DEF uint16_t shm_tensorpool_control_shmPoolAnnounce_announceTimestampNs_id(void)
{
    return 4;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmPoolAnnounce_announceTimestampNs_since_version(void)
{
    return 0;
}

SBE_ONE_DEF bool shm_tensorpool_control_shmPoolAnnounce_announceTimestampNs_in_acting_version(
    const struct shm_tensorpool_control_shmPoolAnnounce *const codec)
{
#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wtautological-compare"
#endif
    return codec->acting_version >= shm_tensorpool_control_shmPoolAnnounce_announceTimestampNs_since_version();
#if defined(__clang__)
#pragma clang diagnostic pop
#endif
}

SBE_ONE_DEF size_t shm_tensorpool_control_shmPoolAnnounce_announceTimestampNs_encoding_offset(void)
{
    return 16;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmPoolAnnounce_announceTimestampNs_null_value(void)
{
    return SBE_NULLVALUE_UINT64;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmPoolAnnounce_announceTimestampNs_min_value(void)
{
    return UINT64_C(0x0);
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmPoolAnnounce_announceTimestampNs_max_value(void)
{
    return UINT64_C(0xfffffffffffffffe);
}

SBE_ONE_DEF size_t shm_tensorpool_control_shmPoolAnnounce_announceTimestampNs_encoding_length(void)
{
    return 8;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmPoolAnnounce_announceTimestampNs(
    const struct shm_tensorpool_control_shmPoolAnnounce *const codec)
{
    uint64_t val;
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
#endif
    memcpy(&val, codec->buffer + codec->offset + 16, sizeof(uint64_t));
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic pop
#endif
    return SBE_LITTLE_ENDIAN_ENCODE_64(val);
}

SBE_ONE_DEF struct shm_tensorpool_control_shmPoolAnnounce *shm_tensorpool_control_shmPoolAnnounce_set_announceTimestampNs(
    struct shm_tensorpool_control_shmPoolAnnounce *const codec,
    const uint64_t value)
{
    uint64_t val = SBE_LITTLE_ENDIAN_ENCODE_64(value);
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
#endif
    memcpy(codec->buffer + codec->offset + 16, &val, sizeof(uint64_t));
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic pop
#endif
    return codec;
}

SBE_ONE_DEF const char *shm_tensorpool_control_shmPoolAnnounce_announceClockDomain_meta_attribute(
    const enum shm_tensorpool_control_shmPoolAnnounce_meta_attribute attribute)
{
    switch (attribute)
    {
        case shm_tensorpool_control_shmPoolAnnounce_meta_attribute_EPOCH: return "";
        case shm_tensorpool_control_shmPoolAnnounce_meta_attribute_TIME_UNIT: return "";
        case shm_tensorpool_control_shmPoolAnnounce_meta_attribute_SEMANTIC_TYPE: return "";
        case shm_tensorpool_control_shmPoolAnnounce_meta_attribute_PRESENCE: return "required";
    }

    return "";
}

SBE_ONE_DEF uint16_t shm_tensorpool_control_shmPoolAnnounce_announceClockDomain_id(void)
{
    return 5;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmPoolAnnounce_announceClockDomain_since_version(void)
{
    return 0;
}

SBE_ONE_DEF bool shm_tensorpool_control_shmPoolAnnounce_announceClockDomain_in_acting_version(
    const struct shm_tensorpool_control_shmPoolAnnounce *const codec)
{
#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wtautological-compare"
#endif
    return codec->acting_version >= shm_tensorpool_control_shmPoolAnnounce_announceClockDomain_since_version();
#if defined(__clang__)
#pragma clang diagnostic pop
#endif
}

SBE_ONE_DEF size_t shm_tensorpool_control_shmPoolAnnounce_announceClockDomain_encoding_offset(void)
{
    return 24;
}

SBE_ONE_DEF size_t shm_tensorpool_control_shmPoolAnnounce_announceClockDomain_encoding_length(void)
{
    return 1;
}

SBE_ONE_DEF bool shm_tensorpool_control_shmPoolAnnounce_announceClockDomain(
    const struct shm_tensorpool_control_shmPoolAnnounce *const codec,
    enum shm_tensorpool_control_clockDomain *const out)
{
    uint8_t val;
    memcpy(&val, codec->buffer + codec->offset + 24, sizeof(uint8_t));

    return shm_tensorpool_control_clockDomain_get((val), out);
}

SBE_ONE_DEF struct shm_tensorpool_control_shmPoolAnnounce *shm_tensorpool_control_shmPoolAnnounce_set_announceClockDomain(
    struct shm_tensorpool_control_shmPoolAnnounce *const codec,
    const enum shm_tensorpool_control_clockDomain value)
{
    uint8_t val = (value);
    memcpy(codec->buffer + codec->offset + 24, &val, sizeof(uint8_t));

    return codec;
}

SBE_ONE_DEF const char *shm_tensorpool_control_shmPoolAnnounce_layoutVersion_meta_attribute(
    const enum shm_tensorpool_control_shmPoolAnnounce_meta_attribute attribute)
{
    switch (attribute)
    {
        case shm_tensorpool_control_shmPoolAnnounce_meta_attribute_EPOCH: return "";
        case shm_tensorpool_control_shmPoolAnnounce_meta_attribute_TIME_UNIT: return "";
        case shm_tensorpool_control_shmPoolAnnounce_meta_attribute_SEMANTIC_TYPE: return "";
        case shm_tensorpool_control_shmPoolAnnounce_meta_attribute_PRESENCE: return "required";
    }

    return "";
}

SBE_ONE_DEF uint16_t shm_tensorpool_control_shmPoolAnnounce_layoutVersion_id(void)
{
    return 6;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmPoolAnnounce_layoutVersion_since_version(void)
{
    return 0;
}

SBE_ONE_DEF bool shm_tensorpool_control_shmPoolAnnounce_layoutVersion_in_acting_version(
    const struct shm_tensorpool_control_shmPoolAnnounce *const codec)
{
#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wtautological-compare"
#endif
    return codec->acting_version >= shm_tensorpool_control_shmPoolAnnounce_layoutVersion_since_version();
#if defined(__clang__)
#pragma clang diagnostic pop
#endif
}

SBE_ONE_DEF size_t shm_tensorpool_control_shmPoolAnnounce_layoutVersion_encoding_offset(void)
{
    return 25;
}

SBE_ONE_DEF uint32_t shm_tensorpool_control_shmPoolAnnounce_layoutVersion_null_value(void)
{
    return SBE_NULLVALUE_UINT32;
}

SBE_ONE_DEF uint32_t shm_tensorpool_control_shmPoolAnnounce_layoutVersion_min_value(void)
{
    return UINT32_C(0x0);
}

SBE_ONE_DEF uint32_t shm_tensorpool_control_shmPoolAnnounce_layoutVersion_max_value(void)
{
    return UINT32_C(0xfffffffe);
}

SBE_ONE_DEF size_t shm_tensorpool_control_shmPoolAnnounce_layoutVersion_encoding_length(void)
{
    return 4;
}

SBE_ONE_DEF uint32_t shm_tensorpool_control_shmPoolAnnounce_layoutVersion(
    const struct shm_tensorpool_control_shmPoolAnnounce *const codec)
{
    uint32_t val;
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
#endif
    memcpy(&val, codec->buffer + codec->offset + 25, sizeof(uint32_t));
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic pop
#endif
    return SBE_LITTLE_ENDIAN_ENCODE_32(val);
}

SBE_ONE_DEF struct shm_tensorpool_control_shmPoolAnnounce *shm_tensorpool_control_shmPoolAnnounce_set_layoutVersion(
    struct shm_tensorpool_control_shmPoolAnnounce *const codec,
    const uint32_t value)
{
    uint32_t val = SBE_LITTLE_ENDIAN_ENCODE_32(value);
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
#endif
    memcpy(codec->buffer + codec->offset + 25, &val, sizeof(uint32_t));
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic pop
#endif
    return codec;
}

SBE_ONE_DEF const char *shm_tensorpool_control_shmPoolAnnounce_headerNslots_meta_attribute(
    const enum shm_tensorpool_control_shmPoolAnnounce_meta_attribute attribute)
{
    switch (attribute)
    {
        case shm_tensorpool_control_shmPoolAnnounce_meta_attribute_EPOCH: return "";
        case shm_tensorpool_control_shmPoolAnnounce_meta_attribute_TIME_UNIT: return "";
        case shm_tensorpool_control_shmPoolAnnounce_meta_attribute_SEMANTIC_TYPE: return "";
        case shm_tensorpool_control_shmPoolAnnounce_meta_attribute_PRESENCE: return "required";
    }

    return "";
}

SBE_ONE_DEF uint16_t shm_tensorpool_control_shmPoolAnnounce_headerNslots_id(void)
{
    return 7;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmPoolAnnounce_headerNslots_since_version(void)
{
    return 0;
}

SBE_ONE_DEF bool shm_tensorpool_control_shmPoolAnnounce_headerNslots_in_acting_version(
    const struct shm_tensorpool_control_shmPoolAnnounce *const codec)
{
#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wtautological-compare"
#endif
    return codec->acting_version >= shm_tensorpool_control_shmPoolAnnounce_headerNslots_since_version();
#if defined(__clang__)
#pragma clang diagnostic pop
#endif
}

SBE_ONE_DEF size_t shm_tensorpool_control_shmPoolAnnounce_headerNslots_encoding_offset(void)
{
    return 29;
}

SBE_ONE_DEF uint32_t shm_tensorpool_control_shmPoolAnnounce_headerNslots_null_value(void)
{
    return SBE_NULLVALUE_UINT32;
}

SBE_ONE_DEF uint32_t shm_tensorpool_control_shmPoolAnnounce_headerNslots_min_value(void)
{
    return UINT32_C(0x0);
}

SBE_ONE_DEF uint32_t shm_tensorpool_control_shmPoolAnnounce_headerNslots_max_value(void)
{
    return UINT32_C(0xfffffffe);
}

SBE_ONE_DEF size_t shm_tensorpool_control_shmPoolAnnounce_headerNslots_encoding_length(void)
{
    return 4;
}

SBE_ONE_DEF uint32_t shm_tensorpool_control_shmPoolAnnounce_headerNslots(
    const struct shm_tensorpool_control_shmPoolAnnounce *const codec)
{
    uint32_t val;
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
#endif
    memcpy(&val, codec->buffer + codec->offset + 29, sizeof(uint32_t));
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic pop
#endif
    return SBE_LITTLE_ENDIAN_ENCODE_32(val);
}

SBE_ONE_DEF struct shm_tensorpool_control_shmPoolAnnounce *shm_tensorpool_control_shmPoolAnnounce_set_headerNslots(
    struct shm_tensorpool_control_shmPoolAnnounce *const codec,
    const uint32_t value)
{
    uint32_t val = SBE_LITTLE_ENDIAN_ENCODE_32(value);
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
#endif
    memcpy(codec->buffer + codec->offset + 29, &val, sizeof(uint32_t));
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic pop
#endif
    return codec;
}

SBE_ONE_DEF const char *shm_tensorpool_control_shmPoolAnnounce_headerSlotBytes_meta_attribute(
    const enum shm_tensorpool_control_shmPoolAnnounce_meta_attribute attribute)
{
    switch (attribute)
    {
        case shm_tensorpool_control_shmPoolAnnounce_meta_attribute_EPOCH: return "";
        case shm_tensorpool_control_shmPoolAnnounce_meta_attribute_TIME_UNIT: return "";
        case shm_tensorpool_control_shmPoolAnnounce_meta_attribute_SEMANTIC_TYPE: return "";
        case shm_tensorpool_control_shmPoolAnnounce_meta_attribute_PRESENCE: return "required";
    }

    return "";
}

SBE_ONE_DEF uint16_t shm_tensorpool_control_shmPoolAnnounce_headerSlotBytes_id(void)
{
    return 8;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmPoolAnnounce_headerSlotBytes_since_version(void)
{
    return 0;
}

SBE_ONE_DEF bool shm_tensorpool_control_shmPoolAnnounce_headerSlotBytes_in_acting_version(
    const struct shm_tensorpool_control_shmPoolAnnounce *const codec)
{
#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wtautological-compare"
#endif
    return codec->acting_version >= shm_tensorpool_control_shmPoolAnnounce_headerSlotBytes_since_version();
#if defined(__clang__)
#pragma clang diagnostic pop
#endif
}

SBE_ONE_DEF size_t shm_tensorpool_control_shmPoolAnnounce_headerSlotBytes_encoding_offset(void)
{
    return 33;
}

SBE_ONE_DEF uint16_t shm_tensorpool_control_shmPoolAnnounce_headerSlotBytes_null_value(void)
{
    return SBE_NULLVALUE_UINT16;
}

SBE_ONE_DEF uint16_t shm_tensorpool_control_shmPoolAnnounce_headerSlotBytes_min_value(void)
{
    return (uint16_t)0;
}

SBE_ONE_DEF uint16_t shm_tensorpool_control_shmPoolAnnounce_headerSlotBytes_max_value(void)
{
    return (uint16_t)65534;
}

SBE_ONE_DEF size_t shm_tensorpool_control_shmPoolAnnounce_headerSlotBytes_encoding_length(void)
{
    return 2;
}

SBE_ONE_DEF uint16_t shm_tensorpool_control_shmPoolAnnounce_headerSlotBytes(
    const struct shm_tensorpool_control_shmPoolAnnounce *const codec)
{
    uint16_t val;
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
#endif
    memcpy(&val, codec->buffer + codec->offset + 33, sizeof(uint16_t));
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic pop
#endif
    return SBE_LITTLE_ENDIAN_ENCODE_16(val);
}

SBE_ONE_DEF struct shm_tensorpool_control_shmPoolAnnounce *shm_tensorpool_control_shmPoolAnnounce_set_headerSlotBytes(
    struct shm_tensorpool_control_shmPoolAnnounce *const codec,
    const uint16_t value)
{
    uint16_t val = SBE_LITTLE_ENDIAN_ENCODE_16(value);
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
#endif
    memcpy(codec->buffer + codec->offset + 33, &val, sizeof(uint16_t));
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic pop
#endif
    return codec;
}

struct shm_tensorpool_control_shmPoolAnnounce_payloadPools
{
    char *buffer;
    uint64_t buffer_length;
    uint64_t *position_ptr;
    uint64_t block_length;
    uint64_t count;
    uint64_t index;
    uint64_t offset;
    uint64_t acting_version;
};

SBE_ONE_DEF uint64_t *shm_tensorpool_control_shmPoolAnnounce_payloadPools_sbe_position_ptr(
    struct shm_tensorpool_control_shmPoolAnnounce_payloadPools *const codec)
{
    return codec->position_ptr;
}

SBE_ONE_DEF struct shm_tensorpool_control_shmPoolAnnounce_payloadPools *shm_tensorpool_control_shmPoolAnnounce_payloadPools_wrap_for_decode(
    struct shm_tensorpool_control_shmPoolAnnounce_payloadPools *const codec,
    char *const buffer,
    uint64_t *const pos,
    const uint64_t acting_version,
    const uint64_t buffer_length)
{
    codec->buffer = buffer;
    codec->buffer_length = buffer_length;
    struct shm_tensorpool_control_groupSizeEncoding dimensions;
    if (!shm_tensorpool_control_groupSizeEncoding_wrap(&dimensions, codec->buffer, *pos, acting_version, buffer_length))
    {
        return NULL;
    }

    codec->block_length = shm_tensorpool_control_groupSizeEncoding_blockLength(&dimensions);
    codec->count = shm_tensorpool_control_groupSizeEncoding_numInGroup(&dimensions);
    codec->index = -1;
    codec->acting_version = acting_version;
    codec->position_ptr = pos;
    *codec->position_ptr = *codec->position_ptr + 4;

    return codec;
}

SBE_ONE_DEF struct shm_tensorpool_control_shmPoolAnnounce_payloadPools *shm_tensorpool_control_shmPoolAnnounce_payloadPools_wrap_for_encode(
    struct shm_tensorpool_control_shmPoolAnnounce_payloadPools *const codec,
    char *const buffer,
    const uint16_t count,
    uint64_t *const pos,
    const uint64_t acting_version,
    const uint64_t buffer_length)
{
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wtype-limits"
#endif
    if (count > 65534)
    {
        errno = E110;
        return NULL;
    }
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic pop
#endif
    codec->buffer = buffer;
    codec->buffer_length = buffer_length;
    struct shm_tensorpool_control_groupSizeEncoding dimensions;
    if (!shm_tensorpool_control_groupSizeEncoding_wrap(&dimensions, codec->buffer, *pos, acting_version, buffer_length))
    {
        return NULL;
    }

    shm_tensorpool_control_groupSizeEncoding_set_blockLength(&dimensions, (uint16_t)10);
    shm_tensorpool_control_groupSizeEncoding_set_numInGroup(&dimensions, (uint16_t)count);
    codec->index = -1;
    codec->count = count;
    codec->block_length = 10;
    codec->acting_version = acting_version;
    codec->position_ptr = pos;
    *codec->position_ptr = *codec->position_ptr + 4;

    return codec;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmPoolAnnounce_payloadPools_sbe_header_size(void)
{
    return 4;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmPoolAnnounce_payloadPools_sbe_block_length(void)
{
    return 10;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmPoolAnnounce_payloadPools_sbe_position(
    const struct shm_tensorpool_control_shmPoolAnnounce_payloadPools *const codec)
{
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
#endif
    return *codec->position_ptr;
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic pop
#endif
}

SBE_ONE_DEF bool shm_tensorpool_control_shmPoolAnnounce_payloadPools_set_sbe_position(
    struct shm_tensorpool_control_shmPoolAnnounce_payloadPools *const codec,
    const uint64_t position)
{
    if (SBE_BOUNDS_CHECK_EXPECT((position > codec->buffer_length), false))
    {
       errno = E100;
       return false;
    }
    *codec->position_ptr = position;

    return true;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmPoolAnnounce_payloadPools_count(
    const struct shm_tensorpool_control_shmPoolAnnounce_payloadPools *const codec)
{
    return codec->count;
}

SBE_ONE_DEF bool shm_tensorpool_control_shmPoolAnnounce_payloadPools_has_next(
    const struct shm_tensorpool_control_shmPoolAnnounce_payloadPools *const codec)
{
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
#endif
    return codec->index + 1 < codec->count;
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic pop
#endif
}

SBE_ONE_DEF struct shm_tensorpool_control_shmPoolAnnounce_payloadPools *shm_tensorpool_control_shmPoolAnnounce_payloadPools_next(
    struct shm_tensorpool_control_shmPoolAnnounce_payloadPools *const codec)
{
    codec->offset = *codec->position_ptr;
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
#endif
    if (SBE_BOUNDS_CHECK_EXPECT(((codec->offset + codec->block_length) > codec->buffer_length), false))
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic pop
#endif
    {
        errno = E108;
        return NULL;
    }
    *codec->position_ptr = codec->offset + codec->block_length;
    ++codec->index;

    return codec;
}

SBE_ONE_DEF struct shm_tensorpool_control_shmPoolAnnounce_payloadPools *shm_tensorpool_control_shmPoolAnnounce_payloadPools_for_each(
    struct shm_tensorpool_control_shmPoolAnnounce_payloadPools *const codec,
    void (*func)(struct shm_tensorpool_control_shmPoolAnnounce_payloadPools *, void *),
    void *const context)
{
    while (shm_tensorpool_control_shmPoolAnnounce_payloadPools_has_next(codec))
    {
        if (!shm_tensorpool_control_shmPoolAnnounce_payloadPools_next(codec))
        {
            return NULL;
        }
        func(codec, context);
    }

    return codec;
}

SBE_ONE_DEF const char *shm_tensorpool_control_shmPoolAnnounce_payloadPools_poolId_meta_attribute(
    const enum shm_tensorpool_control_shmPoolAnnounce_meta_attribute attribute)
{
    switch (attribute)
    {
        case shm_tensorpool_control_shmPoolAnnounce_meta_attribute_EPOCH: return "";
        case shm_tensorpool_control_shmPoolAnnounce_meta_attribute_TIME_UNIT: return "";
        case shm_tensorpool_control_shmPoolAnnounce_meta_attribute_SEMANTIC_TYPE: return "";
        case shm_tensorpool_control_shmPoolAnnounce_meta_attribute_PRESENCE: return "required";
    }

    return "";
}

SBE_ONE_DEF uint16_t shm_tensorpool_control_shmPoolAnnounce_payloadPools_poolId_id(void)
{
    return 1;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmPoolAnnounce_payloadPools_poolId_since_version(void)
{
    return 0;
}

SBE_ONE_DEF bool shm_tensorpool_control_shmPoolAnnounce_payloadPools_poolId_in_acting_version(
    const struct shm_tensorpool_control_shmPoolAnnounce_payloadPools *const codec)
{
#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wtautological-compare"
#endif
    return codec->acting_version >= shm_tensorpool_control_shmPoolAnnounce_payloadPools_poolId_since_version();
#if defined(__clang__)
#pragma clang diagnostic pop
#endif
}

SBE_ONE_DEF size_t shm_tensorpool_control_shmPoolAnnounce_payloadPools_poolId_encoding_offset(void)
{
    return 0;
}

SBE_ONE_DEF uint16_t shm_tensorpool_control_shmPoolAnnounce_payloadPools_poolId_null_value(void)
{
    return SBE_NULLVALUE_UINT16;
}

SBE_ONE_DEF uint16_t shm_tensorpool_control_shmPoolAnnounce_payloadPools_poolId_min_value(void)
{
    return (uint16_t)0;
}

SBE_ONE_DEF uint16_t shm_tensorpool_control_shmPoolAnnounce_payloadPools_poolId_max_value(void)
{
    return (uint16_t)65534;
}

SBE_ONE_DEF size_t shm_tensorpool_control_shmPoolAnnounce_payloadPools_poolId_encoding_length(void)
{
    return 2;
}

SBE_ONE_DEF uint16_t shm_tensorpool_control_shmPoolAnnounce_payloadPools_poolId(
    const struct shm_tensorpool_control_shmPoolAnnounce_payloadPools *const codec)
{
    uint16_t val;
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
#endif
    memcpy(&val, codec->buffer + codec->offset + 0, sizeof(uint16_t));
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic pop
#endif
    return SBE_LITTLE_ENDIAN_ENCODE_16(val);
}

SBE_ONE_DEF struct shm_tensorpool_control_shmPoolAnnounce_payloadPools *shm_tensorpool_control_shmPoolAnnounce_payloadPools_set_poolId(
    struct shm_tensorpool_control_shmPoolAnnounce_payloadPools *const codec,
    const uint16_t value)
{
    uint16_t val = SBE_LITTLE_ENDIAN_ENCODE_16(value);
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
#endif
    memcpy(codec->buffer + codec->offset + 0, &val, sizeof(uint16_t));
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic pop
#endif
    return codec;
}

SBE_ONE_DEF const char *shm_tensorpool_control_shmPoolAnnounce_payloadPools_poolNslots_meta_attribute(
    const enum shm_tensorpool_control_shmPoolAnnounce_meta_attribute attribute)
{
    switch (attribute)
    {
        case shm_tensorpool_control_shmPoolAnnounce_meta_attribute_EPOCH: return "";
        case shm_tensorpool_control_shmPoolAnnounce_meta_attribute_TIME_UNIT: return "";
        case shm_tensorpool_control_shmPoolAnnounce_meta_attribute_SEMANTIC_TYPE: return "";
        case shm_tensorpool_control_shmPoolAnnounce_meta_attribute_PRESENCE: return "required";
    }

    return "";
}

SBE_ONE_DEF uint16_t shm_tensorpool_control_shmPoolAnnounce_payloadPools_poolNslots_id(void)
{
    return 2;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmPoolAnnounce_payloadPools_poolNslots_since_version(void)
{
    return 0;
}

SBE_ONE_DEF bool shm_tensorpool_control_shmPoolAnnounce_payloadPools_poolNslots_in_acting_version(
    const struct shm_tensorpool_control_shmPoolAnnounce_payloadPools *const codec)
{
#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wtautological-compare"
#endif
    return codec->acting_version >= shm_tensorpool_control_shmPoolAnnounce_payloadPools_poolNslots_since_version();
#if defined(__clang__)
#pragma clang diagnostic pop
#endif
}

SBE_ONE_DEF size_t shm_tensorpool_control_shmPoolAnnounce_payloadPools_poolNslots_encoding_offset(void)
{
    return 2;
}

SBE_ONE_DEF uint32_t shm_tensorpool_control_shmPoolAnnounce_payloadPools_poolNslots_null_value(void)
{
    return SBE_NULLVALUE_UINT32;
}

SBE_ONE_DEF uint32_t shm_tensorpool_control_shmPoolAnnounce_payloadPools_poolNslots_min_value(void)
{
    return UINT32_C(0x0);
}

SBE_ONE_DEF uint32_t shm_tensorpool_control_shmPoolAnnounce_payloadPools_poolNslots_max_value(void)
{
    return UINT32_C(0xfffffffe);
}

SBE_ONE_DEF size_t shm_tensorpool_control_shmPoolAnnounce_payloadPools_poolNslots_encoding_length(void)
{
    return 4;
}

SBE_ONE_DEF uint32_t shm_tensorpool_control_shmPoolAnnounce_payloadPools_poolNslots(
    const struct shm_tensorpool_control_shmPoolAnnounce_payloadPools *const codec)
{
    uint32_t val;
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
#endif
    memcpy(&val, codec->buffer + codec->offset + 2, sizeof(uint32_t));
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic pop
#endif
    return SBE_LITTLE_ENDIAN_ENCODE_32(val);
}

SBE_ONE_DEF struct shm_tensorpool_control_shmPoolAnnounce_payloadPools *shm_tensorpool_control_shmPoolAnnounce_payloadPools_set_poolNslots(
    struct shm_tensorpool_control_shmPoolAnnounce_payloadPools *const codec,
    const uint32_t value)
{
    uint32_t val = SBE_LITTLE_ENDIAN_ENCODE_32(value);
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
#endif
    memcpy(codec->buffer + codec->offset + 2, &val, sizeof(uint32_t));
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic pop
#endif
    return codec;
}

SBE_ONE_DEF const char *shm_tensorpool_control_shmPoolAnnounce_payloadPools_strideBytes_meta_attribute(
    const enum shm_tensorpool_control_shmPoolAnnounce_meta_attribute attribute)
{
    switch (attribute)
    {
        case shm_tensorpool_control_shmPoolAnnounce_meta_attribute_EPOCH: return "";
        case shm_tensorpool_control_shmPoolAnnounce_meta_attribute_TIME_UNIT: return "";
        case shm_tensorpool_control_shmPoolAnnounce_meta_attribute_SEMANTIC_TYPE: return "";
        case shm_tensorpool_control_shmPoolAnnounce_meta_attribute_PRESENCE: return "required";
    }

    return "";
}

SBE_ONE_DEF uint16_t shm_tensorpool_control_shmPoolAnnounce_payloadPools_strideBytes_id(void)
{
    return 3;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmPoolAnnounce_payloadPools_strideBytes_since_version(void)
{
    return 0;
}

SBE_ONE_DEF bool shm_tensorpool_control_shmPoolAnnounce_payloadPools_strideBytes_in_acting_version(
    const struct shm_tensorpool_control_shmPoolAnnounce_payloadPools *const codec)
{
#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wtautological-compare"
#endif
    return codec->acting_version >= shm_tensorpool_control_shmPoolAnnounce_payloadPools_strideBytes_since_version();
#if defined(__clang__)
#pragma clang diagnostic pop
#endif
}

SBE_ONE_DEF size_t shm_tensorpool_control_shmPoolAnnounce_payloadPools_strideBytes_encoding_offset(void)
{
    return 6;
}

SBE_ONE_DEF uint32_t shm_tensorpool_control_shmPoolAnnounce_payloadPools_strideBytes_null_value(void)
{
    return SBE_NULLVALUE_UINT32;
}

SBE_ONE_DEF uint32_t shm_tensorpool_control_shmPoolAnnounce_payloadPools_strideBytes_min_value(void)
{
    return UINT32_C(0x0);
}

SBE_ONE_DEF uint32_t shm_tensorpool_control_shmPoolAnnounce_payloadPools_strideBytes_max_value(void)
{
    return UINT32_C(0xfffffffe);
}

SBE_ONE_DEF size_t shm_tensorpool_control_shmPoolAnnounce_payloadPools_strideBytes_encoding_length(void)
{
    return 4;
}

SBE_ONE_DEF uint32_t shm_tensorpool_control_shmPoolAnnounce_payloadPools_strideBytes(
    const struct shm_tensorpool_control_shmPoolAnnounce_payloadPools *const codec)
{
    uint32_t val;
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
#endif
    memcpy(&val, codec->buffer + codec->offset + 6, sizeof(uint32_t));
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic pop
#endif
    return SBE_LITTLE_ENDIAN_ENCODE_32(val);
}

SBE_ONE_DEF struct shm_tensorpool_control_shmPoolAnnounce_payloadPools *shm_tensorpool_control_shmPoolAnnounce_payloadPools_set_strideBytes(
    struct shm_tensorpool_control_shmPoolAnnounce_payloadPools *const codec,
    const uint32_t value)
{
    uint32_t val = SBE_LITTLE_ENDIAN_ENCODE_32(value);
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
#endif
    memcpy(codec->buffer + codec->offset + 6, &val, sizeof(uint32_t));
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic pop
#endif
    return codec;
}

SBE_ONE_DEF const char *shm_tensorpool_control_shmPoolAnnounce_payloadPools_regionUri_meta_attribute(
    const enum shm_tensorpool_control_shmPoolAnnounce_meta_attribute attribute)
{
    switch (attribute)
    {
        case shm_tensorpool_control_shmPoolAnnounce_meta_attribute_EPOCH: return "";
        case shm_tensorpool_control_shmPoolAnnounce_meta_attribute_TIME_UNIT: return "";
        case shm_tensorpool_control_shmPoolAnnounce_meta_attribute_SEMANTIC_TYPE: return "";
        case shm_tensorpool_control_shmPoolAnnounce_meta_attribute_PRESENCE: return "required";
    }

    return "";
}

SBE_ONE_DEF const char *shm_tensorpool_control_shmPoolAnnounce_payloadPools_regionUri_character_encoding(void)
{
    return "US-ASCII";
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmPoolAnnounce_payloadPools_regionUri_since_version(void)
{
    return 0;
}

SBE_ONE_DEF bool shm_tensorpool_control_shmPoolAnnounce_payloadPools_regionUri_in_acting_version(
    const struct shm_tensorpool_control_shmPoolAnnounce_payloadPools *const codec)
{
#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wtautological-compare"
#endif
    return codec->acting_version >= shm_tensorpool_control_shmPoolAnnounce_payloadPools_regionUri_since_version();
#if defined(__clang__)
#pragma clang diagnostic pop
#endif
}

SBE_ONE_DEF uint16_t shm_tensorpool_control_shmPoolAnnounce_payloadPools_regionUri_id(void)
{
    return 4;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmPoolAnnounce_payloadPools_regionUri_header_length(void)
{
    return 4;
}

SBE_ONE_DEF uint32_t shm_tensorpool_control_shmPoolAnnounce_payloadPools_regionUri_length(
    const struct shm_tensorpool_control_shmPoolAnnounce_payloadPools *const codec)
{
    uint32_t length;
    memcpy(&length, codec->buffer + shm_tensorpool_control_shmPoolAnnounce_payloadPools_sbe_position(codec), sizeof(uint32_t));

    return SBE_LITTLE_ENDIAN_ENCODE_32(length);
}

SBE_ONE_DEF const char *shm_tensorpool_control_shmPoolAnnounce_payloadPools_regionUri(
    struct shm_tensorpool_control_shmPoolAnnounce_payloadPools *const codec)
{
    uint32_t length_field_value;
    memcpy(&length_field_value, codec->buffer + shm_tensorpool_control_shmPoolAnnounce_payloadPools_sbe_position(codec), sizeof(uint32_t));
    const char *field_ptr = (codec->buffer + shm_tensorpool_control_shmPoolAnnounce_payloadPools_sbe_position(codec) + 4);

    if (!shm_tensorpool_control_shmPoolAnnounce_payloadPools_set_sbe_position(
        codec, shm_tensorpool_control_shmPoolAnnounce_payloadPools_sbe_position(codec) + 4 + SBE_LITTLE_ENDIAN_ENCODE_32(length_field_value)))
    {
        return NULL;
    }

    return field_ptr;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmPoolAnnounce_payloadPools_get_regionUri(
    struct shm_tensorpool_control_shmPoolAnnounce_payloadPools *const codec,
    char *dst,
    const uint64_t length)
{
    uint64_t length_of_length_field = 4;
    uint64_t length_position = shm_tensorpool_control_shmPoolAnnounce_payloadPools_sbe_position(codec);
    if (!shm_tensorpool_control_shmPoolAnnounce_payloadPools_set_sbe_position(codec, length_position + length_of_length_field))
    {
        return 0;
    }

    uint32_t length_field_value;
    memcpy(&length_field_value, codec->buffer + length_position, sizeof(uint32_t));
    uint64_t data_length = SBE_LITTLE_ENDIAN_ENCODE_32(length_field_value);
    uint64_t bytes_to_copy = length < data_length ? length : data_length;
    uint64_t pos = shm_tensorpool_control_shmPoolAnnounce_payloadPools_sbe_position(codec);

    if (!shm_tensorpool_control_shmPoolAnnounce_payloadPools_set_sbe_position(codec, pos + data_length))
    {
        return 0;
    }

    memcpy(dst, codec->buffer + pos, bytes_to_copy);

    return bytes_to_copy;
}

SBE_ONE_DEF struct shm_tensorpool_control_shmPoolAnnounce_string_view shm_tensorpool_control_shmPoolAnnounce_payloadPools_get_regionUri_as_string_view(
    struct shm_tensorpool_control_shmPoolAnnounce_payloadPools *const codec)
{
    uint32_t length_field_value = shm_tensorpool_control_shmPoolAnnounce_payloadPools_regionUri_length(codec);
    const char *field_ptr = codec->buffer + shm_tensorpool_control_shmPoolAnnounce_payloadPools_sbe_position(codec) + 4;
    if (!shm_tensorpool_control_shmPoolAnnounce_payloadPools_set_sbe_position(
        codec, shm_tensorpool_control_shmPoolAnnounce_payloadPools_sbe_position(codec) + 4 + length_field_value))
    {
        struct shm_tensorpool_control_shmPoolAnnounce_string_view ret = {NULL, 0};
        return ret;
    }

    struct shm_tensorpool_control_shmPoolAnnounce_string_view ret = {field_ptr, length_field_value};

    return ret;
}

SBE_ONE_DEF struct shm_tensorpool_control_shmPoolAnnounce_payloadPools *shm_tensorpool_control_shmPoolAnnounce_payloadPools_put_regionUri(
    struct shm_tensorpool_control_shmPoolAnnounce_payloadPools *const codec,
    const char *src,
    const uint32_t length)
{
    uint64_t length_of_length_field = 4;
    uint64_t length_position = shm_tensorpool_control_shmPoolAnnounce_payloadPools_sbe_position(codec);
    uint32_t length_field_value = SBE_LITTLE_ENDIAN_ENCODE_32(length);
    if (!shm_tensorpool_control_shmPoolAnnounce_payloadPools_set_sbe_position(codec, length_position + length_of_length_field))
    {
        return NULL;
    }

    memcpy(codec->buffer + length_position, &length_field_value, sizeof(uint32_t));
    uint64_t pos = shm_tensorpool_control_shmPoolAnnounce_payloadPools_sbe_position(codec);

    if (!shm_tensorpool_control_shmPoolAnnounce_payloadPools_set_sbe_position(codec, pos + length))
    {
        return NULL;
    }

    memcpy(codec->buffer + pos, src, length);

    return codec;
}

SBE_ONE_DEF uint16_t shm_tensorpool_control_shmPoolAnnounce_payloadPools_id(void)
{
    return 9;
}

SBE_ONE_DEF struct shm_tensorpool_control_shmPoolAnnounce_payloadPools *shm_tensorpool_control_shmPoolAnnounce_get_payloadPools(
    struct shm_tensorpool_control_shmPoolAnnounce *const codec,
    struct shm_tensorpool_control_shmPoolAnnounce_payloadPools *const property)
{
    return shm_tensorpool_control_shmPoolAnnounce_payloadPools_wrap_for_decode(
        property,
        codec->buffer,
        shm_tensorpool_control_shmPoolAnnounce_sbe_position_ptr(codec),
        codec->acting_version,
        codec->buffer_length);
}

SBE_ONE_DEF struct shm_tensorpool_control_shmPoolAnnounce_payloadPools *shm_tensorpool_control_shmPoolAnnounce_payloadPools_set_count(
    struct shm_tensorpool_control_shmPoolAnnounce *const codec,
    struct shm_tensorpool_control_shmPoolAnnounce_payloadPools *const property,
    const uint16_t count)
{
    return shm_tensorpool_control_shmPoolAnnounce_payloadPools_wrap_for_encode(
        property,
        codec->buffer,
        count,
        shm_tensorpool_control_shmPoolAnnounce_sbe_position_ptr(codec),
        codec->acting_version,
        codec->buffer_length);
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmPoolAnnounce_payloadPools_since_version(void)
{
    return 0;
}

SBE_ONE_DEF bool shm_tensorpool_control_shmPoolAnnounce_payloadPools_in_acting_version(
    const struct shm_tensorpool_control_shmPoolAnnounce *const codec)
{
#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wtautological-compare"
#endif
    return codec->acting_version >= shm_tensorpool_control_shmPoolAnnounce_payloadPools_since_version();
#if defined(__clang__)
#pragma clang diagnostic pop
#endif
}

SBE_ONE_DEF const char *shm_tensorpool_control_shmPoolAnnounce_headerRegionUri_meta_attribute(
    const enum shm_tensorpool_control_shmPoolAnnounce_meta_attribute attribute)
{
    switch (attribute)
    {
        case shm_tensorpool_control_shmPoolAnnounce_meta_attribute_EPOCH: return "";
        case shm_tensorpool_control_shmPoolAnnounce_meta_attribute_TIME_UNIT: return "";
        case shm_tensorpool_control_shmPoolAnnounce_meta_attribute_SEMANTIC_TYPE: return "";
        case shm_tensorpool_control_shmPoolAnnounce_meta_attribute_PRESENCE: return "required";
    }

    return "";
}

SBE_ONE_DEF const char *shm_tensorpool_control_shmPoolAnnounce_headerRegionUri_character_encoding(void)
{
    return "US-ASCII";
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmPoolAnnounce_headerRegionUri_since_version(void)
{
    return 0;
}

SBE_ONE_DEF bool shm_tensorpool_control_shmPoolAnnounce_headerRegionUri_in_acting_version(
    const struct shm_tensorpool_control_shmPoolAnnounce *const codec)
{
#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wtautological-compare"
#endif
    return codec->acting_version >= shm_tensorpool_control_shmPoolAnnounce_headerRegionUri_since_version();
#if defined(__clang__)
#pragma clang diagnostic pop
#endif
}

SBE_ONE_DEF uint16_t shm_tensorpool_control_shmPoolAnnounce_headerRegionUri_id(void)
{
    return 10;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmPoolAnnounce_headerRegionUri_header_length(void)
{
    return 4;
}

SBE_ONE_DEF uint32_t shm_tensorpool_control_shmPoolAnnounce_headerRegionUri_length(
    const struct shm_tensorpool_control_shmPoolAnnounce *const codec)
{
    uint32_t length;
    memcpy(&length, codec->buffer + shm_tensorpool_control_shmPoolAnnounce_sbe_position(codec), sizeof(uint32_t));

    return SBE_LITTLE_ENDIAN_ENCODE_32(length);
}

SBE_ONE_DEF const char *shm_tensorpool_control_shmPoolAnnounce_headerRegionUri(
    struct shm_tensorpool_control_shmPoolAnnounce *const codec)
{
    uint32_t length_field_value;
    memcpy(&length_field_value, codec->buffer + shm_tensorpool_control_shmPoolAnnounce_sbe_position(codec), sizeof(uint32_t));
    const char *field_ptr = (codec->buffer + shm_tensorpool_control_shmPoolAnnounce_sbe_position(codec) + 4);

    if (!shm_tensorpool_control_shmPoolAnnounce_set_sbe_position(
        codec, shm_tensorpool_control_shmPoolAnnounce_sbe_position(codec) + 4 + SBE_LITTLE_ENDIAN_ENCODE_32(length_field_value)))
    {
        return NULL;
    }

    return field_ptr;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmPoolAnnounce_get_headerRegionUri(
    struct shm_tensorpool_control_shmPoolAnnounce *const codec,
    char *dst,
    const uint64_t length)
{
    uint64_t length_of_length_field = 4;
    uint64_t length_position = shm_tensorpool_control_shmPoolAnnounce_sbe_position(codec);
    if (!shm_tensorpool_control_shmPoolAnnounce_set_sbe_position(codec, length_position + length_of_length_field))
    {
        return 0;
    }

    uint32_t length_field_value;
    memcpy(&length_field_value, codec->buffer + length_position, sizeof(uint32_t));
    uint64_t data_length = SBE_LITTLE_ENDIAN_ENCODE_32(length_field_value);
    uint64_t bytes_to_copy = length < data_length ? length : data_length;
    uint64_t pos = shm_tensorpool_control_shmPoolAnnounce_sbe_position(codec);

    if (!shm_tensorpool_control_shmPoolAnnounce_set_sbe_position(codec, pos + data_length))
    {
        return 0;
    }

    memcpy(dst, codec->buffer + pos, bytes_to_copy);

    return bytes_to_copy;
}

SBE_ONE_DEF struct shm_tensorpool_control_shmPoolAnnounce_string_view shm_tensorpool_control_shmPoolAnnounce_get_headerRegionUri_as_string_view(
    struct shm_tensorpool_control_shmPoolAnnounce *const codec)
{
    uint32_t length_field_value = shm_tensorpool_control_shmPoolAnnounce_headerRegionUri_length(codec);
    const char *field_ptr = codec->buffer + shm_tensorpool_control_shmPoolAnnounce_sbe_position(codec) + 4;
    if (!shm_tensorpool_control_shmPoolAnnounce_set_sbe_position(
        codec, shm_tensorpool_control_shmPoolAnnounce_sbe_position(codec) + 4 + length_field_value))
    {
        struct shm_tensorpool_control_shmPoolAnnounce_string_view ret = {NULL, 0};
        return ret;
    }

    struct shm_tensorpool_control_shmPoolAnnounce_string_view ret = {field_ptr, length_field_value};

    return ret;
}

SBE_ONE_DEF struct shm_tensorpool_control_shmPoolAnnounce *shm_tensorpool_control_shmPoolAnnounce_put_headerRegionUri(
    struct shm_tensorpool_control_shmPoolAnnounce *const codec,
    const char *src,
    const uint32_t length)
{
    uint64_t length_of_length_field = 4;
    uint64_t length_position = shm_tensorpool_control_shmPoolAnnounce_sbe_position(codec);
    uint32_t length_field_value = SBE_LITTLE_ENDIAN_ENCODE_32(length);
    if (!shm_tensorpool_control_shmPoolAnnounce_set_sbe_position(codec, length_position + length_of_length_field))
    {
        return NULL;
    }

    memcpy(codec->buffer + length_position, &length_field_value, sizeof(uint32_t));
    uint64_t pos = shm_tensorpool_control_shmPoolAnnounce_sbe_position(codec);

    if (!shm_tensorpool_control_shmPoolAnnounce_set_sbe_position(codec, pos + length))
    {
        return NULL;
    }

    memcpy(codec->buffer + pos, src, length);

    return codec;
}

#endif
