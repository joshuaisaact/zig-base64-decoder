# zig-base64

A base64 encoder/decoder in Zig.

## Background

The original version came from a Zig programming book and used an OOP-style approach (struct with `init()` and methods). I refactored it to be more idiomatic Zig:

- Module-level constants instead of struct fields
- Comptime-generated lookup table for O(1) decoding
- Pure functions with explicit allocator parameters
- Inline error types

## Usage

```bash
# Build
zig build

# Encode
zig build run -- encode "Hello, World!"
# Output: SGVsbG8sIFdvcmxkIQ==

# Decode
zig build run -- decode "SGVsbG8sIFdvcmxkIQ=="
# Output: Hello, World!

# Pipe from stdin
echo "Hello" | zig build run -- encode
# Output: SGVsbG8=
```

## Tests

```bash
zig build test
```
