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

enum JSONValue {
    case object([JSONValue: JSONValue], JSONSourcePosition)
    case array([JSONValue], JSONSourcePosition)
    
    case string(String, JSONSourcePosition)
    case float(Double, JSONSourcePosition)
    case integer(Int, JSONSourcePosition)
    case boolean(Bool, JSONSourcePosition)
    case null(JSONSourcePosition)
    
    var objectRepresentation: Any? {
        switch self {
        case .string(let s, _):
            return s as Any
        
        case .float(let f, _):
            return f
            
        case .integer(let i, _):
            return i
            
        case .boolean(let b, _):
            return b
            
        case .null:
            return nil
            
        case .object(let props, _):
            let kvs: [(String, Any?)] = props.map {
                var key: String = ""
                
                switch $0.key {
                case .string(let s, _):
                    key = s
                default:
                    fatalError("Key should be a string!")
                }
                
                let value = $0.value.objectRepresentation
                
                return (key, value)
            }
            
            var rv = [String: Any?]()
            
            for kv in kvs {
                rv[kv.0] = kv.1
            }
            
            return rv as Any
        
        case .array(let array, _):
            return array.map { $0.objectRepresentation }
        }
    }
}

extension JSONValue: Equatable, Hashable {
    static func ==(lhs: JSONValue, rhs: JSONValue) -> Bool {
        switch (lhs, rhs) {
        case (.string(let a, _), .string(let b, _)) where a == b: return true
        case (.float(let a, _), .float(let b, _)) where a == b: return true
        case (.integer(let a, _), .integer(let b, _)) where a == b: return true
        case (.boolean(let a, _), .boolean(let b, _)) where a == b: return true
        case (.null, .null): return true
        default: return false
        }
    }
    
    var hashValue: Int {
        // Only hash strings, since they are the only types that can be keys
        switch self {
        case .string(let str, _):
            return str.hashValue
        default:
            assertionFailure("Only strings can be hashed.")
            return 0
        }
    }
}

extension JSONValue {
    func valueDescription() -> String {
        switch self {
        case .string(let str, _):
            return "\"\(str)\""
        case .float(let f, _):
            return "\(f)"
        case .integer(let i, _):
            return "\(i)"
        case .boolean(let b, _):
            return b ? "true" : "false"
        case .null:
            return "null"
        default:
            return ""
        }
    }
    
    func asJsonString(indent: Int = 0, initialIndent: Bool = true) -> String {
        let indentStr: String = (0..<indent).reduce("") { s, i in
            return s + "  "
        }
        
        switch self {
        case .array(let a, _):
            var str = indentStr + "[\n"
            
            for val in a.enumerated() {
                str += val.element.asJsonString(indent: indent + 1)
                if val.offset < a.count - 1 {
                    str += ","
                }
                
                str += "\n"
            }
            
            str += indentStr + "]"
            return str
            
        case .object(let obj, _):
            var str = ""
            
            if initialIndent {
                str += indentStr
            }
            
            str += "{\n"
            
            for kv in obj.enumerated() {
                str += kv.element.key.asJsonString(indent: indent + 1)
                str += ": "
                str += kv.element.value.asJsonString(indent: indent + 1, initialIndent: false)
                if kv.offset < obj.count - 1 {
                    str += ","
                }
                str += "\n"
            }
            
            str += indentStr + "}"
            return str
            
        default:
            if initialIndent {
                return indentStr + self.valueDescription()
            } else {
                return self.valueDescription()
            }
        }
    }
}
