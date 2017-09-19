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
            let suiteJson = try JSONSerialization.jsonObject(with: suiteFile, options: [])
            
            guard let tests = suiteJson as? [[String: Any]] else {
                XCTFail("Invalid test suite format: \(suitePath)", file: file, line: line)
                return
            }
            
            print("\tRunning test suite \(suiteName)")
            
            for test in tests {
                let description = test["description"]
                guard let schema = test["schema"] else {
                    XCTFail("No schema in test: \(test)", file: file, line: line)
                    return
                }
                
                guard let schemaTests = test["tests"] as? [[String: Any]] else {
                    XCTFail("No tests: \(test)", file: file, line: line)
                    return
                }
                
                print("\t\tRunning schema test: \"\(description ?? "")\"")
                
                for schemaTest in schemaTests {
                    let testDescription = schemaTest["description"]
                    guard let testData = schemaTest["data"] else {
                        XCTFail("No data for test \(schemaTest)", file: file, line: line)
                        return
                    }
                    
                    guard let expectedResult = schemaTest["valid"] as? Bool else {
                        XCTFail("No result for test \(schemaTest)", file: file, line: line)
                        return
                    }
                    
                    print("\t\t\tRunning test: \(testDescription ?? "")")
                    
                    do {
                        let s = try JsonSchema(schema)
                        let result = s.validates(testData)
                        
                        switch result {
                        case .invalid(_):
                            if expectedResult == true {
                                print("\t\t\t\tFailed.")
                                print("\t\t\t\t\(result)")
                                XCTFail("Invalid test result for test \(testDescription ?? ""). Expected validates.", file: file, line: line)
                            } else {
                                print("\t\t\t\tPassed.")
                            }
                        case .valid:
                            if expectedResult == false {
                                print("\t\t\t\tFailed.")
                                print("\t\t\t\t\(result)")
                                XCTFail("Invalid test result for test \(testDescription ?? ""). Expected to not validate.", file: file, line: line)
                            } else {
                                print("\t\t\t\tPassed.")
                            }
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
    //    func testBooleanSchema() {
    //        runTestSuite(suiteName: "boolean_schema")
    //    }
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
    //    func testEnum() {
    //        runTestSuite(suiteName: "enum")
    //    }
    //
    //    func testExclusiveMaximum() {
    //        runTestSuite(suiteName: "exclusiveMaximum")
    //    }
    //
    //    func testExclusiveMinimum() {
    //        runTestSuite(suiteName: "exclusiveMinimum")
    //    }
    //
    //    func testItems() {
    //        runTestSuite(suiteName: "testItems")
    //    }
    //
    //    func testMaximum() {
    //        runTestSuite(suiteName: "maximum")
    //    }
    //
    //    func testMaxItems() {
    //        runTestSuite(suiteName: "maxItems")
    //    }
    //
    //    func testMaxLength() {
    //        runTestSuite(suiteName: "maxLength")
    //    }
    //
    //    func testMaxProperties() {
    //        runTestSuite(suiteName: "maxProperties")
    //    }
    //
    //    func testMinimum() {
    //        runTestSuite(suiteName: "minimum")
    //    }
    //
    //    func testMinItems() {
    //        runTestSuite(suiteName: "minItems")
    //    }
    //
    //    func testMinLength() {
    //        runTestSuite(suiteName: "minLength")
    //    }
    //
    //    func testMinProperties() {
    //        runTestSuite(suiteName: "minProperties")
    //    }
    //
    //    func testMultipleOf() {
    //        runTestSuite(suiteName: "multipleOf")
    //    }
    //
    //    func testNot() {
    //        runTestSuite(suiteName: "not")
    //    }
    //
    //    func testOneOf() {
    //        runTestSuite(suiteName: "oneOf")
    //    }
    //
    //    func testPattern() {
    //        runTestSuite(suiteName: "pattern")
    //    }
    //
    func testPatternProperties() {
        runTestSuite(suiteName: "patternProperties")
    }
    
    func testProperties() {
        runTestSuite(suiteName: "properties")
    }
    
    //    func testPropertyNames() {
    //        runTestSuite(suiteName: "propertyNames")
    //    }
    //
    //    func testRef() {
    //        runTestSuite(suiteName: "ref")
    //    }
    //
    //    func testRefRemote() {
    //        runTestSuite(suiteName: "refRemote")
    //    }
    //
    //    func testRequired() {
    //        runTestSuite(suiteName: "required")
    //    }
    
    func testType() {
        runTestSuite(suiteName: "type")
    }
    
    //    func testUniqueItems() {
    //        runTestSuite(suiteName: "uniqueItems")
    //    }

}
