const std = @import("std");
const print = @import("std").debug.print;
const Archetype = @import("./archetype.zig").Archetype;
const Context = @import("./context.zig").Context;
const Entity = @import("./entity-storage.zig").Entity;
const ComponentId = @import("./component.zig").ComponentId;
const FixedSizeBitset = @import("./fixed-size-bitset.zig").FixedSizeBitset;
const String = @import("./lib/string/string.zig").String;
const QueryCallback = @import("./system.zig").QueryCallback;

pub const MAX_COMPONENTS_PER_QUERY_MATCHER = 100;

pub const QueryMatcherType = enum {
    any,
    all,
    not,
    none,
};

pub const QueryHash = String;

pub fn Query(comptime ContextType: anytype) type {
    return struct {
        const Self = @This();

        archetypes: std.ArrayList(*Archetype),

        matchers: std.ArrayList(QueryMatcher),

        allocator: std.mem.Allocator,

        context: *ContextType,

        on_enter: ?QueryCallback(ContextType),

        pub fn init(matchers: std.ArrayList(QueryMatcher), allocator: std.mem.Allocator) Self {
            return Self{
                .allocator = allocator,
                .matchers = matchers,
                .archetypes = std.ArrayList(*Archetype).init(allocator),
                .context = undefined,
                .on_enter = null,
            };
        }

        pub fn iterator(self: *Self) QueryIterator {
            return QueryIterator{
                .archetypes = &self.archetypes,
            };
        }

        pub fn deinit(self: *Self) void {
            for (self.matchers.items) |*matcher| {
                matcher.deinit();
            }
        }

        pub fn each(self: *Self, function: *const fn (*ContextType, Entity) void) void {
            for (self.archetypes.items) |archetype| {
                for (archetype.entities.toSlice()) |e| {
                    function(self.context, e);
                }
            }
        }

        pub fn maybeRegisterArchetype(self: *Self, archetype: *Archetype) void {
            for (self.matchers.items) |*matcher| {
                const mask = &matcher.mask;

                if (!matcher.match(mask, &archetype.mask))
                    return;
            }

            _ = self.archetypes.append(archetype) catch null;

            if (self.on_enter) |on_enter| {
                for (archetype.entities.toSlice()) |entity| {
                    on_enter(self.context, entity);
                }
            }
        }

        pub fn contains(self: *Self, entity: Entity) bool {
            for (self.archetypes.items) |arch| {
                if (arch.entities.has(entity)) return true;
            }
            return false;
        }

        fn execute(self: *Self, context: anytype) void {
            for (context.archetypes.all.items) |*archetype| {
                self.maybeRegisterArchetype(archetype);
            }
        }
    };
}

pub const QueryMatcher = struct {
    const Self = @This();

    op_type: QueryMatcherType,

    mask: FixedSizeBitset,

    pub fn deinit(self: *Self) void {
        self.mask.deinit();
    }
    pub fn match(self: *Self, bitset: *FixedSizeBitset, other: *FixedSizeBitset) bool {
        return switch (self.op_type) {
            .any => bitset.intersects(other),
            .all => other.contains(bitset),
            .not => !bitset.intersects(other),
            .none => !other.contains(bitset),
        };
    }
};

