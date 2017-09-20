/*
 MIT License
 
 Copyright (c) 2017 Tribal Worldwide London
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
 */

import Foundation
import JSONParser

struct ValidationError: Error {
    let sourceLocation: JSONSourcePosition
    let description: String
    
    init(_ description: String, sourceLocation: JSONSourcePosition) {
        self.sourceLocation = sourceLocation
        self.description = description
    }
}

protocol Validator {
    init(_ json: JSONValue) throws
    func validate(_ json: JSONValue, schema: Schema) throws
}

internal func validateNumber(_ json: JSONValue, f: ((Double) -> Bool)) -> Bool {
    switch json {
    case .integer(let i, _):
        return f(Double(i))
    case .float(let fl, _):
        return f(fl)
    default:
        return true
    }
}

internal func validateString(_ json: JSONValue, f: ((String) -> Bool)) -> Bool {
    switch json {
    case .string(let s, _):
        return f(s)
    default:
        return true
    }
}

internal func validateArray(_ json: JSONValue, f: (([JSONValue]) -> Bool)) -> Bool {
    switch json {
    case .array(let arr, _):
        return f(arr)
    default:
        return true
    }
}

internal func validateObject(_ json: JSONValue, f: (([JSONValue: JSONValue]) -> Bool)) -> Bool {
    switch json {
    case .object(let props, _):
        return f(props)
    default:
        return true
    }
}

internal func validateOrThrow(_ message: String, json: JSONValue, block: () -> Bool) throws {
    if !block() {
        throw ValidationError(message, sourceLocation: json.sourcePosition)
    }
}

internal func getNumberOrThrow(_ message: String, json: JSONValue) throws -> Double {
    switch json {
    case .integer(let i, _):
        return Double(i)
    case .float(let f, _):
        return f
    default:
        throw ValidationError(message, sourceLocation: json.sourcePosition)
    }
}

internal func getIntegerOrThrow(_ message: String, json: JSONValue) throws -> Int {
    switch json {
    case .integer(let i, _):
        return i
    default:
        throw ValidationError(message, sourceLocation: json.sourcePosition)
    }
}

internal func getBoolOrThrow(_ message: String, json: JSONValue) throws -> Bool {
    switch json {
    case .boolean(let b, _):
        return b
    default:
        throw ValidationError(message, sourceLocation: json.sourcePosition)
    }
}

internal func getArrayOrThrow(_ message: String, json: JSONValue) throws -> [JSONValue] {
    guard case let .array(arr, _) = json else {
        throw ValidationError(message, sourceLocation: json.sourcePosition)
    }
    
    return arr
}

internal func getStringArrayOrThrow(_ message: String, json: JSONValue) throws -> [String] {
    let array = try getArrayOrThrow(message, json: json)
    
    var stringArray = [String]()
    stringArray.reserveCapacity(array.count)
    
    for item in array {
        guard case let .string(str, _) = item else {
            throw ValidationError(message, sourceLocation: json.sourcePosition)
        }
        
        stringArray.append(str)
    }
    
    return stringArray
}

struct MultipleOfValidator: Validator {
    let multipleOf: Double
    
    init(_ json: JSONValue) throws {
        multipleOf = try getNumberOrThrow("multipleOf should be a number", json: json)
    }
    
    func validate(_ json: JSONValue, schema: Schema) throws {
        try validateOrThrow("Must be a multiple of \(multipleOf)", json: json) {
            validateNumber(json) {
                $0.remainder(dividingBy: multipleOf) == 0
            }
        }
    }
}

struct MaximumValidator: Validator {
    let maximum: Double
    
    init(_ json: JSONValue) throws {
        maximum = try getNumberOrThrow("maximum should be a number", json: json)
    }
    
    func validate(_ json: JSONValue, schema: Schema) throws {
        try validateOrThrow("Number must be less than or equal to \(maximum)", json: json) {
            validateNumber(json) { $0 <= maximum }
        }
    }
}

struct ExclusiveMaximumValidator: Validator {
    let exclusiveMaximum: Double
    
    init(_ json: JSONValue) throws {
        exclusiveMaximum = try getNumberOrThrow("exclusiveMaximum should be a number", json: json)
    }
    
    func validate(_ json: JSONValue, schema: Schema) throws {
        try validateOrThrow("Number must be less than \(exclusiveMaximum)", json: json) {
            validateNumber(json) { $0 < exclusiveMaximum }
        }
    }
}

struct MinimumValidator: Validator {
    let minimum: Double
    
    init(_ json: JSONValue) throws {
        minimum = try getNumberOrThrow("minimum should be a number", json: json)
    }
    
    func validate(_ json: JSONValue, schema: Schema) throws {
        try validateOrThrow("Number must greater than or equal to \(minimum)", json: json) {
            validateNumber(json) { $0 >= minimum }
        }
    }
}

struct ExclusiveMinimumValidator: Validator {
    let exclusiveMinimum: Double
    
    init(_ json: JSONValue) throws {
        exclusiveMinimum = try getNumberOrThrow("exclusiveMinimum should be a number", json: json)
    }
    
