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

public struct JSONSourcePosition {
    let line: Int
    let column: Int
    let source: String
    
    var sourceLine: String {
        return String(source.split(separator: "\n")[line])
    }
    
    var tokenMarker: String {
        // Creates a "^" marker underneath the source line pointing to the token
        var output = ""
        
        // Add marker at appropriate column
        for _ in 0..<(column - 1) {
            output += " "
        }
        
        output += "^"
        return output
    }
}

public enum JSONTokenType {
    case lBrace(JSONSourcePosition)
    case rBrace(JSONSourcePosition)
    case lSquareBracket(JSONSourcePosition)
    case rSquareBracket(JSONSourcePosition)
    case comma(JSONSourcePosition)
    case colon(JSONSourcePosition)
    
    case float(JSONSourcePosition, Double)
    case integer(JSONSourcePosition, Int)
    case string(JSONSourcePosition, String)
    
    /// Symbol token (used for matching 'true', 'false')
    case symbol(JSONSourcePosition, String)
    
    func sourcePosition() -> JSONSourcePosition {
        switch self {
        case .comma(let s): return s
        case .float(let s, _): return s
        case .integer(let s, _): return s
        case .lBrace(let s): return s
        case .lSquareBracket(let s): return s
        case .rBrace(let s): return s
        case .rSquareBracket(let s): return s
        case .string(let s, _): return s
        case .symbol(let s, _): return s
        case .colon(let s): return s
        }
    }
}

public func ==(a: JSONTokenType, b: JSONTokenType) -> Bool {
    switch (a, b) {
    case (.lBrace, .lBrace): return true
    case (.rBrace, .rBrace): return true
    case (.rSquareBracket, .rSquareBracket): return true
    case (.lSquareBracket, .lSquareBracket): return true
    case (.comma, .comma): return true
        
    case (.float(_, let a), .float(_, let b)) where a == b: return true
    case (.integer(_, let a), .integer(_, let b)) where a == b: return true
    case (.string(_, let a), .string(_, let b)) where a == b: return true
    case (.symbol(_, let a), .symbol(_, let b)) where a == b: return true
        
    default: return false
    }
}

protocol JSONTokenMatcher {
    static func isMatch(_ stream:StringStream) -> Bool
    static func getToken(_ stream:StringStream) throws -> JSONTokenType?
}


// MARK: Token Matchers

class LeftBraceTokenMatcher: JSONTokenMatcher {
    static func isMatch(_ stream: StringStream) -> Bool {
        return stream.currentCharacter == "{"
    }
    
    static func getToken(_ stream: StringStream) -> JSONTokenType? {
        if isMatch(stream) {
            stream.advanceCharacter()
            return JSONTokenType.lBrace(JSONSourcePosition(line: stream.currentLine,
                                                           column: stream.currentColumn,
                                                           source: stream.str))
        }
        return nil
    }
}


class RightBraceTokenMatcher: JSONTokenMatcher {
    static func isMatch(_ stream: StringStream) -> Bool {
        return stream.currentCharacter == "}"
    }
    
    static func getToken(_ stream: StringStream) -> JSONTokenType? {
        if isMatch(stream) {
            stream.advanceCharacter()
            return JSONTokenType.rBrace(JSONSourcePosition(line: stream.currentLine,
                                                           column: stream.currentColumn,
                                                           source: stream.str))
        }
        return nil
    }
}


class LeftSquareBracketTokenMatcher: JSONTokenMatcher {
    static func isMatch(_ stream: StringStream) -> Bool {
        return stream.currentCharacter == "["
    }
    
    static func getToken(_ stream: StringStream) -> JSONTokenType? {
        if isMatch(stream) {
            stream.advanceCharacter()
            return JSONTokenType.lSquareBracket(JSONSourcePosition(line: stream.currentLine,
                                                            column: stream.currentColumn,
                                                            source: stream.str))
        }
        return nil
    }
}


class RightSquareBracketTokenMatcher: JSONTokenMatcher {
    static func isMatch(_ stream: StringStream) -> Bool {
        return stream.currentCharacter == "]"
    }
    
