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

class JsonSchema {
    let root: [SchemaItem]
    
    init(_ schema: Any) throws {
        root = [ try SchemaItem(schema)]
    }
    
    func validates(_ json: Any?) -> ValidationResult {
        return root[0].validates(json)
    }
}

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
    "not": NotValidator.self
]

struct Schema {
    var id: String?
    var schemaUri: String?
    var title: String?
    var description: String?
    
    var validators: [Validator]
    var itemShouldBePresent: Bool? = nil
    
    init(_ json: JSONValue) throws {
        guard case let .object(jsonProps, _) = json else {
            if case let .boolean(b, _) = json {
                itemShouldBePresent = b
            }
            
            validators = []
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
        
        /*
        for key in props.keys {
            switch key.stringValue! {
            case "multipleOf":
                break
                
            default:
                break
            }
        }*/
    }
    
    func validate(_ json: JSONValue) throws {
        if let present = itemShouldBePresent {
            if !present {
                throw ValidationError("item should not be present", sourceLocation: json.sourcePosition)
            }
        }
        
        for validator in validators {
            try validator.validate(json, schema: self)
        }
    }
}
