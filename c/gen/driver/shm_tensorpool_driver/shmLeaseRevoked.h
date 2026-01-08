/* Generated SBE (Simple Binary Encoding) message codec */

#ifndef _SHM_TENSORPOOL_DRIVER_SHMLEASEREVOKED_H_
#define _SHM_TENSORPOOL_DRIVER_SHMLEASEREVOKED_H_

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

#include "role.h"
#include "publishMode.h"
#include "responseCode.h"
#include "leaseRevokeReason.h"
#include "messageHeader.h"
#include "hugepagesPolicy.h"
#include "groupSizeEncoding.h"
#include "varAsciiEncoding.h"
#include "shutdownReason.h"

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

struct shm_tensorpool_driver_shmLeaseRevoked
{
    char *buffer;
    uint64_t buffer_length;
    uint64_t offset;
    uint64_t position;
    uint64_t acting_block_length;
    uint64_t acting_version;
};

enum shm_tensorpool_driver_shmLeaseRevoked_meta_attribute
{
    shm_tensorpool_driver_shmLeaseRevoked_meta_attribute_EPOCH,
    shm_tensorpool_driver_shmLeaseRevoked_meta_attribute_TIME_UNIT,
    shm_tensorpool_driver_shmLeaseRevoked_meta_attribute_SEMANTIC_TYPE,
    shm_tensorpool_driver_shmLeaseRevoked_meta_attribute_PRESENCE
};

union shm_tensorpool_driver_shmLeaseRevoked_float_as_uint
{
    float fp_value;
    uint32_t uint_value;
};

union shm_tensorpool_driver_shmLeaseRevoked_double_as_uint
{
    double fp_value;
    uint64_t uint_value;
};

struct shm_tensorpool_driver_shmLeaseRevoked_string_view
{
    const char* data;
    size_t length;
};

SBE_ONE_DEF uint64_t shm_tensorpool_driver_shmLeaseRevoked_sbe_position(
    const struct shm_tensorpool_driver_shmLeaseRevoked *const codec)
{
    return codec->position;
}

