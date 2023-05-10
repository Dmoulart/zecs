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

pub fn ComponentStorage(comptime component: anytype) type {
    const ComponentsSchemaFields = std.meta.fields(component.Schema);
    // _ = ComponentsSchemaFields;

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
                .default_value = &field.default_value,
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

        const ComponentMultiArrayList = std.MultiArrayList(component.Schema);

        pub const Field = std.meta.FieldEnum(component.Schema);

        const fields = std.meta.fields(component.Schema);

        data: ComponentMultiArrayList = ComponentMultiArrayList{},

        cached_slice: ComponentMultiArrayList.Slice = undefined,

        cached_items: SchemaItems = undefined,

        pub fn resize(self: *Self, gpa: std.mem.Allocator, capacity: u32) !void {
            _ = try self.data.ensureTotalCapacity(gpa, capacity);
            _ = try self.data.resize(gpa, capacity);

            // Cache fields pointers
            self.cached_slice = self.data.slice();
            inline for (fields) |field_info, i| {
                @field(self.cached_items, field_info.name) = self.cached_slice.items(@intToEnum(Field, i));
            }
        }

        // /// Overwrite one array element with new data.
        // pub fn set(self: *Self, index: usize, elem: S) void {
        //     const slices = self.slice();
        //     inline for (fields) |field_info, i| {
        //         slices.items(@intToEnum(Field, i))[index] = @field(elem, field_info.name);
        //     }
        // }

        // /// Obtain all the data for one array element.
        // pub fn get(self: Self, index: usize) S {
        //     const slices = self.slice();
        //     var result: S = undefined;
        //     inline for (fields) |field_info, i| {
        //         @field(result, field_info.name) = slices.items(@intToEnum(Field, i))[index];
        //     }
        //     return result;
        // }

        pub fn get(self: *Self, entity: Entity) Schema {
            var result: Schema = undefined;
            inline for (fields) |field_info| {
                // @field(result, field_info.name) = self.cached_slice.items(@intToEnum(Field, i))[entity];
                @field(result, field_info.name) = @field(self.cached_items, field_info.name)[entity];
            }
            return result;
            // return self.data.get(entity);
        }

        pub fn set(self: *Self, entity: Entity, data: Schema) void {
            inline for (fields) |field_info, i| {
                self.cached_slice.items(@intToEnum(Field, i))[entity] = @field(data, field_info.name);
            }

            // self.data.set(entity, data);
        }

        pub fn deinit(self: *Self, gpa: std.mem.Allocator) void {
            self.data.deinit(gpa);
        }

        // fn FieldType(comptime field: Field) type {
        //     return std.meta.fieldInfo(component.Schema, field).field_type;
        // }

        // fn FieldsTypesSlices(comptime field: Field) type {
        //     inline for (fields) |field_info, i| {

        //     }
        //     return meta.fieldInfo(S, field).field_type;
        // }
    };
}
