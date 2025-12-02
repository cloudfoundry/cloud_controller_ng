/*
 * Copyright (c) 2024 konsolebox
 *
 * MIT License
 *
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
 * LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
 * OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
 * WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#include <ruby.h>
#include <ruby/digest.h>

#define XXH_INLINE_ALL
#include "xxhash.h"
#include "utils.h"

#define _DIGEST_API_VERSION_IS_SUPPORTED(version) (version == 3)

#if !_DIGEST_API_VERSION_IS_SUPPORTED(RUBY_DIGEST_API_VERSION)
#	error Digest API version is not supported.
#endif

#define _XXH32_DIGEST_SIZE 4
#define _XXH32_BLOCK_SIZE 4
#define _XXH32_DEFAULT_SEED 0

#define _XXH64_DIGEST_SIZE 8
#define _XXH64_BLOCK_SIZE 8
#define _XXH64_DEFAULT_SEED 0

#define _XXH3_64BITS_DIGEST_SIZE 8
#define _XXH3_64BITS_BLOCK_SIZE 8
#define _XXH3_64BITS_DEFAULT_SEED 0

#define _XXH3_128BITS_DIGEST_SIZE 16
#define _XXH3_128BITS_BLOCK_SIZE 16
#define _XXH3_128BITS_DEFAULT_SEED 0

#if 0
#	define _DEBUG(...) fprintf(stderr, __VA_ARGS__)
#else
#	define _DEBUG(...) (void)0;
#endif

static ID _id_digest;
static ID _id_finish;
static ID _id_hexdigest;
static ID _id_idigest;
static ID _id_ifinish;
static ID _id_new;
static ID _id_reset;
static ID _id_update;

static VALUE _Digest;
static VALUE _Digest_Class;
static VALUE _Digest_XXHash;
static VALUE _Digest_XXH32;
static VALUE _Digest_XXH64;
static VALUE _Digest_XXH3_64bits;
static VALUE _Digest_XXH3_128bits;

#define _RSTRING_PTR_U(x) ((unsigned char *)RSTRING_PTR(x))
#define _TWICE(x) (x * 2)

static void _xxh32_free_state(void *);
static void _xxh64_free_state(void *);
static void _xxh3_free_state(void *);

/*
 * Data types
 */

static const rb_data_type_t _xxh32_state_data_type = {
	"xxh32_state_data",
	{ 0, _xxh32_free_state, 0, }, 0, 0,
	RUBY_TYPED_FREE_IMMEDIATELY|RUBY_TYPED_WB_PROTECTED
};

static const rb_data_type_t _xxh64_state_data_type = {
	"xxh64_state_data",
	{ 0, _xxh64_free_state, 0, }, 0, 0,
	RUBY_TYPED_FREE_IMMEDIATELY|RUBY_TYPED_WB_PROTECTED
};

static const rb_data_type_t _xxh3_64bits_state_data_type = {
	"xxh3_64bits_state_data",
	{ 0, _xxh3_free_state, 0, }, 0, 0,
	RUBY_TYPED_FREE_IMMEDIATELY|RUBY_TYPED_WB_PROTECTED
};

static const rb_data_type_t _xxh3_128bits_state_data_type = {
	"xxh3_128bits_state_data",
	{ 0, _xxh3_free_state, 0, }, 0, 0,
	RUBY_TYPED_FREE_IMMEDIATELY|RUBY_TYPED_WB_PROTECTED
};

/*
 * Common functions
 */

static XXH32_state_t *_get_state_xxh32(VALUE self)
{
	XXH32_state_t *state_p;
	TypedData_Get_Struct(self, XXH32_state_t, &_xxh32_state_data_type, state_p);
	return state_p;
}

static XXH64_state_t *_get_state_xxh64(VALUE self)
{
	XXH64_state_t *state_p;
	TypedData_Get_Struct(self, XXH64_state_t, &_xxh64_state_data_type, state_p);
	return state_p;
}

static XXH3_state_t *_get_state_xxh3_64bits(VALUE self)
{
	XXH3_state_t *state_p;
	TypedData_Get_Struct(self, XXH3_state_t, &_xxh3_64bits_state_data_type, state_p);
	return state_p;
}

static XXH3_state_t *_get_state_xxh3_128bits(VALUE self)
{
	XXH3_state_t *state_p;
	TypedData_Get_Struct(self, XXH3_state_t, &_xxh3_128bits_state_data_type, state_p);
	return state_p;
}

static void _xxh32_reset(XXH32_state_t *state_p, XXH32_hash_t seed)
{
	if (XXH32_reset(state_p, seed) != XXH_OK)
		rb_raise(rb_eRuntimeError, "Failed to reset state.");
}

static void _xxh64_reset(XXH64_state_t *state_p, XXH64_hash_t seed)
{
	if (XXH64_reset(state_p, seed) != XXH_OK)
		rb_raise(rb_eRuntimeError, "Failed to reset state.");
}

static void _xxh3_64bits_reset(XXH3_state_t *state_p, XXH64_hash_t seed)
{
	if (XXH3_64bits_reset_withSeed(state_p, seed) != XXH_OK)
		rb_raise(rb_eRuntimeError, "Failed to reset state.");
}

static void _xxh3_128bits_reset(XXH3_state_t *state_p, XXH64_hash_t seed)
{
	if (XXH3_128bits_reset_withSeed(state_p, seed) != XXH_OK)
		rb_raise(rb_eRuntimeError, "Failed to reset state.");
}

