/* Generated SBE (Simple Binary Encoding) message codec */

#ifndef _SHM_TENSORPOOL_CONTROL_TENSORHEADER_H_
#define _SHM_TENSORPOOL_CONTROL_TENSORHEADER_H_

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

struct shm_tensorpool_control_tensorHeader
{
    char *buffer;
    uint64_t buffer_length;
    uint64_t offset;
    uint64_t position;
    uint64_t acting_block_length;
    uint64_t acting_version;
};

enum shm_tensorpool_control_tensorHeader_meta_attribute
{
    shm_tensorpool_control_tensorHeader_meta_attribute_EPOCH,
    shm_tensorpool_control_tensorHeader_meta_attribute_TIME_UNIT,
    shm_tensorpool_control_tensorHeader_meta_attribute_SEMANTIC_TYPE,
    shm_tensorpool_control_tensorHeader_meta_attribute_PRESENCE
};

union shm_tensorpool_control_tensorHeader_float_as_uint
{
    float fp_value;
    uint32_t uint_value;
};

union shm_tensorpool_control_tensorHeader_double_as_uint
{
    double fp_value;
    uint64_t uint_value;
};

struct shm_tensorpool_control_tensorHeader_string_view
{
    const char* data;
    size_t length;
};

SBE_ONE_DEF uint64_t shm_tensorpool_control_tensorHeader_sbe_position(
    const struct shm_tensorpool_control_tensorHeader *const codec)
{
    return codec->position;
}

