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
    "anyOf": AnyOfValidator.self,
    "oneOf": OneOfValidator.self,
    "additionalProperties": AdditionalPropertiesValidator.self,
    "patternProperties": PatternPropertiesValidator.self,
    "const": ConstValidator.self
]

class RefResolver {
    var references: [String: Schema]
    var refsToValidate: [String: JSONSourcePosition]
    var remoteRefCache: [String: Schema]
    
    init() {
        references = [:]
        refsToValidate = [:]
        remoteRefCache = [:]
    }
    
    func addReference(_ refPath: [String], forSchema schema: Schema) {
        var path = refPath.map { escapeRef($0) }.joined(separator: "/")
        if path.characters.count > 0 {
            path = "#/" + path
        } else {
            path = "#"
        }
        
        //assert(references[path] == nil, "Ref already added!")
        references[path] = schema
    }
    
    func addRefToResolve(_ ref: String, sourcePosition: JSONSourcePosition) {
        refsToValidate[ref] = sourcePosition
    }
    
    func validateRefsResolve() throws {
        var errors: [(String, JSONSourcePosition)] = []
        
        for (ref, sourcePosition) in refsToValidate {
            do {
                _ = try getSchemaRef(ref, sourceLocation: sourcePosition)
            } catch {
                errors.append(("Unable to resolve reference '\(ref)'", sourcePosition))
            }
        }
        
        if errors.count > 0 {
            throw ValidationError(errors)
        }
    }
    
    func escapeRef(_ ref: String) -> String {
        return ref.replacingOccurrences(of: "~", with: "~0")
            .replacingOccurrences(of: "/", with: "~1")
            .replacingOccurrences(of: "%", with: "%25")
    }
    
    func getSchemaRef(_ ref: String, sourceLocation: JSONSourcePosition) throws -> Schema {
        //let unescapedRef = unescapeRef(ref)
        
        if !ref.hasPrefix("#") {
            let refComponents = ref.split(separator: "#")
            
            if let url = URL(string: String(refComponents[0])) {
                let schema = try resolveRemoteReference(url, sourcePosition: sourceLocation)
                
                if refComponents.count > 1 {
                    return try schema.refResolver.getSchemaRef("#" + refComponents[1], sourceLocation: sourceLocation)
                } else {
                    return schema
                }
            }
            
            throw ValidationError("Remote reference isn't a valid URL", sourceLocation: sourceLocation)
        }
        
        guard let schema = references[ref] else {
            throw ValidationError("Unable to resolve reference: '\(ref)'", sourceLocation: JSONSourcePosition(line: -1, column: -1, source: ""))
        }
        
        return schema
    }
    
    func resolveRemoteReference(_ url: URL, sourcePosition: JSONSourcePosition) throws -> Schema {
        if let cached = remoteRefCache[url.absoluteString] {
            return cached
        }
        
        print("Resolving remote schema ref: \(url.absoluteString)")
        
        let session = URLSession(configuration: .default)
        let (data, _, error) = session.synchronousDataTask(with: url)
        
        if error != nil || data == nil {
            throw ValidationError("Unable to resolve remote reference- \(error!.localizedDescription): \(url.absoluteString)",
                sourceLocation: sourcePosition)
        }
        
        let validationError = ValidationError("Remote reference is not a valid schema.", sourceLocation: sourcePosition)
        
        let jsonString = String(data: data!, encoding: .utf8)
        
        if jsonString == nil {
            throw validationError
        }
        
        do {
            let json = try JSONReader.read(jsonString!)
            let schema = try Schema(json)
            remoteRefCache[url.absoluteString] = schema
            return schema
        } catch {
            throw validationError
        }
        
    }
}

class Schema {
    var refResolver: RefResolver
    
    var refId: String?
    
    var id: String?
    var schemaUri: String?
    var title: String?
    var description: String?
    
    var properties: [String: Schema]
    var patternProperties: [NSRegularExpression: Schema]
    var definitions: [String: Schema]
    
    var validators: [Validator]
    var itemShouldBePresent: Bool? = nil
    