static void _xxh32_free_state(void* state)
{
	XXH32_freeState((XXH32_state_t *)state);
}

static void _xxh64_free_state(void* state)
{
	XXH64_freeState((XXH64_state_t *)state);
}

static void _xxh3_free_state(void* state)
{
	XXH3_freeState((XXH3_state_t *)state);
}

static VALUE _hex_encode_str(VALUE str)
{
	int len = RSTRING_LEN(str);
	VALUE hex = rb_usascii_str_new(0, _TWICE(len));
	hex_encode_str_implied(_RSTRING_PTR_U(str), len, _RSTRING_PTR_U(hex));
	return hex;
}

/*
 * Document-class: Digest::XXHash
 *
 * This is the base class of Digest::XXH32, Digest::XXH64,
 * Digest::XXH3_64bits, and Digest::XXH3_128bits.
 */

static VALUE _Digest_XXHash_internal_allocate(VALUE klass)
{
	if (klass == _Digest_XXHash)
		rb_raise(rb_eRuntimeError, "Digest::XXHash is an incomplete class and cannot be "
				"instantiated.");

	rb_raise(rb_eNotImpError, "Allocator function not implemented.");
}

/*
 * call-seq:
 *     new -> instance
 *     new(seed) -> instance
 *
 * Returns a new hash instance.
 *
 * If seed is provided, the state is reset with its value, otherwise the default
 * seed (0) is used.
 *
 * +seed+ can be in the form of a string, a hex string, or a number.
 */
static VALUE _Digest_XXHash_initialize(int argc, VALUE* argv, VALUE self)
{
	if (argc > 0)
		rb_funcallv(self, _id_reset, argc, argv);

	return self;
}

/* :nodoc: */
static VALUE _Digest_XXHash_ifinish(VALUE self)
{
	rb_raise(rb_eNotImpError, "Method not implemented.");
}

static VALUE _do_digest(int argc, VALUE* argv, VALUE self, ID finish_method_id)
{
	VALUE str, seed, result;
	int argc2 = argc > 0 ? rb_scan_args(argc, argv, "02", &str, &seed) : 0;

	if (argc2 > 0) {
		if (TYPE(str) != T_STRING)
			rb_raise(rb_eTypeError, "Argument type not string.");

		if (argc2 > 1)
			rb_funcall(self, _id_reset, 1, seed);
		else
			rb_funcall(self, _id_reset, 0);

		rb_funcall(self, _id_update, 1, str);
	}

	result = rb_funcall(self, finish_method_id, 0);

	if (argc2 > 0)
		rb_funcall(self, _id_reset, 0);

	return result;
}

/*
 * call-seq:
 *     digest -> str
 *     digest(str, seed = 0) -> str
 *
 * Returns digest value in string form.
 *
 * If no argument is provided, the current digest value is returned, and no
 * reset happens.
 *
 * If a string argument is provided, the string's digest value is calculated
 * with +seed+, and is used as the return value.  The instance's state is reset
 * to default afterwards.
 *
 * Providing an argument means that previous initializations done with custom
 * seeds or secrets, and previous calculations done with #update would be
 * discarded, so be careful with its use.
 *
 * +seed+ can be in the form of a string, a hex string, or a number.
 */
static VALUE _Digest_XXHash_digest(int argc, VALUE* argv, VALUE self)
{
	return _do_digest(argc, argv, self, _id_finish);
}

/*
 * call-seq:
 *     hexdigest -> hex_str
 *     hexdigest(str) -> hex_str
 *     hexdigest(str, seed) -> hex_str
 *
 * Same as #digest but returns the digest value in hex form.
 */
static VALUE _Digest_XXHash_hexdigest(int argc, VALUE* argv, VALUE self)
{
	return _hex_encode_str(_do_digest(argc, argv, self, _id_finish));
}

/*
 * call-seq:
 *     idigest -> num
 *     idigest(str) -> num
 *     idigest(str, seed) -> num
 *
 * Same as #digest but returns the digest value in numerical form.
 */
static VALUE _Digest_XXHash_idigest(int argc, VALUE* argv, VALUE self)
{
	return _do_digest(argc, argv, self, _id_ifinish);
}

/*
 * call-seq: idigest!
 *
 * Returns current digest value and resets state to default form.
 */
static VALUE _Digest_XXHash_idigest_bang(VALUE self)
{
	VALUE result;
	result = rb_funcall(self, _id_ifinish, 0);
	rb_funcall(self, _id_reset, 0);
	return result;
}

/*
 * call-seq: initialize_copy(orig) -> self
 *
 * This method is called when instances are cloned.  It is responsible for
 * replicating internal data.
 */
static VALUE _Digest_XXHash_initialize_copy(VALUE self, VALUE orig)
{
	rb_raise(rb_eNotImpError, "initialize_copy method not implemented.");
}

/*
 * call-seq: inspect -> str
 *
 * Returns a string in the form of <tt>#<class_name|hex_digest></tt>.
 */
static VALUE _Digest_XXHash_inspect(VALUE self)
{
	VALUE klass, klass_name, hexdigest, args[2];
	klass = rb_obj_class(self);
	klass_name = rb_class_name(klass);

	if (klass_name == Qnil)
		klass_name = rb_inspect(klass);

	hexdigest = rb_funcall(self, _id_hexdigest, 0);

	args[0] = klass_name;
	args[1] = hexdigest;
	return rb_str_format(sizeof(args), args, rb_str_new_literal("#<%s|%s>"));
}

