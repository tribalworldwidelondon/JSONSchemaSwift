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

internal let validatorTypes: [String: Validator.Type] = [
    "multipleOf": MultipleOfValidator.self,
    "maximum": MaximumValidator.self,
    "exclusiveMaximum": ExclusiveMaximumValidator.self,
    "minimum": MinimumValidator.self,
    "exclusiveMinimum": ExclusiveMinimumValidator.self,
    "maxLength": MaxLengthValidator.self,
    "minLength": MinLengthValidator.self,
    "pattern": PatternValidator.self,
    "items": ItemsValidator.self,
    "maxItems": MaxItemsValidator.self,
    "minItems": MinItemsValidator.self,
    "uniqueItems": UniqueItemsValidator.self,
    "maxProperties": MaxPropertiesValidator.self,
    "minProperties": MinPropertiesValidator.self,
    "required": RequiredValidator.self,
    "type": TypeValidator.self,
    "propertyNames": PropertyNamesValidator.self,
    "enum": EnumValidator.self,
    "not": NotValidator.self,
    "properties": PropertiesValidator.self,
    "allOf": AllOfValidator.self,
    "anyOf": AnyOfValidator.self
]

struct Schema {
    var id: String?
    var schemaUri: String?
    var title: String?
    var description: String?
    
    var properties: [String: Schema]
    
    var validators: [Validator]
    var itemShouldBePresent: Bool? = nil
    
    init(_ json: JSONValue) throws {
        guard case let .object(jsonProps, _) = json else {
            if case let .boolean(b, _) = json {
                itemShouldBePresent = b
            }
            
            validators = []
            properties = [:]
            return
        }
        
        let props = try objectPropsOrThrow("Object key is not a string", props: jsonProps)
        
        id          = props["$id"]?.stringValue
        schemaUri   = props["$schema"]?.stringValue
        title       = props["title"]?.stringValue
        description = props["description"]?.stringValue
        
        validators = []
        var errors = [ValidationError]()
        
        // Add validators
        for v in validatorTypes {
            if let validatorJson = props[v.key] {
                do {
                    let validator = try v.value.init(validatorJson)
                    validators.append(validator)
                } catch let e as ValidationError {
                    errors.append(e)
                }
            }
        }
        
        properties = [:]
        
        // Extract schemas from properties
        breakProps: if let objProps = props["properties"] {
            guard case let .object(obj, _) = objProps else {
                errors.append(ValidationError("'properties' should be an object", sourceLocation: objProps.sourcePosition))
                break breakProps
            }
            
            do {
                let strProps = try objectPropsOrThrow("'properties' should be an object", props: obj)
                
                
                
                for p in strProps {
                    do {
                        properties[p.key] = try Schema(p.value)
            
                    } catch let e as ValidationError {
                        errors.append(e)
                    }
                }
            } catch let e as ValidationError {
                errors.append(e)
                break breakProps
            }
        }
        
        // Collect all errors and throw as one
        if errors.count > 0 {
            throw ValidationError(errors.flatMap { $0.errors })
        }
        
    }
    
    func validate(_ json: JSONValue) throws {
        var errors: [ValidationError] = []
        
        if let present = itemShouldBePresent {
            if !present {
                errors.append(ValidationError("item should not be present", sourceLocation: json.sourcePosition))
            }
        }
        
        for validator in validators {
            do {
                try validator.validate(json, schema: self)
            } catch let e as ValidationError {
                errors.append(e)
            }
        }
        
        // Collect all errors and throw as one
        if errors.count > 0 {
            throw ValidationError(errors.flatMap { $0.errors })
        }
    }
}
