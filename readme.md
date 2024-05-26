# zgenarena

`zgenarena` is a simple generational arena implementation.
It allows for creating, removing, and reusing elements in an arena.
It provides constant time insertion, lookup, and removal via indices that can be sized to fit the needs of the user.

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