static VALUE _instantiate_and_digest(int argc, VALUE* argv, VALUE klass, ID digest_method_id)
{
	VALUE str, seed, instance;
	int argc2;

	argc2 = rb_scan_args(argc, argv, "11", &str, &seed);

	if (TYPE(str) != T_STRING)
		rb_raise(rb_eTypeError, "Argument type not string.");

	instance = rb_funcall(klass, _id_new, 0);

	if (argc2 > 1)
		return rb_funcall(instance, digest_method_id, 2, str, seed);
	else
		return rb_funcall(instance, digest_method_id, 1, str);
}

/*
 * call-seq: Digest::XXHash::digest(str, seed = 0) -> str
 *
 * Returns the digest value of +str+ in string form with +seed+ as its seed.
 *
 * +seed+ can be in the form of a string, a hex string, or a number.
 *
 * If +seed+ is not provided, the default value would be 0.
 */
static VALUE _Digest_XXHash_singleton_digest(int argc, VALUE* argv, VALUE self)
{
	return _instantiate_and_digest(argc, argv, self, _id_digest);
}

/*
 * call-seq: Digest::XXHash::hexdigest -> hex_str
 *
 * Same as ::digest but returns the digest value in hex form.
 */
static VALUE _Digest_XXHash_singleton_hexdigest(int argc, VALUE* argv, VALUE self)
{
	return _instantiate_and_digest(argc, argv, self, _id_hexdigest);
}

/*
 * call-seq: Digest::XXHash::idigest -> num
 *
 * Same as ::digest but returns the digest value in numerical form.
 */
static VALUE _Digest_XXHash_singleton_idigest(int argc, VALUE* argv, VALUE self)
{
	return _instantiate_and_digest(argc, argv, self, _id_idigest);
}

/*
 * Document-class: Digest::XXH32
 *
 * This class implements XXH32.
 */

static VALUE _Digest_XXH32_internal_allocate(VALUE klass)
{
	XXH32_state_t *state_p = XXH32_createState();
	_xxh32_reset(state_p, 0);
	return TypedData_Wrap_Struct(klass, &_xxh32_state_data_type, state_p);
}

/*
 * call-seq: update(str) -> self
 *
 * Updates current digest value with string.
 */
static VALUE _Digest_XXH32_update(VALUE self, VALUE str)
{
	if (XXH32_update(_get_state_xxh32(self), RSTRING_PTR(str), RSTRING_LEN(str)) != XXH_OK)
		rb_raise(rb_eRuntimeError, "Failed to update state.");

	return self;
}

/* :nodoc: */
static VALUE _Digest_XXH32_finish(VALUE self)
{
	XXH64_hash_t hash = XXH32_digest(_get_state_xxh32(self));
	VALUE str = rb_usascii_str_new(0, sizeof(XXH32_canonical_t));
	XXH32_canonicalFromHash((XXH32_canonical_t *)RSTRING_PTR(str), hash);
	return str;
}

/* :nodoc: */
static VALUE _Digest_XXH32_ifinish(VALUE self)
{
	XXH32_hash_t hash = XXH32_digest(_get_state_xxh32(self));
	return ULONG2NUM(hash);
}

/*
 * call-seq: reset(seed = 0) -> self
 *
 * Resets state to initial form with seed.
 *
 * This discards previous calculations with #update.
 *
 * +seed+ can be in the form of a string, a hex string, or a number.
 * Its virtual length should be 32-bits.
 *
 * If +seed+ is not provided, the default value would be 0.
 */
static VALUE _Digest_XXH32_reset(int argc, VALUE* argv, VALUE self)
{
	VALUE seed;

	if (argc > 0 && rb_scan_args(argc, argv, "01", &seed) > 0) {
		switch (TYPE(seed)) {
		case T_STRING:
			{
				int len = RSTRING_LEN(seed);
				XXH32_hash_t decoded_seed;

				if (len == _TWICE(sizeof(XXH32_hash_t))) {
					unsigned char hex_decoded_seed[sizeof(XXH32_hash_t)];

					if (! hex_decode_str_implied(_RSTRING_PTR_U(seed), len, hex_decoded_seed))
						rb_raise(rb_eArgError, "Invalid hex string seed: %s\n",
								StringValueCStr(seed));

					decoded_seed = XXH_readBE32(hex_decoded_seed);
				} else if (len == sizeof(XXH32_hash_t)) {
					decoded_seed = XXH_readBE32(RSTRING_PTR(seed));
				} else {
					rb_raise(rb_eArgError, "Invalid seed length.  "
							"Expecting an 8-character hex string or a 4-byte string.");
				}

				_xxh32_reset(_get_state_xxh32(self), decoded_seed);
			}

			break;
		case T_FIXNUM:
			_xxh32_reset(_get_state_xxh32(self), FIX2UINT(seed));
			break;
		case T_BIGNUM:
			_xxh32_reset(_get_state_xxh32(self), NUM2UINT(seed));
			break;
		default:
			rb_raise(rb_eArgError, "Invalid argument type for 'seed'.  "
					"Expecting a string or a number.");
		}
	} else {
		_xxh32_reset(_get_state_xxh32(self), _XXH32_DEFAULT_SEED);
	}

	return self;
}

