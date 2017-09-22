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
    let errors: [(String, JSONSourcePosition)]
    
    init(_ description: String, sourceLocation: JSONSourcePosition) {
        errors = [(description, sourceLocation)]
    }
    
    init(_ errors: [(String, JSONSourcePosition)]) {
        self.errors = errors
    }
}

protocol Validator {
    init(_ json: JSONValue, refResolver: RefResolver, refPath: [String]) throws
    func validate(_ json: JSONValue, schema: Schema) throws
}



// MARK: - Validators

struct MultipleOfValidator: Validator {
    let multipleOf: Double
    
    init(_ json: JSONValue, refResolver: RefResolver, refPath: [String]) throws {
        multipleOf = try getNumberOrThrow("multipleOf should be a number", json: json)
    }
    
    func validate(_ json: JSONValue, schema: Schema) throws {
        try validateOrThrow("Must be a multiple of \(multipleOf)", json: json) {
            validateNumber(json) {
                // Check that is less than an epsilon due to floating point inprecision
                abs($0.remainder(dividingBy: multipleOf)) <= 1e-8
            }
        }
    }
}

struct MaximumValidator: Validator {
    let maximum: Double
    
    init(_ json: JSONValue, refResolver: RefResolver, refPath: [String]) throws {
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
    
    init(_ json: JSONValue, refResolver: RefResolver, refPath: [String]) throws {
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
    
    init(_ json: JSONValue, refResolver: RefResolver, refPath: [String]) throws {
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
    
    init(_ json: JSONValue, refResolver: RefResolver, refPath: [String]) throws {
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
    
    init(_ json: JSONValue, refResolver: RefResolver, refPath: [String]) throws {
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
    
    init(_ json: JSONValue, refResolver: RefResolver, refPath: [String]) throws {
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
    
    init(_ json: JSONValue, refResolver: RefResolver, refPath: [String]) throws {
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

struct ItemsValidator: Validator {
    let itemsSchemas: [Schema]
    let isMultiple: Bool
    let canHaveItems: Bool
    
    init(_ json: JSONValue, refResolver: RefResolver, refPath: [String]) throws {
        let newPath = refPath + ["items"]
        
        switch json {
        case .object:
            itemsSchemas = [try Schema(json, refResolver: refResolver, refPath: newPath)]
            isMultiple = false
            canHaveItems = true
        case .array(let array, _):
            var idx = 0
            itemsSchemas = try array.map {
                let schema = try Schema($0, refResolver: refResolver, refPath: newPath + [String(idx)])
                idx += 1
                return schema
            }
            isMultiple = true
            canHaveItems = true
        case .boolean(let b, _):
            itemsSchemas = []
            isMultiple = true
            canHaveItems = b
        default:
            throw ValidationError("items must contain a valid schema or an array of schemas",
                                  sourceLocation: json.sourcePosition)
        }
    }
    
    func validate(_ json: JSONValue, schema: Schema) throws {
        guard case let .array(array, _) = json else {
            return
        }
        
        if !canHaveItems {
            if array.count > 0 {
                throw ValidationError("array must not contain any items", sourceLocation: json.sourcePosition)
            }
        }
        
        if isMultiple {
            var errors: [ValidationError] = []
            
            // Iterate over the array, matching each item with the associated schema item (if any)
            for i in 0..<itemsSchemas.count {
                if i > array.count - 1 {
                    return
                }
                
                do {
                    try itemsSchemas[i].validate(array[i])
                } catch let e as ValidationError {
                    errors.append(e)
                }
            }
            
            if errors.count > 0 {
                throw ValidationError(errors.flatMap{ $0.errors })
            }
            
        } else {
            for item in array {
                try itemsSchemas[0].validate(item)
            }
        }
    }
    
}

struct MaxItemsValidator: Validator {
    let maxItems: Int
    
    init(_ json: JSONValue, refResolver: RefResolver, refPath: [String]) throws {
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
    
    init(_ json: JSONValue, refResolver: RefResolver, refPath: [String]) throws {
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
    
    init(_ json: JSONValue, refResolver: RefResolver, refPath: [String]) throws {
        uniqueItems = try getBoolOrThrow("uniqueItems should be a boolean", json: json)
    }
    
    func validate(_ json: JSONValue, schema: Schema) throws {
        guard case let .array(array, _) = json else {
            return
        }
        
        let duplicates = Array(Set(array.filter { (v: JSONValue) in array.filter { $0 == v }.count > 1}))
        
        if duplicates.count > 0 {
            let errors = duplicates.map {
                ("Item is a duplicate", $0.sourcePosition)
            }
            
            throw ValidationError(errors)
        }
    }
}

struct MaxPropertiesValidator: Validator {
    let maxProperties: Int
    
    init(_ json: JSONValue, refResolver: RefResolver, refPath: [String]) throws {
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
    
    init(_ json: JSONValue, refResolver: RefResolver, refPath: [String]) throws {
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
    
    init(_ json: JSONValue, refResolver: RefResolver, refPath: [String]) throws {
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

struct TypeValidator: Validator {
    let types: [String]
    
    init(_ json: JSONValue, refResolver: RefResolver, refPath: [String]) throws {
        if case let .string(type, _) = json {
            types = [type]
            return
        }
        
        types = try getStringArrayOrThrow("type must be a string, or an array of strings", json: json)
    }
    
    func validate(_ json: JSONValue, schema: Schema) throws {
        for type in types {
            if value(json, matchesType: type) {
                return
            }
        }
        
        if types.count == 1 {
            throw ValidationError("Item must be of type '\(types[0])'", sourceLocation: json.sourcePosition)
        }
        
        let possibleTypes = types.map { "'\($0)'" }.joined(separator: ", ")
        throw ValidationError("Item must be one of the following types: \(possibleTypes)",
            sourceLocation: json.sourcePosition)
    }
}

struct PropertyNamesValidator: Validator {
    let propertyNamesSchema: Schema
    
    init(_ json: JSONValue, refResolver: RefResolver, refPath: [String]) throws {
        switch json {
        case .object, .boolean:
            propertyNamesSchema = try Schema(json, refResolver: refResolver, refPath: refPath + ["propertyNames"])
        default:
            throw ValidationError("propertyNames should be a valid schema", sourceLocation: json.sourcePosition)
        }
    }
    
    func validate(_ json: JSONValue, schema: Schema) throws {
        switch json {
        case .object(let obj, _):
            for key in obj.keys {
                try propertyNamesSchema.validate(key)
            }
        default: break
        }
    }
}

struct EnumValidator: Validator {
    let enumValues: [JSONValue]
    
    init(_ json: JSONValue, refResolver: RefResolver, refPath: [String]) throws {
        enumValues = try getArrayOrThrow("enum must be an array", json: json)
    }
    
    func validate(_ json: JSONValue, schema: Schema) throws {
        guard case let .array(array, _) = json else {
            for v in enumValues {
                if json == v {
                    return
                }
            }
            throw ValidationError("item must be equal to an item in the enum", sourceLocation: json.sourcePosition)
        }
        
        var validationErrors = [ValidationError]()
        
        itemValidate: for item in array {
            for v in enumValues {
                if item == v {
                    break itemValidate
                }
            }
            validationErrors.append(ValidationError("item must be equal to an item in the enum", sourceLocation: item.sourcePosition))
        }
        
        if validationErrors.count > 0 {
            let collectedErrors = validationErrors.flatMap { $0.errors }
            throw ValidationError(collectedErrors)
        }
    }
}

struct NotValidator: Validator {
    let notSchema: Schema
    
    init(_ json: JSONValue, refResolver: RefResolver, refPath: [String]) throws {
        notSchema = try Schema(json, refResolver: refResolver, refPath: ["not"])
    }
    
    func validate(_ json: JSONValue, schema: Schema) throws {
        do {
            try notSchema.validate(json)
        } catch {
            return
        }
        
        throw ValidationError("item should not match schema", sourceLocation: json.sourcePosition)
    }
}

struct PropertiesValidator: Validator {
    init(_ json: JSONValue, refResolver: RefResolver, refPath: [String]) throws {
    }
    
    func validate(_ json: JSONValue, schema: Schema) throws {
        guard case let .object(objProps, _) = json else {
            return
        }
        
        let props = try objectPropsOrThrow("key must be a string", props: objProps)
        
        var errors = [ValidationError]()
        
        for propSchema in schema.properties {
            if let item = props[propSchema.key] {
                do {
                    try propSchema.value.validate(item)
                } catch let e as ValidationError {
                    errors.append(e)
                }
            }
        }
        
        if errors.count > 0 {
            throw ValidationError(errors.flatMap{ $0.errors })
        }
    }
}

struct AllOfValidator: Validator {
    let validationSchemas: [Schema]
    
    init(_ json: JSONValue, refResolver: RefResolver, refPath: [String]) throws {
        let schemaObjs = try getArrayOrThrow("'allOf' must be an array", json: json)
        
        var errors = [ValidationError]()
        var schemas = [Schema]()
        
        var idx = 0
        for obj in schemaObjs {
            do {
                schemas.append(try Schema(obj, refResolver: refResolver, refPath: ["allOf", String(idx)]))
            } catch let e as ValidationError {
                errors.append(e)
            }
            
            idx += 1
        }
        
        if errors.count > 0 {
            throw ValidationError(errors.flatMap { $0.errors })
        }
        
        validationSchemas = schemas
    }
    
    func validate(_ json: JSONValue, schema: Schema) throws {
        var errors = [ValidationError]()
        
        for s in validationSchemas {
            do {
                try s.validate(json)
            } catch let e as ValidationError {
                errors.append(e)
            }
        }
        
        if errors.count > 0 {
            throw ValidationError(errors.flatMap { $0.errors })
        }
    }
}

struct AnyOfValidator: Validator {
    let validationSchemas: [Schema]
    
    init(_ json: JSONValue, refResolver: RefResolver, refPath: [String]) throws {
        let schemaObjs = try getArrayOrThrow("'anyOf' must be an array", json: json)
        
        var errors = [ValidationError]()
        var schemas = [Schema]()
        
        var idx = 0
        for obj in schemaObjs {
            do {
                schemas.append(try Schema(obj, refResolver: refResolver, refPath: ["anyOf", String(idx)]))
            } catch let e as ValidationError {
                errors.append(e)
            }
            
            idx += 1
        }
        
        if errors.count > 0 {
            throw ValidationError(errors.flatMap { $0.errors })
        }
        
        validationSchemas = schemas
    }
    
    func validate(_ json: JSONValue, schema: Schema) throws {
        for s in validationSchemas {
            do {
                try s.validate(json)
                return
            } catch {
            }
        }
        
        throw ValidationError("item must match at least one schema", sourceLocation: json.sourcePosition)
    }
}

struct OneOfValidator: Validator {
    let validationSchemas: [Schema]
    
    init(_ json: JSONValue, refResolver: RefResolver, refPath: [String]) throws {
        let schemaObjs = try getArrayOrThrow("'oneOf' must be an array", json: json)
        
        var errors = [ValidationError]()
        var schemas = [Schema]()
        
        var idx = 0
        for obj in schemaObjs {
            do {
                schemas.append(try Schema(obj, refResolver: refResolver, refPath: ["oneOf", String(idx)]))
            } catch let e as ValidationError {
                errors.append(e)
            }
            idx += 1
        }
        
        if errors.count > 0 {
            throw ValidationError(errors.flatMap { $0.errors })
        }
        
        validationSchemas = schemas
    }
    
    func validate(_ json: JSONValue, schema: Schema) throws {
        var validationCount = 0
        
        for s in validationSchemas {
            do {
                try s.validate(json)
                validationCount += 1
            } catch {
            }
        }
        
        if validationCount == 0 {
            throw ValidationError("item must match exactly one schema", sourceLocation: json.sourcePosition)
        } else if validationCount > 1 {
            throw ValidationError("item must match exactly one schema", sourceLocation: json.sourcePosition)
        }
    }
}

struct PatternPropertiesValidator: Validator {
    init(_ json: JSONValue, refResolver: RefResolver, refPath: [String]) throws {
    }
    
    func validate(_ json: JSONValue, schema: Schema) throws {
        guard case let .object(objProps, _) = json else {
            return
        }
        
        let props = try objectPropsOrThrow("key must be a string", props: objProps)
        
        var errors = [ValidationError]()
        
        for p in props {
            for pattProp in schema.patternProperties {
                if pattProp.key.matches(in: p.key, options: [], range: NSMakeRange(0, p.key.characters.count)).count > 0 {
                    do {
                        try pattProp.value.validate(p.value)
                    } catch let e as ValidationError {
                        errors.append(e)
                    }
                }
            }
        }
        
        if errors.count > 0 {
            throw ValidationError(errors.flatMap{ $0.errors })
        }
    }
}

struct AdditionalPropertiesValidator: Validator {
    let additionalPropertiesSchema: Schema
    
    init(_ json: JSONValue, refResolver: RefResolver, refPath: [String]) throws {
        additionalPropertiesSchema = try Schema(json, refResolver: refResolver, refPath: refPath + ["additionalProperties"])
    }
    
    func validate(_ json: JSONValue, schema: Schema) throws {
        guard case let .object(objProps, _) = json else {
            return
        }
        
        let props = try objectPropsOrThrow("key must be a string", props: objProps)
        
        var errors = [ValidationError]()
        
        for p in props {
            if !schema.properties.keys.contains(p.key) && !string(p.key, matchesPatternArray: Array(schema.patternProperties.keys)) {
                do {
                    try additionalPropertiesSchema.validate(p.value)
                } catch let e as ValidationError {
                    errors.append(e)
                }
            }
        }
        
        if errors.count > 0 {
            throw ValidationError(errors.flatMap{ $0.errors })
        }
    }
}

struct ConstValidator: Validator {
    let constValue: JSONValue
    
    init(_ json: JSONValue, refResolver: RefResolver, refPath: [String]) throws {
        constValue = json
    }
    
    func validate(_ json: JSONValue, schema: Schema) throws {
        if json != constValue {
            throw ValidationError("item should be equal to the constant value: \(constValue.asJsonString())",
                sourceLocation: json.sourcePosition)
        }
    }
}

// MARK: - Helpers

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

internal func objectPropsOrThrow(_ message: String, props: [JSONValue: JSONValue]) throws -> [String: JSONValue] {
    let keys: [String] = try props.keys.map {
        guard case let .string(str, _) = $0 else {
            throw ValidationError(message, sourceLocation: $0.sourcePosition)
        }
        return str
    }
    
    return [String: JSONValue](uniqueKeysWithValues: zip(keys, props.values))
}

internal func value(_ value: JSONValue, matchesType type: String) -> Bool {
    switch value {
    case .array:
        return type == "array"
    case .boolean:
        return type == "boolean"
    case .float:
        return type == "number"
    case .integer:
        return type == "integer" || type == "number"
    case .null:
        return type == "null"
    case .object:
        return type == "object"
    case .string:
        return type == "string"
    }
}

internal func string(_ str: String, matchesPatternArray patterns: [NSRegularExpression]) -> Bool {
    for patt in patterns {
        if patt.matches(in: str, options: [], range: NSMakeRange(0, str.characters.count)).count > 0 {
            return true
        }
    }
    
    return false
}