pub fn QueryBuilder(comptime ContextType: anytype) type {
    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,

        prepared_on_enter: ?QueryCallback(ContextType),
        prepared_on_exit: ?QueryCallback(ContextType),

        prepared_query_matchers: std.ArrayList(QueryMatcher),

        // Todo: make comptime string ds ?
        prepared_query_hash: String,

        queries: std.hash_map.StringHashMap(Query(ContextType)),

        context: *ContextType,

        pub fn init(allocator: std.mem.Allocator) !Self {
            var prepared_query_hash = String.init(allocator);
            prepared_query_hash.allocate(100) catch unreachable;
            return Self{
                .allocator = allocator,
                .prepared_query_matchers = std.ArrayList(QueryMatcher).init(allocator),
                .queries = std.hash_map.StringHashMap(Query(ContextType)).init(allocator),
                .context = undefined,
                .prepared_query_hash = prepared_query_hash,
                .prepared_on_enter = null,
                .prepared_on_exit = null,
            };
        }

        pub fn deinit(self: *Self) void {
            self.prepared_query_matchers.deinit();
            var queries = self.queries.valueIterator();

            while (queries.next()) |query| {
                // The archetypes and matchers need to be freed from query builder I don't know why.
                query.archetypes.deinit();
                query.matchers.deinit();

                query.deinit();
            }

            self.queries.deinit();
            self.prepared_query_hash.deinit();
        }
        //
        // Select the archetypes which posess at least one of the given components.
        //
        pub fn any(self: *Self, comptime componentsTypes: anytype) *Self {
            self.createMatcher(componentsTypes, .any);
            return self;
        }
        //
        // Select the archetypes which posess the entire set of given component.
        //
        pub fn all(self: *Self, comptime componentsTypes: anytype) *Self {
            self.createMatcher(componentsTypes, .all);
            return self;
        }
        //
        // Select the archetypes which does not posess at least one of the given components.
        //
        pub fn not(self: *Self, comptime componentsTypes: anytype) *Self {
            self.createMatcher(componentsTypes, .not);
            return self;
        }
        //
        // Select the archetypes which does not posess the entire set of the given components.
        //
        pub fn none(self: *Self, comptime componentsTypes: anytype) *Self {
            self.createMatcher(componentsTypes, .none);
            return self;
        }

        pub fn onEnter(self: *Self, function: QueryCallback(ContextType)) *Self {
            self.prepared_on_enter = function;
            return self;
        }

        pub fn execute(self: *Self) *Query(ContextType) {
            const hash = self.prepared_query_hash.str();

            var query = self.queries.getOrPut(hash) catch unreachable;

            if (query.found_existing) {
                self.clearPreparedQuery();
                return query.value_ptr;
            }

            var created_query = Query(ContextType).init(
                self.prepared_query_matchers.clone() catch unreachable,
                self.allocator,
            );

            created_query.context = self.context;

            if (self.prepared_on_enter) |callback| {
                created_query.on_enter = callback;
            }

            if (self.prepared_on_exit) |callback| {
                created_query.on_exit = callback;
            }

            created_query.execute(self.context);

            query.value_ptr.* = created_query;

            self.clearPreparedQuery();

            return query.value_ptr;
        }

        fn createMatcher(self: *Self, comptime componentsTypes: anytype, comptime matcher_type: QueryMatcherType) void {
            const components = comptime std.meta.fields(@TypeOf(componentsTypes));

            var mask = FixedSizeBitset.init(.{});

            var matcher_type_str = std.fmt.comptimePrint("{d}", .{@enumToInt(matcher_type)});

            self.prepared_query_hash.concat(matcher_type_str) catch unreachable;
            self.prepared_query_hash.concat(":") catch unreachable;

            inline for (components) |field| {
                const ComponentType = comptime @field(componentsTypes, field.name);
                const component = comptime ContextType.getComponentDefinition(ComponentType);
                mask.set(component.id);

                var component_id_str = std.fmt.comptimePrint("{d}", .{component.id});
                self.prepared_query_hash.concat(component_id_str) catch unreachable;
            }

            self.prepared_query_matchers.append(QueryMatcher{
                .op_type = matcher_type,
                .mask = mask,
            }) catch unreachable;
        }

        fn clearPreparedQuery(self: *Self) void {
            self.prepared_query_hash.clear();
            self.prepared_query_matchers.clearAndFree();
            self.prepared_on_enter = null;
            self.prepared_on_exit = null;
        }
    };
}

pub const QueryIterator = struct {
    const Self = @This();

    archetypes: *std.ArrayList(*Archetype),

    current_archetype_index: usize = 0,

    current_entity_index: usize = 0,

    // Slow iterator is slow. Maybe do something about it ? or delete it ?
    pub fn next(self: *Self) ?Entity {
        if (self.current_archetype_index < self.archetypes.items.len) {
            var archetype_entities = self.archetypes.items[self.current_archetype_index].entities;
            if (self.current_entity_index < archetype_entities.count) {
                self.current_entity_index += 1;
                return archetype_entities.values[self.current_entity_index - 1]; // entities start at 1
            } else {
                self.current_entity_index = 0;
                self.current_archetype_index += 1;
                return self.next();
            }
        } else {
            return null;
        }
    }

    pub fn count(self: *Self) u64 {
        var len: u64 = 0;
        for (self.archetypes.items) |arch| {
            len += arch.entities.count;
        }
        return len;
    }
};