/*
 * call-seq: initialize_copy(orig) -> self
 *
 * This method is called when instances are cloned.  It is responsible for
 * replicating internal data.
 */
static VALUE _Digest_XXH32_initialize_copy(VALUE self, VALUE orig)
{
	XXH32_copyState(_get_state_xxh32(self), _get_state_xxh32(orig));
	return self;
}

/*
 * call-seq: digest_length -> int
 *
 * Returns 4
 */
static VALUE _Digest_XXH32_digest_length(VALUE self)
{
	return INT2FIX(_XXH32_DIGEST_SIZE);
}

/*
 * call-seq: block_length  -> int
 *
 * Returns 4
 */
static VALUE _Digest_XXH32_block_length(VALUE self)
{
	return INT2FIX(_XXH32_BLOCK_SIZE);
}

/*
 * call-seq: digest_length -> int
 *
 * Returns 4
 */
static VALUE _Digest_XXH32_singleton_digest_length(VALUE self)
{
	return INT2FIX(_XXH32_DIGEST_SIZE);
}

/*
 * call-seq: block_length -> int
 *
 * Returns 4
 */
static VALUE _Digest_XXH32_singleton_block_length(VALUE self)
{
	return INT2FIX(_XXH32_BLOCK_SIZE);
}

/*
 * Document-class: Digest::XXH64
 *
 * This class implements XXH64.
 */

static VALUE _Digest_XXH64_internal_allocate(VALUE klass)
{
	XXH64_state_t *state_p = XXH64_createState();
	_xxh64_reset(state_p, 0);
	return TypedData_Wrap_Struct(klass, &_xxh64_state_data_type, state_p);
}

/*
 * call-seq: update(str) -> self
 *
 * Updates current digest value with string.
 */
static VALUE _Digest_XXH64_update(VALUE self, VALUE str)
{
	if (XXH64_update(_get_state_xxh64(self), RSTRING_PTR(str), RSTRING_LEN(str)) != XXH_OK)
		rb_raise(rb_eRuntimeError, "Failed to update state.");

	return self;
}

/* :nodoc: */
static VALUE _Digest_XXH64_finish(VALUE self)
{
	XXH64_hash_t hash = XXH64_digest(_get_state_xxh64(self));
	VALUE str = rb_usascii_str_new(0, sizeof(XXH64_canonical_t));
	XXH64_canonicalFromHash((XXH64_canonical_t *)RSTRING_PTR(str), hash);
	return str;
}

/* :nodoc: */
static VALUE _Digest_XXH64_ifinish(VALUE self)
{
	XXH64_hash_t hash = XXH64_digest(_get_state_xxh64(self));
	return ULL2NUM(hash);
}

/*
 * call-seq: reset(seed = 0) -> self
 *
 * Resets state to initial form with seed.
 *
 * This discards previous calculations with #update.
 *
 * +seed+ can be in the form of a string, a hex string, or a number.
 * Its virtual length should be 64-bits.
 *
 * If +seed+ is not provided, the default value would be 0.
 */
static VALUE _Digest_XXH64_reset(int argc, VALUE* argv, VALUE self)
{
	VALUE seed;

	if (rb_scan_args(argc, argv, "01", &seed) > 0) {
		switch (TYPE(seed)) {
		case T_STRING:
			{
				int len = RSTRING_LEN(seed);
				XXH64_hash_t decoded_seed;

				if (len == _TWICE(sizeof(XXH64_hash_t))) {
					unsigned char hex_decoded_seed[sizeof(XXH64_hash_t)];

					if (! hex_decode_str_implied(_RSTRING_PTR_U(seed), len, hex_decoded_seed))
						rb_raise(rb_eArgError, "Invalid hex string seed: %s\n",
								StringValueCStr(seed));

					decoded_seed = XXH_readBE64(hex_decoded_seed);
				} else if (len == sizeof(XXH64_hash_t)) {
					decoded_seed = XXH_readBE64(RSTRING_PTR(seed));
				} else {
					rb_raise(rb_eArgError, "Invalid seed length.  "
							"Expecting a 16-character hex string or an 8-byte string.");
				}

				_xxh64_reset(_get_state_xxh64(self), decoded_seed);
			}

			break;
		case T_FIXNUM:
		case T_BIGNUM:
			_xxh64_reset(_get_state_xxh64(self), NUM2ULL(seed));
			break;
		default:
			rb_raise(rb_eArgError, "Invalid argument type for 'seed'.  "
					"Expecting a string or a number.");
		}
	} else {
		_xxh64_reset(_get_state_xxh64(self), _XXH64_DEFAULT_SEED);
	}

	return self;
}

/*
 * call-seq: initialize_copy(orig) -> self
 *
 * This method is called when instances are cloned.  It is responsible for
 * replicating internal data.
 */
static VALUE _Digest_XXH64_initialize_copy(VALUE self, VALUE orig)
{
	XXH64_copyState(_get_state_xxh64(self), _get_state_xxh64(orig));
	return self;
}

/*
 * call-seq: digest_length -> int
 *
 * Returns 8
 */
static VALUE _Digest_XXH64_digest_length(VALUE self)
{
	return INT2FIX(_XXH64_DIGEST_SIZE);
}

/*
 * call-seq: block_length -> int
 *
 * Returns 8
 */
static VALUE _Digest_XXH64_block_length(VALUE self)
{
	return INT2FIX(_XXH64_BLOCK_SIZE);
}

