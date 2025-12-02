#ifndef DEBUG_FUNCS_H
#define DEBUG_FUNCS_H

#include "utils.h"

static void print_in_hex(const char *format, const unsigned char *str, size_t len)
{
	unsigned char buffer[len * 2 + 1];
	hex_encode_str_implied(str, len, buffer);
	buffer[len * 2] = '\0';
	_DEBUG(format, buffer);
}

static void dump_state_32(XXH32_state_t *state)
{
	_DEBUG("state->total_len: %u\n", state->total_len_32);
	_DEBUG("state->large_len: %u\n", state->large_len);
	_DEBUG("state->v1: %u\n", state->v1);
	_DEBUG("state->v2: %u\n", state->v2);
	_DEBUG("state->v3: %u\n", state->v3);
	_DEBUG("state->v4: %u\n", state->v4);
	_DEBUG("state->mem32[0]: %u\n", state->mem32[0]);
	_DEBUG("state->mem32[1]: %u\n", state->mem32[1]);
	_DEBUG("state->mem32[2]: %u\n", state->mem32[2]);
	_DEBUG("state->mem32[3]: %u\n", state->mem32[3]);
	_DEBUG("state->memsize: %u\n", state->memsize);
	_DEBUG("state->reserved: %u\n", state->reserved);
}

static void dump_state_64(XXH64_state_t *state)
{
	_DEBUG("state->total_len: %llu\n", state->total_len);
	_DEBUG("state->v1: %llu\n", state->v1);
	_DEBUG("state->v2: %llu\n", state->v2);
	_DEBUG("state->v3: %llu\n", state->v3);
	_DEBUG("state->v4: %llu\n", state->v4);
	_DEBUG("state->mem64[0]: %llu\n", state->mem64[0]);
	_DEBUG("state->mem64[1]: %llu\n", state->mem64[1]);
	_DEBUG("state->mem64[2]: %llu\n", state->mem64[2]);
	_DEBUG("state->mem64[3]: %llu\n", state->mem64[3]);
	_DEBUG("state->memsize: %u\n", state->memsize);
	_DEBUG("state->reserved[0]: %u\n", state->reserved[0]);
	_DEBUG("state->reserved[1]: %u\n", state->reserved[1]);
}

#endif
