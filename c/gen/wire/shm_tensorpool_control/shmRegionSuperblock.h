/* Generated SBE (Simple Binary Encoding) message codec */

#ifndef _SHM_TENSORPOOL_CONTROL_SHMREGIONSUPERBLOCK_H_
#define _SHM_TENSORPOOL_CONTROL_SHMREGIONSUPERBLOCK_H_

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

struct shm_tensorpool_control_shmRegionSuperblock
{
    char *buffer;
    uint64_t buffer_length;
    uint64_t offset;
    uint64_t position;
    uint64_t acting_block_length;
    uint64_t acting_version;
};

enum shm_tensorpool_control_shmRegionSuperblock_meta_attribute
{
    shm_tensorpool_control_shmRegionSuperblock_meta_attribute_EPOCH,
    shm_tensorpool_control_shmRegionSuperblock_meta_attribute_TIME_UNIT,
    shm_tensorpool_control_shmRegionSuperblock_meta_attribute_SEMANTIC_TYPE,
    shm_tensorpool_control_shmRegionSuperblock_meta_attribute_PRESENCE
};

union shm_tensorpool_control_shmRegionSuperblock_float_as_uint
{
    float fp_value;
    uint32_t uint_value;
};

union shm_tensorpool_control_shmRegionSuperblock_double_as_uint
{
    double fp_value;
    uint64_t uint_value;
};

struct shm_tensorpool_control_shmRegionSuperblock_string_view
{
    const char* data;
    size_t length;
};

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmRegionSuperblock_sbe_position(
    const struct shm_tensorpool_control_shmRegionSuperblock *const codec)
{
    return codec->position;
}

