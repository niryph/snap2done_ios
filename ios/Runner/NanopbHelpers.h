#ifndef NanopbHelpers_h
#define NanopbHelpers_h

#include <nanopb/pb.h>
#include <nanopb/pb_common.h>
#include <nanopb/pb_decode.h>
#include <nanopb/pb_encode.h>

// Ensure pb_release is properly defined
#ifndef pb_release
#define pb_release(fields, dest_struct) pb_release_wrapper(fields, dest_struct)
void pb_release_wrapper(const pb_msgdesc_t *fields, void *dest_struct);
#endif

#endif /* NanopbHelpers_h */ 