/*
 * call-seq: digest_length -> int
 *
 * Returns 8
 */
static VALUE _Digest_XXH64_singleton_digest_length(VALUE self)
{
	return INT2FIX(_XXH64_DIGEST_SIZE);
}

/*
 * call-seq: block_length -> int
 *
 * Returns 8
 */
static VALUE _Digest_XXH64_singleton_block_length(VALUE self)
{
	return INT2FIX(_XXH64_BLOCK_SIZE);
}

/*
 * Document-class: Digest::XXH3_64bits
 *
 * This class implements XXH3_64bits.
 */

static VALUE _Digest_XXH3_64bits_internal_allocate(VALUE klass)
{
	XXH3_state_t *state_p = XXH3_createState();
	XXH3_64bits_reset(state_p);
	return TypedData_Wrap_Struct(klass, &_xxh3_64bits_state_data_type, state_p);
}

/*
 * call-seq: update(str) -> self
 *
 * Updates current digest value with string.
 */
static VALUE _Digest_XXH3_64bits_update(VALUE self, VALUE str)
{
	if (XXH3_64bits_update(_get_state_xxh3_64bits(self), RSTRING_PTR(str), RSTRING_LEN(str)) != XXH_OK)
		rb_raise(rb_eRuntimeError, "Failed to update state.");

	return self;
}

/* :nodoc: */
static VALUE _Digest_XXH3_64bits_finish(VALUE self)
{
	XXH64_hash_t hash = XXH3_64bits_digest(_get_state_xxh3_64bits(self));
	VALUE str = rb_usascii_str_new(0, sizeof(XXH64_canonical_t));
	XXH64_canonicalFromHash((XXH64_canonical_t *)RSTRING_PTR(str), hash);
	return str;
}

/* :nodoc: */
static VALUE _Digest_XXH3_64bits_ifinish(VALUE self)
{
	XXH64_hash_t hash = XXH3_64bits_digest(_get_state_xxh3_64bits(self));
	return ULL2NUM(hash);
}

/*
 * call-seq: reset(seed = 0) -> self
 *
 * Resets state to initial form with seed.
 *
 * This discards previous calculations with #update.
 *
 * +seed+ can be in the form of a string, a hex string, or a number.
 * Its virtual length should be 64-bits.
 *
 * If +seed+ is not provided, the default value would be 0.
 */
static VALUE _Digest_XXH3_64bits_reset(int argc, VALUE* argv, VALUE self)
{
	VALUE seed;

	if (rb_scan_args(argc, argv, "01", &seed) > 0) {
		switch (TYPE(seed)) {
		case T_STRING:
			{
				int len = RSTRING_LEN(seed);
				XXH64_hash_t decoded_seed;

				if (len == _TWICE(sizeof(XXH64_hash_t))) {
					unsigned char hex_decoded_seed[sizeof(XXH64_hash_t)];

					if (! hex_decode_str_implied(_RSTRING_PTR_U(seed), len, hex_decoded_seed))
						rb_raise(rb_eArgError, "Invalid hex string seed: %s\n",
								StringValueCStr(seed));

					decoded_seed = XXH_readBE64(hex_decoded_seed);
				} else if (len == sizeof(XXH64_hash_t)) {
					decoded_seed = XXH_readBE64(RSTRING_PTR(seed));
				} else {
					rb_raise(rb_eArgError, "Invalid seed length.  "
							"Expecting a 16-character hex string or an 8-byte string.");
				}

				_xxh3_64bits_reset(_get_state_xxh3_64bits(self), decoded_seed);
			}

			break;
		case T_FIXNUM:
		case T_BIGNUM:
			_xxh3_64bits_reset(_get_state_xxh3_64bits(self), NUM2ULL(seed));
			break;
		default:
			rb_raise(rb_eArgError, "Invalid argument type for 'seed'.  "
					"Expecting a string or a number.");
		}
	} else {
		_xxh3_64bits_reset(_get_state_xxh3_64bits(self), _XXH3_64BITS_DEFAULT_SEED);
	}

	return self;
}

/*
 * call-seq: reset_with_secret(secret) -> self
 *
 * Resets state to initial form using a secret.
 *
 * This discards previous calculations with #update.
 *
 * Secret should be a string and have a minimum length of XXH3_SECRET_SIZE_MIN.
 */
static VALUE _Digest_XXH3_64bits_reset_with_secret(VALUE self, VALUE secret)
{
	if (TYPE(secret) != T_STRING)
		rb_raise(rb_eArgError, "Argument 'secret' needs to be a string.");

	if (RSTRING_LEN(secret) < XXH3_SECRET_SIZE_MIN)
		rb_raise(rb_eRuntimeError, "Secret needs to be at least %d bytes in length.",
				XXH3_SECRET_SIZE_MIN);

	if (XXH3_64bits_reset_withSecret(_get_state_xxh3_64bits(self), RSTRING_PTR(secret),
			RSTRING_LEN(secret)) != XXH_OK)
		rb_raise(rb_eRuntimeError, "Failed to reset state with secret.");

	return self;
}

/*
 * call-seq: initialize_copy(orig) -> self
 *
 * This method is called when instances are cloned.  It is responsible for
 * replicating internal data.
 */
static VALUE _Digest_XXH3_64bits_initialize_copy(VALUE self, VALUE orig)
{
	XXH3_copyState(_get_state_xxh3_64bits(self), _get_state_xxh3_64bits(orig));
	return self;
}