SBE_ONE_DEF bool shm_tensorpool_driver_shmLeaseRevoked_set_sbe_position(
    struct shm_tensorpool_driver_shmLeaseRevoked *const codec,
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

SBE_ONE_DEF uint64_t *shm_tensorpool_driver_shmLeaseRevoked_sbe_position_ptr(
    struct shm_tensorpool_driver_shmLeaseRevoked *const codec)
{
    return &codec->position;
}

SBE_ONE_DEF struct shm_tensorpool_driver_shmLeaseRevoked *shm_tensorpool_driver_shmLeaseRevoked_reset(
    struct shm_tensorpool_driver_shmLeaseRevoked *const codec,
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
    if (!shm_tensorpool_driver_shmLeaseRevoked_set_sbe_position(codec, offset + acting_block_length))
    {
        return NULL;
    }

    return codec;
}

SBE_ONE_DEF struct shm_tensorpool_driver_shmLeaseRevoked *shm_tensorpool_driver_shmLeaseRevoked_copy(
    struct shm_tensorpool_driver_shmLeaseRevoked *const codec,
    const struct shm_tensorpool_driver_shmLeaseRevoked *const other)
{
     codec->buffer = other->buffer;
     codec->offset = other->offset;
     codec->buffer_length = other->buffer_length;
     codec->acting_block_length = other->acting_block_length;
     codec->acting_version = other->acting_version;
     codec->position = other->position;

     return codec;
}

SBE_ONE_DEF uint16_t shm_tensorpool_driver_shmLeaseRevoked_sbe_block_length(void)
{
    return (uint16_t)18;
}

#define SHM_TENSORPOOL_DRIVER_SHM_LEASE_REVOKED_SBE_TEMPLATE_ID (uint16_t)6

SBE_ONE_DEF uint16_t shm_tensorpool_driver_shmLeaseRevoked_sbe_template_id(void)
{
    return (uint16_t)6;
}

SBE_ONE_DEF uint16_t shm_tensorpool_driver_shmLeaseRevoked_sbe_schema_id(void)
{
    return (uint16_t)901;
}

SBE_ONE_DEF uint16_t shm_tensorpool_driver_shmLeaseRevoked_sbe_schema_version(void)
{
    return (uint16_t)1;
}

SBE_ONE_DEF const char* shm_tensorpool_driver_shmLeaseRevoked_sbe_semantic_version(void)
{
    return "1.0";
}

SBE_ONE_DEF const char *shm_tensorpool_driver_shmLeaseRevoked_sbe_semantic_type(void)
{
    return "";
}

SBE_ONE_DEF uint64_t shm_tensorpool_driver_shmLeaseRevoked_offset(
    const struct shm_tensorpool_driver_shmLeaseRevoked *const codec)
{
    return codec->offset;
}

SBE_ONE_DEF struct shm_tensorpool_driver_shmLeaseRevoked *shm_tensorpool_driver_shmLeaseRevoked_wrap_and_apply_header(
    struct shm_tensorpool_driver_shmLeaseRevoked *const codec,
    char *buffer,
    const uint64_t offset,
    const uint64_t buffer_length,
    struct shm_tensorpool_driver_messageHeader *const hdr)
{
    shm_tensorpool_driver_messageHeader_wrap(
        hdr, buffer + offset, 0, shm_tensorpool_driver_messageHeader_sbe_schema_version(), buffer_length);

    shm_tensorpool_driver_messageHeader_set_blockLength(hdr, shm_tensorpool_driver_shmLeaseRevoked_sbe_block_length());
    shm_tensorpool_driver_messageHeader_set_templateId(hdr, shm_tensorpool_driver_shmLeaseRevoked_sbe_template_id());
    shm_tensorpool_driver_messageHeader_set_schemaId(hdr, shm_tensorpool_driver_shmLeaseRevoked_sbe_schema_id());
    shm_tensorpool_driver_messageHeader_set_version(hdr, shm_tensorpool_driver_shmLeaseRevoked_sbe_schema_version());

    shm_tensorpool_driver_shmLeaseRevoked_reset(
        codec,
        buffer + offset + shm_tensorpool_driver_messageHeader_encoded_length(),
        0,
        buffer_length - shm_tensorpool_driver_messageHeader_encoded_length(),
        shm_tensorpool_driver_shmLeaseRevoked_sbe_block_length(),
        shm_tensorpool_driver_shmLeaseRevoked_sbe_schema_version());

    return codec;
}

SBE_ONE_DEF struct shm_tensorpool_driver_shmLeaseRevoked *shm_tensorpool_driver_shmLeaseRevoked_wrap_for_encode(
    struct shm_tensorpool_driver_shmLeaseRevoked *const codec,
    char *buffer,
    const uint64_t offset,
    const uint64_t buffer_length)
{
    return shm_tensorpool_driver_shmLeaseRevoked_reset(
        codec,
        buffer,
        offset,
        buffer_length,
        shm_tensorpool_driver_shmLeaseRevoked_sbe_block_length(),
        shm_tensorpool_driver_shmLeaseRevoked_sbe_schema_version());
}

SBE_ONE_DEF struct shm_tensorpool_driver_shmLeaseRevoked *shm_tensorpool_driver_shmLeaseRevoked_wrap_for_decode(
    struct shm_tensorpool_driver_shmLeaseRevoked *const codec,
    char *buffer,
    const uint64_t offset,
    const uint64_t acting_block_length,
    const uint64_t acting_version,
    const uint64_t buffer_length)
{
    return shm_tensorpool_driver_shmLeaseRevoked_reset(
        codec,
        buffer,
        offset,
        buffer_length,
        acting_block_length,
        acting_version);
}

SBE_ONE_DEF struct shm_tensorpool_driver_shmLeaseRevoked *shm_tensorpool_driver_shmLeaseRevoked_sbe_rewind(
    struct shm_tensorpool_driver_shmLeaseRevoked *const codec)
{
    return shm_tensorpool_driver_shmLeaseRevoked_wrap_for_decode(
        codec,
        codec->buffer,
        codec->offset,
        codec->acting_block_length,
        codec->acting_version,
        codec->buffer_length);
}

SBE_ONE_DEF uint64_t shm_tensorpool_driver_shmLeaseRevoked_encoded_length(
    const struct shm_tensorpool_driver_shmLeaseRevoked *const codec)
{
    return shm_tensorpool_driver_shmLeaseRevoked_sbe_position(codec) - codec->offset;
}

SBE_ONE_DEF const char *shm_tensorpool_driver_shmLeaseRevoked_buffer(
    const struct shm_tensorpool_driver_shmLeaseRevoked *const codec)
{
    return codec->buffer;
}

SBE_ONE_DEF char *shm_tensorpool_driver_shmLeaseRevoked_mut_buffer(
    struct shm_tensorpool_driver_shmLeaseRevoked *const codec)
{
    return codec->buffer;
}

SBE_ONE_DEF uint64_t shm_tensorpool_driver_shmLeaseRevoked_buffer_length(
    const struct shm_tensorpool_driver_shmLeaseRevoked *const codec)
{
    return codec->buffer_length;
}

SBE_ONE_DEF uint64_t shm_tensorpool_driver_shmLeaseRevoked_acting_version(
    const struct shm_tensorpool_driver_shmLeaseRevoked *const codec)
{
    return codec->acting_version;
}

SBE_ONE_DEF const char *shm_tensorpool_driver_shmLeaseRevoked_leaseId_meta_attribute(
    const enum shm_tensorpool_driver_shmLeaseRevoked_meta_attribute attribute)
{
    switch (attribute)
    {
        case shm_tensorpool_driver_shmLeaseRevoked_meta_attribute_EPOCH: return "";
        case shm_tensorpool_driver_shmLeaseRevoked_meta_attribute_TIME_UNIT: return "";
        case shm_tensorpool_driver_shmLeaseRevoked_meta_attribute_SEMANTIC_TYPE: return "";
        case shm_tensorpool_driver_shmLeaseRevoked_meta_attribute_PRESENCE: return "required";
    }

    return "";
}

SBE_ONE_DEF uint16_t shm_tensorpool_driver_shmLeaseRevoked_leaseId_id(void)
{
    return 1;
}

SBE_ONE_DEF uint64_t shm_tensorpool_driver_shmLeaseRevoked_leaseId_since_version(void)
{
    return 0;
}

SBE_ONE_DEF bool shm_tensorpool_driver_shmLeaseRevoked_leaseId_in_acting_version(
    const struct shm_tensorpool_driver_shmLeaseRevoked *const codec)
{
#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wtautological-compare"
#endif
    return codec->acting_version >= shm_tensorpool_driver_shmLeaseRevoked_leaseId_since_version();
#if defined(__clang__)
#pragma clang diagnostic pop
#endif
}

SBE_ONE_DEF size_t shm_tensorpool_driver_shmLeaseRevoked_leaseId_encoding_offset(void)
{
    return 0;
}

SBE_ONE_DEF uint64_t shm_tensorpool_driver_shmLeaseRevoked_leaseId_null_value(void)
{
    return SBE_NULLVALUE_UINT64;
}

SBE_ONE_DEF uint64_t shm_tensorpool_driver_shmLeaseRevoked_leaseId_min_value(void)
{
    return UINT64_C(0x0);
}

SBE_ONE_DEF uint64_t shm_tensorpool_driver_shmLeaseRevoked_leaseId_max_value(void)
{
    return UINT64_C(0xfffffffffffffffe);
}

SBE_ONE_DEF size_t shm_tensorpool_driver_shmLeaseRevoked_leaseId_encoding_length(void)
{
    return 8;
}

SBE_ONE_DEF uint64_t shm_tensorpool_driver_shmLeaseRevoked_leaseId(
    const struct shm_tensorpool_driver_shmLeaseRevoked *const codec)
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

SBE_ONE_DEF struct shm_tensorpool_driver_shmLeaseRevoked *shm_tensorpool_driver_shmLeaseRevoked_set_leaseId(
    struct shm_tensorpool_driver_shmLeaseRevoked *const codec,
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

SBE_ONE_DEF const char *shm_tensorpool_driver_shmLeaseRevoked_streamId_meta_attribute(
    const enum shm_tensorpool_driver_shmLeaseRevoked_meta_attribute attribute)
{
    switch (attribute)
    {
        case shm_tensorpool_driver_shmLeaseRevoked_meta_attribute_EPOCH: return "";
        case shm_tensorpool_driver_shmLeaseRevoked_meta_attribute_TIME_UNIT: return "";
        case shm_tensorpool_driver_shmLeaseRevoked_meta_attribute_SEMANTIC_TYPE: return "";
        case shm_tensorpool_driver_shmLeaseRevoked_meta_attribute_PRESENCE: return "required";
    }

    return "";
}

SBE_ONE_DEF uint16_t shm_tensorpool_driver_shmLeaseRevoked_streamId_id(void)
{
    return 2;
}

SBE_ONE_DEF uint64_t shm_tensorpool_driver_shmLeaseRevoked_streamId_since_version(void)
{
    return 0;
}

SBE_ONE_DEF bool shm_tensorpool_driver_shmLeaseRevoked_streamId_in_acting_version(
    const struct shm_tensorpool_driver_shmLeaseRevoked *const codec)
{
#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wtautological-compare"
#endif
    return codec->acting_version >= shm_tensorpool_driver_shmLeaseRevoked_streamId_since_version();
#if defined(__clang__)
#pragma clang diagnostic pop
#endif
}

SBE_ONE_DEF size_t shm_tensorpool_driver_shmLeaseRevoked_streamId_encoding_offset(void)
{
    return 8;
}

SBE_ONE_DEF uint32_t shm_tensorpool_driver_shmLeaseRevoked_streamId_null_value(void)
{
    return SBE_NULLVALUE_UINT32;
}

SBE_ONE_DEF uint32_t shm_tensorpool_driver_shmLeaseRevoked_streamId_min_value(void)
{
    return UINT32_C(0x0);
}

SBE_ONE_DEF uint32_t shm_tensorpool_driver_shmLeaseRevoked_streamId_max_value(void)
{
    return UINT32_C(0xfffffffe);
}

SBE_ONE_DEF size_t shm_tensorpool_driver_shmLeaseRevoked_streamId_encoding_length(void)
{
    return 4;
}

SBE_ONE_DEF uint32_t shm_tensorpool_driver_shmLeaseRevoked_streamId(
    const struct shm_tensorpool_driver_shmLeaseRevoked *const codec)
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

SBE_ONE_DEF struct shm_tensorpool_driver_shmLeaseRevoked *shm_tensorpool_driver_shmLeaseRevoked_set_streamId(
    struct shm_tensorpool_driver_shmLeaseRevoked *const codec,
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

SBE_ONE_DEF const char *shm_tensorpool_driver_shmLeaseRevoked_clientId_meta_attribute(
    const enum shm_tensorpool_driver_shmLeaseRevoked_meta_attribute attribute)
{
    switch (attribute)
    {
        case shm_tensorpool_driver_shmLeaseRevoked_meta_attribute_EPOCH: return "";
        case shm_tensorpool_driver_shmLeaseRevoked_meta_attribute_TIME_UNIT: return "";
        case shm_tensorpool_driver_shmLeaseRevoked_meta_attribute_SEMANTIC_TYPE: return "";
        case shm_tensorpool_driver_shmLeaseRevoked_meta_attribute_PRESENCE: return "required";
    }

    return "";
}

SBE_ONE_DEF uint16_t shm_tensorpool_driver_shmLeaseRevoked_clientId_id(void)
{
    return 3;
}

SBE_ONE_DEF uint64_t shm_tensorpool_driver_shmLeaseRevoked_clientId_since_version(void)
{
    return 0;
}

SBE_ONE_DEF bool shm_tensorpool_driver_shmLeaseRevoked_clientId_in_acting_version(
    const struct shm_tensorpool_driver_shmLeaseRevoked *const codec)
{
#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wtautological-compare"
#endif
    return codec->acting_version >= shm_tensorpool_driver_shmLeaseRevoked_clientId_since_version();
#if defined(__clang__)
#pragma clang diagnostic pop
#endif
}

SBE_ONE_DEF size_t shm_tensorpool_driver_shmLeaseRevoked_clientId_encoding_offset(void)
{
    return 12;
}

SBE_ONE_DEF uint32_t shm_tensorpool_driver_shmLeaseRevoked_clientId_null_value(void)
{
    return SBE_NULLVALUE_UINT32;
}

SBE_ONE_DEF uint32_t shm_tensorpool_driver_shmLeaseRevoked_clientId_min_value(void)
{
    return UINT32_C(0x0);
}

SBE_ONE_DEF uint32_t shm_tensorpool_driver_shmLeaseRevoked_clientId_max_value(void)
{
    return UINT32_C(0xfffffffe);
}

SBE_ONE_DEF size_t shm_tensorpool_driver_shmLeaseRevoked_clientId_encoding_length(void)
{
    return 4;
}

SBE_ONE_DEF uint32_t shm_tensorpool_driver_shmLeaseRevoked_clientId(
    const struct shm_tensorpool_driver_shmLeaseRevoked *const codec)
{
    uint32_t val;
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
#endif
    memcpy(&val, codec->buffer + codec->offset + 12, sizeof(uint32_t));
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic pop
#endif
    return SBE_LITTLE_ENDIAN_ENCODE_32(val);
}

SBE_ONE_DEF struct shm_tensorpool_driver_shmLeaseRevoked *shm_tensorpool_driver_shmLeaseRevoked_set_clientId(
    struct shm_tensorpool_driver_shmLeaseRevoked *const codec,
    const uint32_t value)
{
    uint32_t val = SBE_LITTLE_ENDIAN_ENCODE_32(value);
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
#endif
    memcpy(codec->buffer + codec->offset + 12, &val, sizeof(uint32_t));
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic pop
#endif
    return codec;
}

SBE_ONE_DEF const char *shm_tensorpool_driver_shmLeaseRevoked_role_meta_attribute(
    const enum shm_tensorpool_driver_shmLeaseRevoked_meta_attribute attribute)
{
    switch (attribute)
    {
        case shm_tensorpool_driver_shmLeaseRevoked_meta_attribute_EPOCH: return "";
        case shm_tensorpool_driver_shmLeaseRevoked_meta_attribute_TIME_UNIT: return "";
        case shm_tensorpool_driver_shmLeaseRevoked_meta_attribute_SEMANTIC_TYPE: return "";
        case shm_tensorpool_driver_shmLeaseRevoked_meta_attribute_PRESENCE: return "required";
    }

    return "";
}

SBE_ONE_DEF uint16_t shm_tensorpool_driver_shmLeaseRevoked_role_id(void)
{
    return 4;
}

SBE_ONE_DEF uint64_t shm_tensorpool_driver_shmLeaseRevoked_role_since_version(void)
{
    return 0;
}

SBE_ONE_DEF bool shm_tensorpool_driver_shmLeaseRevoked_role_in_acting_version(
    const struct shm_tensorpool_driver_shmLeaseRevoked *const codec)
{
#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wtautological-compare"
#endif
    return codec->acting_version >= shm_tensorpool_driver_shmLeaseRevoked_role_since_version();
#if defined(__clang__)
#pragma clang diagnostic pop
#endif
}

SBE_ONE_DEF size_t shm_tensorpool_driver_shmLeaseRevoked_role_encoding_offset(void)
{
    return 16;
}

SBE_ONE_DEF size_t shm_tensorpool_driver_shmLeaseRevoked_role_encoding_length(void)
{
    return 1;
}

SBE_ONE_DEF bool shm_tensorpool_driver_shmLeaseRevoked_role(
    const struct shm_tensorpool_driver_shmLeaseRevoked *const codec,
    enum shm_tensorpool_driver_role *const out)
{
    uint8_t val;
    memcpy(&val, codec->buffer + codec->offset + 16, sizeof(uint8_t));

    return shm_tensorpool_driver_role_get((val), out);
}

SBE_ONE_DEF struct shm_tensorpool_driver_shmLeaseRevoked *shm_tensorpool_driver_shmLeaseRevoked_set_role(
    struct shm_tensorpool_driver_shmLeaseRevoked *const codec,
    const enum shm_tensorpool_driver_role value)
{
    uint8_t val = (value);
    memcpy(codec->buffer + codec->offset + 16, &val, sizeof(uint8_t));

    return codec;
}

SBE_ONE_DEF const char *shm_tensorpool_driver_shmLeaseRevoked_reason_meta_attribute(
    const enum shm_tensorpool_driver_shmLeaseRevoked_meta_attribute attribute)
{
    switch (attribute)
    {
        case shm_tensorpool_driver_shmLeaseRevoked_meta_attribute_EPOCH: return "";
        case shm_tensorpool_driver_shmLeaseRevoked_meta_attribute_TIME_UNIT: return "";
        case shm_tensorpool_driver_shmLeaseRevoked_meta_attribute_SEMANTIC_TYPE: return "";
        case shm_tensorpool_driver_shmLeaseRevoked_meta_attribute_PRESENCE: return "required";
    }

    return "";
}

SBE_ONE_DEF uint16_t shm_tensorpool_driver_shmLeaseRevoked_reason_id(void)
{
    return 5;
}

SBE_ONE_DEF uint64_t shm_tensorpool_driver_shmLeaseRevoked_reason_since_version(void)
{
    return 0;
}

SBE_ONE_DEF bool shm_tensorpool_driver_shmLeaseRevoked_reason_in_acting_version(
    const struct shm_tensorpool_driver_shmLeaseRevoked *const codec)
{
#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wtautological-compare"
#endif
    return codec->acting_version >= shm_tensorpool_driver_shmLeaseRevoked_reason_since_version();
#if defined(__clang__)
#pragma clang diagnostic pop
#endif
}

SBE_ONE_DEF size_t shm_tensorpool_driver_shmLeaseRevoked_reason_encoding_offset(void)
{
    return 17;
}

SBE_ONE_DEF size_t shm_tensorpool_driver_shmLeaseRevoked_reason_encoding_length(void)
{
    return 1;
}

SBE_ONE_DEF bool shm_tensorpool_driver_shmLeaseRevoked_reason(
    const struct shm_tensorpool_driver_shmLeaseRevoked *const codec,
    enum shm_tensorpool_driver_leaseRevokeReason *const out)
{
    uint8_t val;
    memcpy(&val, codec->buffer + codec->offset + 17, sizeof(uint8_t));

    return shm_tensorpool_driver_leaseRevokeReason_get((val), out);
}

SBE_ONE_DEF struct shm_tensorpool_driver_shmLeaseRevoked *shm_tensorpool_driver_shmLeaseRevoked_set_reason(
    struct shm_tensorpool_driver_shmLeaseRevoked *const codec,
    const enum shm_tensorpool_driver_leaseRevokeReason value)
{
    uint8_t val = (value);
    memcpy(codec->buffer + codec->offset + 17, &val, sizeof(uint8_t));

    return codec;
}

#endif
