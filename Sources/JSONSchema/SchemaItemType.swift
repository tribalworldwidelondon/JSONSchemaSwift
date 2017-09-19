//
//  SchemaItemType.swift
//  JSONSchemaPackageDescription
//
//  Created by Andy Best on 19/09/2017.
//

import Foundation

enum SchemaItemType {
    case string
    case number
    case integer
    case boolean
    case null
    case array
    case object
    case anyType
    case oneOf([SchemaItemType])
    
    static func fromString(_ str: String) -> SchemaItemType? {
        switch str.lowercased() {
        case "string": return .string
        case "number": return .number
        case "integer": return .integer
        case "boolean": return .boolean
        case "null": return .null
        case "array": return .array
        case "object": return .object
        default: return nil
        }
    }
    
    func validates(_ json: Any) -> ValidationResult {
        switch self {
        case .string where json is String: return .valid
        case .number where json is Double: return .valid
        case .integer where json is Int: return .valid
        case .boolean where json is Bool: return .valid
        case .null where json is NSNull: return .valid
        case .array where json is [Any]: return .valid
        case .object where json is [String: Any]: return .valid
            
        default: return .invalid("")
        }
    }
}
