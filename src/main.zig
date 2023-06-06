const std = @import("std");
const mem = std.mem;
const c = @cImport({
    @cInclude("hidapi/hidapi.h");
});

pub fn main() !void {
    const init_ret = c.hid_init();
    defer _ = c.hid_exit();
    std.debug.print("hid_init: {d}\n", .{ init_ret });

    const device_list = c.hid_enumerate(0x0801, 0x0003);
    defer c.hid_free_enumeration(device_list);

    if (device_list == null) {
        std.debug.print("No devices\n", .{});
        return;
    }
    std.debug.print("Yes devices\n", .{});
    var device: ?*c.hid_device_info = device_list;
    var serial_number: ?[*c]c.wchar_t = null;

    while (device) |dev| : (device = dev.next) {
        std.debug.print("Device: {d}\n", .{ dev.interface_number });
        std.debug.print("  Path: {s}\n", .{ dev.path });
        std.debug.print("  Product ID: {x}\n", .{ dev.product_id });
        if (dev.product_string) |str| {
            std.debug.print("  Product String: ", .{});
            for (mem.span(str)) |char| {
                std.debug.print("{u}", .{ @intCast(u21, char) });
            }
            std.debug.print("\n", .{});
        }
        if (dev.serial_number) |srl| {
            serial_number = srl;
            std.debug.print("  Serial Number: ", .{});
            for (mem.span(srl)) |char| {
                std.debug.print("{u}", .{ @intCast(u21, char) });
            }
            std.debug.print("\n", .{});
        }
        std.debug.print("  Vendor ID: {x}\n", .{ dev.vendor_id });
        if (dev.manufacturer_string) |str| {
            std.debug.print("  Manufacturer String: ", .{});
            for (mem.span(str)) |char| {
                std.debug.print("{u}", .{ @intCast(u21, char) });
            }
            std.debug.print("\n", .{});
        }
    }

    std.debug.print("\nOpening ", .{});
    if (serial_number) |str| {
        for (mem.span(str)) |char| {
            std.debug.print("{u}", .{ @intCast(u21, char) });
        }
        std.debug.print("\n", .{});
    } else {
        std.debug.print("unknown serial number\n", .{});
    }
    const hid = c.hid_open(0x0801, 0x0003, serial_number orelse null);
    defer c.hid_close(hid);

    if (hid == null) {
        std.debug.print("Unable to open\n", .{});
        return;
    }
    std.debug.print("HID: {any}\n", .{ hid });

    std.debug.print("Initializing\n", .{});
    const initializer = "\x00\x1ba";
    const read = "\x00\x1br";
    const initializer_ret = c.hid_write(hid, initializer, initializer.len);
    std.debug.print("initializer ret: {d}\n", .{ initializer_ret });
    const read_ret = c.hid_write(hid, read, read.len);

    std.debug.print("read ret: {d}\n", .{ read_ret });

    var buf: [63]u8 = undefined;
    while (true) {
        buf[0] = 0;
        const n = c.hid_read(hid, &buf, buf.len);
        if (n < 0) {
            std.debug.print("error\n", .{});
            const err = c.hid_error(hid);
            const err_msg = mem.span(err);
            for (err_msg) |char| {
                std.debug.print("{u}", .{ @intCast(u21, char) });
            }
            std.debug.print("\n", .{});
            return;
        }
        std.debug.print("In: {d}\n", .{ buf[0..@intCast(usize, n)] });
    }
}
