//
//  MIMEHTMLParser.swift
//  团队工作台
//

import Foundation
import AppKit
import PDFKit

public struct MIMEHTMLParser {
    /// Extracts and decodes the HTML body from a raw RFC822 / MIME email source string.
    /// 同时自动扫描并内联全部 CID 图片附件为 Base64 data:image URL，确保图片脱机 100% 可见
    public static func extractHTML(from rawSource: String, fallbackPlainText: String? = nil) -> String? {
        let normalized = rawSource.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        
        // 1. 扫描邮件源文件中所有的图片附件（抽取 Content-ID 与 Base64 数据）
        let cidInfo = extractCIDImageMap(from: normalized)
        
        // 2. Find all boundary strings defined anywhere in the message headers or sub-headers
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
        
        var htmlCandidates: [String] = []
        
        // 3. Iterate through all boundary chunks to find candidate leaf text/html parts
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
                
                let isQP = headerBlock.range(of: "quoted-printable", options: .caseInsensitive) != nil
                let isB64 = headerBlock.range(of: "base64", options: .caseInsensitive) != nil
                let charset = extractCharset(from: headerBlock)
                
                var body = String(part[doubleNewlineRange.upperBound...])
                if body.hasSuffix("--") {
                    body = String(body.dropLast(2))
                }
                body = body.trimmingCharacters(in: .whitespacesAndNewlines)
                
                var decoded: String? = nil
                if isQP {
                    decoded = decodeQuotedPrintable(body, charset: charset)
                } else if isB64 {
                    let cleanB64 = body.components(separatedBy: .whitespacesAndNewlines).joined()
                    if let data = Data(base64Encoded: cleanB64) {
                        decoded = decodeDataWithCharset(data, charset: charset)
                    }
                } else {
                    if body.contains("=3D") || body.contains("=E4=") || body.contains("=E5=") || body.contains("=20") {
                        decoded = decodeQuotedPrintable(body, charset: charset)
                    } else {
                        decoded = body
                    }
                }
                if let dec = decoded, !dec.isEmpty {
                    htmlCandidates.append(dec)
                }
            }
        }
        
        // 4. Regex Fallback: Scan directly for leaf text/html part header and its body
        if htmlCandidates.isEmpty {
            let partPattern = #"(?i)(?:^|\n)--([^\n\r]+)[\r\n]+([^\n]*?Content-Type:\s*text/html[^\n]*\n[\s\S]*?\n\n)([\s\S]*?)(?=\r?\n--\1|\Z)"#
            if let regex = try? NSRegularExpression(pattern: partPattern) {
                let matches = regex.matches(in: normalized, options: [], range: NSRange(location: 0, length: normalized.utf16.count))
                for match in matches {
                    if match.numberOfRanges >= 4,
                       let headerRange = Range(match.range(at: 2), in: normalized),
                       let bodyRange = Range(match.range(at: 3), in: normalized) {
                        let headerBlock = String(normalized[headerRange])
                        let body = String(normalized[bodyRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        let isQP = headerBlock.range(of: "quoted-printable", options: .caseInsensitive) != nil || body.contains("=3D") || body.contains("=E4=")
                        let isB64 = headerBlock.range(of: "base64", options: .caseInsensitive) != nil
                        let charset = extractCharset(from: headerBlock)
                        
                        var decoded: String? = nil
                        if isQP {
                            decoded = decodeQuotedPrintable(body, charset: charset)
                        } else if isB64 {
                            let cleanB64 = body.components(separatedBy: .whitespacesAndNewlines).joined()
                            if let data = Data(base64Encoded: cleanB64) {
                                decoded = decodeDataWithCharset(data, charset: charset)
                            }
                        } else {
                            decoded = body
                        }
                        if let dec = decoded, !dec.isEmpty {
                            htmlCandidates.append(dec)
                        }
                    }
                }
            }
        }
        
        // 选择实质内容最丰富的候选 HTML（排除仅包含空白 div 的骨架）
        var extractedHTML = htmlCandidates.max(by: { htmlContentScore($0) < htmlContentScore($1) })
        
        // 若 HTML 为空或无任何实质文本/图片，且存在纯文本正文，自动用纯文本构建排版 HTML
        if (extractedHTML == nil || htmlContentScore(extractedHTML!) == 0), let plain = fallbackPlainText, !plain.isEmpty {
            let escaped = plain.replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
            extractedHTML = """
            <!DOCTYPE html>
            <html>
            <head>
            <meta charset="utf-8">
            <style>
            body { font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif; font-size: 14px; line-height: 1.6; color: #1d1d1f; padding: 20px; }
            .plain-box { white-space: pre-wrap; word-wrap: break-word; }
            </style>
            </head>
            <body>
            <div class="plain-box">\(escaped)</div>
            </body>
            </html>
            """
        }
        
        guard let finalBaseHTML = extractedHTML else { return nil }
        
        // 5. 将提取出的 HTML 中的 CID 图片地址无感替换为 Base64 内联图片，同时自动将未引用的附件图片追加展示
        return inlineCIDImages(in: finalBaseHTML, using: cidInfo)
    }
    
    /// 计算 HTML 文本与图片的实质内容丰富度权重（区分真正正文与空白骨架）
    private static func htmlContentScore(_ html: String) -> Int {
        var score = 0
        if html.contains("<img") { score += 5000 }
        let stripped = html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        score += stripped.count
        return score
    }
    
    // MARK: - CID 附件图像提取器 (自动扫描邮件各多分卷中的图片并生成 Base64 Data URL)
    private static func extractCIDImageMap(from normalized: String) -> (map: [String: String], ordered: [String]) {
        var cidMap: [String: String] = [:]
        var orderedImages: [String] = []
        
        // 寻找每个包含 image/ 的分卷
        let partSplitter = #"(?i)\n--[^\n]+\n"#
        guard let regex = try? NSRegularExpression(pattern: partSplitter) else { return (cidMap, orderedImages) }
        
        let matches = regex.matches(in: normalized, options: [], range: NSRange(location: 0, length: normalized.utf16.count))
        var chunkRanges: [Range<String.Index>] = []
        var lastIdx = normalized.startIndex
        for m in matches {
            if let r = Range(m.range, in: normalized) {
                if lastIdx < r.lowerBound {
                    chunkRanges.append(lastIdx..<r.lowerBound)
                }
                lastIdx = r.upperBound
            }
        }
        if lastIdx < normalized.endIndex {
            chunkRanges.append(lastIdx..<normalized.endIndex)
        }
        
        for range in chunkRanges {
            let chunk = String(normalized[range])
            guard let doubleNewline = chunk.range(of: "\n\n") else { continue }
            let headers = String(chunk[..<doubleNewline.lowerBound])
            
            // 必须是图片类型或包含图片扩展名的附件分卷，或内联 PDF (Apple Mail 经常以单页 PDF 形式发送高清大图海报)
            let isImageType = headers.range(of: "Content-Type:\\s*image/", options: [.regularExpression, .caseInsensitive]) != nil
            let isImageExtension = headers.range(of: #"(?i)(?:filename|name)=["']?[^"'\n\r]+\.(png|jpe?g|gif|webp|svg|tiff?)["']?"#, options: .regularExpression) != nil
            let isPDF = headers.range(of: "Content-Type:\\s*application/pdf", options: [.regularExpression, .caseInsensitive]) != nil ||
                        headers.range(of: #"(?i)(?:filename|name)=["']?[^"'\n\r]+\.pdf["']?"#, options: .regularExpression) != nil
            guard isImageType || isImageExtension || isPDF else {
                continue
            }
            
            // 提取 mime 类型 (image/png, image/jpeg, image/tiff 等)
            var mimeType = "image/png"
            if isPDF {
                mimeType = "application/pdf"
            } else if let mimeRegex = try? NSRegularExpression(pattern: #"(?i)Content-Type:\s*(image/[a-zA-Z0-9\-\+\.]+)"#),
               let match = mimeRegex.firstMatch(in: headers, range: NSRange(headers.startIndex..., in: headers)),
               let r = Range(match.range(at: 1), in: headers) {
                mimeType = String(headers[r]).lowercased()
            } else if let fnMatch = headers.range(of: #"(?i)(?:filename|name)=["']?[^"'\n\r]+\.(png|jpe?g|gif|webp|svg|tiff?)["']?"#, options: .regularExpression) {
                let matchedStr = String(headers[fnMatch]).lowercased()
                if matchedStr.contains(".jpg") || matchedStr.contains(".jpeg") { mimeType = "image/jpeg" }
                else if matchedStr.contains(".gif") { mimeType = "image/gif" }
                else if matchedStr.contains(".webp") { mimeType = "image/webp" }
                else if matchedStr.contains(".svg") { mimeType = "image/svg+xml" }
                else { mimeType = "image/png" }
            }
            
            // 提取 Content-ID: <xxx>
            var contentID: String? = nil
            if let cidRegex = try? NSRegularExpression(pattern: #"(?i)Content-ID:\s*<([^>]+)>"#),
               let match = cidRegex.firstMatch(in: headers, range: NSRange(headers.startIndex..., in: headers)),
               let r = Range(match.range(at: 1), in: headers) {
                contentID = String(headers[r]).trimmingCharacters(in: .whitespaces)
            }
            
            // 提取文件名 filename="xxx" 或 name="xxx"
            var filename: String? = nil
            if let fnRegex = try? NSRegularExpression(pattern: #"(?i)(?:filename|name)=["']?([^"';\n\r]+)["']?"#),
               let match = fnRegex.firstMatch(in: headers, range: NSRange(headers.startIndex..., in: headers)),
               let r = Range(match.range(at: 1), in: headers) {
                filename = String(headers[r]).trimmingCharacters(in: .whitespaces)
            }
            
            // 提取 Base64 编码的图片数据
            var rawBody = String(chunk[doubleNewline.upperBound...])
            if let endPos = rawBody.range(of: "\n--") {
                rawBody = String(rawBody[..<endPos.lowerBound])
            }
            let cleanB64 = rawBody.components(separatedBy: .whitespacesAndNewlines).joined()
            guard !cleanB64.isEmpty, cleanB64.count > 100 else { continue }
            
            // 如果是 PDF 附件海报，用 PDFKit 渲染为高清 JPEG
            if isPDF {
                if let rawData = Data(base64Encoded: cleanB64),
                   let pdfDoc = PDFDocument(data: rawData) {
                    for pageIdx in 0..<pdfDoc.pageCount {
                        if let page = pdfDoc.page(at: pageIdx) {
                            let pageRect = page.bounds(for: .mediaBox)
                            let img = NSImage(size: pageRect.size, flipped: false) { rect in
                                guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
                                ctx.setFillColor(NSColor.white.cgColor)
                                ctx.fill(rect)
                                page.draw(with: .mediaBox, to: ctx)
                                return true
                            }
                            if let tiff = img.tiffRepresentation,
                               let rep = NSBitmapImageRep(data: tiff),
                               let jpgData = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.85]) {
                                let dataUrl = "data:image/jpeg;base64,\(jpgData.base64EncodedString())"
                                orderedImages.append(dataUrl)
                            }
                        }
                    }
                }
                continue
            }
            
            var finalMime = mimeType
            var finalB64 = cleanB64
            // 如果是 tiff 格式，转成通用的 png
            if mimeType.contains("tiff") {
                if let rawData = Data(base64Encoded: cleanB64),
                   let rep = NSBitmapImageRep(data: rawData),
                   let pngData = rep.representation(using: .png, properties: [:]) {
                    finalMime = "image/png"
                    finalB64 = pngData.base64EncodedString()
                }
            }
            
            let dataUrl = "data:\(finalMime);base64,\(finalB64)"
            orderedImages.append(dataUrl)
            
            if let cid = contentID {
                cidMap[cid.lowercased()] = dataUrl
                cidMap["cid:" + cid.lowercased()] = dataUrl
            }
            if let fn = filename {
                let cleanFn = fn.lowercased().replacingOccurrences(of: "%20", with: " ")
                cidMap[cleanFn] = dataUrl
                cidMap["cid:" + cleanFn] = dataUrl
            }
        }
        
        return (cidMap, orderedImages)
    }
    
    // MARK: - 将 HTML 中的 CID 引用安全替换为 Data URL
    private static func inlineCIDImages(in html: String, using cidInfo: (map: [String: String], ordered: [String])) -> String {
        let cidMap = cidInfo.map
        let orderedImages = cidInfo.ordered
        guard !cidMap.isEmpty || !orderedImages.isEmpty else { return html }
        var result = html
        
        // 匹配各类 <img ... src="cid:..." 或 id="<...>" 或 alt="..." 属性>
        let imgPattern = #"(?i)<img\b[^>]*>"#
        guard let imgRegex = try? NSRegularExpression(pattern: imgPattern) else { return html }
        
        let matches = imgRegex.matches(in: html, range: NSRange(html.startIndex..., in: html))
        
        // 顺序匹配：找出所有需要替换的匹配项与对应的 dataUrl
        var replacements: [(range: Range<String.Index>, dataUrl: String, oldTag: String)] = []
        var fallbackIdx = 0
        
        for match in matches {
            guard let r = Range(match.range, in: result) else { continue }
            let imgTag = String(result[r])
            
            var matchedDataUrl: String? = nil
            
            // 1. 尝试从 src="cid:..." 匹配
            if let srcRegex = try? NSRegularExpression(pattern: #"(?i)src=["']?(?:cid:)?([^"'\s>]+)["']?"#),
               let srcMatch = srcRegex.firstMatch(in: imgTag, range: NSRange(imgTag.startIndex..., in: imgTag)),
               let srcRange = Range(srcMatch.range(at: 1), in: imgTag) {
                let srcVal = String(imgTag[srcRange]).lowercased().replacingOccurrences(of: "%20", with: " ").trimmingCharacters(in: CharacterSet(charactersIn: "<>\"' "))
                matchedDataUrl = cidMap[srcVal] ?? cidMap["cid:" + srcVal]
            }
            
            // 2. 尝试从 alt="..." 文件名匹配
            if matchedDataUrl == nil {
                if let altRegex = try? NSRegularExpression(pattern: #"(?i)alt=["']([^"']+)["']"#),
                   let altMatch = altRegex.firstMatch(in: imgTag, range: NSRange(imgTag.startIndex..., in: imgTag)),
                   let altRange = Range(altMatch.range(at: 1), in: imgTag) {
                    let altVal = String(imgTag[altRange]).lowercased().replacingOccurrences(of: "%20", with: " ").replacingOccurrences(of: "\u{202F}", with: " ").trimmingCharacters(in: .whitespaces)
                    matchedDataUrl = cidMap[altVal]
                }
            }
            
            // 3. 尝试从 id="<...>" 匹配
            if matchedDataUrl == nil {
                if let idRegex = try? NSRegularExpression(pattern: #"(?i)id=["']?(?:&lt;|<)?([^"'>&]+)(?:&gt;|>)?["']?"#),
                   let idMatch = idRegex.firstMatch(in: imgTag, range: NSRange(imgTag.startIndex..., in: imgTag)),
                   let idRange = Range(idMatch.range(at: 1), in: imgTag) {
                    let idVal = String(imgTag[idRange]).lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "<>\"' "))
                    matchedDataUrl = cidMap[idVal] ?? cidMap["cid:" + idVal]
                }
            }
            
            // 4. 序号保底匹配：如果包含 cid: 但未能命中特定 key，则按出现顺序兜底映射附件图片
            if matchedDataUrl == nil && imgTag.localizedCaseInsensitiveContains("cid:") {
                if fallbackIdx < orderedImages.count {
                    matchedDataUrl = orderedImages[fallbackIdx]
                    fallbackIdx += 1
                }
            }
            
            if let dataUrl = matchedDataUrl {
                replacements.append((range: r, dataUrl: dataUrl, oldTag: imgTag))
            }
        }
        
        // 从后往前替换，保持字符索引有效
        for rep in replacements.reversed() {
            var newImgTag = rep.oldTag
            if newImgTag.range(of: #"(?i)\bsrc=["']"#, options: .regularExpression) != nil {
                if let replaceSrcRegex = try? NSRegularExpression(pattern: #"(?i)src=["'][^"']*["']"#) {
                    newImgTag = replaceSrcRegex.stringByReplacingMatches(in: newImgTag, range: NSRange(newImgTag.startIndex..., in: newImgTag), withTemplate: "src=\"\(rep.dataUrl)\"")
                }
            } else {
                newImgTag = newImgTag.replacingOccurrences(of: "<img", with: "<img src=\"\(rep.dataUrl)\"")
                if !newImgTag.contains("src=") {
                    newImgTag = newImgTag.replacingOccurrences(of: "<IMG", with: "<IMG src=\"\(rep.dataUrl)\"")
                }
            }
            result.replaceSubrange(rep.range, with: newImgTag)
        }
        
        // 关键增强：如果邮件分卷中包含图片附件（如直接粘贴或附加的图片），
        // 但 HTML 中并未通过 <img> 标签引用它们，自动将所有未内联的图片追加到 HTML 正文中！
        if !orderedImages.isEmpty {
            var unreferencedImages: [String] = []
            for imgUrl in orderedImages {
                if !result.contains(imgUrl) {
                    unreferencedImages.append(imgUrl)
                }
            }
            
            if !unreferencedImages.isEmpty {
                var imagesHTML = "<div class=\"mail-inline-attachments\" style=\"margin: 20px auto; display: flex; flex-direction: column; gap: 20px; align-items: center; max-width: 100%;\">"
                for imgUrl in unreferencedImages {
                    imagesHTML += "<div style=\"width: 100%; text-align: center; margin-bottom: 12px;\"><img src=\"\(imgUrl)\" style=\"max-width: 100%; height: auto; border-radius: 8px; box-shadow: 0 4px 12px rgba(0,0,0,0.08); display: inline-block;\" /></div>"
                }
                imagesHTML += "</div>"
                
                if let bodyClose = result.range(of: "</body>", options: .caseInsensitive) {
                    result.insert(contentsOf: imagesHTML, at: bodyClose.lowerBound)
                } else {
                    result += imagesHTML
                }
            }
        }
        
        return result
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
