#ifndef TENSORPOOL_ERRORS_H
#define TENSORPOOL_ERRORS_H

#ifdef __cplusplus
extern "C" {
#endif

typedef enum tp_err_enum
{
    TP_OK = 0,
    TP_ERR_ARG = -1,
    TP_ERR_AERON = -2,
    TP_ERR_TIMEOUT = -3,
    TP_ERR_PROTOCOL = -4,
    TP_ERR_SHM = -5,
    TP_ERR_IO = -6,
    TP_ERR_NOMEM = -7,
    TP_ERR_UNSUPPORTED = -8,
    TP_ERR_BUSY = -9,
    TP_ERR_NOT_FOUND = -10
}
tp_err_t;

#ifdef __cplusplus
}
#endif

#endif
