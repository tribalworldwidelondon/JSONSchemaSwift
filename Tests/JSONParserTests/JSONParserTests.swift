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

import XCTest

@testable import JSONParser

class JSONParserTests: XCTestCase {
    
    func testObjectRepresentation() {
        let src = """
        {
            "string": "Hello, world!",
            "float": 123.456,
            "int": 123456,
            "boolean": true,
            "array": [1, 2, 3, 4, 5],
            "object": {
                "a": 1,
                "b": 2.2
            }
        }
        """
        
        let json = try! JSONReader.read(src)
        
        let expectedRepr: [String: Any] = [
            "string": "Hello, world!",
            "float": 123.456,
            "int": 123456,
            "boolean": true,
            "array": [1, 2, 3, 4, 5],
            "object": [
                "a": 1 as Int,
                "b": 2.2
            ]
        ]
        
        let repr = json.objectRepresentation as! [String: Any]
        
        XCTAssertEqual(repr["string"] as! String, expectedRepr["string"] as! String)
        XCTAssertEqual(repr["float"] as! Double, expectedRepr["float"] as! Double)
        
        let actualA = (repr["object"] as! [String: Any])["a"] as! Int
        let expectedA = (expectedRepr["object"] as! [String: Any])["a"] as! Int

        XCTAssertEqual(actualA, expectedA)
        
    }
    
    func testParsesString() {
        let src = """
        \"Hello, world!\"
        """
        
        let json = try! JSONReader.read(src)
        
        XCTAssertEqual(json, JSONValue.string("Hello, world!",
                                              JSONSourcePosition(line: 0,
                                                                 column: 0,
                                                                 source: "")))
    }
    
    func testParsesFloat() {
        let src = """
        123.456
        """
        
        let json = try! JSONReader.read(src)
        
        XCTAssertEqual(json, JSONValue.float(123.456,
                                              JSONSourcePosition(line: 0,
                                                                 column: 0,
                                                                 source: "")))
    }
    
    func testParsesInteger() {
        let src = """
        123456
        """
        
        let json = try! JSONReader.read(src)
        
        XCTAssertEqual(json, JSONValue.integer(123456,
                                             JSONSourcePosition(line: 0,
                                                                column: 0,
                                                                source: "")))
    }
    
    func testParsesBool() {
        let src = """
        false
        """
        
        let json = try! JSONReader.read(src)
        
        XCTAssertEqual(json, JSONValue.boolean(false,
                                               JSONSourcePosition(line: 0,
                                                                  column: 0,
                                                                  source: "")))
    }
    
    func testCommaAtEndOfArrayThrowsError() {
        let src = """
        [ 1, 2, 3,]
        """
        
        XCTAssertThrowsError(try JSONReader.read(src))
    }
    
    func testCommaAtEndOfObjectThrowsError() {
        let src = """
        { "a": 1, }
        """
        
        XCTAssertThrowsError(try JSONReader.read(src))
    }
    
    func testInvalidSymbolInObjectThrowsError() {
        let src = """
        { "a": foo, }
        """
        
        XCTAssertThrowsError(try JSONReader.read(src))
    }
    
    func testExtraInputThrowsError() {
        let src = """
        1 2
        """
        
        XCTAssertThrowsError(try JSONReader.read(src))
    }
    
    func testCommaAfterObjectThrowsError() {
        let src = """
        { "a": 1 },
        """
        
        XCTAssertThrowsError(try JSONReader.read(src))
    }
    
    func testCommaAfterArrayThrowsError() {
        let src = """
        [1, 2, 3],
        """
        
        XCTAssertThrowsError(try JSONReader.read(src))
    }
    
    func testUnicodeScalarsAreDecoded() {
        let src = "\"\\uD83D\\uDCA9\\uD83D\\uDCA9\""
        
        let val = try! JSONReader.read(src)
        
        guard case let .string(str, _) = val else {
            XCTFail("Should be a string")
            return
        }
        
        XCTAssertEqual(str, "💩💩")
    }
    
}
