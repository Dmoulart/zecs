const std = @import("std");
const Entity = @import("entity-storage.zig").Entity;
var global_component_counter: u64 = 1;

pub const ComponentId = u64;

pub fn Component(comptime component_name: []const u8, comptime T: type) type {
    return struct {
        const Self = @This();

        pub const name = component_name;

        pub const Schema = T;

        id: ComponentId,

        storage: ComponentStorage(Self) = ComponentStorage(Self){},

        ready: bool = false,

        pub fn ensureTotalCapacity(self: *Self, gpa: std.mem.Allocator, capacity: usize) !void {
            try self.storage.ensureTotalCapacity(gpa, capacity);
        }

        pub fn deinit(self: *Self, gpa: std.mem.Allocator) void {
            self.storage.deinit(gpa);
        }
    };
}

// Schema type with pointers as props
pub fn Packed(comptime Schema: anytype) type {
    const SchemaFields = std.meta.fields(Schema);
    const SchemaWithPropsPointers = comptime blk: {
        var fields: []const std.builtin.Type.StructField = &[0]std.builtin.Type.StructField{};
        var Field = std.meta.FieldEnum(Schema);

        inline for (SchemaFields) |field, i| {
            const FieldType = std.meta.fieldInfo(Schema, @intToEnum(Field, i)).field_type;

            fields = fields ++ [_]std.builtin.Type.StructField{.{
                .name = field.name[0..],
                .field_type = *FieldType,
                .is_comptime = false,
                .alignment = @alignOf(*FieldType),
                .default_value = field.default_value,
            }};
        }
        break :blk @Type(.{
            .Struct = .{
                .layout = .Auto,
                .is_tuple = false,
                .fields = fields,
                .decls = &[_]std.builtin.Type.Declaration{},
            },
        });
    };
    return SchemaWithPropsPointers;
}
pub fn ComponentStorage(comptime component: anytype) type {
    const ComponentsSchemaFields = std.meta.fields(component.Schema);

    const SchemaItems = comptime blk: {
        var fields: []const std.builtin.Type.StructField = &[0]std.builtin.Type.StructField{};
        var Field = std.meta.FieldEnum(component.Schema);

        inline for (ComponentsSchemaFields) |field, i| {
            // const componentsSchemaField = @field(component.Schema, field.name);
            const FieldType = std.meta.fieldInfo(component.Schema, @intToEnum(Field, i)).field_type;
            fields = fields ++ [_]std.builtin.Type.StructField{.{
                .name = field.name[0..],
                .field_type = []FieldType,
                .is_comptime = false,
                .alignment = @alignOf(FieldType),
                .default_value = field.default_value,
            }};
        }
        break :blk @Type(.{
            .Struct = .{
                .layout = .Auto,
                .is_tuple = false,
                .fields = fields,
                .decls = &[_]std.builtin.Type.Declaration{},
            },
        });
    };

    return struct {
        const Self = @This();

        const Schema = component.Schema;

        // used to get type infos more easily.. remove when better at zig meta programming
        pub const schema_instance: component.Schema = undefined;

        const ComponentMultiArrayList = std.MultiArrayList(component.Schema);

        pub const Field = std.meta.FieldEnum(component.Schema);

        const fields = std.meta.fields(component.Schema);

        data: ComponentMultiArrayList = ComponentMultiArrayList{},

        cached_slice: ComponentMultiArrayList.Slice = undefined,

        cached_items: SchemaItems = undefined,

        read_data_cache: Schema = undefined,

        pub fn setup(self: *Self, gpa: std.mem.Allocator, capacity: u32) !void {
            _ = try self.data.ensureTotalCapacity(gpa, capacity + 1);
            _ = try self.data.resize(gpa, capacity + 1);

            // Cache fields pointers
            self.cached_slice = self.data.slice();
            inline for (fields) |field_info, i| {
                @field(self.cached_items, field_info.name) = self.cached_slice.items(@intToEnum(Field, i));
            }
        }

        pub fn deinit(self: *Self, gpa: std.mem.Allocator) void {
            self.data.deinit(gpa);
        }

        pub fn copy(self: *Self, entity: Entity) Schema {
            var result: Schema = undefined;
            inline for (fields) |field_info| {
                @field(result, field_info.name) = @field(self.cached_items, field_info.name)[entity];
            }

            return result;
        }

        // this is a copy op not a read op
        pub fn read(self: *Self, entity: Entity) Schema {
            var result: Schema = undefined;
            inline for (fields) |field_info| {
                @field(result, field_info.name) = @field(self.cached_items, field_info.name)[entity];
            }

            return result;
        }

        // pub fn readCached(self: *Self, entity: Entity) *const Schema {
        //     inline for (fields) |field_info| {
        //         @field(self.read_data_cache, field_info.name) = @field(self.cached_items, field_info.name)[entity];
        //     }

        //     return &self.read_data_cache;
        // }

        pub fn pack(self: *Self, entity: Entity) Packed(Schema) {
            var result: Packed(Schema) = undefined;
            inline for (fields) |field_info| {
                @field(result, field_info.name) = &@field(self.cached_items, field_info.name)[entity];
            }
            return result;
        }

        pub fn get(self: *Self, entity: Entity, comptime prop: anytype) *@TypeOf(@field(schema_instance, prop)) {
            return &@field(self.cached_items, prop)[entity];
        }

        pub fn write(self: *Self, entity: Entity, data: Schema) void {
            inline for (fields) |field_info| {
                @field(self.cached_items, field_info.name)[entity] = @field(data, field_info.name);
            }
        }

        pub fn set(self: *Self, entity: Entity, comptime prop: std.meta.FieldEnum(Schema), data: anytype) void {
            @field(self.cached_items, @tagName(prop))[entity] = data;
        }
    };
}
