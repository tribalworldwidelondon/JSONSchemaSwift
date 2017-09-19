/*
 
 MIT License
 
 Copyright (c) 2017 Andy Best
 
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

class StringStream {
    var str: String
    var position = 0
    var currentCharacter: Character?
    var nextCharacter: Character?
    var currentCharacterIdx: String.Index
    var nextCharacterIdx: String.Index?
    var characterCount: Int
    
    var currentLine: Int
    var currentColumn: Int
    
    var sourcePosition: JSONSourcePosition {
        return JSONSourcePosition(line: currentLine,
                           column: currentColumn,
                           source: str)
    }
    
    init(source: String) {
        str = source
        characterCount = str.count
        position = 0
        currentCharacterIdx = str.startIndex
        nextCharacterIdx = str.index(after: currentCharacterIdx)
        currentCharacter = str.characters[currentCharacterIdx]
        
        currentLine = 0
        currentColumn = 0
        
        if str.count > 1 {
            nextCharacter = str[nextCharacterIdx!]
        }
    }
    
    func advanceCharacter() {
        if currentCharacter != nil && currentCharacter! == "\n" {
            currentLine += 1
            currentColumn = 0
        } else {
            currentColumn += 1
        }
        
        position += 1
        
        if position >= characterCount
        {
            currentCharacter = nil
            nextCharacter = nil
            return
        }
        
        currentCharacterIdx = nextCharacterIdx!
        currentCharacter = str[currentCharacterIdx]
        
        if position >= characterCount - 1 {
            nextCharacter = nil
        } else {
            nextCharacterIdx = str.index(after: currentCharacterIdx)
            nextCharacter = str[nextCharacterIdx!]
        }
    }
    
    func eatWhitespace() -> Int {
        var count = 0
        while position < characterCount {
            if isWhitespace(currentCharacter!) {
                advanceCharacter()
                count += 1
            } else {
                return count
            }
        }
        return count
    }
    
    func rewind() {
        position = 0
        
        currentCharacterIdx = str.startIndex
        nextCharacterIdx = str.index(after: currentCharacterIdx)
        currentCharacter = str.characters[currentCharacterIdx]
        
        if str.count > 1 {
            nextCharacter = str[nextCharacterIdx!]
        }
    }
}

func characterIsInSet(_ c: Character, set: CharacterSet) -> Bool {
    var found = true
    for ch in String(c).utf16 {
        if !set.contains(UnicodeScalar(ch)!) {
            found = false
        }
    }
    return found
}

func isWhitespace(_ c: Character) -> Bool {
    return characterIsInSet(c, set: CharacterSet.whitespacesAndNewlines)
}
