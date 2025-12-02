#include <ruby.h>

uint64_t crc64(uint64_t crc, void *buf, size_t len);
uint64_t crc64_combine(uint64_t crc1, uint64_t crc2, uintmax_t len2);
void crc64_init_once(void);

VALUE crc64_wrapper(VALUE self, VALUE init_crc, VALUE buffer, VALUE size);
VALUE crc64_combine_wrapper(VALUE self, VALUE crc1, VALUE crc2, VALUE len2);
