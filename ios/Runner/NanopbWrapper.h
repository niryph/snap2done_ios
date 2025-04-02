#ifndef NanopbWrapper_h
#define NanopbWrapper_h

#include <nanopb/pb_common.h>
#include <nanopb/pb_decode.h>
#include <nanopb/pb_encode.h>

// Add wrapper for pb_release function to prevent undeclared function errors
inline void pb_release_wrapper(const pb_msgdesc_t *fields, void *dest_struct) {
    pb_release(fields, dest_struct);
}

#endif /* NanopbWrapper_h */ 