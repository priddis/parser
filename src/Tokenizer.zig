const std = @import("std");
const StringTable = @import("StringTable.zig");
const StringHandle = StringTable.StringHandle;

const State = enum {
    start,
    numeric,
    identifier,
    operator,
};

const Token = struct {
    str: StringHandle,
    type: TokenType,
    offset: usize,
    length: usize,
};

pub fn tokenize(text: []const u8, string_table: *StringTable, gpa: std.mem.Allocator) !std.ArrayListUnmanaged(Token) {
    var i: usize = 0;
    var tokens: std.ArrayListUnmanaged(Token) = .empty;
    var next_token: Token = undefined;
    tokenize_loop: switch (State.start) {
        .start => switch (text[i]) {
            //Single char tokens
            '(', ')', '{', '}', '[', ']', ';', ',', '"', '\'', '=' => |c| {
                const str = try string_table.put(text[i .. i + 1]);
                try tokens.append(gpa, .{
                    .str = str,
                    .offset = i,
                    .length = 1,
                    .type = Constants.get(&.{c}).?,
                });
                i += 1;
                continue :tokenize_loop .start;
            },
            'a'...'z', 'A'...'Z' => {
                next_token = .{ .offset = i, .length = undefined, .type = .identifier, .str = undefined };
                continue :tokenize_loop .identifier;
            },
            '0'...'9' => {
                next_token = .{ .offset = i, .length = undefined, .type = .number, .str = undefined };
                continue :tokenize_loop .numeric;
            },
            ' ', '\t', '\n' => {
                i += 1;
                continue :tokenize_loop .start;
            },
            '+', '*', '/', '-' => |c| {
                next_token.type = Constants.get(&.{c}).?;
                const token_str = text[next_token.offset .. i + 1];
                const handle = try string_table.put(token_str);
                next_token.str = handle;
                next_token.length = i - next_token.offset;
                try tokens.append(gpa, next_token);
                i += 1;
                continue :tokenize_loop .start;
            },
            0 => break :tokenize_loop,
            else => std.debug.panic("Unknown token '{c}'", .{text[i]}),
        },
        .numeric => switch (text[i]) {
            '0'...'9' => {
                i += 1;
                continue :tokenize_loop .numeric;
            },

            //Token end states
            'l', 'L' => |c| {
                next_token.type = Constants.get(&.{c}) orelse .number;
                const token_str = text[next_token.offset .. i + 1];
                const handle = try string_table.put(token_str);
                next_token.str = handle;
                next_token.length = i - next_token.offset;
                try tokens.append(gpa, next_token);
                i += 1;
                continue :tokenize_loop .start;
            },
            0 => {
                next_token.type = .number;
                const token_str = text[next_token.offset..i];
                const handle = try string_table.put(token_str);
                next_token.str = handle;
                next_token.length = i - next_token.offset;
                try tokens.append(gpa, next_token);
                break :tokenize_loop;
            },
            else => {
                next_token.type = .number;
                const token_str = text[next_token.offset..i];
                const handle = try string_table.put(token_str);
                next_token.str = handle;
                next_token.length = i - next_token.offset;
                try tokens.append(gpa, next_token);
                continue :tokenize_loop .start;
            },
        },
        .identifier => switch (text[i]) {
            'a'...'z', 'A'...'Z', '0'...'9' => {
                i += 1;
                continue :tokenize_loop .identifier;
            },
            0 => {
                std.debug.print("|end token {s} \n", .{text[i .. i + 1]});
                const token_str = text[next_token.offset..i];
                next_token.type = Constants.get(token_str) orelse .identifier;
                const handle = try string_table.put(token_str);
                next_token.str = handle;
                next_token.length = i - next_token.offset;
                try tokens.append(gpa, next_token);
                break :tokenize_loop;
            },
            else => {
                const token_str = text[next_token.offset..i];
                next_token.type = Constants.get(token_str) orelse .identifier;
                const handle = try string_table.put(token_str);
                next_token.str = handle;
                next_token.length = i - next_token.offset;
                try tokens.append(gpa, next_token);
                continue :tokenize_loop .start;
            },
        },
    }
    return tokens;
}