/*
 * call-seq: digest_length -> int
 *
 * Returns 8
 */
static VALUE _Digest_XXH3_64bits_digest_length(VALUE self)
{
	return INT2FIX(_XXH3_64BITS_DIGEST_SIZE);
}

/*
 * call-seq: block_length -> int
 *
 * Returns 8
 */
static VALUE _Digest_XXH3_64bits_block_length(VALUE self)
{
	return INT2FIX(_XXH3_64BITS_BLOCK_SIZE);
}

/*
 * call-seq: digest_length -> int
 *
 * Returns 8
 */
static VALUE _Digest_XXH3_64bits_singleton_digest_length(VALUE self)
{
	return INT2FIX(_XXH3_64BITS_DIGEST_SIZE);
}

/*
 * call-seq: block_length -> int
 *
 * Returns 8
 */
static VALUE _Digest_XXH3_64bits_singleton_block_length(VALUE self)
{
	return INT2FIX(_XXH3_64BITS_BLOCK_SIZE);
}

/*
 * Document-class: Digest::XXH3_128bits
 *
 * This class implements XXH3_128bits.
 */

static VALUE _Digest_XXH3_128bits_internal_allocate(VALUE klass)
{
	XXH3_state_t *state_p = XXH3_createState();
	XXH3_128bits_reset(state_p);
	return TypedData_Wrap_Struct(klass, &_xxh3_128bits_state_data_type, state_p);
}

/*
 * call-seq: update(str) -> self
 *
 * Updates current digest value with string.
 */
static VALUE _Digest_XXH3_128bits_update(VALUE self, VALUE str)
{
	if (XXH3_128bits_update(_get_state_xxh3_128bits(self), RSTRING_PTR(str), RSTRING_LEN(str)) != XXH_OK)
		rb_raise(rb_eRuntimeError, "Failed to update state.");

	return self;
}

/* :nodoc: */
static VALUE _Digest_XXH3_128bits_finish(VALUE self)
{
	XXH128_hash_t hash = XXH3_128bits_digest(_get_state_xxh3_128bits(self));
	VALUE str = rb_usascii_str_new(0, sizeof(XXH128_canonical_t));
	XXH128_canonicalFromHash((XXH128_canonical_t *)RSTRING_PTR(str), hash);
	return str;
}

/* :nodoc: */
static VALUE _Digest_XXH3_128bits_ifinish(VALUE self)
{
	XXH128_hash_t hash = XXH3_128bits_digest(_get_state_xxh3_128bits(self));

	if (! XXH_CPU_LITTLE_ENDIAN) {
		#define _SWAP_WORDS(x) ((x << 32) & 0xffffffff00000000ULL) | \
			((x >> 32) & 0x000000000ffffffffULL)
		hash.low64 = _SWAP_WORDS(hash.low64);
		hash.high64 = _SWAP_WORDS(hash.high64);
	}

	return rb_integer_unpack(&hash, 4, sizeof(XXH32_hash_t), 0, INTEGER_PACK_LSWORD_FIRST|
			INTEGER_PACK_NATIVE_BYTE_ORDER);
}

/*
 * call-seq: reset(seed = 0) -> self
 *
 * Resets state to initial form with seed.
 *
 * This discards previous calculations with #update.
 *
 * +seed+ can be in the form of a string, a hex string, or a number.
 * Its virtual length should be 64-bits and not 128-bits.
 *
 * If +seed+ is not provided, the default value would be 0.
 */
static VALUE _Digest_XXH3_128bits_reset(int argc, VALUE* argv, VALUE self)
{
	VALUE seed;

	if (rb_scan_args(argc, argv, "01", &seed) > 0) {
		switch (TYPE(seed)) {
		case T_STRING:
			{
				int len = RSTRING_LEN(seed);
				XXH64_hash_t decoded_seed;

				if (len == _TWICE(sizeof(XXH64_hash_t))) {
					unsigned char hex_decoded_seed[sizeof(XXH64_hash_t)];

					if (! hex_decode_str_implied(_RSTRING_PTR_U(seed), len, hex_decoded_seed))
						rb_raise(rb_eArgError, "Invalid hex string seed: %s\n",
								StringValueCStr(seed));

					decoded_seed = XXH_readBE64(hex_decoded_seed);
				} else if (len == sizeof(XXH64_hash_t)) {
					decoded_seed = XXH_readBE64(RSTRING_PTR(seed));
				} else {
					rb_raise(rb_eArgError, "Invalid seed length.  Expecting a 16-character hex "
							"string or an 8-byte string.");
				}

				_xxh3_128bits_reset(_get_state_xxh3_128bits(self), decoded_seed);
			}

			break;
		case T_FIXNUM:
		case T_BIGNUM:
			_xxh3_128bits_reset(_get_state_xxh3_128bits(self), NUM2ULL(seed));
			break;
		default:
			rb_raise(rb_eArgError, "Invalid argument type for 'seed'.  "
					"Expecting a string or a number.");
		}
	} else {
		_xxh3_128bits_reset(_get_state_xxh3_128bits(self), _XXH3_128BITS_DEFAULT_SEED);
	}

	return self;
}

/*
 * call-seq: reset_with_secret(secret) -> self
 *
 * Resets state to initial form using a secret.
 *
 * This discards previous calculations with #update.
 *
 * Secret should be a string having a minimum length of XXH3_SECRET_SIZE_MIN.
 */
