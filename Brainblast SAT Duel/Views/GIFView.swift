import SwiftUI
import WebKit

struct GIFView: UIViewRepresentable {
    private let gifName: String
    
    init(gifName: String) {
        self.gifName = gifName
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.backgroundColor = .clear
        webView.isOpaque = false
        webView.scrollView.isScrollEnabled = false
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        guard let gifURL = Bundle.main.url(forResource: gifName, withExtension: "gif") else {
            print("Could not find GIF: \(gifName)")
            return
        }
        
        let data = try? Data(contentsOf: gifURL)
        
        webView.load(data ?? Data(),
                     mimeType: "image/gif",
                     characterEncodingName: "UTF-8",
                     baseURL: gifURL.deletingLastPathComponent())
    }
}
