import Cocoa
import WebKit

let appDelegate = AppDelegate()
let app = NSApplication.shared
app.delegate = appDelegate
app.setActivationPolicy(.regular)
app.run()

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var webView: WKWebView!
    var popups: [PopupWindowController] = []

    // Change this if the BNV app ever moves.
    let bnvURL = URL(string: "https://bnv-app.vercel.app")!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let width: CGFloat = 1280
        let height: CGFloat = 900
        let frame = NSRect(x: 0, y: 0, width: width, height: height)

        window = NSWindow(contentRect: frame,
                           styleMask: [.titled, .closable, .miniaturizable, .resizable],
                           backing: .buffered,
                           defer: false)
        window.title = "BNV"
        window.minSize = NSSize(width: 480, height: 400)
        window.isReleasedWhenClosed = false
        window.tabbingIdentifier = "BNVTabGroup"
        window.center()
        window.setFrameAutosaveName("BNVMainWindow")

        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        webView = WKWebView(frame: frame, configuration: config)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.autoresizingMask = [.width, .height]

        // developerExtrasEnabled is what actually puts "Inspect Element" in the
        // right-click menu inside the app. isInspectable (macOS 13.3+) is a
        // separate, additional thing: it lets you inspect this view *externally*
        // from Safari's Develop menu. Turn both on.
        webView.configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
        if #available(macOS 13.3, *) {
            webView.isInspectable = true
        }

        window.contentView = webView
        window.makeKeyAndOrderFront(nil)

        // WKWebView tiles blurred/translucent layers (e.g. frosted-glass modals) for
        // GPU compositing. If the layer's contentsScale doesn't match the display's
        // actual backing scale factor, those tiles can show a faint seam at their
        // boundaries. Force it to match, and keep it matched if the window moves to
        // a display with a different scale factor.
        webView.wantsLayer = true
        webView.layer?.contentsScale = window.backingScaleFactor
        NotificationCenter.default.addObserver(self,
                                                selector: #selector(backingPropertiesChanged),
                                                name: NSWindow.didChangeBackingPropertiesNotification,
                                                object: window)

        webView.load(URLRequest(url: bnvURL))

        NSApp.activate(ignoringOtherApps: true)
        setupMenu()
    }

    @objc func backingPropertiesChanged(_ note: Notification) {
        webView.layer?.contentsScale = window.backingScaleFactor
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    private func setupMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "Quit BNV", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appMenuItem.submenu = appMenu

        let fileMenuItem = NSMenuItem()
        mainMenu.addItem(fileMenuItem)
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(NSMenuItem(title: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
        fileMenuItem.submenu = fileMenu

        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z"))
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editMenuItem.submenu = editMenu

        let viewMenuItem = NSMenuItem()
        mainMenu.addItem(viewMenuItem)
        let viewMenu = NSMenu(title: "View")
        viewMenu.addItem(NSMenuItem(title: "Reload", action: #selector(reload), keyEquivalent: "r"))
        viewMenu.addItem(NSMenuItem.separator())
        viewMenu.addItem(NSMenuItem(title: "Back", action: #selector(goBack), keyEquivalent: "["))
        viewMenu.addItem(NSMenuItem(title: "Forward", action: #selector(goForward), keyEquivalent: "]"))
        viewMenu.addItem(NSMenuItem.separator())
        viewMenu.addItem(NSMenuItem(title: "Zoom In", action: #selector(zoomIn), keyEquivalent: "="))
        viewMenu.addItem(NSMenuItem(title: "Zoom Out", action: #selector(zoomOut), keyEquivalent: "-"))
        viewMenu.addItem(NSMenuItem(title: "Actual Size", action: #selector(zoomReset), keyEquivalent: "0"))
        viewMenuItem.submenu = viewMenu

        let windowMenuItem = NSMenuItem()
        mainMenu.addItem(windowMenuItem)
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(NSMenuItem(title: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m"))
        windowMenuItem.submenu = windowMenu
        NSApp.windowsMenu = windowMenu

        NSApp.mainMenu = mainMenu
    }

    @objc func reload() { webView.reload() }
    @objc func goBack() { webView.goBack() }
    @objc func goForward() { webView.goForward() }
    @objc func zoomIn() { webView.pageZoom = min(3.0, webView.pageZoom + 0.1) }
    @objc func zoomOut() { webView.pageZoom = max(0.3, webView.pageZoom - 0.1) }
    @objc func zoomReset() { webView.pageZoom = 1.0 }
}

// MARK: - Navigation + downloads

extension AppDelegate: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.shouldPerformDownload {
            decisionHandler(.download)
        } else {
            decisionHandler(.allow)
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        // Only turn undisplayable responses into a native download for main-frame
        // navigations. A subframe (e.g. a hidden iframe fetching JSON) hitting a
        // MIME type WebKit can't render shouldn't pop a Save panel in the user's face.
        if navigationResponse.canShowMIMEType || !navigationResponse.isForMainFrame {
            decisionHandler(.allow)
        } else {
            decisionHandler(.download)
        }
    }

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        download.delegate = self
    }

    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        download.delegate = self
    }
}

extension AppDelegate: WKDownloadDelegate {
    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedFilename
        panel.canCreateDirectories = true
        panel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            panel.begin { result in
                completionHandler(result == .OK ? panel.url : nil)
            }
        }
    }

    func downloadDidFinish(_ download: WKDownload) {}

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        NSLog("BNV download failed: \(error.localizedDescription)")
    }
}

// MARK: - New windows (target=_blank, window.open, OAuth popups) + camera permission

extension AppDelegate: WKUIDelegate {
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        let popup = PopupWindowController(configuration: configuration, owner: self)
        popups.append(popup)
        return popup.webView
    }

    func webViewDidClose(_ webView: WKWebView) {
        // windowWillClose (NSWindowDelegate) removes the controller from `popups`.
        if let popup = popups.first(where: { $0.webView === webView }) {
            popup.window.close()
        }
    }

    @available(macOS 12.0, *)
    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        decisionHandler(.grant)
    }
}

// A lightweight window that hosts a popped-out WKWebView (new tabs, OAuth sign-in flows).
// Auto-closes and refreshes the main window once navigation lands back on the BNV domain.
class PopupWindowController: NSObject, WKNavigationDelegate, NSWindowDelegate {
    let window: NSWindow
    let webView: WKWebView
    weak var owner: AppDelegate?
    private var hasLeftMainDomain = false

    init(configuration: WKWebViewConfiguration, owner: AppDelegate) {
        self.owner = owner
        let frame = NSRect(x: 0, y: 0, width: 900, height: 700)
        webView = WKWebView(frame: frame, configuration: configuration)
        window = NSWindow(contentRect: frame,
                           styleMask: [.titled, .closable, .miniaturizable, .resizable],
                           backing: .buffered,
                           defer: false)
        super.init()
        webView.navigationDelegate = self
        webView.autoresizingMask = [.width, .height]
        window.title = "BNV"
        window.contentView = webView
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.tabbingIdentifier = "BNVTabGroup"
        window.center()

        if let mainWindow = owner.window {
            mainWindow.addTabbedWindow(window, ordered: .above)
            window.makeKeyAndOrderFront(nil)
        } else {
            window.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let host = webView.url?.host, let mainHost = owner?.bnvURL.host else { return }

        if host != mainHost {
            // Left to an external site (e.g. an OAuth provider) — remember that,
            // so we know a later return to the main domain really means "signed in",
            // not just "this was a same-site link opened in a new tab".
            hasLeftMainDomain = true
            return
        }

        guard hasLeftMainDomain else { return }
        owner?.webView.reload()
        window.close()
    }

    // Covers the case where the user closes the popup by hand (titlebar button)
    // instead of the OAuth flow completing — without this, the controller (and
    // its WKWebView) would stay strongly referenced in owner.popups forever.
    func windowWillClose(_ notification: Notification) {
        owner?.popups.removeAll { $0 === self }
    }
}