SBE_ONE_DEF bool shm_tensorpool_control_shmRegionSuperblock_set_sbe_position(
    struct shm_tensorpool_control_shmRegionSuperblock *const codec,
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

SBE_ONE_DEF uint64_t *shm_tensorpool_control_shmRegionSuperblock_sbe_position_ptr(
    struct shm_tensorpool_control_shmRegionSuperblock *const codec)
{
    return &codec->position;
}

SBE_ONE_DEF struct shm_tensorpool_control_shmRegionSuperblock *shm_tensorpool_control_shmRegionSuperblock_reset(
    struct shm_tensorpool_control_shmRegionSuperblock *const codec,
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
    if (!shm_tensorpool_control_shmRegionSuperblock_set_sbe_position(codec, offset + acting_block_length))
    {
        return NULL;
    }

    return codec;
}

SBE_ONE_DEF struct shm_tensorpool_control_shmRegionSuperblock *shm_tensorpool_control_shmRegionSuperblock_copy(
    struct shm_tensorpool_control_shmRegionSuperblock *const codec,
    const struct shm_tensorpool_control_shmRegionSuperblock *const other)
{
     codec->buffer = other->buffer;
     codec->offset = other->offset;
     codec->buffer_length = other->buffer_length;
     codec->acting_block_length = other->acting_block_length;
     codec->acting_version = other->acting_version;
     codec->position = other->position;

     return codec;
}

SBE_ONE_DEF uint16_t shm_tensorpool_control_shmRegionSuperblock_sbe_block_length(void)
{
    return (uint16_t)64;
}

#define SHM_TENSORPOOL_CONTROL_SHM_REGION_SUPERBLOCK_SBE_TEMPLATE_ID (uint16_t)50

SBE_ONE_DEF uint16_t shm_tensorpool_control_shmRegionSuperblock_sbe_template_id(void)
{
    return (uint16_t)50;
}

SBE_ONE_DEF uint16_t shm_tensorpool_control_shmRegionSuperblock_sbe_schema_id(void)
{
    return (uint16_t)900;
}

SBE_ONE_DEF uint16_t shm_tensorpool_control_shmRegionSuperblock_sbe_schema_version(void)
{
    return (uint16_t)1;
}

SBE_ONE_DEF const char* shm_tensorpool_control_shmRegionSuperblock_sbe_semantic_version(void)
{
    return "1.1";
}

SBE_ONE_DEF const char *shm_tensorpool_control_shmRegionSuperblock_sbe_semantic_type(void)
{
    return "";
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmRegionSuperblock_offset(
    const struct shm_tensorpool_control_shmRegionSuperblock *const codec)
{
    return codec->offset;
}

SBE_ONE_DEF struct shm_tensorpool_control_shmRegionSuperblock *shm_tensorpool_control_shmRegionSuperblock_wrap_and_apply_header(
    struct shm_tensorpool_control_shmRegionSuperblock *const codec,
    char *buffer,
    const uint64_t offset,
    const uint64_t buffer_length,
    struct shm_tensorpool_control_messageHeader *const hdr)
{
    shm_tensorpool_control_messageHeader_wrap(
        hdr, buffer + offset, 0, shm_tensorpool_control_messageHeader_sbe_schema_version(), buffer_length);

    shm_tensorpool_control_messageHeader_set_blockLength(hdr, shm_tensorpool_control_shmRegionSuperblock_sbe_block_length());
    shm_tensorpool_control_messageHeader_set_templateId(hdr, shm_tensorpool_control_shmRegionSuperblock_sbe_template_id());
    shm_tensorpool_control_messageHeader_set_schemaId(hdr, shm_tensorpool_control_shmRegionSuperblock_sbe_schema_id());
    shm_tensorpool_control_messageHeader_set_version(hdr, shm_tensorpool_control_shmRegionSuperblock_sbe_schema_version());

    shm_tensorpool_control_shmRegionSuperblock_reset(
        codec,
        buffer + offset + shm_tensorpool_control_messageHeader_encoded_length(),
        0,
        buffer_length - shm_tensorpool_control_messageHeader_encoded_length(),
        shm_tensorpool_control_shmRegionSuperblock_sbe_block_length(),
        shm_tensorpool_control_shmRegionSuperblock_sbe_schema_version());

    return codec;
}

SBE_ONE_DEF struct shm_tensorpool_control_shmRegionSuperblock *shm_tensorpool_control_shmRegionSuperblock_wrap_for_encode(
    struct shm_tensorpool_control_shmRegionSuperblock *const codec,
    char *buffer,
    const uint64_t offset,
    const uint64_t buffer_length)
{
    return shm_tensorpool_control_shmRegionSuperblock_reset(
        codec,
        buffer,
        offset,
        buffer_length,
        shm_tensorpool_control_shmRegionSuperblock_sbe_block_length(),
        shm_tensorpool_control_shmRegionSuperblock_sbe_schema_version());
}

SBE_ONE_DEF struct shm_tensorpool_control_shmRegionSuperblock *shm_tensorpool_control_shmRegionSuperblock_wrap_for_decode(
    struct shm_tensorpool_control_shmRegionSuperblock *const codec,
    char *buffer,
    const uint64_t offset,
    const uint64_t acting_block_length,
    const uint64_t acting_version,
    const uint64_t buffer_length)
{
    return shm_tensorpool_control_shmRegionSuperblock_reset(
        codec,
        buffer,
        offset,
        buffer_length,
        acting_block_length,
        acting_version);
}

SBE_ONE_DEF struct shm_tensorpool_control_shmRegionSuperblock *shm_tensorpool_control_shmRegionSuperblock_sbe_rewind(
    struct shm_tensorpool_control_shmRegionSuperblock *const codec)
{
    return shm_tensorpool_control_shmRegionSuperblock_wrap_for_decode(
        codec,
        codec->buffer,
        codec->offset,
        codec->acting_block_length,
        codec->acting_version,
        codec->buffer_length);
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmRegionSuperblock_encoded_length(
    const struct shm_tensorpool_control_shmRegionSuperblock *const codec)
{
    return shm_tensorpool_control_shmRegionSuperblock_sbe_position(codec) - codec->offset;
}

SBE_ONE_DEF const char *shm_tensorpool_control_shmRegionSuperblock_buffer(
    const struct shm_tensorpool_control_shmRegionSuperblock *const codec)
{
    return codec->buffer;
}

SBE_ONE_DEF char *shm_tensorpool_control_shmRegionSuperblock_mut_buffer(
    struct shm_tensorpool_control_shmRegionSuperblock *const codec)
{
    return codec->buffer;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmRegionSuperblock_buffer_length(
    const struct shm_tensorpool_control_shmRegionSuperblock *const codec)
{
    return codec->buffer_length;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmRegionSuperblock_acting_version(
    const struct shm_tensorpool_control_shmRegionSuperblock *const codec)
{
    return codec->acting_version;
}

SBE_ONE_DEF const char *shm_tensorpool_control_shmRegionSuperblock_magic_meta_attribute(
    const enum shm_tensorpool_control_shmRegionSuperblock_meta_attribute attribute)
{
    switch (attribute)
    {
        case shm_tensorpool_control_shmRegionSuperblock_meta_attribute_EPOCH: return "";
        case shm_tensorpool_control_shmRegionSuperblock_meta_attribute_TIME_UNIT: return "";
        case shm_tensorpool_control_shmRegionSuperblock_meta_attribute_SEMANTIC_TYPE: return "";
        case shm_tensorpool_control_shmRegionSuperblock_meta_attribute_PRESENCE: return "required";
    }

    return "";
}

SBE_ONE_DEF uint16_t shm_tensorpool_control_shmRegionSuperblock_magic_id(void)
{
    return 1;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmRegionSuperblock_magic_since_version(void)
{
    return 0;
}

SBE_ONE_DEF bool shm_tensorpool_control_shmRegionSuperblock_magic_in_acting_version(
    const struct shm_tensorpool_control_shmRegionSuperblock *const codec)
{
#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wtautological-compare"
#endif
    return codec->acting_version >= shm_tensorpool_control_shmRegionSuperblock_magic_since_version();
#if defined(__clang__)
#pragma clang diagnostic pop
#endif
}

SBE_ONE_DEF size_t shm_tensorpool_control_shmRegionSuperblock_magic_encoding_offset(void)
{
    return 0;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmRegionSuperblock_magic_null_value(void)
{
    return SBE_NULLVALUE_UINT64;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmRegionSuperblock_magic_min_value(void)
{
    return UINT64_C(0x0);
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmRegionSuperblock_magic_max_value(void)
{
    return UINT64_C(0xfffffffffffffffe);
}

SBE_ONE_DEF size_t shm_tensorpool_control_shmRegionSuperblock_magic_encoding_length(void)
{
    return 8;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmRegionSuperblock_magic(
    const struct shm_tensorpool_control_shmRegionSuperblock *const codec)
{
    uint64_t val;
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
#endif
    memcpy(&val, codec->buffer + codec->offset + 0, sizeof(uint64_t));
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic pop
#endif
    return SBE_LITTLE_ENDIAN_ENCODE_64(val);
}

SBE_ONE_DEF struct shm_tensorpool_control_shmRegionSuperblock *shm_tensorpool_control_shmRegionSuperblock_set_magic(
    struct shm_tensorpool_control_shmRegionSuperblock *const codec,
    const uint64_t value)
{
    uint64_t val = SBE_LITTLE_ENDIAN_ENCODE_64(value);
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
#endif
    memcpy(codec->buffer + codec->offset + 0, &val, sizeof(uint64_t));
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic pop
#endif
    return codec;
}

SBE_ONE_DEF const char *shm_tensorpool_control_shmRegionSuperblock_layoutVersion_meta_attribute(
    const enum shm_tensorpool_control_shmRegionSuperblock_meta_attribute attribute)
{
    switch (attribute)
    {
        case shm_tensorpool_control_shmRegionSuperblock_meta_attribute_EPOCH: return "";
        case shm_tensorpool_control_shmRegionSuperblock_meta_attribute_TIME_UNIT: return "";
        case shm_tensorpool_control_shmRegionSuperblock_meta_attribute_SEMANTIC_TYPE: return "";
        case shm_tensorpool_control_shmRegionSuperblock_meta_attribute_PRESENCE: return "required";
    }

    return "";
}

SBE_ONE_DEF uint16_t shm_tensorpool_control_shmRegionSuperblock_layoutVersion_id(void)
{
    return 2;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmRegionSuperblock_layoutVersion_since_version(void)
{
    return 0;
}

SBE_ONE_DEF bool shm_tensorpool_control_shmRegionSuperblock_layoutVersion_in_acting_version(
    const struct shm_tensorpool_control_shmRegionSuperblock *const codec)
{
#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wtautological-compare"
#endif
    return codec->acting_version >= shm_tensorpool_control_shmRegionSuperblock_layoutVersion_since_version();
#if defined(__clang__)
#pragma clang diagnostic pop
#endif
}

SBE_ONE_DEF size_t shm_tensorpool_control_shmRegionSuperblock_layoutVersion_encoding_offset(void)
{
    return 8;
}

SBE_ONE_DEF uint32_t shm_tensorpool_control_shmRegionSuperblock_layoutVersion_null_value(void)
{
    return SBE_NULLVALUE_UINT32;
}

SBE_ONE_DEF uint32_t shm_tensorpool_control_shmRegionSuperblock_layoutVersion_min_value(void)
{
    return UINT32_C(0x0);
}

SBE_ONE_DEF uint32_t shm_tensorpool_control_shmRegionSuperblock_layoutVersion_max_value(void)
{
    return UINT32_C(0xfffffffe);
}

SBE_ONE_DEF size_t shm_tensorpool_control_shmRegionSuperblock_layoutVersion_encoding_length(void)
{
    return 4;
}

SBE_ONE_DEF uint32_t shm_tensorpool_control_shmRegionSuperblock_layoutVersion(
    const struct shm_tensorpool_control_shmRegionSuperblock *const codec)
{
    uint32_t val;
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
#endif
    memcpy(&val, codec->buffer + codec->offset + 8, sizeof(uint32_t));
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic pop
#endif
    return SBE_LITTLE_ENDIAN_ENCODE_32(val);
}

SBE_ONE_DEF struct shm_tensorpool_control_shmRegionSuperblock *shm_tensorpool_control_shmRegionSuperblock_set_layoutVersion(
    struct shm_tensorpool_control_shmRegionSuperblock *const codec,
    const uint32_t value)
{
    uint32_t val = SBE_LITTLE_ENDIAN_ENCODE_32(value);
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
#endif
    memcpy(codec->buffer + codec->offset + 8, &val, sizeof(uint32_t));
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic pop
#endif
    return codec;
}

SBE_ONE_DEF const char *shm_tensorpool_control_shmRegionSuperblock_epoch_meta_attribute(
    const enum shm_tensorpool_control_shmRegionSuperblock_meta_attribute attribute)
{
    switch (attribute)
    {
        case shm_tensorpool_control_shmRegionSuperblock_meta_attribute_EPOCH: return "";
        case shm_tensorpool_control_shmRegionSuperblock_meta_attribute_TIME_UNIT: return "";
        case shm_tensorpool_control_shmRegionSuperblock_meta_attribute_SEMANTIC_TYPE: return "";
        case shm_tensorpool_control_shmRegionSuperblock_meta_attribute_PRESENCE: return "required";
    }

    return "";
}

SBE_ONE_DEF uint16_t shm_tensorpool_control_shmRegionSuperblock_epoch_id(void)
{
    return 3;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmRegionSuperblock_epoch_since_version(void)
{
    return 0;
}

SBE_ONE_DEF bool shm_tensorpool_control_shmRegionSuperblock_epoch_in_acting_version(
    const struct shm_tensorpool_control_shmRegionSuperblock *const codec)
{
#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wtautological-compare"
#endif
    return codec->acting_version >= shm_tensorpool_control_shmRegionSuperblock_epoch_since_version();
#if defined(__clang__)
#pragma clang diagnostic pop
#endif
}

SBE_ONE_DEF size_t shm_tensorpool_control_shmRegionSuperblock_epoch_encoding_offset(void)
{
    return 12;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmRegionSuperblock_epoch_null_value(void)
{
    return SBE_NULLVALUE_UINT64;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmRegionSuperblock_epoch_min_value(void)
{
    return UINT64_C(0x0);
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmRegionSuperblock_epoch_max_value(void)
{
    return UINT64_C(0xfffffffffffffffe);
}

SBE_ONE_DEF size_t shm_tensorpool_control_shmRegionSuperblock_epoch_encoding_length(void)
{
    return 8;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmRegionSuperblock_epoch(
    const struct shm_tensorpool_control_shmRegionSuperblock *const codec)
{
    uint64_t val;
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
#endif
    memcpy(&val, codec->buffer + codec->offset + 12, sizeof(uint64_t));
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic pop
#endif
    return SBE_LITTLE_ENDIAN_ENCODE_64(val);
}

SBE_ONE_DEF struct shm_tensorpool_control_shmRegionSuperblock *shm_tensorpool_control_shmRegionSuperblock_set_epoch(
    struct shm_tensorpool_control_shmRegionSuperblock *const codec,
    const uint64_t value)
{
    uint64_t val = SBE_LITTLE_ENDIAN_ENCODE_64(value);
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
#endif
    memcpy(codec->buffer + codec->offset + 12, &val, sizeof(uint64_t));
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic pop
#endif
    return codec;
}

SBE_ONE_DEF const char *shm_tensorpool_control_shmRegionSuperblock_streamId_meta_attribute(
    const enum shm_tensorpool_control_shmRegionSuperblock_meta_attribute attribute)
{
    switch (attribute)
    {
        case shm_tensorpool_control_shmRegionSuperblock_meta_attribute_EPOCH: return "";
        case shm_tensorpool_control_shmRegionSuperblock_meta_attribute_TIME_UNIT: return "";
        case shm_tensorpool_control_shmRegionSuperblock_meta_attribute_SEMANTIC_TYPE: return "";
        case shm_tensorpool_control_shmRegionSuperblock_meta_attribute_PRESENCE: return "required";
    }

    return "";
}

SBE_ONE_DEF uint16_t shm_tensorpool_control_shmRegionSuperblock_streamId_id(void)
{
    return 4;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmRegionSuperblock_streamId_since_version(void)
{
    return 0;
}

SBE_ONE_DEF bool shm_tensorpool_control_shmRegionSuperblock_streamId_in_acting_version(
    const struct shm_tensorpool_control_shmRegionSuperblock *const codec)
{
#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wtautological-compare"
#endif
    return codec->acting_version >= shm_tensorpool_control_shmRegionSuperblock_streamId_since_version();
#if defined(__clang__)
#pragma clang diagnostic pop
#endif
}

SBE_ONE_DEF size_t shm_tensorpool_control_shmRegionSuperblock_streamId_encoding_offset(void)
{
    return 20;
}

SBE_ONE_DEF uint32_t shm_tensorpool_control_shmRegionSuperblock_streamId_null_value(void)
{
    return SBE_NULLVALUE_UINT32;
}

SBE_ONE_DEF uint32_t shm_tensorpool_control_shmRegionSuperblock_streamId_min_value(void)
{
    return UINT32_C(0x0);
}

SBE_ONE_DEF uint32_t shm_tensorpool_control_shmRegionSuperblock_streamId_max_value(void)
{
    return UINT32_C(0xfffffffe);
}

SBE_ONE_DEF size_t shm_tensorpool_control_shmRegionSuperblock_streamId_encoding_length(void)
{
    return 4;
}

SBE_ONE_DEF uint32_t shm_tensorpool_control_shmRegionSuperblock_streamId(
    const struct shm_tensorpool_control_shmRegionSuperblock *const codec)
{
    uint32_t val;
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
#endif
    memcpy(&val, codec->buffer + codec->offset + 20, sizeof(uint32_t));
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic pop
#endif
    return SBE_LITTLE_ENDIAN_ENCODE_32(val);
}

SBE_ONE_DEF struct shm_tensorpool_control_shmRegionSuperblock *shm_tensorpool_control_shmRegionSuperblock_set_streamId(
    struct shm_tensorpool_control_shmRegionSuperblock *const codec,
    const uint32_t value)
{
    uint32_t val = SBE_LITTLE_ENDIAN_ENCODE_32(value);
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
#endif
    memcpy(codec->buffer + codec->offset + 20, &val, sizeof(uint32_t));
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic pop
#endif
    return codec;
}

SBE_ONE_DEF const char *shm_tensorpool_control_shmRegionSuperblock_regionType_meta_attribute(
    const enum shm_tensorpool_control_shmRegionSuperblock_meta_attribute attribute)
{
    switch (attribute)
    {
        case shm_tensorpool_control_shmRegionSuperblock_meta_attribute_EPOCH: return "";
        case shm_tensorpool_control_shmRegionSuperblock_meta_attribute_TIME_UNIT: return "";
        case shm_tensorpool_control_shmRegionSuperblock_meta_attribute_SEMANTIC_TYPE: return "";
        case shm_tensorpool_control_shmRegionSuperblock_meta_attribute_PRESENCE: return "required";
    }

    return "";
}

SBE_ONE_DEF uint16_t shm_tensorpool_control_shmRegionSuperblock_regionType_id(void)
{
    return 5;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmRegionSuperblock_regionType_since_version(void)
{
    return 0;
}

SBE_ONE_DEF bool shm_tensorpool_control_shmRegionSuperblock_regionType_in_acting_version(
    const struct shm_tensorpool_control_shmRegionSuperblock *const codec)
{
#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wtautological-compare"
#endif
    return codec->acting_version >= shm_tensorpool_control_shmRegionSuperblock_regionType_since_version();
#if defined(__clang__)
#pragma clang diagnostic pop
#endif
}

SBE_ONE_DEF size_t shm_tensorpool_control_shmRegionSuperblock_regionType_encoding_offset(void)
{
    return 24;
}

SBE_ONE_DEF size_t shm_tensorpool_control_shmRegionSuperblock_regionType_encoding_length(void)
{
    return 2;
}

SBE_ONE_DEF bool shm_tensorpool_control_shmRegionSuperblock_regionType(
    const struct shm_tensorpool_control_shmRegionSuperblock *const codec,
    enum shm_tensorpool_control_regionType *const out)
{
    int16_t val;
    memcpy(&val, codec->buffer + codec->offset + 24, sizeof(int16_t));

    return shm_tensorpool_control_regionType_get(SBE_LITTLE_ENDIAN_ENCODE_16(val), out);
}

SBE_ONE_DEF struct shm_tensorpool_control_shmRegionSuperblock *shm_tensorpool_control_shmRegionSuperblock_set_regionType(
    struct shm_tensorpool_control_shmRegionSuperblock *const codec,
    const enum shm_tensorpool_control_regionType value)
{
    int16_t val = SBE_LITTLE_ENDIAN_ENCODE_16(value);
    memcpy(codec->buffer + codec->offset + 24, &val, sizeof(int16_t));

    return codec;
}

SBE_ONE_DEF const char *shm_tensorpool_control_shmRegionSuperblock_poolId_meta_attribute(
    const enum shm_tensorpool_control_shmRegionSuperblock_meta_attribute attribute)
{
    switch (attribute)
    {
        case shm_tensorpool_control_shmRegionSuperblock_meta_attribute_EPOCH: return "";
        case shm_tensorpool_control_shmRegionSuperblock_meta_attribute_TIME_UNIT: return "";
        case shm_tensorpool_control_shmRegionSuperblock_meta_attribute_SEMANTIC_TYPE: return "";
        case shm_tensorpool_control_shmRegionSuperblock_meta_attribute_PRESENCE: return "required";
    }

    return "";
}

SBE_ONE_DEF uint16_t shm_tensorpool_control_shmRegionSuperblock_poolId_id(void)
{
    return 6;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmRegionSuperblock_poolId_since_version(void)
{
    return 0;
}

SBE_ONE_DEF bool shm_tensorpool_control_shmRegionSuperblock_poolId_in_acting_version(
    const struct shm_tensorpool_control_shmRegionSuperblock *const codec)
{
#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wtautological-compare"
#endif
    return codec->acting_version >= shm_tensorpool_control_shmRegionSuperblock_poolId_since_version();
#if defined(__clang__)
#pragma clang diagnostic pop
#endif
}

SBE_ONE_DEF size_t shm_tensorpool_control_shmRegionSuperblock_poolId_encoding_offset(void)
{
    return 26;
}

SBE_ONE_DEF uint16_t shm_tensorpool_control_shmRegionSuperblock_poolId_null_value(void)
{
    return SBE_NULLVALUE_UINT16;
}

SBE_ONE_DEF uint16_t shm_tensorpool_control_shmRegionSuperblock_poolId_min_value(void)
{
    return (uint16_t)0;
}

SBE_ONE_DEF uint16_t shm_tensorpool_control_shmRegionSuperblock_poolId_max_value(void)
{
    return (uint16_t)65534;
}

SBE_ONE_DEF size_t shm_tensorpool_control_shmRegionSuperblock_poolId_encoding_length(void)
{
    return 2;
}

SBE_ONE_DEF uint16_t shm_tensorpool_control_shmRegionSuperblock_poolId(
    const struct shm_tensorpool_control_shmRegionSuperblock *const codec)
{
    uint16_t val;
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
#endif
    memcpy(&val, codec->buffer + codec->offset + 26, sizeof(uint16_t));
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic pop
#endif
    return SBE_LITTLE_ENDIAN_ENCODE_16(val);
}

SBE_ONE_DEF struct shm_tensorpool_control_shmRegionSuperblock *shm_tensorpool_control_shmRegionSuperblock_set_poolId(
    struct shm_tensorpool_control_shmRegionSuperblock *const codec,
    const uint16_t value)
{
    uint16_t val = SBE_LITTLE_ENDIAN_ENCODE_16(value);
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
#endif
    memcpy(codec->buffer + codec->offset + 26, &val, sizeof(uint16_t));
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic pop
#endif
    return codec;
}

SBE_ONE_DEF const char *shm_tensorpool_control_shmRegionSuperblock_nslots_meta_attribute(
    const enum shm_tensorpool_control_shmRegionSuperblock_meta_attribute attribute)
{
    switch (attribute)
    {
        case shm_tensorpool_control_shmRegionSuperblock_meta_attribute_EPOCH: return "";
        case shm_tensorpool_control_shmRegionSuperblock_meta_attribute_TIME_UNIT: return "";
        case shm_tensorpool_control_shmRegionSuperblock_meta_attribute_SEMANTIC_TYPE: return "";
        case shm_tensorpool_control_shmRegionSuperblock_meta_attribute_PRESENCE: return "required";
    }

    return "";
}

SBE_ONE_DEF uint16_t shm_tensorpool_control_shmRegionSuperblock_nslots_id(void)
{
    return 7;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmRegionSuperblock_nslots_since_version(void)
{
    return 0;
}

SBE_ONE_DEF bool shm_tensorpool_control_shmRegionSuperblock_nslots_in_acting_version(
    const struct shm_tensorpool_control_shmRegionSuperblock *const codec)
{
#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wtautological-compare"
#endif
    return codec->acting_version >= shm_tensorpool_control_shmRegionSuperblock_nslots_since_version();
#if defined(__clang__)
#pragma clang diagnostic pop
#endif
}

SBE_ONE_DEF size_t shm_tensorpool_control_shmRegionSuperblock_nslots_encoding_offset(void)
{
    return 28;
}

SBE_ONE_DEF uint32_t shm_tensorpool_control_shmRegionSuperblock_nslots_null_value(void)
{
    return SBE_NULLVALUE_UINT32;
}

SBE_ONE_DEF uint32_t shm_tensorpool_control_shmRegionSuperblock_nslots_min_value(void)
{
    return UINT32_C(0x0);
}

SBE_ONE_DEF uint32_t shm_tensorpool_control_shmRegionSuperblock_nslots_max_value(void)
{
    return UINT32_C(0xfffffffe);
}

SBE_ONE_DEF size_t shm_tensorpool_control_shmRegionSuperblock_nslots_encoding_length(void)
{
    return 4;
}

SBE_ONE_DEF uint32_t shm_tensorpool_control_shmRegionSuperblock_nslots(
    const struct shm_tensorpool_control_shmRegionSuperblock *const codec)
{
    uint32_t val;
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
#endif
    memcpy(&val, codec->buffer + codec->offset + 28, sizeof(uint32_t));
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic pop
#endif
    return SBE_LITTLE_ENDIAN_ENCODE_32(val);
}

SBE_ONE_DEF struct shm_tensorpool_control_shmRegionSuperblock *shm_tensorpool_control_shmRegionSuperblock_set_nslots(
    struct shm_tensorpool_control_shmRegionSuperblock *const codec,
    const uint32_t value)
{
    uint32_t val = SBE_LITTLE_ENDIAN_ENCODE_32(value);
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
#endif
    memcpy(codec->buffer + codec->offset + 28, &val, sizeof(uint32_t));
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic pop
#endif
    return codec;
}

SBE_ONE_DEF const char *shm_tensorpool_control_shmRegionSuperblock_slotBytes_meta_attribute(
    const enum shm_tensorpool_control_shmRegionSuperblock_meta_attribute attribute)
{
    switch (attribute)
    {
        case shm_tensorpool_control_shmRegionSuperblock_meta_attribute_EPOCH: return "";
        case shm_tensorpool_control_shmRegionSuperblock_meta_attribute_TIME_UNIT: return "";
        case shm_tensorpool_control_shmRegionSuperblock_meta_attribute_SEMANTIC_TYPE: return "";
        case shm_tensorpool_control_shmRegionSuperblock_meta_attribute_PRESENCE: return "required";
    }

    return "";
}

SBE_ONE_DEF uint16_t shm_tensorpool_control_shmRegionSuperblock_slotBytes_id(void)
{
    return 8;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmRegionSuperblock_slotBytes_since_version(void)
{
    return 0;
}

SBE_ONE_DEF bool shm_tensorpool_control_shmRegionSuperblock_slotBytes_in_acting_version(
    const struct shm_tensorpool_control_shmRegionSuperblock *const codec)
{
#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wtautological-compare"
#endif
    return codec->acting_version >= shm_tensorpool_control_shmRegionSuperblock_slotBytes_since_version();
#if defined(__clang__)
#pragma clang diagnostic pop
#endif
}

SBE_ONE_DEF size_t shm_tensorpool_control_shmRegionSuperblock_slotBytes_encoding_offset(void)
{
    return 32;
}

SBE_ONE_DEF uint32_t shm_tensorpool_control_shmRegionSuperblock_slotBytes_null_value(void)
{
    return SBE_NULLVALUE_UINT32;
}

SBE_ONE_DEF uint32_t shm_tensorpool_control_shmRegionSuperblock_slotBytes_min_value(void)
{
    return UINT32_C(0x0);
}

SBE_ONE_DEF uint32_t shm_tensorpool_control_shmRegionSuperblock_slotBytes_max_value(void)
{
    return UINT32_C(0xfffffffe);
}

SBE_ONE_DEF size_t shm_tensorpool_control_shmRegionSuperblock_slotBytes_encoding_length(void)
{
    return 4;
}

SBE_ONE_DEF uint32_t shm_tensorpool_control_shmRegionSuperblock_slotBytes(
    const struct shm_tensorpool_control_shmRegionSuperblock *const codec)
{
    uint32_t val;
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
#endif
    memcpy(&val, codec->buffer + codec->offset + 32, sizeof(uint32_t));
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic pop
#endif
    return SBE_LITTLE_ENDIAN_ENCODE_32(val);
}

SBE_ONE_DEF struct shm_tensorpool_control_shmRegionSuperblock *shm_tensorpool_control_shmRegionSuperblock_set_slotBytes(
    struct shm_tensorpool_control_shmRegionSuperblock *const codec,
    const uint32_t value)
{
    uint32_t val = SBE_LITTLE_ENDIAN_ENCODE_32(value);
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
#endif
    memcpy(codec->buffer + codec->offset + 32, &val, sizeof(uint32_t));
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic pop
#endif
    return codec;
}

SBE_ONE_DEF const char *shm_tensorpool_control_shmRegionSuperblock_strideBytes_meta_attribute(
    const enum shm_tensorpool_control_shmRegionSuperblock_meta_attribute attribute)
{
    switch (attribute)
    {
        case shm_tensorpool_control_shmRegionSuperblock_meta_attribute_EPOCH: return "";
        case shm_tensorpool_control_shmRegionSuperblock_meta_attribute_TIME_UNIT: return "";
        case shm_tensorpool_control_shmRegionSuperblock_meta_attribute_SEMANTIC_TYPE: return "";
        case shm_tensorpool_control_shmRegionSuperblock_meta_attribute_PRESENCE: return "required";
    }

    return "";
}

SBE_ONE_DEF uint16_t shm_tensorpool_control_shmRegionSuperblock_strideBytes_id(void)
{
    return 9;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmRegionSuperblock_strideBytes_since_version(void)
{
    return 0;
}

SBE_ONE_DEF bool shm_tensorpool_control_shmRegionSuperblock_strideBytes_in_acting_version(
    const struct shm_tensorpool_control_shmRegionSuperblock *const codec)
{
#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wtautological-compare"
#endif
    return codec->acting_version >= shm_tensorpool_control_shmRegionSuperblock_strideBytes_since_version();
#if defined(__clang__)
#pragma clang diagnostic pop
#endif
}

SBE_ONE_DEF size_t shm_tensorpool_control_shmRegionSuperblock_strideBytes_encoding_offset(void)
{
    return 36;
}

SBE_ONE_DEF uint32_t shm_tensorpool_control_shmRegionSuperblock_strideBytes_null_value(void)
{
    return SBE_NULLVALUE_UINT32;
}

SBE_ONE_DEF uint32_t shm_tensorpool_control_shmRegionSuperblock_strideBytes_min_value(void)
{
    return UINT32_C(0x0);
}

SBE_ONE_DEF uint32_t shm_tensorpool_control_shmRegionSuperblock_strideBytes_max_value(void)
{
    return UINT32_C(0xfffffffe);
}

SBE_ONE_DEF size_t shm_tensorpool_control_shmRegionSuperblock_strideBytes_encoding_length(void)
{
    return 4;
}

SBE_ONE_DEF uint32_t shm_tensorpool_control_shmRegionSuperblock_strideBytes(
    const struct shm_tensorpool_control_shmRegionSuperblock *const codec)
{
    uint32_t val;
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
#endif
    memcpy(&val, codec->buffer + codec->offset + 36, sizeof(uint32_t));
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic pop
#endif
    return SBE_LITTLE_ENDIAN_ENCODE_32(val);
}

SBE_ONE_DEF struct shm_tensorpool_control_shmRegionSuperblock *shm_tensorpool_control_shmRegionSuperblock_set_strideBytes(
    struct shm_tensorpool_control_shmRegionSuperblock *const codec,
    const uint32_t value)
{
    uint32_t val = SBE_LITTLE_ENDIAN_ENCODE_32(value);
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
#endif
    memcpy(codec->buffer + codec->offset + 36, &val, sizeof(uint32_t));
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic pop
#endif
    return codec;
}

SBE_ONE_DEF const char *shm_tensorpool_control_shmRegionSuperblock_pid_meta_attribute(
    const enum shm_tensorpool_control_shmRegionSuperblock_meta_attribute attribute)
{
    switch (attribute)
    {
        case shm_tensorpool_control_shmRegionSuperblock_meta_attribute_EPOCH: return "";
        case shm_tensorpool_control_shmRegionSuperblock_meta_attribute_TIME_UNIT: return "";
        case shm_tensorpool_control_shmRegionSuperblock_meta_attribute_SEMANTIC_TYPE: return "";
        case shm_tensorpool_control_shmRegionSuperblock_meta_attribute_PRESENCE: return "required";
    }

    return "";
}

SBE_ONE_DEF uint16_t shm_tensorpool_control_shmRegionSuperblock_pid_id(void)
{
    return 10;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmRegionSuperblock_pid_since_version(void)
{
    return 0;
}

SBE_ONE_DEF bool shm_tensorpool_control_shmRegionSuperblock_pid_in_acting_version(
    const struct shm_tensorpool_control_shmRegionSuperblock *const codec)
{
#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wtautological-compare"
#endif
    return codec->acting_version >= shm_tensorpool_control_shmRegionSuperblock_pid_since_version();
#if defined(__clang__)
#pragma clang diagnostic pop
#endif
}

SBE_ONE_DEF size_t shm_tensorpool_control_shmRegionSuperblock_pid_encoding_offset(void)
{
    return 40;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmRegionSuperblock_pid_null_value(void)
{
    return SBE_NULLVALUE_UINT64;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmRegionSuperblock_pid_min_value(void)
{
    return UINT64_C(0x0);
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmRegionSuperblock_pid_max_value(void)
{
    return UINT64_C(0xfffffffffffffffe);
}

SBE_ONE_DEF size_t shm_tensorpool_control_shmRegionSuperblock_pid_encoding_length(void)
{
    return 8;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmRegionSuperblock_pid(
    const struct shm_tensorpool_control_shmRegionSuperblock *const codec)
{
    uint64_t val;
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
#endif
    memcpy(&val, codec->buffer + codec->offset + 40, sizeof(uint64_t));
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic pop
#endif
    return SBE_LITTLE_ENDIAN_ENCODE_64(val);
}

SBE_ONE_DEF struct shm_tensorpool_control_shmRegionSuperblock *shm_tensorpool_control_shmRegionSuperblock_set_pid(
    struct shm_tensorpool_control_shmRegionSuperblock *const codec,
    const uint64_t value)
{
    uint64_t val = SBE_LITTLE_ENDIAN_ENCODE_64(value);
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
#endif
    memcpy(codec->buffer + codec->offset + 40, &val, sizeof(uint64_t));
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic pop
#endif
    return codec;
}

SBE_ONE_DEF const char *shm_tensorpool_control_shmRegionSuperblock_startTimestampNs_meta_attribute(
    const enum shm_tensorpool_control_shmRegionSuperblock_meta_attribute attribute)
{
    switch (attribute)
    {
        case shm_tensorpool_control_shmRegionSuperblock_meta_attribute_EPOCH: return "";
        case shm_tensorpool_control_shmRegionSuperblock_meta_attribute_TIME_UNIT: return "";
        case shm_tensorpool_control_shmRegionSuperblock_meta_attribute_SEMANTIC_TYPE: return "";
        case shm_tensorpool_control_shmRegionSuperblock_meta_attribute_PRESENCE: return "required";
    }

    return "";
}

SBE_ONE_DEF uint16_t shm_tensorpool_control_shmRegionSuperblock_startTimestampNs_id(void)
{
    return 11;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmRegionSuperblock_startTimestampNs_since_version(void)
{
    return 0;
}

SBE_ONE_DEF bool shm_tensorpool_control_shmRegionSuperblock_startTimestampNs_in_acting_version(
    const struct shm_tensorpool_control_shmRegionSuperblock *const codec)
{
#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wtautological-compare"
#endif
    return codec->acting_version >= shm_tensorpool_control_shmRegionSuperblock_startTimestampNs_since_version();
#if defined(__clang__)
#pragma clang diagnostic pop
#endif
}

SBE_ONE_DEF size_t shm_tensorpool_control_shmRegionSuperblock_startTimestampNs_encoding_offset(void)
{
    return 48;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmRegionSuperblock_startTimestampNs_null_value(void)
{
    return SBE_NULLVALUE_UINT64;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmRegionSuperblock_startTimestampNs_min_value(void)
{
    return UINT64_C(0x0);
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmRegionSuperblock_startTimestampNs_max_value(void)
{
    return UINT64_C(0xfffffffffffffffe);
}

SBE_ONE_DEF size_t shm_tensorpool_control_shmRegionSuperblock_startTimestampNs_encoding_length(void)
{
    return 8;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmRegionSuperblock_startTimestampNs(
    const struct shm_tensorpool_control_shmRegionSuperblock *const codec)
{
    uint64_t val;
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
#endif
    memcpy(&val, codec->buffer + codec->offset + 48, sizeof(uint64_t));
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic pop
#endif
    return SBE_LITTLE_ENDIAN_ENCODE_64(val);
}

SBE_ONE_DEF struct shm_tensorpool_control_shmRegionSuperblock *shm_tensorpool_control_shmRegionSuperblock_set_startTimestampNs(
    struct shm_tensorpool_control_shmRegionSuperblock *const codec,
    const uint64_t value)
{
    uint64_t val = SBE_LITTLE_ENDIAN_ENCODE_64(value);
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
#endif
    memcpy(codec->buffer + codec->offset + 48, &val, sizeof(uint64_t));
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic pop
#endif
    return codec;
}

SBE_ONE_DEF const char *shm_tensorpool_control_shmRegionSuperblock_activityTimestampNs_meta_attribute(
    const enum shm_tensorpool_control_shmRegionSuperblock_meta_attribute attribute)
{
    switch (attribute)
    {
        case shm_tensorpool_control_shmRegionSuperblock_meta_attribute_EPOCH: return "";
        case shm_tensorpool_control_shmRegionSuperblock_meta_attribute_TIME_UNIT: return "";
        case shm_tensorpool_control_shmRegionSuperblock_meta_attribute_SEMANTIC_TYPE: return "";
        case shm_tensorpool_control_shmRegionSuperblock_meta_attribute_PRESENCE: return "required";
    }

    return "";
}

SBE_ONE_DEF uint16_t shm_tensorpool_control_shmRegionSuperblock_activityTimestampNs_id(void)
{
    return 12;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmRegionSuperblock_activityTimestampNs_since_version(void)
{
    return 0;
}

SBE_ONE_DEF bool shm_tensorpool_control_shmRegionSuperblock_activityTimestampNs_in_acting_version(
    const struct shm_tensorpool_control_shmRegionSuperblock *const codec)
{
#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wtautological-compare"
#endif
    return codec->acting_version >= shm_tensorpool_control_shmRegionSuperblock_activityTimestampNs_since_version();
#if defined(__clang__)
#pragma clang diagnostic pop
#endif
}

SBE_ONE_DEF size_t shm_tensorpool_control_shmRegionSuperblock_activityTimestampNs_encoding_offset(void)
{
    return 56;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmRegionSuperblock_activityTimestampNs_null_value(void)
{
    return SBE_NULLVALUE_UINT64;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmRegionSuperblock_activityTimestampNs_min_value(void)
{
    return UINT64_C(0x0);
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmRegionSuperblock_activityTimestampNs_max_value(void)
{
    return UINT64_C(0xfffffffffffffffe);
}

SBE_ONE_DEF size_t shm_tensorpool_control_shmRegionSuperblock_activityTimestampNs_encoding_length(void)
{
    return 8;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_shmRegionSuperblock_activityTimestampNs(
    const struct shm_tensorpool_control_shmRegionSuperblock *const codec)
{
    uint64_t val;
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
#endif
    memcpy(&val, codec->buffer + codec->offset + 56, sizeof(uint64_t));
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic pop
#endif
    return SBE_LITTLE_ENDIAN_ENCODE_64(val);
}

SBE_ONE_DEF struct shm_tensorpool_control_shmRegionSuperblock *shm_tensorpool_control_shmRegionSuperblock_set_activityTimestampNs(
    struct shm_tensorpool_control_shmRegionSuperblock *const codec,
    const uint64_t value)
{
    uint64_t val = SBE_LITTLE_ENDIAN_ENCODE_64(value);
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
#endif
    memcpy(codec->buffer + codec->offset + 56, &val, sizeof(uint64_t));
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic pop
#endif
    return codec;
}

#endif
