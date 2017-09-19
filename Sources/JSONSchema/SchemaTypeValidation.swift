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

protocol SchemaTypeValidation {
    /// Returns a validation failure reason if the schema rule is invalid.
    func validRule() -> ValidationResult
    
    /// Returns a validation failure reason if the value does not validate against the schema.
    func validates(_ value: Any) -> ValidationResult
}

enum ValidationResult {
    case valid
    case invalid(String)
}

struct SchemaStringRestrictions: SchemaTypeValidation {
    let minLength: Int?
    let maxLength: Int?
    let pattern: NSRegularExpression?
    
    func validates(_ inp: Any) -> ValidationResult {
        guard let input = inp as? String else {
            return .invalid("Type does not match")
        }
        
        if let min = minLength, input.characters.count < min {
            return .invalid("String \"\(input)\" needs to be more than \(min) characters.")
        }
        
        if let max = maxLength, input.characters.count > max {
            return .invalid("String \"\(input)\" needs to be less that \(max) characters.")
        }
        
        if let regex = pattern {
            let result = regex.firstMatch(in: input, options: [], range: NSMakeRange(0, input.characters.count))
            
            if result == nil {
                return .invalid("String\"\(input)\" does not match \"\(regex.pattern)\"")
            }
        }
        
        return .valid
    }
    
    func validRule() -> ValidationResult {
        if let min = minLength, let max = maxLength, min > max {
            return .invalid("Min length(\(min)) is greater than max length(\(max))")
        }
        
        return .valid
    }
}

struct SchemaIntegerRestrictions: SchemaTypeValidation {
    let minimum: Double?
    let maximum: Double?
    let exclusiveMaximum: Bool?
    let multipleOf: Double?
    
    func validRule() -> ValidationResult {
        return .valid
    }
    
    func validates(_ value: Any) -> ValidationResult {
        guard let i = value as? Int else {
            return .invalid("Type does not match.")
        }
        
        if minimum != nil {
            if Double(i) < minimum! {
                return .invalid("Value \(i) is less than the minimum value \(minimum!)")
            }
        }
        
        if maximum != nil {
            if Double(i) > maximum! {
                return .invalid("Value \(i) is greater than the maximum value \(maximum!)")
            }
        }
        
        if multipleOf != nil {
            if Double(i).truncatingRemainder(dividingBy: multipleOf!) > 0.0 {
                return .invalid("Value \(i) is not a multiple of \(maximum!)")
            }
        }
        
        return .valid
    }
}

struct SchemaArrayRestrictions: SchemaTypeValidation {
    let minItems: Int?
    let maxItems: Int?
    
    func validRule() -> ValidationResult {
        return .valid
    }
    
    func validates(_ value: Any) -> ValidationResult {
        guard let array = value as? [Any] else {
            return .invalid("Type does not match.")
        }
        
        if minItems != nil, array.count < minItems! {
            return .invalid("Number of items (\(array.count)) is less than minimum items (\(minItems!))")
        }
        
        if maxItems != nil, array.count > maxItems! {
            return .invalid("Number of items (\(array.count)) is greater than max items (\(maxItems!))")
        }
        
        
        return .valid
    }
}

