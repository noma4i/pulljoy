import Foundation

/// An arbitrary JSON value, for the few places — GraphQL variables, JSON-RPC —
/// where the shape is not known to the type system ahead of time.
///
/// A number written without a fraction or exponent that fits in 64 bits is
/// kept as `.integer`, so it survives a round trip exactly — a JSON-RPC id
/// above 2^53 must come back as sent, not rounded to the nearest `Double`.
/// The two number cases compare equal when they hold the same value.
public enum JSONValue: Hashable, Sendable, Codable {
    case null
    case bool(Bool)
    case integer(Int64)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    public init(from decoder: any Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() {
            self = .null
        } else if let b = try? c.decode(Bool.self) {
            self = .bool(b)
        } else if let i = try? c.decode(Int64.self) {
            self = .integer(i)
        } else if let n = try? c.decode(Double.self) {
            self = .number(n)
        } else if let s = try? c.decode(String.self) {
            self = .string(s)
        } else if let a = try? c.decode([JSONValue].self) {
            self = .array(a)
        } else {
            self = .object(try c.decode([String: JSONValue].self))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let b): try c.encode(b)
        case .integer(let i): try c.encode(i)
        case .number(let n):
            if n.rounded() == n, abs(n) < 1e15 { try c.encode(Int64(n)) } else { try c.encode(n) }
        case .string(let s): try c.encode(s)
        case .array(let a): try c.encode(a)
        case .object(let o): try c.encode(o)
        }
    }

    public func decode<T: Decodable>(_ type: T.Type) throws -> T {
        try JSONDecoder().decode(T.self, from: JSONEncoder().encode(self))
    }

    public subscript(key: String) -> JSONValue? {
        if case .object(let o) = self { return o[key] }
        return nil
    }

    public var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }

    public var boolValue: Bool? {
        if case .bool(let b) = self { return b }
        return nil
    }

    /// Any number, as a `Double`: an integer beyond 2^53 comes back rounded.
    public var numberValue: Double? {
        switch self {
        case .integer(let i): Double(i)
        case .number(let n): n
        default: nil
        }
    }

    /// The number exactly, or nil when it is not a whole number that fits in
    /// an `Int64` — so a caller never has to convert, or trap on, `1e20`.
    public var integerValue: Int64? {
        switch self {
        case .integer(let i): i
        case .number(let n): Int64(exactly: n)
        default: nil
        }
    }

    public var objectValue: [String: JSONValue]? {
        if case .object(let o) = self { return o }
        return nil
    }

    public static func == (lhs: JSONValue, rhs: JSONValue) -> Bool {
        switch (lhs, rhs) {
        case (.null, .null): true
        case (.bool(let a), .bool(let b)): a == b
        case (.integer(let a), .integer(let b)): a == b
        case (.number(let a), .number(let b)): a == b
        case (.integer(let a), .number(let b)), (.number(let b), .integer(let a)): Int64(exactly: b) == a
        case (.string(let a), .string(let b)): a == b
        case (.array(let a), .array(let b)): a == b
        case (.object(let a), .object(let b)): a == b
        default: false
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .null: hasher.combine(0)
        case .bool(let b):
            hasher.combine(1)
            hasher.combine(b)
        // Hashed alike when they compare equal: a whole `Double` as its integer.
        case .integer(let i):
            hasher.combine(2)
            hasher.combine(i)
        case .number(let n):
            if let i = Int64(exactly: n) {
                hasher.combine(2)
                hasher.combine(i)
            } else {
                hasher.combine(3)
                hasher.combine(n)
            }
        case .string(let s):
            hasher.combine(4)
            hasher.combine(s)
        case .array(let a):
            hasher.combine(5)
            hasher.combine(a)
        case .object(let o):
            hasher.combine(6)
            hasher.combine(o)
        }
    }

    /// Round-trips any `Encodable` into a `JSONValue`.
    public static func from<T: Encodable>(_ value: T, encoder: JSONEncoder = JSONEncoder()) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: encoder.encode(value))
    }
}

extension JSONValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) { self = .string(value) }
}

extension JSONValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) { self = .bool(value) }
}

extension JSONValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int64) { self = .integer(value) }
}

extension JSONValue: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: JSONValue...) { self = .array(elements) }
}

extension JSONValue: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, JSONValue)...) {
        self = .object(Dictionary(elements, uniquingKeysWith: { _, last in last }))
    }
}

extension JSONValue: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) { self = .null }
}