    init(_ json: JSONValue, refResolver: RefResolver? = nil, refPath: [String] = []) throws {
        let isRoot: Bool
        
        if refResolver != nil {
            isRoot = false
            self.refResolver = refResolver!
        } else {
            isRoot = true
            self.refResolver = RefResolver()
        }
        
        guard case let .object(jsonProps, _) = json else {
            if case let .boolean(b, _) = json {
                itemShouldBePresent = b
            }
            
            validators = []
            properties = [:]
            patternProperties = [:]
            definitions = [:]
            return
        }
        
        let props = try objectPropsOrThrow("Object key is not a string", props: jsonProps)
        
        if let ref = props["$ref"] {
            guard case let .string(str, _) = ref else {
                throw ValidationError("'$ref' field must be a string", sourceLocation: props["$ref"]!.sourcePosition)
            }
            
            refId = str
            self.refResolver.addRefToResolve(str, sourcePosition: ref.sourcePosition)
        }
        
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
                    let validator = try v.value.init(validatorJson, refResolver: self.refResolver, refPath: refPath)
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
                        properties[p.key] = try Schema(p.value, refResolver: self.refResolver, refPath: refPath + ["properties", p.key])
            
                    } catch let e as ValidationError {
                        errors.append(e)
                    }
                }
            } catch let e as ValidationError {
                errors.append(e)
                break breakProps
            }
        }
        
        patternProperties = [:]
        
        // Extract schemas from patternProperties
        breakPattProps: if let objProps = props["patternProperties"] {
            guard case let .object(obj, _) = objProps else {
                errors.append(ValidationError("'patternProperties' should be an object", sourceLocation: objProps.sourcePosition))
                break breakPattProps
            }
            
            do {
                let strProps = try objectPropsOrThrow("'patternProperties' should be an object", props: obj)
                
                for p in strProps {
                    do {
                        let key = try NSRegularExpression(pattern: p.key, options: [])
                        patternProperties[key] = try Schema(p.value, refResolver: self.refResolver, refPath: refPath + ["patternProperties", p.key])
                        
                    } catch let e as ValidationError {
                        errors.append(e)
                    } catch {
                        let keyIndex = Array(strProps.keys).index(of: p.key)
                        
                        errors.append(ValidationError("Pattern is not a valid regular expression",
                                                      sourceLocation: Array(obj.keys)[keyIndex!].sourcePosition))
                    }
                }
            } catch let e as ValidationError {
                errors.append(e)
                break breakPattProps
            }
        }
        
        // Extract schemas from definitions
        
        definitions = [:]
        breakDefinitions: if let objProps = props["definitions"] {
            guard case let .object(obj, _) = objProps else {
                errors.append(ValidationError("'definitions' should be an object", sourceLocation: objProps.sourcePosition))
                break breakDefinitions
            }
            
            do {
                let strProps = try objectPropsOrThrow("'definitions' should be an object", props: obj)
                
                for p in strProps {
                    do {
                        definitions[p.key] = try Schema(p.value, refResolver: self.refResolver, refPath: refPath + ["definitions", p.key])
                    } catch let e as ValidationError {
                        errors.append(e)
                    }
                }
            } catch let e as ValidationError {
                errors.append(e)
                break breakDefinitions
            }
        }
        
        if refResolver == nil {
            if refPath.count == 0 {
                self.refResolver.addReference(refPath, forSchema: self)
            }
        } else {
            if refPath.count > 0 {
                self.refResolver.addReference(refPath, forSchema: self)
            }
        }
        
        let recognizedProps: [String] = [
            "$id",
            "title",
            "description",
            "additionalItems",
            "contains",
            "dependencies",
            "definitions",
            "properties"
        ] + Array(validatorTypes.keys)
        
        for prop in props {
            if !recognizedProps.contains(prop.key) {
                do {
                    _ = try Schema(prop.value, refResolver: self.refResolver, refPath: refPath + [prop.key])
                } catch let e as ValidationError {
                    errors.append(e)
                }
            }
        }
        
        // Try and resolve all references
        if isRoot {
            do {
                try self.refResolver.validateRefsResolve()
            } catch let e as ValidationError {
                errors.append(e)
            }
        }
        
        // Collect all errors and throw as one
        if errors.count > 0 {
            throw ValidationError(errors.flatMap { $0.errors })
        }
        
    }
    
    func validate(_ json: JSONValue) throws {
        if refId != nil {
            try refResolver.getSchemaRef(refId!,
                                         sourceLocation: JSONSourcePosition(line: -1, column: -1, source: "")).validate(json)
            return
        }
        
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
