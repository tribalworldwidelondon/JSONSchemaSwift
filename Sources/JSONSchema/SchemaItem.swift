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

struct SchemaItem {
    var title: String? = nil
    var description: String? = nil
    let type: SchemaItemType
    let schema: [String: Any]
    
    var required = false
    var typeValidation: SchemaTypeValidation? = nil
    var canBePresent: Bool = true
    var hasConcreteType: Bool = true
    
    let properties: [String: SchemaItem]
    let patternProperties: [NSRegularExpression: SchemaItem]
    let additionalProperties: [SchemaItem]?
    
    init(_ schemaObject: Any) throws {
        if let numberSchema = schemaObject as? NSNumber {
            if CFNumberGetType(numberSchema) == .charType {
                // Schema is a boolean- just says whether this property is allowed to be present or not.
                canBePresent = numberSchema as! Bool
                type = .anyType
                properties = [:]
                self.additionalProperties = nil
                self.patternProperties = [:]
                schema = [:]
                return
            }
        }
        
        guard let schema = schemaObject as? [String: Any] else {
            throw SchemaError(failureReason: "Invalid schema")
        }
        
        title = schema["title"] as? String
        description = schema["description"] as? String
        
        if let t = try SchemaItem.getType(schema) {
            self.type = t
        } else {
            self.type = .object
            hasConcreteType = false
        }
        
        self.properties = try SchemaItem.getProperties(schema)
        
        if let additionalProps = schema["additionalProperties"] {
            additionalProperties = [try SchemaItem(additionalProps)]
        } else {
            additionalProperties = nil
        }
        
        self.patternProperties = try SchemaItem.getPatternProperties(schema)
            
        self.schema = schema
        
        updateSpecificTypeValidators()
    }
    
    static func getType(_ schema: [String: Any]) throws -> SchemaItemType? {
        if let types = schema["type"] as? String {
            guard let t = SchemaItemType.fromString(types) else {
                throw SchemaError(failureReason: "Invalid type: \(types)")
            }
            
           return t
        } else if let types = schema["type"] as? [String] {
            var t = [SchemaItemType]()
            
            for typeString in types {
                guard let type = SchemaItemType.fromString(typeString) else {
                    throw SchemaError(failureReason: "Invalid type: \(types)")
                }
                t.append(type)
            }
            return .oneOf(t)
        } else {
            if let possibleType = guessTypeFromProperties(schema), let t = SchemaItemType.fromString(possibleType) {
                return t
            } else {
                return nil
            }
        }
    }
    
    static func guessTypeFromProperties(_ schema: [String: Any]) -> String? {
        let arrayProps = ["minItems", "maxItems"]
        let integerProps = ["maximum", "minimum", "exclusiveMaximum", "multipleOf"]
        
        let possibleTypes: [String: [String]] = [
            "array": arrayProps,
            "integer": integerProps
        ]
        
        for t in possibleTypes {
            for prop in schema {
                if t.value.contains(prop.key) {
                    return t.key
                }
            }
        }
        
        return nil
    }
    
    static func getProperties(_ schema: [String: Any]) throws -> [String: SchemaItem] {
        if let props = schema["properties"] as? [String: Any] {
            var properties = [String: SchemaItem]()
            
            for prop in props {
                let name = prop.key
                let schemaItem = try SchemaItem(prop.value)
                properties[name] = schemaItem
            }
            
            return properties
        }
        
        return [:]
    }
    
    static func getPatternProperties(_ schema: [String: Any]) throws -> [NSRegularExpression: SchemaItem] {
        if let props = schema["patternProperties"] as? [String: Any] {
            var properties = [NSRegularExpression: SchemaItem]()
            
            for prop in props {
                let pattern = try NSRegularExpression(pattern: prop.key, options: [])
                let schemaItem = try SchemaItem(prop.value)
                properties[pattern] = schemaItem
            }
            
            return properties
        }
        
        return [:]
    }
    
    func validates(_ json: Any) -> ValidationResult {
        
        switch type {
        case .object:
            return validateObject(json)
        default:
            break
        }
        
        let result = type.validates(json)
        
        switch result {
        case .invalid(let msg):
            return .invalid(msg)
        default: break
        }
        
        if typeValidation != nil {
            return typeValidation!.validates(json)
        }
        return .valid
    }
    
    func validateObject(_ json: Any?) -> ValidationResult {
        guard let objectValue = json as? [String: Any] else {
            if !hasConcreteType {
                return .valid
            }
            
            return .invalid("Is not an object")
        }
        
        let props = objectValue.filter {
            properties.keys.contains($0.key)
        }
        
        let propsValid = validateProperties(props)
        
        switch propsValid {
        case .invalid(let msg):
            return .invalid(msg)
        default: break
        }
        
        var propsToRemove = [String]()
        
        // Iterate over the json properties to see if the match any patterns in patternProperties.
        for pattProp in self.patternProperties {
            for jsonProp in objectValue {
                if pattProp.key.matches(in: jsonProp.key, options: [], range: NSMakeRange(0, jsonProp.key.characters.count)).count > 0 {
                    propsToRemove.append(jsonProp.key)
                    
                    let result = validateProperty(pattProp.value, name: jsonProp.key, withValue: jsonProp.value)
                    
                    switch result {
                    case .invalid(let msg):
                        return .invalid(msg)
                    default: break
                    }
                }
            }
        }
        
        let remainingProps = objectValue.filter {
            !props.keys.contains($0.key) && !propsToRemove.contains($0.key)
        }
        
        // Iterate over the rest of the properties and check against additionalProperties
        if additionalProperties != nil {
            for prop in remainingProps {
                let result = validateProperty(additionalProperties![0], name: prop.key, withValue: prop.value)
                
                switch result {
                case .invalid(let msg):
                    return .invalid(msg)
                default: break
                }
            }
        }
        
        return .valid
    }
    
    func validateProperties(_ json: [String: Any]) -> ValidationResult {
        for (name, prop) in self.properties {
            let value = json[name]
            
            switch validateProperty(prop, name: name, withValue: value) {
            case .invalid(let msg):
                return .invalid(msg)
            default: break
            }
        }
        
        return .valid
    }
    
    func validateProperty(_ prop: SchemaItem, name: String, withValue value: Any?) -> ValidationResult {
        if value == nil {
            if prop.required {
                return .invalid("Required property \(name) is missing.")
            } else {
                return .valid
            }
        } else {
            if prop.canBePresent == false {
                return .invalid("Property present, when schema says it isn't allowed to be")
            }
        }
        
        return prop.validates(value)
    }
    
    /// Add validation for the current type- e.g. "maxItems" for Array.
    mutating func updateSpecificTypeValidators() {
        switch type {
        case .array:
            typeValidation = SchemaArrayRestrictions(
                minItems: schema["minItems"] as? Int,
                maxItems: schema["maxItems"] as? Int)
            
        case .integer:
            typeValidation = SchemaIntegerRestrictions(minimum: schema["minimum"] as? Double,
                                                       maximum: schema["maximum"] as? Double,
                                                       exclusiveMaximum: schema["exclusiveMaximum"] as? Bool,
                                                       multipleOf: schema["multipleOf"] as? Double)
        default:
            break
        }
    }
}
