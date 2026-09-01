//
//  HTMLMailView.swift
//  团队工作台
//

import SwiftUI
import WebKit

public struct HTMLMailView: NSViewRepresentable {
    public let htmlContent: String
    
    public init(htmlContent: String) {
        self.htmlContent = htmlContent
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground") // Transparent background
        
        webView.wantsLayer = true
        webView.layer?.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
        
        loadHTML(into: webView)
        return webView
    }
    
    public func updateNSView(_ nsView: WKWebView, context: Context) {
        if context.coordinator.lastLoadedHTML != htmlContent {
            loadHTML(into: nsView)
            context.coordinator.lastLoadedHTML = htmlContent
        }
    }
    
    private func loadHTML(into webView: WKWebView) {
        let injectedStyleAndScript = ##"""
        <style>
            :root { color-scheme: light dark; }
            html, body {
                margin: 0;
                padding: 16px 20px;
                font-family: -apple-system, BlinkMacSystemFont, "SF Hello", "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif !important;
                font-size: 14px;
                line-height: 1.6;
                color: CanvasText;
                background-color: transparent;
                word-wrap: break-word;
                -webkit-font-smoothing: antialiased;
            }
            a {
                color: #007AFF !important;
                text-decoration: underline !important;
                cursor: pointer;
            }
            table {
                max-width: 100% !important;
                box-sizing: border-box !important;
            }
            img {
                max-width: 100% !important;
                height: auto !important;
            }
            
            /* Suppress all horizontal lines and decorative rules */
            hr {
                display: none !important;
                visibility: hidden !important;
                height: 0 !important;
            }
            
            /* Suppress top and bottom green banner boxes, green divider lines, and base64 decorative backgrounds */
            table[style*="58, 122, 86"], table[style*="58,122,86"],
            table[style*="67, 145, 100"], table[style*="67,145,100"],
            table[style*="#3A7A56"], table[style*="#3a7a56"],
            table[style*="#439164"], table[style*="#439164"],
            table[bgcolor*="3A7A56"], table[bgcolor*="3a7a56"],
            table[bgcolor*="439164"], table[bgcolor*="439164"],
            table[style*="base64"],
            td[style*="34, 197, 94"], td[style*="34,197,94"],
            td[style*="58, 122, 86"], td[style*="58,122,86"],
            td[style*="67, 145, 100"], td[style*="67,145,100"],
            td[style*="#3A7A56"], td[style*="#3a7a56"],
            td[style*="#439164"], td[style*="#439164"],
            td[bgcolor*="3A7A56"], td[bgcolor*="3a7a56"],
            td[bgcolor*="439164"], td[bgcolor*="439164"],
            td[style*="base64"],
            div[style*="58, 122, 86"], div[style*="58,122,86"],
            div[style*="67, 145, 100"], div[style*="67,145,100"],
            div[style*="#3A7A56"], div[style*="#3a7a56"],
            div[style*="#439164"], div[style*="#439164"] {
                display: none !important;
            }
            
            /* Remove green borders */
            *[style*="border"][style*="58, 122, 86"],
            *[style*="border"][style*="58,122,86"],
            *[style*="border"][style*="67, 145, 100"],
            *[style*="border"][style*="67,145,100"],
            *[style*="border"][style*="#3a7a56"],
            *[style*="border"][style*="#3A7A56"],
            *[style*="border"][style*="#439164"],
            *[style*="border"][style*="#22c55e"],
            *[style*="border"][style*="#22C55E"] {
                border: none !important;
                border-top: none !important;
                border-bottom: none !important;
            }
        </style>
        <script>
            function cleanGreenDividersAndBanners() {
                // 1. Remove all HR tags
                document.querySelectorAll("hr").forEach(el => el.remove());
                
                // 2. Scan all elements to detect green backgrounds, green borders, or thin divider strips
                const allElements = document.querySelectorAll("*");
                allElements.forEach(el => {
                    if (el.tagName === "BODY" || el.tagName === "HTML") return;
                    
                    const style = window.getComputedStyle(el);
                    const bg = style.backgroundColor;
                    const bt = style.borderTopColor;
                    const bb = style.borderBottomColor;
                    const bl = style.borderLeftColor;
                    const br = style.borderRightColor;
                    
                    function isGreenColor(c) {
                        if (!c || c === "transparent" || c.startsWith("rgba(0, 0, 0, 0)")) return false;
                        const match = c.match(/rgba?\((\d+),\s*(\d+),\s*(\d+)/);
                        if (match) {
                            const r = parseInt(match[1]), g = parseInt(match[2]), b = parseInt(match[3]);
                            // Detect shades of green
                            if (g > 60 && g > r * 1.15 && g > b * 1.15) return true;
                            if (g > 90 && r < 120 && b < 120) return true;
                        }
                        return false;
                    }
                    
                    if (isGreenColor(bg)) {
                        if (el.offsetHeight <= 15 || el.offsetWidth > 400 || el.textContent.trim().length === 0) {
                            el.remove();
                            return;
                        } else {
                            el.style.backgroundColor = "transparent";
                        }
                    }
                    
                    if (isGreenColor(bt)) el.style.borderTop = "none";
                    if (isGreenColor(bb)) el.style.borderBottom = "none";
                    if (isGreenColor(bl)) el.style.borderLeft = "none";
                    if (isGreenColor(br)) el.style.borderRight = "none";
                });
                
                // 3. Strip trailing empty containers / dividers at the bottom
                while (document.body && document.body.lastElementChild) {
                    const last = document.body.lastElementChild;
                    if (last.offsetHeight === 0 || last.textContent.trim().length === 0 || last.tagName === "HR" || last.tagName === "BR") {
                        last.remove();
                    } else {
                        break;
                    }
                }
            }
            
            if (document.readyState === "loading") {
                document.addEventListener("DOMContentLoaded", cleanGreenDividersAndBanners);
            } else {
                cleanGreenDividersAndBanners();
            }
            window.addEventListener("load", cleanGreenDividersAndBanners);
            setTimeout(cleanGreenDividersAndBanners, 200);
            setTimeout(cleanGreenDividersAndBanners, 600);
        </script>
        """##
        
        let hasHTMLWrapper = htmlContent.localizedCaseInsensitiveContains("<html") || htmlContent.localizedCaseInsensitiveContains("<!DOCTYPE")
        
        let finalHTMLToLoad: String
        if hasHTMLWrapper {
            if let headEnd = htmlContent.range(of: "</head>", options: .caseInsensitive) {
                var modified = htmlContent
                modified.insert(contentsOf: injectedStyleAndScript, at: headEnd.lowerBound)
                finalHTMLToLoad = modified
            } else {
                finalHTMLToLoad = injectedStyleAndScript + htmlContent
            }
        } else {
            finalHTMLToLoad = """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="utf-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                \(injectedStyleAndScript)
            </head>
            <body>
                \(htmlContent)
            </body>
            </html>
            """
        }
        
        webView.loadHTMLString(finalHTMLToLoad, baseURL: nil)
    }
    
    public class Coordinator: NSObject, WKNavigationDelegate {
        var parent: HTMLMailView
        var lastLoadedHTML: String = ""
        
        init(_ parent: HTMLMailView) {
            self.parent = parent
        }
        
        // Intercept link clicks and open via native macOS URL handler (supports core:// and https://)
        public func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            if navigationAction.navigationType == .linkActivated {
                if let url = navigationAction.request.url {
                    NSWorkspace.shared.open(url)
                }
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
}
