const std = @import("std");
const math = std.math;
const mem = std.mem;

const BASE64_TABLE = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
const ASCII_TABLE = build_ascii_table();
const DecodeError = error{ InvalidLength, InvalidCharacter, OutOfMemory };

fn build_ascii_table() [256]u8 {
    comptime var table: [256]u8 = .{255} ** 256;
    inline for (BASE64_TABLE, 0..) |char, i| {
        table[char] = @intCast(i);
    }

    // Handle the null value
    table['='] = 64;

    return table;
}

fn calc_encode_length(input: []const u8) usize {
    if (input.len < 3) {
        return 4;
    }
    return (math.divCeil(usize, input.len, 3) catch unreachable) * 4;
}

fn calc_decode_length(input: []const u8) !usize {
    if (input.len < 3) return 3;

    const n_groups = input.len / 4;
    var result = n_groups * 3;
    if (input[input.len - 1] == '=') result -= 1;
    if (input[input.len - 2] == '=') result -= 1;

    return result;
}

pub fn encode(allocator: mem.Allocator, input: []const u8) ![]u8 {
    if (input.len == 0) {
        return allocator.alloc(u8, 0);
    }

    const n_out = calc_encode_length(input);
    var out = try allocator.alloc(u8, n_out);
    var buf = [3]u8{ 0, 0, 0 };
    var count: u8 = 0;
    var iout: u64 = 0;

    for (input) |byte| {
        buf[count] = byte;
        count += 1;

        if (count == 3) {
            out[iout] = BASE64_TABLE[(buf[0] >> 2)];
            out[iout + 1] = BASE64_TABLE[((buf[0] & 0x03) << 4) + (buf[1] >> 4)];
            out[iout + 2] = BASE64_TABLE[((buf[1] & 0x0f) << 2) + (buf[2] >> 6)];
            out[iout + 3] = BASE64_TABLE[buf[2] & 0x3f];
            iout += 4;
            count = 0;
        }
    }

    if (count == 1) {
        out[iout] = BASE64_TABLE[buf[0] >> 2];
        out[iout + 1] = BASE64_TABLE[(buf[0] & 0x03) << 4];
        out[iout + 2] = '=';
        out[iout + 3] = '=';
    }

    if (count == 2) {
        out[iout] = BASE64_TABLE[buf[0] >> 2];
        out[iout + 1] = BASE64_TABLE[((buf[0] & 0x03) << 4) + (buf[1] >> 4)];
        out[iout + 2] = BASE64_TABLE[(buf[1] & 0x0f) << 2];
        out[iout + 3] = '=';
    }

    return out;
}

pub fn decode(allocator: mem.Allocator, input: []const u8) DecodeError![]u8 {
    if (input.len == 0) {
        return allocator.alloc(u8, 0);
    }
    if (input.len % 4 != 0) {
        return DecodeError.InvalidLength;
    }
    const n_output = try calc_decode_length(input);
    var output = try allocator.alloc(u8, n_output);
    errdefer allocator.free(output);
    var count: u8 = 0;
    var iout: u64 = 0;
    var buf = [4]u8{ 0, 0, 0, 0 };

    for (0..input.len) |i| {
        const char_index = ASCII_TABLE[input[i]];
        if (char_index == 255) {
            return DecodeError.InvalidCharacter;
        }
        buf[count] = char_index;
        count += 1;
        if (count == 4) {
            output[iout] = (buf[0] << 2) + (buf[1] >> 4);
            if (buf[2] != 64) {
                output[iout + 1] = (buf[1] << 4) + (buf[2] >> 2);
            }
            if (buf[3] != 64) {
                output[iout + 2] = (buf[2] << 6) + buf[3];
            }
            iout += 3;
            count = 0;
        }
    }

    return output;
}

pub fn main() !void {
    var threaded: std.Io.Threaded = .init_single_threaded;
    const io = threaded.io();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    // Args
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("Usage: zig-base64 <encode|decode> [text]\n", .{});
        return;
    }

    const command = args[1];

    const input = if (args.len >= 3) args[2] else blk: {
        var stdin_buffer: [1024 * 1024]u8 = undefined;
        var stdin_reader = std.fs.File.stdin().reader(io, &stdin_buffer);
        const stdin = &stdin_reader.interface;
        const line = try stdin.takeDelimiterExclusive('\n');
        break :blk line;
    };

    if (mem.eql(u8, command, "encode")) {
        const result = try encode(allocator, input);
        defer allocator.free(result);
        try stdout.writeAll(result);
        try stdout.writeAll("\n");
        try stdout.flush();
    } else if (mem.eql(u8, command, "decode")) {
        const result = try decode(allocator, input);
        defer allocator.free(result);
        try stdout.writeAll(result);
        try stdout.writeAll("\n");
        try stdout.flush();
    } else {
        std.debug.print("Unknown command. Use 'encode' or 'decode'.\n", .{});
    }
}

test "encode and decode" {
    const text = "Testing some more stuff";
    const etext = "VGVzdGluZyBzb21lIG1vcmUgc3R1ZmY=";
    const allocator = std.testing.allocator;

    const encoded_text = try encode(allocator, text);
    defer allocator.free(encoded_text);

    const decoded_text = try decode(allocator, etext);
    defer allocator.free(decoded_text);

    try std.testing.expectEqualStrings(etext, encoded_text);
    try std.testing.expectEqualStrings(text, decoded_text);
}

test "gracefully handles an empty string" {
    const allocator = std.testing.allocator;

    const encoded_text = try encode(allocator, "");
    defer allocator.free(encoded_text);

    const decoded_text = try decode(allocator, "");
    defer allocator.free(decoded_text);

    try std.testing.expectEqual(@as(usize, 0), encoded_text.len);
    try std.testing.expectEqual(@as(usize, 0), decoded_text.len);
}

test "single byte encodes with double padding" {
    const allocator = std.testing.allocator;
    const result = try encode(allocator, "A");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("QQ==", result);
}

test "two bytes encode with single padding" {
    const allocator = std.testing.allocator;
    const result = try encode(allocator, "AB");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("QUI=", result);
}

test "three bytes encode with no padding" {
    const allocator = std.testing.allocator;
    const result = try encode(allocator, "ABC");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("QUJD", result);
}

test "roundtrip preserves data" {
    const allocator = std.testing.allocator;
    const original = "Hello, World!";

    const encoded = try encode(allocator, original);
    defer allocator.free(encoded);

    const decoded = try decode(allocator, encoded);
    defer allocator.free(decoded);

    try std.testing.expectEqualStrings(original, decoded);
}

test "decode rejects invalid length" {
    const allocator = std.testing.allocator;
    const result = decode(allocator, "ABC");
    try std.testing.expectError(error.InvalidLength, result);
}

test "decode rejects invalid characters" {
    const allocator = std.testing.allocator;
    const result = decode(allocator, "!!!!");
    try std.testing.expectError(error.InvalidCharacter, result);
}