    static func getToken(_ stream: StringStream) -> JSONTokenType? {
        if isMatch(stream) {
            stream.advanceCharacter()
            return JSONTokenType.rSquareBracket(JSONSourcePosition(line: stream.currentLine,
                                                                   column: stream.currentColumn,
                                                                   source: stream.str))
        }
        return nil
    }
}


class CommaTokenMatcher: JSONTokenMatcher {
    static func isMatch(_ stream: StringStream) -> Bool {
        return stream.currentCharacter == ","
    }
    
    static func getToken(_ stream: StringStream) -> JSONTokenType? {
        if isMatch(stream) {
            stream.advanceCharacter()
            return JSONTokenType.comma(JSONSourcePosition(line: stream.currentLine,
                                                          column: stream.currentColumn,
                                                          source: stream.str))
        }
        return nil
    }
}

class ColonTokenMatcher: JSONTokenMatcher {
    static func isMatch(_ stream: StringStream) -> Bool {
        return stream.currentCharacter == ":"
    }
    
    static func getToken(_ stream: StringStream) -> JSONTokenType? {
        if isMatch(stream) {
            stream.advanceCharacter()
            return JSONTokenType.colon(JSONSourcePosition(line: stream.currentLine,
                                                          column: stream.currentColumn,
                                                          source: stream.str))
        }
        return nil
    }
}


class SymbolMatcher: JSONTokenMatcher {
    static var matcherCharacterSet: NSMutableCharacterSet?
    static var matcherStartCharacterSet: NSMutableCharacterSet?
    
    static func isMatch(_ stream: StringStream) -> Bool {
        return characterIsInSet(stream.currentCharacter!, set: startCharacterSet())
    }
    
    static func getToken(_ stream: StringStream) -> JSONTokenType? {
        if isMatch(stream) {
            var tok = ""
            
            while characterIsInSet(stream.currentCharacter!, set: characterSet()) {
                tok += String(stream.currentCharacter!)
                stream.advanceCharacter()
                if stream.currentCharacter == nil {
                    break
                }
            }
            
            return .symbol(JSONSourcePosition(line: stream.currentLine,
                                              column: stream.currentColumn,
                                              source: stream.str), tok)
        }
        return nil
    }
    
    static func characterSet() -> CharacterSet {
        if matcherCharacterSet == nil {
            matcherCharacterSet = NSMutableCharacterSet.letter()
            matcherCharacterSet!.formUnion(with: CharacterSet.decimalDigits)
            matcherCharacterSet!.formUnion(with: CharacterSet.punctuationCharacters)
            matcherCharacterSet!.formUnion(with: NSMutableCharacterSet.symbol() as CharacterSet)
            matcherCharacterSet!.removeCharacters(in: "[]{},:")
        }
        return matcherCharacterSet! as CharacterSet
    }
    
    static func startCharacterSet() -> CharacterSet {
        if matcherStartCharacterSet == nil {
            matcherStartCharacterSet = NSMutableCharacterSet.letter()
            matcherStartCharacterSet!.formUnion(with: CharacterSet.punctuationCharacters)
            matcherStartCharacterSet!.formUnion(with: NSMutableCharacterSet.symbol() as CharacterSet)
            matcherStartCharacterSet!.removeCharacters(in: "[]{},:")
        }
        return matcherStartCharacterSet! as CharacterSet
    }
}


class StringMatcher: JSONTokenMatcher {
    static var matcherCharacterSet: NSMutableCharacterSet?
    
    static func isMatch(_ stream: StringStream) -> Bool {
        return stream.currentCharacter == "\""
    }
    