const TokenType = enum {
    identifier,
    annotation,
    number,
    number_double,
    number_long,

    //Keywords
    abstract_keyword,
    continue_keyword,
    for_keyword,
    new_keyword,
    switch_keyword,
    assert_keyword,
    default_keyword,
    goto_keyword,
    package_keyword,
    synchronized_keyword,
    boolean_keyword,
    do_keyword,
    if_keyword,
    private_keyword,
    this_keyword,
    break_keyword,
    double_keyword,
    implements_keyword,
    protected_keyword,
    throw_keyword,
    byte_keyword,
    else_keyword,
    import_keyword,
    public_keyword,
    throws_keyword,
    case_keyword,
    enum_keyword,
    instanceof_keyword,
    return_keyword,
    transient_keyword,
    catch_keyword,
    extends_keyword,
    int_keyword,
    short_keyword,
    try_keyword,
    char_keyword,
    final_keyword,
    interface_keyword,
    static_keyword,
    void_keyword,
    class_keyword,
    finally_keyword,
    long_keyword,
    strictfp_keyword,
    volatile_keyword,
    const_keyword,
    float_keyword,
    native_keyword,
    super_keyword,
    while_keyword,
    var_keyword,

    //Symbols
    lparen,
    rparen,
    lcurly,
    rcurly,
    lbracket,
    rbracket,
    dot,
    singlequote,
    doublequote,
    bang,
    star,
    slash,
    slashslash,
    percent,
    plus,
    minus,

    greaterthan,
    greaterthanorequal,
    lessthan,
    lessthanorequal,

    equal,
    equalequal,
    notequal,
    ampersand,
    ampersandampersand,
    pipe,
    pipepipe,

    semicolon,
};
const Modifiers = std.StaticStringMap(TokenType).initComptime(.{
    .{ "l", .number_long },
    .{ "L", .number_long },
});

const Constants = std.StaticStringMap(TokenType).initComptime(.{
    .{ "(", .lparen },
    .{ ")", .rparen },
    .{ "{", .lcurly },
    .{ "}", .rcurly },
    .{ ";", .semicolon },
    .{ ".", .dot },
    .{ ";", .semicolon },

    .{ "abstract", .abstract_keyword },
    .{ "continue", .continue_keyword },
    .{ "for", .for_keyword },
    .{ "new", .new_keyword },
    .{ "switch", .switch_keyword },
    .{ "assert", .assert_keyword },
    .{ "default", .default_keyword },
    .{ "goto", .goto_keyword },
    .{ "package", .package_keyword },
    .{ "synchronized", .synchronized_keyword },
    .{ "boolean", .boolean_keyword },
    .{ "do", .do_keyword },
    .{ "if", .if_keyword },
    .{ "private", .private_keyword },
    .{ "this", .this_keyword },
    .{ "break", .break_keyword },
    .{ "double", .double_keyword },
    .{ "implements", .implements_keyword },
    .{ "protected", .protected_keyword },
    .{ "throw", .throw_keyword },
    .{ "byte", .byte_keyword },
    .{ "else", .else_keyword },
    .{ "import", .import_keyword },
    .{ "public", .public_keyword },
    .{ "throws", .throws_keyword },
    .{ "case", .case_keyword },
    .{ "enum", .enum_keyword },
    .{ "instanceof", .instanceof_keyword },
    .{ "return", .return_keyword },
    .{ "transient", .transient_keyword },
    .{ "catch", .catch_keyword },
    .{ "extends", .extends_keyword },
    .{ "int", .int_keyword },
    .{ "short", .short_keyword },
    .{ "try", .try_keyword },
    .{ "char", .char_keyword },
    .{ "final", .final_keyword },
    .{ "interface", .interface_keyword },
    .{ "static", .static_keyword },
    .{ "void", .void_keyword },
    .{ "class", .class_keyword },
    .{ "finally", .finally_keyword },
    .{ "long", .long_keyword },
    .{ "strictfp", .strictfp_keyword },
    .{ "volatile", .volatile_keyword },
    .{ "const", .const_keyword },
    .{ "float", .float_keyword },
    .{ "native", .native_keyword },
    .{ "super", .super_keyword },
    .{ "while", .while_keyword },
    .{ "var", .var_keyword },
});
test "keyword" {
    const extract = @import("test.zig").extract;
    var debug_alloc: std.heap.DebugAllocator(.{}) = .init;
    const gpa = debug_alloc.allocator();
    var string_table = StringTable.init(gpa);

    const code = "int;\x00";
    const expected = [_]TokenType{
        .int_keyword,
        .semicolon,
    };

    const tokens = try tokenize(code, &string_table, gpa);
    const token_types = try extract(gpa, Token, tokens.items, "type");
    try std.testing.expectEqualSlices(TokenType, &expected, token_types);
}

test "basic addition" {
    const extract = @import("test.zig").extract;
    var debug_alloc: std.heap.DebugAllocator(.{}) = .init;
    const gpa = debug_alloc.allocator();
    var string_table = StringTable.init(gpa);

    const code =
        \\;int a = 3; long b = 0; return a + b;\x00
    ;
    const expected = [_]TokenType{
        .semicolon,
        .int_keyword,
        .identifier,
        .equal,
        .number,
        .semicolon,
        .long_keyword,
        .identifier,
        .equal,
        .identifier,
        .semicolon,
        .return_keyword,
        .identifier,
        .plus,
        .identifier,
        .semicolon,
    };

    const tokens = try tokenize(code, &string_table, gpa);
    const token_types = try extract(gpa, Token, tokens.items, "type");
    try std.testing.expectEqualSlices(TokenType, &expected, token_types);
}
