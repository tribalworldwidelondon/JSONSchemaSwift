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

// TODO: Investigate splitting string into characters first

class StringStream {
    var position = 0
    var characters: [Character]
    var source: String
    
    var currentCharacter: Character? {
        if position >= characters.count {
            return nil
        }
        
        return characters[position]
    }
    
    var nextCharacter: Character? {
        if position < characters.count - 1 {
            return characters[position + 1]
        }
        return nil
    }
    
    var currentLine: Int
    var currentColumn: Int
    
    var sourcePosition: JSONSourcePosition {
        return JSONSourcePosition(line: currentLine,
                           column: currentColumn,
                           source: source)
    }
    
    init(source: String) {
        characters = []
        characters.reserveCapacity(source.count)
        
        for c in source {
            characters.append(c)
        }
        
        self.source = source
        
        position = 0
        currentLine = 0
        currentColumn = 0
    }
    
    func advanceCharacter() {
        if currentCharacter != nil && currentCharacter! == "\n" {
            currentLine += 1
            currentColumn = 0
        } else {
            currentColumn += 1
        }
        
        position += 1
    }
    
    func eatWhitespace() -> Int {
        var count = 0
        while position < characters.count {
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
