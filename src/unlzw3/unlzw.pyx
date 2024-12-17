from __future__ import annotations
# distutils: language=c
# cython: boundscheck=False, wraparound=False, nonecheck=False, cdivision=True

from libc.stdlib cimport malloc, free
from pathlib import Path

__version__ = "0.2.2"

def unlzw_fast(inp: Path | bytes) -> bytes:
    """
    Decompress Unix compress .Z files using LZW compression.
    Adapted for Cython from Python implementation.
    """
    cdef unsigned char *ba_in
    cdef unsigned int inlen, i
    cdef unsigned short *prefix
    cdef unsigned short *suffix
    cdef unsigned int bits, mask, max_, flags, end, rem
    cdef unsigned int buf, left, prev, final, code, temp, mark, nxt
    cdef unsigned int *stack
    cdef unsigned int stack_ptr = 0
    cdef bytearray output
    cdef unsigned int output_len = 0

    # Input handling
    if isinstance(inp, Path):
        ba_temp = bytearray(inp.read_bytes())

    else:
        ba_temp = bytearray(inp)

    try:
        ba_in = <unsigned char *> ba_temp
    except ValueError:
        raise TypeError("Unable to convert input data to bytearray")
    
    inlen = len(ba_temp)

    if inlen < 3:
        raise ValueError("Invalid Input: Length of input too short for processing")
    
    if ba_in[0] != 0x1F or ba_in[1] != 0x9D:
        raise ValueError("Invalid Header Flags Byte: Incorrect magic bytes")
    
    flags = ba_in[2]
    if flags & 0x60:
        raise ValueError("Invalid Header Flags Byte: Flag byte contains invalid data")

    max_ = flags & 0x1F
    if max_ < 9 or max_ > 16:
        raise ValueError("Invalid Header Flags Byte: Max code size bits out of range")

    if max_ == 9:
        max_ = 10
    
    flags &= 0x80
    bits = 9
    mask = 0x1FF
    end = 256 if flags else 255

    if inlen == 3:
        return b""
    if inlen == 4:
        raise ValueError("Invalid Data: Stream ended in the middle of a code")
    
    # Allocate memory
    prefix = <unsigned short *> malloc(65536 * sizeof(unsigned short))
    suffix = <unsigned short *> malloc(65536 * sizeof(unsigned short))
    stack = <unsigned int *> malloc(65536 * sizeof(unsigned int))
    if not prefix or not suffix or not stack:
        raise MemoryError("Failed to allocate memory")
    
    try:
        # Setup initial state
        buf = ba_in[3] | (ba_in[4] << 8)
        prev = buf & mask
        buf >>= bits
        left = 16 - bits
        final = prev
        if prev > 255:
            raise ValueError("Invalid Data: First code must be a literal")
        
        output = bytearray()
        output.append(final)
        output_len += 1

        mark = 3
        nxt = 5

        while nxt < inlen:
            if end >= mask and bits < max_:
                rem = (nxt - mark) % bits
                if rem:
                    rem = bits - rem
                    if rem >= inlen - nxt:
                        break
                    nxt += rem
                
                buf = 0
                left = 0
                mark = nxt
                bits += 1
                mask = (mask << 1) | 1
            
            while left < bits:
                if nxt == inlen:
                    raise ValueError("Invalid Data: Stream ended in the middle of a code")
                buf |= ba_in[nxt] << left
                nxt += 1
                left += 8
            
            code = buf & mask
            buf >>= bits
            left -= bits

            if code == 256 and flags:
                rem = (nxt - mark) % bits
                if rem:
                    rem = bits - rem
                    if rem > inlen - nxt:
                        break
                    nxt += rem
                buf = 0
                left = 0
                mark = nxt
                bits = 9
                mask = 0x1FF
                end = 255
                continue
            
            temp = code
            stack_ptr = 0
            if code > end:
                if code != end + 1 or prev > end:
                    raise ValueError("Invalid Data: Invalid code detected")
                stack[stack_ptr] = final
                stack_ptr += 1
                code = prev
            
            while code >= 256:
                stack[stack_ptr] = suffix[code]
                stack_ptr += 1
                code = prefix[code]
            
            final = code
            stack[stack_ptr] = code
            stack_ptr += 1

            if end < mask:
                end += 1
                prefix[end] = prev
                suffix[end] = final
            
            prev = temp

            for i in range(stack_ptr - 1, -1, -1):
                output.append(stack[i])
                output_len += 1
        
        return bytes(output)
    
    finally:
        free(prefix)
        free(suffix)
        free(stack)

