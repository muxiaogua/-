//
//  MIMEHTMLParser.swift
//  团队工作台
//

import Foundation

public struct MIMEHTMLParser {
    /// Extracts and decodes the HTML body from a raw RFC822 / MIME email source string.
    public static func extractHTML(from rawSource: String) -> String? {
        let normalized = rawSource.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        
        // 1. Find all boundary strings defined anywhere in the message headers or sub-headers
        var boundaries: [String] = []
        let boundaryPattern = #"(?i)boundary\s*=\s*["']?([^"';\n\r]+)["']?"#
        if let regex = try? NSRegularExpression(pattern: boundaryPattern) {
            let matches = regex.matches(in: normalized, options: [], range: NSRange(location: 0, length: normalized.utf16.count))
            for match in matches {
                if match.numberOfRanges > 1, let range = Range(match.range(at: 1), in: normalized) {
                    let b = String(normalized[range]).trimmingCharacters(in: .whitespaces)
                    if !b.isEmpty && !boundaries.contains(b) {
                        boundaries.append(b)
                    }
                }
            }
        }
        
        // 2. Iterate through all boundary chunks to find the exact leaf text/html part
        for boundary in boundaries {
            let delimiter = "--" + boundary
            let rawParts = normalized.components(separatedBy: delimiter)
            
            for part in rawParts {
                guard let doubleNewlineRange = part.range(of: "\n\n") else { continue }
                let headerBlock = String(part[..<doubleNewlineRange.lowerBound])
                
                // Must be true text/html, NOT a container multipart/related or multipart/alternative
                let isHTML = headerBlock.range(of: "text/html", options: .caseInsensitive) != nil
                let isMultipart = headerBlock.range(of: "multipart", options: .caseInsensitive) != nil
                
                guard isHTML && !isMultipart else {
                    continue
                }
                
                // Found the exact leaf HTML part!
                let isQP = headerBlock.range(of: "quoted-printable", options: .caseInsensitive) != nil
                let isB64 = headerBlock.range(of: "base64", options: .caseInsensitive) != nil
                let charset = extractCharset(from: headerBlock)
                
                var body = String(part[doubleNewlineRange.upperBound...])
                if let endPos = body.range(of: "\n--") {
                    body = String(body[..<endPos.lowerBound])
                }
                if body.hasSuffix("--") {
                    body = String(body.dropLast(2))
                }
                body = body.trimmingCharacters(in: .whitespacesAndNewlines)
                
                if isQP {
                    return decodeQuotedPrintable(body, charset: charset)
                } else if isB64 {
                    let cleanB64 = body.components(separatedBy: .whitespacesAndNewlines).joined()
                    if let data = Data(base64Encoded: cleanB64) {
                        return decodeDataWithCharset(data, charset: charset)
                    }
                } else {
                    // If body contains Quoted-Printable artifacts like =3D or =E4=
                    if body.contains("=3D") || body.contains("=E4=") || body.contains("=E5=") || body.contains("=20") {
                        return decodeQuotedPrintable(body, charset: charset)
                    }
                    return body
                }
            }
        }
        
        // 3. Regex Fallback: Scan directly for leaf text/html part header and its body
        let partPattern = #"(?i)(?:^|\n)--[^\n]+\n([^\n]*?Content-Type:\s*text/html[^\n]*\n[\s\S]*?\n\n)([\s\S]*?)(?=\n--|\Z)"#
        if let regex = try? NSRegularExpression(pattern: partPattern) {
            if let match = regex.firstMatch(in: normalized, options: [], range: NSRange(location: 0, length: normalized.utf16.count)) {
                if match.numberOfRanges >= 3,
                   let headerRange = Range(match.range(at: 1), in: normalized),
                   let bodyRange = Range(match.range(at: 2), in: normalized) {
                    let headerBlock = String(normalized[headerRange])
                    let body = String(normalized[bodyRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    let isQP = headerBlock.range(of: "quoted-printable", options: .caseInsensitive) != nil || body.contains("=3D") || body.contains("=E4=")
                    let isB64 = headerBlock.range(of: "base64", options: .caseInsensitive) != nil
                    let charset = extractCharset(from: headerBlock)
                    
                    if isQP {
                        return decodeQuotedPrintable(body, charset: charset)
                    } else if isB64 {
                        let cleanB64 = body.components(separatedBy: .whitespacesAndNewlines).joined()
                        if let data = Data(base64Encoded: cleanB64) {
                            return decodeDataWithCharset(data, charset: charset)
                        }
                    } else {
                        return body
                    }
                }
            }
        }
        
        return nil
    }
    
    private static func extractCharset(from headerBlock: String) -> String {
        if let cRange = headerBlock.range(of: "charset=", options: .caseInsensitive) {
            let cSub = headerBlock[cRange.upperBound...]
            let cLine = cSub.prefix(while: { $0 != "\n" && $0 != ";" && $0 != "\r" })
            return cLine.trimmingCharacters(in: CharacterSet(charactersIn: "\" '")).lowercased()
        }
        return "utf-8"
    }
    
    /// Decodes a Quoted-Printable encoded string into clear text using pure byte scanning and charset awareness.
    public static func decodeQuotedPrintable(_ input: String, charset: String = "utf-8") -> String {
        // 1. Remove soft line breaks: = optionally followed by spaces/tabs, then newline
        var text = input
        if let softBreakRegex = try? NSRegularExpression(pattern: #"=[ \t]*\n"#) {
            text = softBreakRegex.stringByReplacingMatches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count), withTemplate: "")
        }
        text = text.replacingOccurrences(of: "=\r\n", with: "").replacingOccurrences(of: "=\n", with: "")
        
        // 2. Scan bytes as raw ASCII byte array
        let asciiBytes = Array(text.utf8)
        var decodedBytes = [UInt8]()
        decodedBytes.reserveCapacity(asciiBytes.count)
        
        var i = 0
        let count = asciiBytes.count
        
        while i < count {
            let byte = asciiBytes[i]
            if byte == 61 /* '=' */ && i + 2 < count {
                let h1 = asciiBytes[i + 1]
                let h2 = asciiBytes[i + 2]
                if let v1 = hexVal(h1), let v2 = hexVal(h2) {
                    decodedBytes.append((v1 << 4) | v2)
                    i += 3
                    continue
                }
            }
            decodedBytes.append(byte)
            i += 1
        }
        
        let data = Data(decodedBytes)
        return decodeDataWithCharset(data, charset: charset)
    }
    
    private static func decodeDataWithCharset(_ data: Data, charset: String) -> String {
        let gbkEncoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
        
        // If charset specifies GBK / GB2312 / GB18030
        if charset.contains("gb") {
            if let str = String(data: data, encoding: gbkEncoding) {
                return str
            }
        }
        
        // Try UTF-8
        if let str = String(data: data, encoding: .utf8) {
            return str
        }
        
        // Fallback to GB18030 / GBK
        if let str = String(data: data, encoding: gbkEncoding) {
            return str
        }
        
        // Fallback to Windows-CP1252 / Latin1
        if let str = String(data: data, encoding: .windowsCP1252) ?? String(data: data, encoding: .isoLatin1) {
            return str
        }
        
        return String(decoding: data, as: UTF8.self)
    }
    
    private static func hexVal(_ byte: UInt8) -> UInt8? {
        switch byte {
        case 48...57: // '0'-'9'
            return byte - 48
        case 65...70: // 'A'-'F'
            return byte - 65 + 10
        case 97...102: // 'a'-'f'
            return byte - 97 + 10
        default:
            return nil
        }
    }
}
