//
//  RichMailTextView.swift
//  团队工作台
//

import SwiftUI
import AppKit

public struct RichMailTextView: NSViewRepresentable {
    public let htmlContent: String
    
    public init(htmlContent: String) {
        self.htmlContent = htmlContent
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    public func makeNSView(context: Context) -> NSTextView {
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.delegate = context.coordinator
        textView.isRichText = true
        
        if let container = textView.textContainer {
            container.lineFragmentPadding = 0
            container.widthTracksTextView = true
        }
        
        loadHTML(into: textView)
        return textView
    }
    
    public func updateNSView(_ textView: NSTextView, context: Context) {
        loadHTML(into: textView)
    }
    
    private func loadHTML(into textView: NSTextView) {
        guard let data = htmlContent.data(using: .utf8) else { return }
        
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        
        if let attrStr = try? NSMutableAttributedString(data: data, options: options, documentAttributes: nil) {
            let fullRange = NSRange(location: 0, length: attrStr.length)
            
            // Adjust colors for dark/light mode and ensure red text pops out brightly
            attrStr.enumerateAttribute(.foregroundColor, in: fullRange) { value, range, _ in
                if let color = value as? NSColor {
                    let r = color.redComponent
                    let g = color.greenComponent
                    let b = color.blueComponent
                    
                    // If it's a red text in the email (red dominant)
                    if r > 0.55 && g < 0.45 && b < 0.45 {
                        attrStr.addAttribute(.foregroundColor, value: NSColor.systemRed, range: range)
                        attrStr.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: 14), range: range)
                    } else if (r < 0.25 && g < 0.25 && b < 0.25) || color == .black {
                        // Standard black/dark text adapts to system labelColor in dark/light mode
                        attrStr.addAttribute(.foregroundColor, value: NSColor.labelColor, range: range)
                    }
                } else {
                    attrStr.addAttribute(.foregroundColor, value: NSColor.labelColor, range: range)
                }
            }
            
            // Ensure proper base font size if missing
            attrStr.enumerateAttribute(.font, in: fullRange) { value, range, _ in
                if let font = value as? NSFont {
                    let isBold = font.fontDescriptor.symbolicTraits.contains(.bold)
                    let newFont = isBold ? NSFont.boldSystemFont(ofSize: max(14, font.pointSize)) : NSFont.systemFont(ofSize: max(13.5, font.pointSize))
                    attrStr.addAttribute(.font, value: newFont, range: range)
                }
            }
            
            textView.textStorage?.setAttributedString(attrStr)
        }
    }
    
    public class Coordinator: NSObject, NSTextViewDelegate {
        public func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
            if let url = link as? URL {
                NSWorkspace.shared.open(url)
                return true
            } else if let linkStr = link as? String, let url = URL(string: linkStr) {
                NSWorkspace.shared.open(url)
                return true
            }
            return false
        }
    }
}
