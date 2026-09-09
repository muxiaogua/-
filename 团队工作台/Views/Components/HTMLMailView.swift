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
                background-color: transparent !important;
                word-wrap: break-word;
                -webkit-font-smoothing: antialiased;
            }
            a {
                color: #007AFF !important;
                text-decoration: underline !important;
                cursor: pointer;
            }
            @media (prefers-color-scheme: dark) {
                a {
                    color: #0A84FF !important;
                }
            }
            table {
                max-width: 100% !important;
                box-sizing: border-box !important;
            }
            img {
                max-width: 100% !important;
                height: auto !important;
            }
            
            /* High-contrast Red highlights */
            .apple-mail-highlight-red {
                color: #D70015 !important;
            }
            @media (prefers-color-scheme: dark) {
                .apple-mail-highlight-red {
                    color: #FF453A !important;
                }
                .apple-mail-dark-text-adapted {
                    color: #F2F2F7 !important;
                }
            }
            
            /* Suppress all horizontal lines and decorative rules */
            hr {
                display: none !important;
                visibility: hidden !important;
                height: 0 !important;
            }
        </style>
        <script>
            function adaptMailContent() {
                const isDark = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
                
                // 1. Remove all HR tags
                document.querySelectorAll("hr").forEach(el => el.remove());
                
                const allElements = document.querySelectorAll("*");
                
                function parseRGB(c) {
                    if (!c || c === "transparent" || c.startsWith("rgba(0, 0, 0, 0)")) return null;
                    const match = c.match(/rgba?\((\d+),\s*(\d+),\s*(\d+)/);
                    if (match) {
                        return { r: parseInt(match[1]), g: parseInt(match[2]), b: parseInt(match[3]) };
                    }
                    return null;
                }
                
                function isRedColor(str, compColor) {
                    if (str) {
                        const s = str.toLowerCase();
                        if (s.includes('red') || s.includes('#ff') || s.includes('#ee') || s.includes('#dd') || s.includes('#cc') || s.includes('#c0') || s.includes('#d0') || s.includes('#e0')) return true;
                    }
                    const rgb = parseRGB(compColor || str);
                    if (rgb) {
                        if (rgb.r > 130 && rgb.r > rgb.g * 1.4 && rgb.r > rgb.b * 1.4) return true;
                    }
                    return false;
                }
                
                function isDarkOrBlackColor(str, compColor) {
                    if (str) {
                        const s = str.toLowerCase().trim();
                        if (s === 'black' || s === '#000' || s === '#000000' || s === '#111' || s === '#222' || s === '#333' || s === '#444' || s === '#1c1c1e' || s === '#2c2c2e') return true;
                    }
                    const rgb = parseRGB(compColor || str);
                    if (rgb) {
                        if (rgb.r < 80 && rgb.g < 80 && rgb.b < 80) return true;
                    }
                    return false;
                }
                
                function isLightOrWhiteBackground(c) {
                    const rgb = parseRGB(c);
                    if (rgb) {
                        if (rgb.r > 210 && rgb.g > 210 && rgb.b > 210) return true;
                    }
                    return false;
                }
                
                allElements.forEach(el => {
                    if (el.tagName === "BODY" || el.tagName === "HTML") return;
                    
                    const style = window.getComputedStyle(el);
                    const bg = style.backgroundColor;
                    
                    // Color adaptations
                    if (el.tagName !== "A" && el.tagName !== "IMG") {
                        const inlineColor = el.style ? el.style.color : '';
                        const fontColor = el.getAttribute ? el.getAttribute('color') : '';
                        const compColor = style.color;
                        
                        if (isRedColor(inlineColor, compColor) || isRedColor(fontColor, compColor)) {
                            el.classList.add('apple-mail-highlight-red');
                            if (el.style) el.style.removeProperty('color');
                            if (el.removeAttribute) el.removeAttribute('color');
                        } else if (isDark) {
                            if (isDarkOrBlackColor(inlineColor, compColor) || isDarkOrBlackColor(fontColor, compColor)) {
                                el.classList.add('apple-mail-dark-text-adapted');
                                if (el.style) el.style.removeProperty('color');
                                if (el.removeAttribute) el.removeAttribute('color');
                            }
                            if (isLightOrWhiteBackground(bg)) {
                                el.style.backgroundColor = 'transparent';
                            }
                            if (el.getAttribute && el.getAttribute('bgcolor')) {
                                const bgAttr = el.getAttribute('bgcolor');
                                if (bgAttr === 'white' || bgAttr === '#ffffff' || bgAttr === '#FFF' || bgAttr === '#FFFFFF') {
                                    el.style.backgroundColor = 'transparent';
                                }
                            }
                        }
                    }
                });
            }
            
            if (document.readyState === "loading") {
                document.addEventListener("DOMContentLoaded", adaptMailContent);
            } else {
                adaptMailContent();
            }
            window.addEventListener("load", adaptMailContent);
            setTimeout(adaptMailContent, 200);
            setTimeout(adaptMailContent, 600);
            
            if (window.matchMedia) {
                window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', adaptMailContent);
            }
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
