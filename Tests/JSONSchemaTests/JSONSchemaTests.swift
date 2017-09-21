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
@testable import JSONSchema

class JSONSchemaTests: XCTestCase {
    
    func harnessLocation() -> String {
        let filePath = #file
        let basePathComponents = (filePath as NSString).pathComponents.dropLast(3)
        let harnessPathComponents = basePathComponents + ["schema-test-harness", "tests", "draft6"]
        
        return NSString.path(withComponents: Array(harnessPathComponents))
    }
    
    func runTestSuite(suiteName: String, file: StaticString = #file, line: UInt = #line) {
        let suitePath = harnessLocation() + "/" + suiteName + ".json"
        
        do {
            let suiteFile = try Data(contentsOf: URL(fileURLWithPath: suitePath))
            let suiteString = String(data: suiteFile, encoding: .utf8)!
            let suiteJson = try JSONReader.read(suiteString)
            
            let tests = try getArrayOrThrow("Invalid test json", json: suiteJson)
            
            print("\tRunning test suite \(suiteName)")
            
            for test in tests {
                guard case let .object(oProps, _) = test else {
                    XCTFail("Test data invalid", file: file, line: line)
                    return
                }
                
                let props = try! objectPropsOrThrow("Invalid test data", props: oProps)
                
                let description = props["description"]?.stringValue
                
                guard let schema = props["schema"] else {
                    XCTFail("No schema in test: \(test.asJsonString())", file: file, line: line)
                    return
                }
                
                let schemaTests = try! getArrayOrThrow("Invalid test data", json: props["tests"]!)
                
                print("\t\tRunning schema test: \"\(description ?? "")\"")
                
                for schemaTestObj in schemaTests {
                    guard case let .object(oTestProps, _) = schemaTestObj else {
                        XCTFail("Test data invalid", file: file, line: line)
                        return
                    }
                    
                    let schemaTest = try! objectPropsOrThrow("Invalid schema test", props: oTestProps)
                    
                    let testDescription = schemaTest["description"]
                    guard let testData = schemaTest["data"] else {
                        XCTFail("No data for test \(schemaTest)", file: file, line: line)
                        return
                    }
                    
                    guard let expectedResult = schemaTest["valid"]?.boolValue else {
                        XCTFail("No result for test \(schemaTest)", file: file, line: line)
                        return
                    }
                    
                    print("\t\t\tRunning test: \(testDescription?.stringValue ?? "")")
                    
                    do {
                        
                        let s = try Schema(schema)
                        
                        do {
                            try s.validate(testData)
                        } catch let e as ValidationError {
                            if expectedResult == true {
                                print("\t\t\t\tFailed.")
                                for errorDesc in e.errors {
                                    print("\t\t\t\t\(errorDesc.0)")
                                }
                                
                                XCTFail("Invalid test result for test \(testDescription?.stringValue ?? ""). Expected validates.", file: file, line: line)
                            } else {
                                print("\t\t\t\tPassed.")
                            }
                            continue
                        }
                        
                        if expectedResult == false {
                            print("\t\t\t\tFailed.")
                            XCTFail("Invalid test result for test \(testDescription?.stringValue ?? ""). Expected to not validate.", file: file, line: line)
                        } else {
                            print("\t\t\t\tPassed.")
                        }
                        
                    } catch {
                        XCTFail("Schema error: \(error)", file: file, line: line)
                    }
                }
            }
            
        } catch {
            XCTFail("Unable to load test suite \(suiteName).json", file: file, line: line)
            return
        }
    }
    
    //    func testAdditionalItems() {
    //        runTestSuite(suiteName: "additionalItems")
    //    }
    //
    //    func testAdditionalProperties() {
    //        runTestSuite(suiteName: "additionalProperties")
    //    }
    //
    //    func testAllOf() {
    //        runTestSuite(suiteName: "allOf")
    //    }
    //
    //    func testAnyOf() {
    //        runTestSuite(suiteName: "anyOf")
    //    }
    //
    func testBooleanSchema() {
        runTestSuite(suiteName: "boolean_schema")
    }
    //
    //    func testConst() {
    //        runTestSuite(suiteName: "const")
    //    }
    //
    //    func testContains() {
    //        runTestSuite(suiteName: "contains")
    //    }
    //
    //    func testDefault() {
    //        runTestSuite(suiteName: "default")
    //    }
    //
    //    func testDefinitions() {
    //        runTestSuite(suiteName: "definitions")
    //    }
    //
    //    func testDependencies() {
    //        runTestSuite(suiteName: "dependencies")
    //    }
    //
    func testEnum() {
        runTestSuite(suiteName: "enum")
    }
    
    func testExclusiveMaximum() {
        runTestSuite(suiteName: "exclusiveMaximum")
    }
    
    func testExclusiveMinimum() {
        runTestSuite(suiteName: "exclusiveMinimum")
    }
    
    func testItems() {
        runTestSuite(suiteName: "items")
    }
    
    func testMaximum() {
        runTestSuite(suiteName: "maximum")
    }
    
    func testMaxItems() {
        runTestSuite(suiteName: "maxItems")
    }
    
    func testMaxLength() {
        runTestSuite(suiteName: "maxLength")
    }
    
    func testMaxProperties() {
        runTestSuite(suiteName: "maxProperties")
    }
    
    func testMinimum() {
        runTestSuite(suiteName: "minimum")
    }
    
    func testMinItems() {
        runTestSuite(suiteName: "minItems")
    }
    
    func testMinLength() {
        runTestSuite(suiteName: "minLength")
    }
    
    func testMinProperties() {
        runTestSuite(suiteName: "minProperties")
    }
    
    func testMultipleOf() {
        runTestSuite(suiteName: "multipleOf")
    }
    //
    //    func testNot() {
    //        runTestSuite(suiteName: "not")
    //    }
    //
    //    func testOneOf() {
    //        runTestSuite(suiteName: "oneOf")
    //    }
    //
    func testPattern() {
        runTestSuite(suiteName: "pattern")
    }
    //
    //    func testPatternProperties() {
    //        runTestSuite(suiteName: "patternProperties")
    //    }
    //
    //    func testProperties() {
    //        runTestSuite(suiteName: "properties")
    //    }
    
    func testPropertyNames() {
        runTestSuite(suiteName: "propertyNames")
    }
    //
    //    func testRef() {
    //        runTestSuite(suiteName: "ref")
    //    }
    //
    //    func testRefRemote() {
    //        runTestSuite(suiteName: "refRemote")
    //    }
    //
    func testRequired() {
        runTestSuite(suiteName: "required")
    }
    
    func testType() {
        runTestSuite(suiteName: "type")
    }
    
    //    func testUniqueItems() {
    //        runTestSuite(suiteName: "uniqueItems")
    //    }
    
}
