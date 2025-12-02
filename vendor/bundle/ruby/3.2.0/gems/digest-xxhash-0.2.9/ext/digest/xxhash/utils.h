/*
 * These works are licensed under the Creative Commons Attribution-ShareAlike
 * 3.0 Unported License.  To view a copy of this license, visit
 * http://creativecommons.org/licenses/by-sa/3.0/ or send a letter to Creative
 * Commons, PO Box 1866, Mountain View, CA 94042, USA.
 */

#ifndef UTILS_H
#define UTILS_H

#include <string.h>

#if 0
/*
 * Checks if system uses little endian.
 *
 * Original Author: AusCBloke
 * https://stackoverflow.com/a/8842686/445221
 */
static int is_little_endian()
{
	const unsigned num = 0xABCD;
	return *((unsigned char *) &num) == 0xCD;
}
#endif

#if 0
/*
 * Swaps bytes to transform numbers from little endian mode to big endian mode
 * or vice versa.
 *
 * Author: chmike
 * https://stackoverflow.com/a/2637138/445221
 */
static uint32_t swap_uint32(uint32_t val)
{
    val = ((val << 8) & 0xFF00FF00 ) | ((val >> 8) & 0xFF00FF );
    return (val << 16) | (val >> 16);
}
static uint64_t swap_uint64(uint64_t val)
{
    val = ((val << 8) & 0xFF00FF00FF00FF00ULL ) | ((val >> 8) & 0x00FF00FF00FF00FFULL );
    val = ((val << 16) & 0xFFFF0000FFFF0000ULL ) | ((val >> 16) & 0x0000FFFF0000FFFFULL );
    return (val << 32) | (val >> 32);
}
#endif

#if 0
/*
 * Reads primitive numerical data from an address which can be aligned or not.
 *
 * Author: Cyan
 * https://stackoverflow.com/a/32095106/445221
 */
static uint32_t read32(const void *ptr)
{
	uint32_t value;
	memcpy(&value, ptr, sizeof(uint32_t));
	return value;
}
static uint64_t read64(const void *ptr)
{
	uint64_t value;
	memcpy(&value, ptr, sizeof(uint64_t));
	return value;
}
#endif

/*
 * A simplified hex encoder based on Yannuth's answer in StackOverflow
 * (https://stackoverflow.com/a/17147874/445221).
 *
 * Length of `dest[]` is implied to be twice of `len`.
 */
static void hex_encode_str_implied(const unsigned char *src, size_t len, unsigned char *dest)
{
	static const unsigned char table[] = "0123456789abcdef";
	unsigned char c;

	for (; len > 0; --len) {
		c = *src++;
		*dest++ = table[c >> 4];
		*dest++ = table[c & 0x0f];
	}
}

/*
 * Decodes hex string.
 *
 * Length of `dest[]` is implied to be calculated with calc_hex_decoded_str_length.
 *
 * Returns nonzero is successful.
 */
static int hex_decode_str_implied(const unsigned char *src, size_t len, unsigned char *dest)
{
	unsigned char low, high;

	if (len % 2) {
		low = *src++;

		if (low >= '0' && low <= '9') {
			low -= '0';
		} else if (low >= 'A' && low <= 'F') {
			low -= 'A' - 10;
		} else if (low >= 'a' && low <= 'f') {
			low -= 'a' - 10;
		} else {
			return 0;
		}

		*dest++ = low;
		--len;
	}

	for (; len > 0; len -= 2) {
		high = *src++;

		if (high >= '0' && high <= '9') {
			high -= '0';
		} else if (high >= 'A' && high <= 'F') {
			high -= 'A' - 10;
		} else if (high >= 'a' && high <= 'f') {
			high -= 'a' - 10;
		} else {
			return 0;
		}

		low = *src++;

		if (low >= '0' && low <= '9') {
			low -= '0';
		} else if (low >= 'A' && low <= 'F') {
			low -= 'A' - 10;
		} else if (low >= 'a' && low <= 'f') {
			low -= 'a' - 10;
		} else {
			return 0;
		}

		*dest++ = high << 4 | low;
	}

	return -1;
}

#if 0
/*
 * Calculates length of string that would store decoded hex.
 */
static size_t calc_hex_decoded_str_length(size_t hex_encoded_length)
{
	if (hex_encoded_length == 0)
		return 0;

	if (hex_encoded_length % 2)
		++hex_encoded_length;

	return hex_encoded_length / 2;
}
#endif

#endif
