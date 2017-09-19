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

class JSONReader {
    let tokens: [JSONTokenType]
    var pos = 0
    var currentSourcePosition: JSONSourcePosition?
    
    public static func read(_ input: String) throws -> JSONValue {
        let tokenizer = JSONTokenizer(source: input)
        let tokens    = try tokenizer.tokenizeInput()
        
        let reader = JSONReader(tokens: tokens)
        let value = try reader.read_token(reader.nextToken()!)
        
        if let tok = reader.nextToken() {
            throw JSONParserError(sourcePosition: tok.sourcePosition(),
                                  errorType: .parser,
                                  message: "Expected EOF: \(tok)")
        }
        
        return value
    }
    
    public init(tokens: [JSONTokenType]) {
        self.tokens = tokens
        
        if tokens.count > 0 {
            currentSourcePosition = tokens[0].sourcePosition()
        }
    }
    
    func nextToken() -> JSONTokenType? {
        defer {
            pos += 1
        }
        
        if pos < tokens.count {
            currentSourcePosition = tokens[pos].sourcePosition()
            return tokens[pos]
        }
        
        return nil
    }
    
    func peekNextToken() -> JSONTokenType? {
        if pos < tokens.count {
            return tokens[pos]
        }
        
        return nil
    }
    
    func read_token(_ token: JSONTokenType) throws -> JSONValue {
        switch token {
        case .lBrace(let sourcePosition):
            return try read_object(sourcePosition)
            
        case .lSquareBracket(let sourcePosition):
            return try read_array(sourcePosition)
            
        case .symbol(let sourcePosition, let str):
            switch str {
            case "true":
                return .boolean(true, sourcePosition)
            case "false":
                return .boolean(false, sourcePosition)
            default:
                throw JSONParserError(sourcePosition: sourcePosition,
                                      errorType: .parser,
                                      message: "Invalid symbol: \(str)")
            }
            
        case .string(let sourcePosition, let str):
            return .string(str, sourcePosition)
            
        case .float(let sourcePosition, let num):
            return .float(num, sourcePosition)
            
        case .integer(let sourcePosition, let num):
            return .integer(num, sourcePosition)
            
        case .rBrace(let sourcePosition):
            throw JSONParserError(sourcePosition: sourcePosition,
                                  errorType: .parser,
                                  message: "Unexpected '}'")
            
        case .rSquareBracket(let sourcePosition):
            throw JSONParserError(sourcePosition: sourcePosition,
                                  errorType: .parser,
                                  message: "Unexpected '}'")
            
        case .comma(let sourcePosition):
            throw JSONParserError(sourcePosition: sourcePosition,
                                  errorType: .parser,
                                  message: "Unexpected ','")
        case .colon(let sourcePosition):
            throw JSONParserError(sourcePosition: sourcePosition,
                                  errorType: .parser,
                                  message: "Unexpected ':'")
        }
    }
    
    func read_array(_ sourcePosition: JSONSourcePosition) throws -> JSONValue {
        var array: [JSONValue] = []
        var endOfArray         = false
        var expectedComma      = false
        
        
        while let token = nextToken() {
            switch token {
            case .rSquareBracket:
                endOfArray = true
            case .comma(let s):
                if let nextTok = peekNextToken() {
                    switch nextTok {
                    case .rSquareBracket:
                        throw JSONParserError(sourcePosition: s,
                                              errorType: .parser,
                                              message: "Unexpected ','")
                    default: break
                    }
                }
                
                if expectedComma {
                    expectedComma = false
                } else {
                    throw JSONParserError(sourcePosition: s,
                                          errorType: .parser,
                                          message: "Unexpected ','")
                }
            default:
                if expectedComma {
                    throw JSONParserError(sourcePosition: token.sourcePosition(),
                                          errorType: .parser,
                                          message: "Expected ','")
                } else {
                    array.append(try read_token(token))
                    expectedComma = true
                }
            }
            
            if endOfArray {
                break
            }
        }
        
        if !endOfArray {
            throw JSONParserError(sourcePosition: currentSourcePosition ?? JSONSourcePosition(line: -1,
                                                                                              column: -1,
                                                                                              source: ""),
                                  errorType: .parser,
                                  message: "Expected ']'")
        }
        
        return .array(array, sourcePosition)
    }
    
    func read_object(_ sourcePosition: JSONSourcePosition) throws -> JSONValue {
        var endOfObject = false
        var dict: [JSONValue: JSONValue] = [:]
        
        var currentKey: JSONValue? = nil
        var expectedComma: Bool = false
        var expectedColon: Bool = false
        
        while let token = nextToken() {
            if currentKey == nil {
                // Can either be a string, or right brace.
                switch token {
                case .string(let sp, let str):
                    if expectedComma {
                        throw JSONParserError(sourcePosition: sp,
                                              errorType: .parser,
                                              message: "Unexpected ','")
                    } else {
                        currentKey = JSONValue.string(str, sp)
                        expectedColon = true
                    }
                case .rBrace:
                    endOfObject = true
                case .comma(let sp):
                    if let tok = peekNextToken() {
                        switch tok {
                        case .rBrace:
                            throw JSONParserError(sourcePosition: sp,
                                                  errorType: .parser,
                                                  message: "Unexpected ','")
                        default: break
                        }
                    }
                    
                    if expectedComma {
                        expectedComma = false
                    } else {
                        throw JSONParserError(sourcePosition: sp,
                                              errorType: .parser,
                                              message: "Unexpected ','")
                    }
                default:
                    throw JSONParserError(sourcePosition: token.sourcePosition(),
                                          errorType: .parser,
                                          message: "Expected a string. Got '\(token)'.")
                }
            } else {
                switch token {
                case .colon(let sp):
                    if expectedColon {
                        expectedColon = false
                    } else {
                        throw JSONParserError(sourcePosition: sp,
                                              errorType: .parser,
                                              message: "Unexpected ':'")
                    }
                default:
                    if expectedColon {
                        throw JSONParserError(sourcePosition: token.sourcePosition(),
                                              errorType: .parser,
                                              message: "Expected ':'")
                    } else {
                        dict[currentKey!] = try read_token(token)
                        currentKey = nil
                        expectedComma = true
                    }
                }
            }
            
            if endOfObject {
                break
            }
        }
        
        if !endOfObject {
            throw JSONParserError(sourcePosition: currentSourcePosition ?? JSONSourcePosition(line: -1,
                                                                                              column: -1,
                                                                                              source: ""),
                                  errorType: .parser,
                                  message: "Expected '}'")
        }
        
        return .object(dict, sourcePosition)
    }
}

