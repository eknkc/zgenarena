# zgenarena

[![zgenarena - Docs](https://img.shields.io/badge/zgenarena-Docs-2ea44f)](https://eknkc.github.io/zgenarena/)

`zgenarena` is a simple generational arena implementation.
It allows for creating, removing, and reusing elements in an arena.
It provides constant time insertion, lookup, and removal via indices that can be sized to fit the needs of the user.

## Installation

```sh
zig fetch --save https://github.com/eknkc/zgenarena/archive/refs/heads/master.tar.gz
```

Add the following to your `build.zig`:

```zig
const zgenarena = b.dependency("zgenarena", .{
    .target = target,
    .optimize = optimize,
});

exe.root_module.addImport("zgenarena", zgenarena.module("zgenarena"));
```

## Usage

```zig
const Arena = @import("zgenarena").Arena;

const arena = Arena(i32, u32, u32).init(std.testing.allocator);
defer arena.deinit();

const ix1 = try arena.create(42);
const ix2 = try arena.create(43);

try std.testing.expect(arena.getConst(ix1) == 42);
try std.testing.expect(arena.getConst(ix2) == 43);
```

## License

MIT
