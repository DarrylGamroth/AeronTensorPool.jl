#include "tensorpool_errors.h"

const char *tp_err_str(tp_err_t err)
{
    switch (err)
    {
        case TP_OK:
            return "ok";
        case TP_ERR_ARG:
            return "invalid argument";
        case TP_ERR_AERON:
            return "aeron error";
        case TP_ERR_TIMEOUT:
            return "timeout";
        case TP_ERR_PROTOCOL:
            return "protocol error";
        case TP_ERR_SHM:
            return "shm error";
        case TP_ERR_IO:
            return "io error";
        case TP_ERR_NOMEM:
            return "out of memory";
        case TP_ERR_UNSUPPORTED:
            return "unsupported";
        case TP_ERR_BUSY:
            return "busy";
        case TP_ERR_NOT_FOUND:
            return "not found";
        default:
            return "unknown";
    }
}
