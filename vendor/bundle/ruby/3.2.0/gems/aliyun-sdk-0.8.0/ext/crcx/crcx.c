#include "crcx.h"

void Init_crcx(){
    VALUE mAliyun = Qnil;
    VALUE CrcX = Qnil;

    crc64_init_once();

    mAliyun = rb_define_module("Aliyun");
    CrcX = rb_define_module_under(mAliyun, "CrcX");
    rb_define_module_function(CrcX, "crc64", crc64_wrapper, 3);
    rb_define_module_function(CrcX, "crc64_combine", crc64_combine_wrapper, 3);
}

void check_num_type(VALUE crc_value)
{
    if (T_BIGNUM == TYPE(crc_value)) {
        Check_Type(crc_value, T_BIGNUM);
    }
    else {
        Check_Type(crc_value, T_FIXNUM);
    }
    return ;
}

VALUE crc64_wrapper(VALUE self, VALUE init_crc, VALUE buffer, VALUE size)
{
    uint64_t crc_value = 0;

    check_num_type(init_crc);
    check_num_type(size);
    Check_Type(buffer, T_STRING);
    crc_value = crc64(NUM2ULL(init_crc), (void *)RSTRING_PTR(buffer), NUM2ULL(size));
    return ULL2NUM(crc_value);
}

VALUE crc64_combine_wrapper(VALUE self, VALUE crc1, VALUE crc2, VALUE len2)
{
    uint64_t crc_value = 0;
    check_num_type(crc1);
    check_num_type(crc2);
    check_num_type(len2);
    crc_value = crc64_combine(NUM2ULL(crc1), NUM2ULL(crc2), NUM2ULL(len2));
    return ULL2NUM(crc_value);
}
