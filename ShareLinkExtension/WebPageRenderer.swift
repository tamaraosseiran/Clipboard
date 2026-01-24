//
//  WebPageRenderer.swift
//  ShareLinkExtension
//
//  Free JavaScript rendering using WKWebView (Apple's built-in engine)
//

import Foundation
import WebKit
import OSLog

/// Renders JavaScript-heavy pages using WKWebView and extracts the rendered HTML
class WebPageRenderer: NSObject {
    private let logger = Logger(subsystem: "com.tamaraosseiran.clipboard.share", category: "WebPageRenderer")
    private var webView: WKWebView?
    private var completion: ((String?) -> Void)?
    private var timeoutWorkItem: DispatchWorkItem?
    private var tempContainer: UIView? // Keep container alive
    
    /// Renders a URL and returns the fully rendered HTML (after JavaScript execution)
    static func render(url: URL, timeout: TimeInterval = 8.0, logger: Logger, completion: @escaping (String?) -> Void) {
        let renderer = WebPageRenderer()
        renderer.render(url: url, timeout: timeout, logger: logger, completion: completion)
    }
    
    private func render(url: URL, timeout: TimeInterval, logger: Logger, completion: @escaping (String?) -> Void) {
        self.completion = completion
        
        // Create WKWebView configuration
        let config = WKWebViewConfiguration()
        config.suppressesIncrementalRendering = false
        
        // Create web view (must be on main thread)
        // Note: In extensions, we can't use UIApplication.shared, so we create the webview directly
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Create WKWebView directly (doesn't need to be in view hierarchy to load)
            let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 375, height: 667), configuration: config)
            webView.navigationDelegate = self
            webView.isHidden = true // Keep it hidden
            self.webView = webView
            
            // Keep a strong reference by adding to a temporary container
            // This is needed so the webview doesn't get deallocated
            let container = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
            container.isHidden = true
            container.addSubview(webView)
            self.tempContainer = container // Keep container alive
            
            logger.info("🌐 Loading URL in WKWebView: \(url.absoluteString)")
            
            // Load the URL
            let request = URLRequest(url: url)
            webView.load(request)
            
            // Set timeout
            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                logger.warning("⏱️ WebView render timeout after \(timeout) seconds")
                self.extractHTML()
            }
            self.timeoutWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: workItem)
        }
    }
    
    private func extractHTML() {
        guard let webView = webView else {
            completion?(nil)
            cleanup()
            return
        }
        
        // Extract rendered HTML via JavaScript
        webView.evaluateJavaScript("document.documentElement.outerHTML") { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                self.logger.error("❌ Error extracting HTML: \(error.localizedDescription)")
                self.completion?(nil)
            } else if let html = result as? String {
                self.logger.info("✅ Extracted rendered HTML (\(html.count) chars)")
                self.completion?(html)
            } else {
                self.logger.warning("⚠️ No HTML extracted from WebView")
                self.completion?(nil)
            }
            
            self.cleanup()
        }
    }
    
    private func cleanup() {
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        
        DispatchQueue.main.async { [weak self] in
            self?.webView?.removeFromSuperview()
            self?.webView = nil
            self?.completion = nil
            self?.tempContainer = nil
        }
    }
}

// MARK: - WKNavigationDelegate
extension WebPageRenderer: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        logger.info("✅ WebView finished loading")
        
        // Wait a bit for JavaScript to finish executing
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.extractHTML()
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        logger.error("❌ WebView failed to load: \(error.localizedDescription)")
        completion?(nil)
        cleanup()
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        logger.error("❌ WebView failed provisional navigation: \(error.localizedDescription)")
        completion?(nil)
        cleanup()
    }
}