static VALUE _Digest_XXH3_128bits_reset_with_secret(VALUE self, VALUE secret)
{
	if (TYPE(secret) != T_STRING)
		rb_raise(rb_eArgError, "Argument 'secret' needs to be a string.");

	if (RSTRING_LEN(secret) < XXH3_SECRET_SIZE_MIN)
		rb_raise(rb_eRuntimeError, "Secret needs to be at least %d bytes in length.",
				XXH3_SECRET_SIZE_MIN);

	if (XXH3_128bits_reset_withSecret(_get_state_xxh3_128bits(self), RSTRING_PTR(secret),
			RSTRING_LEN(secret)) != XXH_OK)
		rb_raise(rb_eRuntimeError, "Failed to reset state with secret.");

	return self;
}

/*
 * call-seq: initialize_copy(orig) -> self
 *
 * This method is called when instances are cloned.  It is responsible for
 * replicating internal data.
 */
static VALUE _Digest_XXH3_128bits_initialize_copy(VALUE self, VALUE orig)
{
	XXH3_copyState(_get_state_xxh3_128bits(self), _get_state_xxh3_128bits(orig));
	return self;
}

/*
 * call-seq: digest_length -> int
 *
 * Returns 16
 */
static VALUE _Digest_XXH3_128bits_digest_length(VALUE self)
{
	return INT2FIX(_XXH3_128BITS_DIGEST_SIZE);
}

/*
 * call-seq: block_length -> int
 *
 * Returns 16
 */
static VALUE _Digest_XXH3_128bits_block_length(VALUE self)
{
	return INT2FIX(_XXH3_128BITS_BLOCK_SIZE);
}

/*
 * call-seq: digest_length -> int
 *
 * Returns 16
 */
static VALUE _Digest_XXH3_128bits_singleton_digest_length(VALUE self)
{
	return INT2FIX(_XXH3_128BITS_DIGEST_SIZE);
}

/*
 * call-seq: block_length -> int
 *
 * Returns 16
 */
static VALUE _Digest_XXH3_128bits_singleton_block_length(VALUE self)
{
	return INT2FIX(_XXH3_128BITS_BLOCK_SIZE);
}

/*
 * Initialization
 */

