const std = @import("std");
const StringTable = @import("StringTable.zig");
const StringHandle = StringTable.StringHandle;
const Tokenizer = @import("Tokenizer.zig");
const Token = Tokenizer.Token;
const TokenStream = Tokenizer.TokenStream;
const ArrayList = std.mem.ArrayListUnmanaged;
const MultiArrayList = std.MultiArrayList;

const Parser = @This();
gpa: std.mem.Allocator,
tokens: TokenStream,
strings: *StringTable,
ast: Ast,

const Ast = struct {
    nodes: std.ArrayListUnmanaged(SyntaxNode),

    pub fn addNode(self: Ast, node: SyntaxNode) !void {
        try self.nodes.append(node);
    }

    const Index = enum(u32) { _ };

};

const SyntaxNode = struct {
    const Kind = enum(u32) { 
        PackageBegin, 
        PackageStr,
        ImportBegin,
        ImportStr,
        ClassDecl,
        ClassStart,
        ClassEnd,

        MethodDecl,
        MethodDefStart,
        MethodDefEnd,
        Error,
    };

    str: StringHandle,
    kind: Kind,
    offset: usize,
    childBegin: Ast.Index,
    childEnd: Ast.Index
};

pub fn parse(
    buf: []u8,
    string_table: *StringTable,
    gpa: std.mem.Allocator,
) !Ast {
    const stream = try Tokenizer.tokenize(buf, string_table, gpa);
    var parser: Parser = .{ .gpa = gpa, .strings = string_table, .tokens = stream, .ast = .{ .nodes = .empty } };
    try parser.parseRoot();
    return parser.ast;
}

const ClassModifiers = packed struct {
    access: enum(u2) {
        public,
        private,
        protected,
        default,
    },
    static: bool,
    final: bool,
    abstract: bool,
    synchronized: bool
};

fn parseRoot(self: *Parser) !void {
    while (self.tokens.next()) |t| {
        var classModifiers: ClassModifiers = .{ .access = .default, .static = false, .final = false, .synchronized = false, .abstract = false };
        switch (t.type) {
            .package_keyword => try self.parseNamespace(.PackageStr),
            .import_keyword => try self.parseNamespace(.ImportStr),
            .class_keyword => try self.parseClass(classModifiers),

            .public_keyword => {
                if (classModifiers.access != .default) try self.ast.addNode(.{ .kind = .Error, .str = t.str, .offset = t.offset});
                classModifiers.access = .public;
            },
            .protected_keyword => {
                if (classModifiers.access != .default) try self.ast.addNode(.{ .kind = .Error, .str = t.str, .offset = t.offset});
                classModifiers.access = .protected;
            },
            .private_keyword => {
                if (classModifiers.access != .default) try self.ast.addNode(.{ .kind = .Error, .str = t.str, .offset = t.offset});
                classModifiers.access = .private;
            },
            .static_keyword => classModifiers.static = true,
            .synchronized_keyword => classModifiers.synchronized = true,
            .abstract_keyword => classModifiers.abstract = true,
            .final_keyword => classModifiers.final = true,
            else => try self.ast.addNode(.{ .kind = .Error, .str = t.str, .offset = t.offset }),
        }
    }
}

fn parseNamespace(self: *Parser, comptime namespaceKind: SyntaxNode.Kind) !void {
    comptime std.debug.assert(namespaceKind == .PackageStr or namespaceKind == .ImportStr);
    const syntaxNodeKind = comptime if (namespaceKind == .PackageStr) .PackageBegin else .ImportBegin;
    try self.ast.addNode(.{ .kind = syntaxNodeKind, .str = self.strings.get("package").?, .offset = 0 });

    var t = self.tokens.next() orelse return;
    while (t.type == .identifier) {
        try self.ast.addNode(.{ .kind = namespaceKind, .str = t.str, .offset = t.offset });
        t = self.tokens.next() orelse return;
    }
    //Assert semicolon
}

fn parseClass(self: *Parser, mods: ClassModifiers) !void {
    _ = mods;
    const class_identifier = self.tokens.next() orelse return;
    try self.ast.addNode(.{ .kind = .ClassDecl, .str = class_identifier.str, .offset = class_identifier.offset });
    
    //TODO extends/implements 

    const t = self.tokens.next() orelse return;
    if (t.type != .lparen) {
        try self.ast.addNode(.{ .kind = .Error, .str = t.str, .offset = t.offset});
    }
    try self.ast.addNode(.{ .kind = .ClassStart, .str = class_identifier.str, .offset = t.offset});



}

fn parseMethod(self: *Parser) !void {
    const param_start = self.tokens.next() orelse {
        //try self.ast.addNode(.{ .kind = .Error, .str = 0, .offset = .offset });
        return;
    };
    if (param_start != .identifier) {
        try self.ast.addNode(.{ .kind = .Error, .str = 0, .offset = param_start.offset });
        return;
    }

    const t = self.tokens.next();
    while (t.kind == .identifier or t.kind == .final_keyword)  {
        try self.ast.addNode(.{.kind = .param_type, .str = t.str, .offset = t.offset});
        try self.ast.addNode(.{.kind = .param_identifer, .str = t.str, .offset = t.offset});
    }
}

const Class = enum(u32) {
    Unknown,
    Object,
    String,
    Class,
    Enum,
    Number,
    Process,
    byte,
    Byte,
    short,
    Short,
    int,
    Integer,
    long,
    Long,
    boolean,
    Boolean,
    char,
    Character,
    float,
    Float,
    double,
    Double,
    _,
};