SBE_ONE_DEF bool shm_tensorpool_control_tensorHeader_set_sbe_position(
    struct shm_tensorpool_control_tensorHeader *const codec,
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

SBE_ONE_DEF uint64_t *shm_tensorpool_control_tensorHeader_sbe_position_ptr(
    struct shm_tensorpool_control_tensorHeader *const codec)
{
    return &codec->position;
}

SBE_ONE_DEF struct shm_tensorpool_control_tensorHeader *shm_tensorpool_control_tensorHeader_reset(
    struct shm_tensorpool_control_tensorHeader *const codec,
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
    if (!shm_tensorpool_control_tensorHeader_set_sbe_position(codec, offset + acting_block_length))
    {
        return NULL;
    }

    return codec;
}

SBE_ONE_DEF struct shm_tensorpool_control_tensorHeader *shm_tensorpool_control_tensorHeader_copy(
    struct shm_tensorpool_control_tensorHeader *const codec,
    const struct shm_tensorpool_control_tensorHeader *const other)
{
     codec->buffer = other->buffer;
     codec->offset = other->offset;
     codec->buffer_length = other->buffer_length;
     codec->acting_block_length = other->acting_block_length;
     codec->acting_version = other->acting_version;
     codec->position = other->position;

     return codec;
}

SBE_ONE_DEF uint16_t shm_tensorpool_control_tensorHeader_sbe_block_length(void)
{
    return (uint16_t)184;
}

#define SHM_TENSORPOOL_CONTROL_TENSOR_HEADER_SBE_TEMPLATE_ID (uint16_t)52

SBE_ONE_DEF uint16_t shm_tensorpool_control_tensorHeader_sbe_template_id(void)
{
    return (uint16_t)52;
}

SBE_ONE_DEF uint16_t shm_tensorpool_control_tensorHeader_sbe_schema_id(void)
{
    return (uint16_t)900;
}

SBE_ONE_DEF uint16_t shm_tensorpool_control_tensorHeader_sbe_schema_version(void)
{
    return (uint16_t)1;
}

SBE_ONE_DEF const char* shm_tensorpool_control_tensorHeader_sbe_semantic_version(void)
{
    return "1.1";
}

SBE_ONE_DEF const char *shm_tensorpool_control_tensorHeader_sbe_semantic_type(void)
{
    return "";
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_tensorHeader_offset(
    const struct shm_tensorpool_control_tensorHeader *const codec)
{
    return codec->offset;
}

SBE_ONE_DEF struct shm_tensorpool_control_tensorHeader *shm_tensorpool_control_tensorHeader_wrap_and_apply_header(
    struct shm_tensorpool_control_tensorHeader *const codec,
    char *buffer,
    const uint64_t offset,
    const uint64_t buffer_length,
    struct shm_tensorpool_control_messageHeader *const hdr)
{
    shm_tensorpool_control_messageHeader_wrap(
        hdr, buffer + offset, 0, shm_tensorpool_control_messageHeader_sbe_schema_version(), buffer_length);

    shm_tensorpool_control_messageHeader_set_blockLength(hdr, shm_tensorpool_control_tensorHeader_sbe_block_length());
    shm_tensorpool_control_messageHeader_set_templateId(hdr, shm_tensorpool_control_tensorHeader_sbe_template_id());
    shm_tensorpool_control_messageHeader_set_schemaId(hdr, shm_tensorpool_control_tensorHeader_sbe_schema_id());
    shm_tensorpool_control_messageHeader_set_version(hdr, shm_tensorpool_control_tensorHeader_sbe_schema_version());

    shm_tensorpool_control_tensorHeader_reset(
        codec,
        buffer + offset + shm_tensorpool_control_messageHeader_encoded_length(),
        0,
        buffer_length - shm_tensorpool_control_messageHeader_encoded_length(),
        shm_tensorpool_control_tensorHeader_sbe_block_length(),
        shm_tensorpool_control_tensorHeader_sbe_schema_version());

    return codec;
}

SBE_ONE_DEF struct shm_tensorpool_control_tensorHeader *shm_tensorpool_control_tensorHeader_wrap_for_encode(
    struct shm_tensorpool_control_tensorHeader *const codec,
    char *buffer,
    const uint64_t offset,
    const uint64_t buffer_length)
{
    return shm_tensorpool_control_tensorHeader_reset(
        codec,
        buffer,
        offset,
        buffer_length,
        shm_tensorpool_control_tensorHeader_sbe_block_length(),
        shm_tensorpool_control_tensorHeader_sbe_schema_version());
}

SBE_ONE_DEF struct shm_tensorpool_control_tensorHeader *shm_tensorpool_control_tensorHeader_wrap_for_decode(
    struct shm_tensorpool_control_tensorHeader *const codec,
    char *buffer,
    const uint64_t offset,
    const uint64_t acting_block_length,
    const uint64_t acting_version,
    const uint64_t buffer_length)
{
    return shm_tensorpool_control_tensorHeader_reset(
        codec,
        buffer,
        offset,
        buffer_length,
        acting_block_length,
        acting_version);
}

SBE_ONE_DEF struct shm_tensorpool_control_tensorHeader *shm_tensorpool_control_tensorHeader_sbe_rewind(
    struct shm_tensorpool_control_tensorHeader *const codec)
{
    return shm_tensorpool_control_tensorHeader_wrap_for_decode(
        codec,
        codec->buffer,
        codec->offset,
        codec->acting_block_length,
        codec->acting_version,
        codec->buffer_length);
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_tensorHeader_encoded_length(
    const struct shm_tensorpool_control_tensorHeader *const codec)
{
    return shm_tensorpool_control_tensorHeader_sbe_position(codec) - codec->offset;
}

SBE_ONE_DEF const char *shm_tensorpool_control_tensorHeader_buffer(
    const struct shm_tensorpool_control_tensorHeader *const codec)
{
    return codec->buffer;
}

SBE_ONE_DEF char *shm_tensorpool_control_tensorHeader_mut_buffer(
    struct shm_tensorpool_control_tensorHeader *const codec)
{
    return codec->buffer;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_tensorHeader_buffer_length(
    const struct shm_tensorpool_control_tensorHeader *const codec)
{
    return codec->buffer_length;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_tensorHeader_acting_version(
    const struct shm_tensorpool_control_tensorHeader *const codec)
{
    return codec->acting_version;
}

SBE_ONE_DEF const char *shm_tensorpool_control_tensorHeader_dtype_meta_attribute(
    const enum shm_tensorpool_control_tensorHeader_meta_attribute attribute)
{
    switch (attribute)
    {
        case shm_tensorpool_control_tensorHeader_meta_attribute_EPOCH: return "";
        case shm_tensorpool_control_tensorHeader_meta_attribute_TIME_UNIT: return "";
        case shm_tensorpool_control_tensorHeader_meta_attribute_SEMANTIC_TYPE: return "";
        case shm_tensorpool_control_tensorHeader_meta_attribute_PRESENCE: return "required";
    }

    return "";
}

SBE_ONE_DEF uint16_t shm_tensorpool_control_tensorHeader_dtype_id(void)
{
    return 1;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_tensorHeader_dtype_since_version(void)
{
    return 0;
}

SBE_ONE_DEF bool shm_tensorpool_control_tensorHeader_dtype_in_acting_version(
    const struct shm_tensorpool_control_tensorHeader *const codec)
{
#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wtautological-compare"
#endif
    return codec->acting_version >= shm_tensorpool_control_tensorHeader_dtype_since_version();
#if defined(__clang__)
#pragma clang diagnostic pop
#endif
}

SBE_ONE_DEF size_t shm_tensorpool_control_tensorHeader_dtype_encoding_offset(void)
{
    return 0;
}

SBE_ONE_DEF size_t shm_tensorpool_control_tensorHeader_dtype_encoding_length(void)
{
    return 2;
}

SBE_ONE_DEF bool shm_tensorpool_control_tensorHeader_dtype(
    const struct shm_tensorpool_control_tensorHeader *const codec,
    enum shm_tensorpool_control_dtype *const out)
{
    int16_t val;
    memcpy(&val, codec->buffer + codec->offset + 0, sizeof(int16_t));

    return shm_tensorpool_control_dtype_get(SBE_LITTLE_ENDIAN_ENCODE_16(val), out);
}

SBE_ONE_DEF struct shm_tensorpool_control_tensorHeader *shm_tensorpool_control_tensorHeader_set_dtype(
    struct shm_tensorpool_control_tensorHeader *const codec,
    const enum shm_tensorpool_control_dtype value)
{
    int16_t val = SBE_LITTLE_ENDIAN_ENCODE_16(value);
    memcpy(codec->buffer + codec->offset + 0, &val, sizeof(int16_t));

    return codec;
}

SBE_ONE_DEF const char *shm_tensorpool_control_tensorHeader_majorOrder_meta_attribute(
    const enum shm_tensorpool_control_tensorHeader_meta_attribute attribute)
{
    switch (attribute)
    {
        case shm_tensorpool_control_tensorHeader_meta_attribute_EPOCH: return "";
        case shm_tensorpool_control_tensorHeader_meta_attribute_TIME_UNIT: return "";
        case shm_tensorpool_control_tensorHeader_meta_attribute_SEMANTIC_TYPE: return "";
        case shm_tensorpool_control_tensorHeader_meta_attribute_PRESENCE: return "required";
    }

    return "";
}

SBE_ONE_DEF uint16_t shm_tensorpool_control_tensorHeader_majorOrder_id(void)
{
    return 2;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_tensorHeader_majorOrder_since_version(void)
{
    return 0;
}

SBE_ONE_DEF bool shm_tensorpool_control_tensorHeader_majorOrder_in_acting_version(
    const struct shm_tensorpool_control_tensorHeader *const codec)
{
#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wtautological-compare"
#endif
    return codec->acting_version >= shm_tensorpool_control_tensorHeader_majorOrder_since_version();
#if defined(__clang__)
#pragma clang diagnostic pop
#endif
}

SBE_ONE_DEF size_t shm_tensorpool_control_tensorHeader_majorOrder_encoding_offset(void)
{
    return 2;
}

SBE_ONE_DEF size_t shm_tensorpool_control_tensorHeader_majorOrder_encoding_length(void)
{
    return 2;
}

SBE_ONE_DEF bool shm_tensorpool_control_tensorHeader_majorOrder(
    const struct shm_tensorpool_control_tensorHeader *const codec,
    enum shm_tensorpool_control_majorOrder *const out)
{
    int16_t val;
    memcpy(&val, codec->buffer + codec->offset + 2, sizeof(int16_t));

    return shm_tensorpool_control_majorOrder_get(SBE_LITTLE_ENDIAN_ENCODE_16(val), out);
}

SBE_ONE_DEF struct shm_tensorpool_control_tensorHeader *shm_tensorpool_control_tensorHeader_set_majorOrder(
    struct shm_tensorpool_control_tensorHeader *const codec,
    const enum shm_tensorpool_control_majorOrder value)
{
    int16_t val = SBE_LITTLE_ENDIAN_ENCODE_16(value);
    memcpy(codec->buffer + codec->offset + 2, &val, sizeof(int16_t));

    return codec;
}

SBE_ONE_DEF const char *shm_tensorpool_control_tensorHeader_ndims_meta_attribute(
    const enum shm_tensorpool_control_tensorHeader_meta_attribute attribute)
{
    switch (attribute)
    {
        case shm_tensorpool_control_tensorHeader_meta_attribute_EPOCH: return "";
        case shm_tensorpool_control_tensorHeader_meta_attribute_TIME_UNIT: return "";
        case shm_tensorpool_control_tensorHeader_meta_attribute_SEMANTIC_TYPE: return "";
        case shm_tensorpool_control_tensorHeader_meta_attribute_PRESENCE: return "required";
    }

    return "";
}

SBE_ONE_DEF uint16_t shm_tensorpool_control_tensorHeader_ndims_id(void)
{
    return 3;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_tensorHeader_ndims_since_version(void)
{
    return 0;
}

SBE_ONE_DEF bool shm_tensorpool_control_tensorHeader_ndims_in_acting_version(
    const struct shm_tensorpool_control_tensorHeader *const codec)
{
#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wtautological-compare"
#endif
    return codec->acting_version >= shm_tensorpool_control_tensorHeader_ndims_since_version();
#if defined(__clang__)
#pragma clang diagnostic pop
#endif
}

SBE_ONE_DEF size_t shm_tensorpool_control_tensorHeader_ndims_encoding_offset(void)
{
    return 4;
}

SBE_ONE_DEF uint8_t shm_tensorpool_control_tensorHeader_ndims_null_value(void)
{
    return SBE_NULLVALUE_UINT8;
}

SBE_ONE_DEF uint8_t shm_tensorpool_control_tensorHeader_ndims_min_value(void)
{
    return (uint8_t)0;
}

SBE_ONE_DEF uint8_t shm_tensorpool_control_tensorHeader_ndims_max_value(void)
{
    return (uint8_t)254;
}

SBE_ONE_DEF size_t shm_tensorpool_control_tensorHeader_ndims_encoding_length(void)
{
    return 1;
}

SBE_ONE_DEF uint8_t shm_tensorpool_control_tensorHeader_ndims(
    const struct shm_tensorpool_control_tensorHeader *const codec)
{
    uint8_t val;
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
#endif
    memcpy(&val, codec->buffer + codec->offset + 4, sizeof(uint8_t));
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic pop
#endif
    return (val);
}

SBE_ONE_DEF struct shm_tensorpool_control_tensorHeader *shm_tensorpool_control_tensorHeader_set_ndims(
    struct shm_tensorpool_control_tensorHeader *const codec,
    const uint8_t value)
{
    uint8_t val = (value);
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
#endif
    memcpy(codec->buffer + codec->offset + 4, &val, sizeof(uint8_t));
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic pop
#endif
    return codec;
}

SBE_ONE_DEF const char *shm_tensorpool_control_tensorHeader_maxDims_meta_attribute(
    const enum shm_tensorpool_control_tensorHeader_meta_attribute attribute)
{
    switch (attribute)
    {
        case shm_tensorpool_control_tensorHeader_meta_attribute_EPOCH: return "";
        case shm_tensorpool_control_tensorHeader_meta_attribute_TIME_UNIT: return "";
        case shm_tensorpool_control_tensorHeader_meta_attribute_SEMANTIC_TYPE: return "";
        case shm_tensorpool_control_tensorHeader_meta_attribute_PRESENCE: return "constant";
    }

    return "";
}

SBE_ONE_DEF uint16_t shm_tensorpool_control_tensorHeader_maxDims_id(void)
{
    return 4;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_tensorHeader_maxDims_since_version(void)
{
    return 0;
}

SBE_ONE_DEF bool shm_tensorpool_control_tensorHeader_maxDims_in_acting_version(
    const struct shm_tensorpool_control_tensorHeader *const codec)
{
#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wtautological-compare"
#endif
    return codec->acting_version >= shm_tensorpool_control_tensorHeader_maxDims_since_version();
#if defined(__clang__)
#pragma clang diagnostic pop
#endif
}

SBE_ONE_DEF size_t shm_tensorpool_control_tensorHeader_maxDims_encoding_offset(void)
{
    return 5;
}

SBE_ONE_DEF uint8_t shm_tensorpool_control_tensorHeader_maxDims_null_value(void)
{
    return SBE_NULLVALUE_UINT8;
}

SBE_ONE_DEF uint8_t shm_tensorpool_control_tensorHeader_maxDims_min_value(void)
{
    return (uint8_t)0;
}

SBE_ONE_DEF uint8_t shm_tensorpool_control_tensorHeader_maxDims_max_value(void)
{
    return (uint8_t)254;
}

SBE_ONE_DEF size_t shm_tensorpool_control_tensorHeader_maxDims_encoding_length(void)
{
    return 0;
}

SBE_ONE_DEF uint8_t shm_tensorpool_control_tensorHeader_maxDims(void)
{
    return (uint8_t)8;
}

SBE_ONE_DEF const char *shm_tensorpool_control_tensorHeader_padAlign_meta_attribute(
    const enum shm_tensorpool_control_tensorHeader_meta_attribute attribute)
{
    switch (attribute)
    {
        case shm_tensorpool_control_tensorHeader_meta_attribute_EPOCH: return "";
        case shm_tensorpool_control_tensorHeader_meta_attribute_TIME_UNIT: return "";
        case shm_tensorpool_control_tensorHeader_meta_attribute_SEMANTIC_TYPE: return "";
        case shm_tensorpool_control_tensorHeader_meta_attribute_PRESENCE: return "required";
    }

    return "";
}

SBE_ONE_DEF uint16_t shm_tensorpool_control_tensorHeader_padAlign_id(void)
{
    return 5;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_tensorHeader_padAlign_since_version(void)
{
    return 0;
}

SBE_ONE_DEF bool shm_tensorpool_control_tensorHeader_padAlign_in_acting_version(
    const struct shm_tensorpool_control_tensorHeader *const codec)
{
#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wtautological-compare"
#endif
    return codec->acting_version >= shm_tensorpool_control_tensorHeader_padAlign_since_version();
#if defined(__clang__)
#pragma clang diagnostic pop
#endif
}

SBE_ONE_DEF size_t shm_tensorpool_control_tensorHeader_padAlign_encoding_offset(void)
{
    return 5;
}

SBE_ONE_DEF uint8_t shm_tensorpool_control_tensorHeader_padAlign_null_value(void)
{
    return SBE_NULLVALUE_UINT8;
}

SBE_ONE_DEF uint8_t shm_tensorpool_control_tensorHeader_padAlign_min_value(void)
{
    return (uint8_t)0;
}

SBE_ONE_DEF uint8_t shm_tensorpool_control_tensorHeader_padAlign_max_value(void)
{
    return (uint8_t)254;
}

SBE_ONE_DEF size_t shm_tensorpool_control_tensorHeader_padAlign_encoding_length(void)
{
    return 1;
}

SBE_ONE_DEF uint8_t shm_tensorpool_control_tensorHeader_padAlign(
    const struct shm_tensorpool_control_tensorHeader *const codec)
{
    uint8_t val;
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
#endif
    memcpy(&val, codec->buffer + codec->offset + 5, sizeof(uint8_t));
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic pop
#endif
    return (val);
}

SBE_ONE_DEF struct shm_tensorpool_control_tensorHeader *shm_tensorpool_control_tensorHeader_set_padAlign(
    struct shm_tensorpool_control_tensorHeader *const codec,
    const uint8_t value)
{
    uint8_t val = (value);
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
#endif
    memcpy(codec->buffer + codec->offset + 5, &val, sizeof(uint8_t));
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic pop
#endif
    return codec;
}

SBE_ONE_DEF const char *shm_tensorpool_control_tensorHeader_progressUnit_meta_attribute(
    const enum shm_tensorpool_control_tensorHeader_meta_attribute attribute)
{
    switch (attribute)
    {
        case shm_tensorpool_control_tensorHeader_meta_attribute_EPOCH: return "";
        case shm_tensorpool_control_tensorHeader_meta_attribute_TIME_UNIT: return "";
        case shm_tensorpool_control_tensorHeader_meta_attribute_SEMANTIC_TYPE: return "";
        case shm_tensorpool_control_tensorHeader_meta_attribute_PRESENCE: return "required";
    }

    return "";
}

SBE_ONE_DEF uint16_t shm_tensorpool_control_tensorHeader_progressUnit_id(void)
{
    return 6;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_tensorHeader_progressUnit_since_version(void)
{
    return 0;
}

SBE_ONE_DEF bool shm_tensorpool_control_tensorHeader_progressUnit_in_acting_version(
    const struct shm_tensorpool_control_tensorHeader *const codec)
{
#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wtautological-compare"
#endif
    return codec->acting_version >= shm_tensorpool_control_tensorHeader_progressUnit_since_version();
#if defined(__clang__)
#pragma clang diagnostic pop
#endif
}

SBE_ONE_DEF size_t shm_tensorpool_control_tensorHeader_progressUnit_encoding_offset(void)
{
    return 6;
}

SBE_ONE_DEF size_t shm_tensorpool_control_tensorHeader_progressUnit_encoding_length(void)
{
    return 1;
}

SBE_ONE_DEF bool shm_tensorpool_control_tensorHeader_progressUnit(
    const struct shm_tensorpool_control_tensorHeader *const codec,
    enum shm_tensorpool_control_progressUnit *const out)
{
    uint8_t val;
    memcpy(&val, codec->buffer + codec->offset + 6, sizeof(uint8_t));

    return shm_tensorpool_control_progressUnit_get((val), out);
}

SBE_ONE_DEF struct shm_tensorpool_control_tensorHeader *shm_tensorpool_control_tensorHeader_set_progressUnit(
    struct shm_tensorpool_control_tensorHeader *const codec,
    const enum shm_tensorpool_control_progressUnit value)
{
    uint8_t val = (value);
    memcpy(codec->buffer + codec->offset + 6, &val, sizeof(uint8_t));

    return codec;
}

SBE_ONE_DEF const char *shm_tensorpool_control_tensorHeader_progressStrideBytes_meta_attribute(
    const enum shm_tensorpool_control_tensorHeader_meta_attribute attribute)
{
    switch (attribute)
    {
        case shm_tensorpool_control_tensorHeader_meta_attribute_EPOCH: return "";
        case shm_tensorpool_control_tensorHeader_meta_attribute_TIME_UNIT: return "";
        case shm_tensorpool_control_tensorHeader_meta_attribute_SEMANTIC_TYPE: return "";
        case shm_tensorpool_control_tensorHeader_meta_attribute_PRESENCE: return "required";
    }

    return "";
}

SBE_ONE_DEF uint16_t shm_tensorpool_control_tensorHeader_progressStrideBytes_id(void)
{
    return 7;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_tensorHeader_progressStrideBytes_since_version(void)
{
    return 0;
}

SBE_ONE_DEF bool shm_tensorpool_control_tensorHeader_progressStrideBytes_in_acting_version(
    const struct shm_tensorpool_control_tensorHeader *const codec)
{
#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wtautological-compare"
#endif
    return codec->acting_version >= shm_tensorpool_control_tensorHeader_progressStrideBytes_since_version();
#if defined(__clang__)
#pragma clang diagnostic pop
#endif
}

SBE_ONE_DEF size_t shm_tensorpool_control_tensorHeader_progressStrideBytes_encoding_offset(void)
{
    return 7;
}

SBE_ONE_DEF uint32_t shm_tensorpool_control_tensorHeader_progressStrideBytes_null_value(void)
{
    return SBE_NULLVALUE_UINT32;
}

SBE_ONE_DEF uint32_t shm_tensorpool_control_tensorHeader_progressStrideBytes_min_value(void)
{
    return UINT32_C(0x0);
}

SBE_ONE_DEF uint32_t shm_tensorpool_control_tensorHeader_progressStrideBytes_max_value(void)
{
    return UINT32_C(0xfffffffe);
}

SBE_ONE_DEF size_t shm_tensorpool_control_tensorHeader_progressStrideBytes_encoding_length(void)
{
    return 4;
}

SBE_ONE_DEF uint32_t shm_tensorpool_control_tensorHeader_progressStrideBytes(
    const struct shm_tensorpool_control_tensorHeader *const codec)
{
    uint32_t val;
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
#endif
    memcpy(&val, codec->buffer + codec->offset + 7, sizeof(uint32_t));
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic pop
#endif
    return SBE_LITTLE_ENDIAN_ENCODE_32(val);
}

SBE_ONE_DEF struct shm_tensorpool_control_tensorHeader *shm_tensorpool_control_tensorHeader_set_progressStrideBytes(
    struct shm_tensorpool_control_tensorHeader *const codec,
    const uint32_t value)
{
    uint32_t val = SBE_LITTLE_ENDIAN_ENCODE_32(value);
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
#endif
    memcpy(codec->buffer + codec->offset + 7, &val, sizeof(uint32_t));
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic pop
#endif
    return codec;
}

SBE_ONE_DEF const char *shm_tensorpool_control_tensorHeader_dims_meta_attribute(
    const enum shm_tensorpool_control_tensorHeader_meta_attribute attribute)
{
    switch (attribute)
    {
        case shm_tensorpool_control_tensorHeader_meta_attribute_EPOCH: return "";
        case shm_tensorpool_control_tensorHeader_meta_attribute_TIME_UNIT: return "";
        case shm_tensorpool_control_tensorHeader_meta_attribute_SEMANTIC_TYPE: return "";
        case shm_tensorpool_control_tensorHeader_meta_attribute_PRESENCE: return "required";
    }

    return "";
}

SBE_ONE_DEF uint16_t shm_tensorpool_control_tensorHeader_dims_id(void)
{
    return 8;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_tensorHeader_dims_since_version(void)
{
    return 0;
}

SBE_ONE_DEF bool shm_tensorpool_control_tensorHeader_dims_in_acting_version(
    const struct shm_tensorpool_control_tensorHeader *const codec)
{
#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wtautological-compare"
#endif
    return codec->acting_version >= shm_tensorpool_control_tensorHeader_dims_since_version();
#if defined(__clang__)
#pragma clang diagnostic pop
#endif
}

SBE_ONE_DEF size_t shm_tensorpool_control_tensorHeader_dims_encoding_offset(void)
{
    return 11;
}

SBE_ONE_DEF int32_t shm_tensorpool_control_tensorHeader_dims_null_value(void)
{
    return SBE_NULLVALUE_INT32;
}

SBE_ONE_DEF int32_t shm_tensorpool_control_tensorHeader_dims_min_value(void)
{
    return INT32_C(-2147483647);
}

SBE_ONE_DEF int32_t shm_tensorpool_control_tensorHeader_dims_max_value(void)
{
    return INT32_C(2147483647);
}

SBE_ONE_DEF size_t shm_tensorpool_control_tensorHeader_dims_encoding_length(void)
{
    return 32;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_tensorHeader_dims_length(void)
{
    return 8;
}

SBE_ONE_DEF const char *shm_tensorpool_control_tensorHeader_dims_buffer(
    const struct shm_tensorpool_control_tensorHeader *const codec)
{
    return codec->buffer + codec->offset + 11;
}

SBE_ONE_DEF int32_t shm_tensorpool_control_tensorHeader_dims_unsafe(
    const struct shm_tensorpool_control_tensorHeader *const codec,
    const uint64_t index)
{
    int32_t val;
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
#endif
    memcpy(&val, codec->buffer + codec->offset + 11 + (index * 4), sizeof(int32_t));
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic pop
#endif
    return SBE_LITTLE_ENDIAN_ENCODE_32(val);
}

SBE_ONE_DEF bool shm_tensorpool_control_tensorHeader_dims(
    const struct shm_tensorpool_control_tensorHeader *const codec,
    const uint64_t index,
    int32_t *const out)
{
    if (index >= 8)
    {
        errno = E104;
        return false;
    }

    int32_t val;
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
#endif
    memcpy(&val, codec->buffer + codec->offset + 11 + (index * 4), sizeof(int32_t));
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic pop
#endif
    *out = SBE_LITTLE_ENDIAN_ENCODE_32(val);
    return true;
}

SBE_ONE_DEF struct shm_tensorpool_control_tensorHeader *shm_tensorpool_control_tensorHeader_set_dims_unsafe(
    struct shm_tensorpool_control_tensorHeader *const codec,
    const uint64_t index,
    const int32_t value)
{
    int32_t val = SBE_LITTLE_ENDIAN_ENCODE_32(value);
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
#endif
    memcpy(codec->buffer + codec->offset + 11 + (index * 4), &val, sizeof(int32_t));
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic pop
#endif
    return codec;
}

SBE_ONE_DEF struct shm_tensorpool_control_tensorHeader *shm_tensorpool_control_tensorHeader_set_dims(
    struct shm_tensorpool_control_tensorHeader *const codec,
    const uint64_t index,
    const int32_t value)
{
    if (index >= 8)
    {
        errno = E105;
        return NULL;
    }

    int32_t val = SBE_LITTLE_ENDIAN_ENCODE_32(value);
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
#endif
    memcpy(codec->buffer + codec->offset + 11 + (index * 4), &val, sizeof(int32_t));
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic pop
#endif
    return codec;
}

SBE_ONE_DEF char *shm_tensorpool_control_tensorHeader_get_dims(
    const struct shm_tensorpool_control_tensorHeader *const codec,
    char *dst,
    const uint64_t length)
{
    if (length > 8)
    {
        errno = E106;
        return NULL;
    }

    memcpy(dst, codec->buffer + codec->offset + 11, sizeof(int32_t) * length);

    return dst;
}

SBE_ONE_DEF struct shm_tensorpool_control_tensorHeader *shm_tensorpool_control_tensorHeader_put_dims(
    struct shm_tensorpool_control_tensorHeader *const codec,
    const char *src)
{
    memcpy(codec->buffer + codec->offset + 11, src, sizeof(int32_t) * 8);

    return codec;
}

SBE_ONE_DEF const char *shm_tensorpool_control_tensorHeader_strides_meta_attribute(
    const enum shm_tensorpool_control_tensorHeader_meta_attribute attribute)
{
    switch (attribute)
    {
        case shm_tensorpool_control_tensorHeader_meta_attribute_EPOCH: return "";
        case shm_tensorpool_control_tensorHeader_meta_attribute_TIME_UNIT: return "";
        case shm_tensorpool_control_tensorHeader_meta_attribute_SEMANTIC_TYPE: return "";
        case shm_tensorpool_control_tensorHeader_meta_attribute_PRESENCE: return "required";
    }

    return "";
}

SBE_ONE_DEF uint16_t shm_tensorpool_control_tensorHeader_strides_id(void)
{
    return 9;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_tensorHeader_strides_since_version(void)
{
    return 0;
}

SBE_ONE_DEF bool shm_tensorpool_control_tensorHeader_strides_in_acting_version(
    const struct shm_tensorpool_control_tensorHeader *const codec)
{
#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wtautological-compare"
#endif
    return codec->acting_version >= shm_tensorpool_control_tensorHeader_strides_since_version();
#if defined(__clang__)
#pragma clang diagnostic pop
#endif
}

SBE_ONE_DEF size_t shm_tensorpool_control_tensorHeader_strides_encoding_offset(void)
{
    return 43;
}

SBE_ONE_DEF int32_t shm_tensorpool_control_tensorHeader_strides_null_value(void)
{
    return SBE_NULLVALUE_INT32;
}

SBE_ONE_DEF int32_t shm_tensorpool_control_tensorHeader_strides_min_value(void)
{
    return INT32_C(-2147483647);
}

SBE_ONE_DEF int32_t shm_tensorpool_control_tensorHeader_strides_max_value(void)
{
    return INT32_C(2147483647);
}

SBE_ONE_DEF size_t shm_tensorpool_control_tensorHeader_strides_encoding_length(void)
{
    return 32;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_tensorHeader_strides_length(void)
{
    return 8;
}

SBE_ONE_DEF const char *shm_tensorpool_control_tensorHeader_strides_buffer(
    const struct shm_tensorpool_control_tensorHeader *const codec)
{
    return codec->buffer + codec->offset + 43;
}

SBE_ONE_DEF int32_t shm_tensorpool_control_tensorHeader_strides_unsafe(
    const struct shm_tensorpool_control_tensorHeader *const codec,
    const uint64_t index)
{
    int32_t val;
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
#endif
    memcpy(&val, codec->buffer + codec->offset + 43 + (index * 4), sizeof(int32_t));
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic pop
#endif
    return SBE_LITTLE_ENDIAN_ENCODE_32(val);
}

SBE_ONE_DEF bool shm_tensorpool_control_tensorHeader_strides(
    const struct shm_tensorpool_control_tensorHeader *const codec,
    const uint64_t index,
    int32_t *const out)
{
    if (index >= 8)
    {
        errno = E104;
        return false;
    }

    int32_t val;
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
#endif
    memcpy(&val, codec->buffer + codec->offset + 43 + (index * 4), sizeof(int32_t));
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic pop
#endif
    *out = SBE_LITTLE_ENDIAN_ENCODE_32(val);
    return true;
}

SBE_ONE_DEF struct shm_tensorpool_control_tensorHeader *shm_tensorpool_control_tensorHeader_set_strides_unsafe(
    struct shm_tensorpool_control_tensorHeader *const codec,
    const uint64_t index,
    const int32_t value)
{
    int32_t val = SBE_LITTLE_ENDIAN_ENCODE_32(value);
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
#endif
    memcpy(codec->buffer + codec->offset + 43 + (index * 4), &val, sizeof(int32_t));
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic pop
#endif
    return codec;
}

SBE_ONE_DEF struct shm_tensorpool_control_tensorHeader *shm_tensorpool_control_tensorHeader_set_strides(
    struct shm_tensorpool_control_tensorHeader *const codec,
    const uint64_t index,
    const int32_t value)
{
    if (index >= 8)
    {
        errno = E105;
        return NULL;
    }

    int32_t val = SBE_LITTLE_ENDIAN_ENCODE_32(value);
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
#endif
    memcpy(codec->buffer + codec->offset + 43 + (index * 4), &val, sizeof(int32_t));
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic pop
#endif
    return codec;
}

SBE_ONE_DEF char *shm_tensorpool_control_tensorHeader_get_strides(
    const struct shm_tensorpool_control_tensorHeader *const codec,
    char *dst,
    const uint64_t length)
{
    if (length > 8)
    {
        errno = E106;
        return NULL;
    }

    memcpy(dst, codec->buffer + codec->offset + 43, sizeof(int32_t) * length);

    return dst;
}

SBE_ONE_DEF struct shm_tensorpool_control_tensorHeader *shm_tensorpool_control_tensorHeader_put_strides(
    struct shm_tensorpool_control_tensorHeader *const codec,
    const char *src)
{
    memcpy(codec->buffer + codec->offset + 43, src, sizeof(int32_t) * 8);

    return codec;
}

SBE_ONE_DEF const char *shm_tensorpool_control_tensorHeader_pad_meta_attribute(
    const enum shm_tensorpool_control_tensorHeader_meta_attribute attribute)
{
    switch (attribute)
    {
        case shm_tensorpool_control_tensorHeader_meta_attribute_EPOCH: return "";
        case shm_tensorpool_control_tensorHeader_meta_attribute_TIME_UNIT: return "";
        case shm_tensorpool_control_tensorHeader_meta_attribute_SEMANTIC_TYPE: return "";
        case shm_tensorpool_control_tensorHeader_meta_attribute_PRESENCE: return "required";
    }

    return "";
}

SBE_ONE_DEF uint16_t shm_tensorpool_control_tensorHeader_pad_id(void)
{
    return 10;
}

SBE_ONE_DEF uint64_t shm_tensorpool_control_tensorHeader_pad_since_version(void)
{
    return 0;
}

SBE_ONE_DEF bool shm_tensorpool_control_tensorHeader_pad_in_acting_version(
    const struct shm_tensorpool_control_tensorHeader *const codec)
{
#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wtautological-compare"
#endif
    return codec->acting_version >= shm_tensorpool_control_tensorHeader_pad_since_version();
#if defined(__clang__)
#pragma clang diagnostic pop
#endif
}

SBE_ONE_DEF size_t shm_tensorpool_control_tensorHeader_pad_encoding_offset(void)
{
    return 75;
}

SBE_ONE_DEF uint8_t shm_tensorpool_control_tensorHeader_pad_null_value(void)
{
    return SBE_NULLVALUE_UINT8;
}

SBE_ONE_DEF uint8_t shm_tensorpool_control_tensorHeader_pad_min_value(void)
{
    return (uint8_t)0;
}

SBE_ONE_DEF uint8_t shm_tensorpool_control_tensorHeader_pad_max_value(void)
{
    return (uint8_t)254;
}

SBE_ONE_DEF size_t shm_tensorpool_control_tensorHeader_pad_encoding_length(void)
{
    return 1;
}

SBE_ONE_DEF uint8_t shm_tensorpool_control_tensorHeader_pad(
    const struct shm_tensorpool_control_tensorHeader *const codec)
{
    uint8_t val;
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
#endif
    memcpy(&val, codec->buffer + codec->offset + 75, sizeof(uint8_t));
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic pop
#endif
    return (val);
}

SBE_ONE_DEF struct shm_tensorpool_control_tensorHeader *shm_tensorpool_control_tensorHeader_set_pad(
    struct shm_tensorpool_control_tensorHeader *const codec,
    const uint8_t value)
{
    uint8_t val = (value);
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
#endif
    memcpy(codec->buffer + codec->offset + 75, &val, sizeof(uint8_t));
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic pop
#endif
    return codec;
}

#endif