void Init_xxhash(void)
{
	#define DEFINE_ID(x) _id_##x = rb_intern_const(#x);

	DEFINE_ID(digest)
	DEFINE_ID(finish)
	DEFINE_ID(hexdigest)
	DEFINE_ID(idigest)
	DEFINE_ID(ifinish)
	DEFINE_ID(new)
	DEFINE_ID(reset)
	DEFINE_ID(update)

	rb_require("digest");
	_Digest = rb_path2class("Digest");
	_Digest_Class = rb_path2class("Digest::Class");

	#if 0
	/* Tell RDoc about Digest and Digest::Class since it doesn't parse rb_path2class. */
	_Digest = rb_define_module("Digest");
	_Digest_Class = rb_define_class_under(_Digest, "Class", rb_cObject);
	#endif

	/*
	 * Document-class: Digest::XXHash
	 */

	_Digest_XXHash = rb_define_class_under(_Digest, "XXHash", _Digest_Class);
	rb_define_alloc_func(_Digest_XXHash, _Digest_XXHash_internal_allocate);
	rb_define_method(_Digest_XXHash, "digest", _Digest_XXHash_digest, -1);
	rb_define_method(_Digest_XXHash, "hexdigest", _Digest_XXHash_hexdigest, -1);
	rb_define_method(_Digest_XXHash, "idigest", _Digest_XXHash_idigest, -1);
	rb_define_method(_Digest_XXHash, "idigest!", _Digest_XXHash_idigest_bang, 0);
	rb_define_method(_Digest_XXHash, "initialize", _Digest_XXHash_initialize, -1);
	rb_define_method(_Digest_XXHash, "inspect", _Digest_XXHash_inspect, 0);
	rb_define_method(_Digest_XXHash, "initialize_copy", _Digest_XXHash_initialize_copy, 1);
	rb_define_protected_method(_Digest_XXHash, "ifinish", _Digest_XXHash_ifinish, 0);
	rb_define_singleton_method(_Digest_XXHash, "digest", _Digest_XXHash_singleton_digest, -1);
	rb_define_singleton_method(_Digest_XXHash, "hexdigest", _Digest_XXHash_singleton_hexdigest, -1);
	rb_define_singleton_method(_Digest_XXHash, "idigest", _Digest_XXHash_singleton_idigest, -1);

	/*
	 * Document-class: Digest::XXH32
	 */

	_Digest_XXH32 = rb_define_class_under(_Digest, "XXH32", _Digest_XXHash);
	rb_define_alloc_func(_Digest_XXH32, _Digest_XXH32_internal_allocate);
	rb_define_private_method(_Digest_XXH32, "finish", _Digest_XXH32_finish, 0);
	rb_define_private_method(_Digest_XXH32, "ifinish", _Digest_XXH32_ifinish, 0);
	rb_define_method(_Digest_XXH32, "update", _Digest_XXH32_update, 1);
	rb_define_method(_Digest_XXH32, "reset", _Digest_XXH32_reset, -1);
	rb_define_method(_Digest_XXH32, "digest_length", _Digest_XXH32_digest_length, 0);
	rb_define_method(_Digest_XXH32, "block_length", _Digest_XXH32_block_length, 0);
	rb_define_method(_Digest_XXH32, "initialize_copy", _Digest_XXH32_initialize_copy, 1);
	rb_define_singleton_method(_Digest_XXH32, "digest_length", _Digest_XXH32_singleton_digest_length, 0);
	rb_define_singleton_method(_Digest_XXH32, "block_length", _Digest_XXH32_singleton_block_length, 0);

	/*
	 * Document-class: Digest::XXH64
	 */

	_Digest_XXH64 = rb_define_class_under(_Digest, "XXH64", _Digest_XXHash);
	rb_define_alloc_func(_Digest_XXH64, _Digest_XXH64_internal_allocate);
	rb_define_private_method(_Digest_XXH64, "finish", _Digest_XXH64_finish, 0);
	rb_define_private_method(_Digest_XXH64, "ifinish", _Digest_XXH64_ifinish, 0);
	rb_define_method(_Digest_XXH64, "update", _Digest_XXH64_update, 1);
	rb_define_method(_Digest_XXH64, "reset", _Digest_XXH64_reset, -1);
	rb_define_method(_Digest_XXH64, "digest_length", _Digest_XXH64_digest_length, 0);
	rb_define_method(_Digest_XXH64, "block_length", _Digest_XXH64_block_length, 0);
	rb_define_method(_Digest_XXH64, "initialize_copy", _Digest_XXH64_initialize_copy, 1);
	rb_define_singleton_method(_Digest_XXH64, "digest_length", _Digest_XXH64_singleton_digest_length, 0);
	rb_define_singleton_method(_Digest_XXH64, "block_length", _Digest_XXH64_singleton_block_length, 0);

	/*
	 * Document-class: Digest::XXH3_64bits
	 */

	_Digest_XXH3_64bits = rb_define_class_under(_Digest, "XXH3_64bits", _Digest_XXHash);
	rb_define_alloc_func(_Digest_XXH3_64bits, _Digest_XXH3_64bits_internal_allocate);
	rb_define_private_method(_Digest_XXH3_64bits, "finish", _Digest_XXH3_64bits_finish, 0);
	rb_define_private_method(_Digest_XXH3_64bits, "ifinish", _Digest_XXH3_64bits_ifinish, 0);
	rb_define_method(_Digest_XXH3_64bits, "update", _Digest_XXH3_64bits_update, 1);
	rb_define_method(_Digest_XXH3_64bits, "reset", _Digest_XXH3_64bits_reset, -1);
	rb_define_method(_Digest_XXH3_64bits, "reset_with_secret", _Digest_XXH3_64bits_reset_with_secret, 1);
	rb_define_method(_Digest_XXH3_64bits, "digest_length", _Digest_XXH3_64bits_digest_length, 0);
	rb_define_method(_Digest_XXH3_64bits, "block_length", _Digest_XXH3_64bits_block_length, 0);
	rb_define_method(_Digest_XXH3_64bits, "initialize_copy", _Digest_XXH3_64bits_initialize_copy, 1);
	rb_define_singleton_method(_Digest_XXH3_64bits, "digest_length", _Digest_XXH3_64bits_singleton_digest_length, 0);
	rb_define_singleton_method(_Digest_XXH3_64bits, "block_length", _Digest_XXH3_64bits_singleton_block_length, 0);

	/*
	 * Document-class: Digest::XXH3_128bits
	 */

	_Digest_XXH3_128bits = rb_define_class_under(_Digest, "XXH3_128bits", _Digest_XXHash);
	rb_define_alloc_func(_Digest_XXH3_128bits, _Digest_XXH3_128bits_internal_allocate);
	rb_define_private_method(_Digest_XXH3_128bits, "finish", _Digest_XXH3_128bits_finish, 0);
	rb_define_private_method(_Digest_XXH3_128bits, "ifinish", _Digest_XXH3_128bits_ifinish, 0);
	rb_define_method(_Digest_XXH3_128bits, "update", _Digest_XXH3_128bits_update, 1);
	rb_define_method(_Digest_XXH3_128bits, "reset", _Digest_XXH3_128bits_reset, -1);
	rb_define_method(_Digest_XXH3_128bits, "reset_with_secret", _Digest_XXH3_128bits_reset_with_secret, 1);
	rb_define_method(_Digest_XXH3_128bits, "digest_length", _Digest_XXH3_128bits_digest_length, 0);
	rb_define_method(_Digest_XXH3_128bits, "block_length", _Digest_XXH3_128bits_block_length, 0);
	rb_define_method(_Digest_XXH3_128bits, "initialize_copy", _Digest_XXH3_128bits_initialize_copy, 1);
	rb_define_singleton_method(_Digest_XXH3_128bits, "digest_length", _Digest_XXH3_128bits_singleton_digest_length, 0);
	rb_define_singleton_method(_Digest_XXH3_128bits, "block_length", _Digest_XXH3_128bits_singleton_block_length, 0);

	/*
	 * Document-const: Digest::XXHash::XXH3_SECRET_SIZE_MIN
	 *
	 * Minimum allowed custom secret size defined in the core XXHash
	 * code.  The current value is 136.
	 *
	 * The author of Digest::XXHash doesn't know if this value would
	 * change in the future.
	 */

	rb_define_const(_Digest_XXHash, "XXH3_SECRET_SIZE_MIN", INT2FIX(XXH3_SECRET_SIZE_MIN));

	rb_require("digest/xxhash/version");
}