    static func getToken(_ stream: StringStream) throws -> JSONTokenType? {
        if isMatch(stream) {
            stream.advanceCharacter()
            
            var tok = ""
            var unicodeScalars: [UInt16] = []
            
            func checkScalars() throws {
                if unicodeScalars.count > 0 {
                    let str = String(utf16CodeUnits: unicodeScalars, count: unicodeScalars.count)
                    tok += str
                    
                    unicodeScalars = []
                }
            }
            
            while stream.currentCharacter != nil && !isMatch(stream) {
                let char = stream.currentCharacter!
                
                // Check for escapes
                if char == "\\" {
                    stream.advanceCharacter()
                    
                    guard let escapeChar = stream.currentCharacter else {
                        throw JSONParserError(sourcePosition: stream.sourcePosition,
                                              errorType: .lexer,
                                              message: "Expected escape character")
                    }
                    
                    var escapeResult: String? = nil
                    
                    switch escapeChar {
                    case "n":
                        escapeResult = "\n"
                    case "t":
                        escapeResult = "\t"
                    case "x":
                        stream.advanceCharacter()
                        guard let h1 = stream.currentCharacter else {
                            throw JSONParserError(sourcePosition: stream.sourcePosition,
                                                  errorType: .lexer,
                                                  message: "Error in string: unexpected EOF")
                        }
                        
                        stream.advanceCharacter()
                        guard let h2 = stream.currentCharacter else {
                            throw JSONParserError(sourcePosition: stream.sourcePosition,
                                                  errorType: .lexer,
                                                  message: "Error in string: unexpected EOF")
                        }
                        
                        guard let hexValue = UInt8(String([h1, h2]), radix: 16) else {
                            throw JSONParserError(sourcePosition: stream.sourcePosition,
                                                  errorType: .lexer,
                                                  message: "Error in string: invalid hex escape sequence: \(String([h1, h2]))")
                        }
                        escapeResult = String(Character(UnicodeScalar(hexValue)))
                    case "\"":
                        escapeResult = "\""
                    case "u":
                        stream.advanceCharacter()
                        guard let u1 = stream.currentCharacter else {
                            throw JSONParserError(sourcePosition: stream.sourcePosition,
                                                  errorType: .lexer,
                                                  message: "Error in string: unexpected EOF")
                        }
                        
                        stream.advanceCharacter()
                        guard let u2 = stream.currentCharacter else {
                            throw JSONParserError(sourcePosition: stream.sourcePosition,
                                                  errorType: .lexer,
                                                  message: "Error in string: unexpected EOF")
                        }
                        
                        stream.advanceCharacter()
                        guard let u3 = stream.currentCharacter else {
                            throw JSONParserError(sourcePosition: stream.sourcePosition,
                                                  errorType: .lexer,
                                                  message: "Error in string: unexpected EOF")
                        }
                        
                        stream.advanceCharacter()
                        guard let u4 = stream.currentCharacter else {
                            throw JSONParserError(sourcePosition: stream.sourcePosition,
                                                  errorType: .lexer,
                                                  message: "Error in string: unexpected EOF")
                        }
                        
                        guard let hexValue = UInt16(String([u1, u2, u3, u4]), radix: 16) else {
                            throw JSONParserError(sourcePosition: stream.sourcePosition,
                                                  errorType: .lexer,
                                                  message: "Error in string: invalid unicode escape sequence: \(String([u1, u2, u3, u4]))")
                        }
                        
                        unicodeScalars.append(hexValue)
                        
                    default:
                        throw JSONParserError(sourcePosition: stream.sourcePosition,
                                              errorType: .lexer,
                                              message: "Error in string: Unknown escape character: \\\(escapeChar)")
                    }
                    
                    if escapeResult != nil {
                        tok += escapeResult!
                    }
                    
                    stream.advanceCharacter()
                    
                } else {
                    try checkScalars()
                    
                    tok += String(char)
                    stream.advanceCharacter()
                }
            }
            
            try checkScalars()
            
            if stream.currentCharacter != "\"" {
                throw JSONParserError(sourcePosition: stream.sourcePosition,
                                      errorType: .lexer,
                                      message: "Expected '\"'")
            }
            
            stream.advanceCharacter()
            
            return .string(stream.sourcePosition, tok)
        }
        
        return nil
    }
    
    static func characterSet() -> CharacterSet {
        if matcherCharacterSet == nil {
            matcherCharacterSet = NSMutableCharacterSet.letter()
            matcherCharacterSet!.formUnion(with: CharacterSet.decimalDigits)
            
            let allowedSymbols = NSMutableCharacterSet.symbol()
            allowedSymbols.formIntersection(with:CharacterSet(charactersIn: "\""))
            
            matcherCharacterSet!.formUnion(with: allowedSymbols as CharacterSet)
        }
        return matcherCharacterSet! as CharacterSet
    }
}


