# zig-base64

A base64 encoder/decoder in Zig.

## Background

The original version came from a Zig programming book and used an OOP-style approach (struct with `init()` and methods). I've kept that version in `reference/oop.zig` for comparison.

I refactored it to be more idiomatic Zig:

- Plain functions instead of a struct with methods. I find this easier to test and follow
- You pass in an allocator, so you control the memory.
- The decoder uses a lookup table built at compile time. Instead of searching "is this character in A-Z? a-z? 0-9?", it just looks up the answer directly. The table is baked into the binary so there's zero cost at runtime. Previously it looped through the alphabet for each character (up to 64 comparisons). Now it's a single lookup.

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