    func validate(_ json: JSONValue, schema: Schema) throws {
        try validateOrThrow("Number must greater than \(exclusiveMinimum)", json: json) {
            validateNumber(json) { $0 > exclusiveMinimum }
        }
    }
}

struct MaxLengthValidator: Validator {
    let maxLength: Int
    
    init(_ json: JSONValue) throws {
        maxLength = try getIntegerOrThrow("maxLength should be an integer", json: json)
    }
    
    func validate(_ json: JSONValue, schema: Schema) throws {
        try validateOrThrow("String must have a length less than or equal to \(maxLength)", json: json) {
            validateString(json) { $0.characters.count <= maxLength }
        }
    }
}

struct MinLengthValidator: Validator {
    let minLength: Int
    
    init(_ json: JSONValue) throws {
        minLength = try getIntegerOrThrow("minLength should be an integer", json: json)
    }
    
    func validate(_ json: JSONValue, schema: Schema) throws {
        try validateOrThrow("String must have a length greater than or equal to \(minLength)", json: json) {
            validateString(json) { $0.characters.count >= minLength }
        }
    }
}

struct PatternValidator: Validator {
    let regex: NSRegularExpression
    
    init(_ json: JSONValue) throws {
        guard case let .string(str, _) = json else {
            throw ValidationError("pattern should be a string", sourceLocation: json.sourcePosition)
        }
        
        do {
            regex = try NSRegularExpression(pattern: str, options: [])
        } catch {
            throw ValidationError("pattern should be a valid regular expression", sourceLocation: json.sourcePosition)
        }
    }
    
    func validate(_ json: JSONValue, schema: Schema) throws {
        try validateOrThrow("String must match pattern '\(regex.pattern)'", json: json) {
            validateString(json) {
                regex.matches(in: $0, options: [], range: NSMakeRange(0, $0.characters.count)).count > 0
            }
        }
    }
}

struct MaxItemsValidator: Validator {
    let maxItems: Int
    
    init(_ json: JSONValue) throws {
        maxItems = try getIntegerOrThrow("maxItems should be an integer", json: json)
    }
    
    func validate(_ json: JSONValue, schema: Schema) throws {
        try validateOrThrow("Array must have \(maxItems) items or less", json: json) {
            validateArray(json) { $0.count <= maxItems }
        }
    }
}

struct MinItemsValidator: Validator {
    let minItems: Int
    
    init(_ json: JSONValue) throws {
        minItems = try getIntegerOrThrow("minItems should be an integer", json: json)
    }
    
    func validate(_ json: JSONValue, schema: Schema) throws {
        try validateOrThrow("Array must have \(minItems) or more items", json: json) {
            validateArray(json) { $0.count >= minItems }
        }
    }
}

struct UniqueItemsValidator: Validator {
    let uniqueItems: Bool
    
    init(_ json: JSONValue) throws {
        uniqueItems = try getBoolOrThrow("uniqueItems should be a boolean", json: json)
    }
    
    func validate(_ json: JSONValue, schema: Schema) throws {
        try validateOrThrow("Array must have unique items", json: json) {
            validateArray(json) {
                if !uniqueItems {
                    return true
                }
                
                let s = Set<JSONValue>($0)
                return s.count == $0.count
            }
        }
    }
}

struct MaxPropertiesValidator: Validator {
    let maxProperties: Int
    
    init(_ json: JSONValue) throws {
        maxProperties = try getIntegerOrThrow("maxProperties should be an integer", json: json)
    }
    
    func validate(_ json: JSONValue, schema: Schema) throws {
        try validateOrThrow("Object must have \(maxProperties) properties or less", json: json) {
            validateObject(json) { $0.keys.count <= maxProperties }
        }
    }
}

struct MinPropertiesValidator: Validator {
    let minProperties: Int
    
    init(_ json: JSONValue) throws {
        minProperties = try getIntegerOrThrow("minProperties should be an integer", json: json)
    }
    
    func validate(_ json: JSONValue, schema: Schema) throws {
        try validateOrThrow("Object must have \(minProperties) or more properties", json: json) {
            validateObject(json) { $0.keys.count >= minProperties }
        }
    }
}

struct RequiredValidator: Validator {
    let required: [String]
    
    init(_ json: JSONValue) throws {
        required = try getStringArrayOrThrow("required must be an array of strings", json: json)
    }
    
    func validate(_ json: JSONValue, schema: Schema) throws {
        guard case let .object(props, _) = json else {
            return
        }
        
        var missingKeys = [String]()
        
        let objKeys: [String] = props.keys.map {
            if case let .string(key, _) = $0 {
                return key
            }
            
            return ""
        }
        
        for key in required {
            if !objKeys.contains(key) {
                missingKeys.append(key)
            }
        }
        
        if missingKeys.count > 0 {
            let keysString = "\"\(missingKeys.joined(separator: ", "))\""
            throw ValidationError("Object is missing the following keys: \(keysString)", sourceLocation: json.sourcePosition)
        }
    }
}