class NumberMatcher: JSONTokenMatcher {
    static var matcherCharacterSet: NSMutableCharacterSet?
    static var matcherStartCharacterSet: NSMutableCharacterSet?
    
    static func isMatch(_ stream: StringStream) -> Bool {
        var matches: Bool
        if stream.currentCharacter! == "-" {
            if let next = stream.nextCharacter {
                matches = characterIsInSet(next, set: characterSet())
            } else {
                return false
            }
        } else {
            matches = characterIsInSet(stream.currentCharacter!, set: startCharacterSet())
        }
        return matches
    }
    
    static func getToken(_ stream: StringStream) throws -> JSONTokenType? {
        if isMatch(stream) {
            var tok = ""
            
            tok += String(stream.currentCharacter!)
            stream.advanceCharacter()
            
            while stream.currentCharacter != nil &&
                characterIsInSet(stream.currentCharacter!, set: characterSet()) {
                    tok += String(stream.currentCharacter!)
                    stream.advanceCharacter()
            }
            
            if tok.contains(".") {
                guard let num = Double(tok) else {
                    throw JSONParserError(sourcePosition: stream.sourcePosition,
                                          errorType: .lexer,
                                          message: "\(tok) is not a valid floating point number.")
                }
                return .float(stream.sourcePosition, num)
            } else {
                guard let num = Int(tok) else {
                    throw JSONParserError(sourcePosition: stream.sourcePosition,
                                          errorType: .lexer,
                                          message: "\(tok) is not a valid number.")
                }
                return .integer(stream.sourcePosition, num)
            }
            
        }
        
        return nil
    }
    
    static func characterSet() -> CharacterSet {
        if matcherCharacterSet == nil {
            matcherCharacterSet = NSMutableCharacterSet(charactersIn: "0123456789.")
        }
        return matcherCharacterSet! as CharacterSet
    }
    
    static func startCharacterSet() -> CharacterSet {
        if matcherStartCharacterSet == nil {
            matcherStartCharacterSet = NSMutableCharacterSet(charactersIn: "-0123456789.")
        }
        return matcherStartCharacterSet! as CharacterSet
    }
}


// MARK: - Lexer

// Token matchers in order
let jsonTokenClasses: [JSONTokenMatcher.Type] = [
    LeftBraceTokenMatcher.self,
    RightBraceTokenMatcher.self,
    LeftSquareBracketTokenMatcher.self,
    RightSquareBracketTokenMatcher.self,
    CommaTokenMatcher.self,
    ColonTokenMatcher.self,
    NumberMatcher.self,
    StringMatcher.self,
    SymbolMatcher.self
]


class JSONTokenizer {
    let stream: StringStream
    var currentTokenMatcher: JSONTokenMatcher.Type? = nil
    var currentTokenString: String
    
    init(source: String) {
        self.stream = StringStream(source: source)
        self.currentTokenString = ""
    }
    
    func tokenizeInput() throws -> [JSONTokenType] {
        var tokens = [JSONTokenType]()
        
        while let t = try getNextToken() {
            tokens.append(t)
        }
        
        return tokens
    }
    
    func getNextToken() throws -> JSONTokenType? {
        if stream.position >= stream.str.count {
            return nil
        }
        
        for matcher in jsonTokenClasses {
            if matcher.isMatch(stream) {
                return try matcher.getToken(stream)
            }
        }
        
        let count = stream.eatWhitespace()
        
        if stream.position >= stream.str.count {
            return nil
        }
        
        if stream.currentCharacter == ";" {
            while stream.currentCharacter != "\n" {
                if stream.position >= stream.str.count {
                    return nil
                }
                stream.advanceCharacter()
            }
            stream.advanceCharacter()
            
            if stream.position >= stream.str.count {
                return nil
            }
        } else {
            if count == 0 {
                throw JSONParserError(sourcePosition: stream.sourcePosition,
                                      errorType: .lexer,
                                      message: "Unrecognized character '\(stream.currentCharacter ?? " ".first!)'")
            }
        }
        
        return try getNextToken()
    }
}

