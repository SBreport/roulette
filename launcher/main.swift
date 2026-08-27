// 추첨기 네이티브 런처.
//
// 크롬을 띄우던 방식은 macOS 크롬이 마지막 창을 닫아도 종료되지 않는 탓에
// Dock 아이콘과 프로세스가 계속 쌓였다. 여기서는 앱이 창을 직접 들고 있으므로
// 창을 닫으면 앱과 서버가 함께 끝난다.

import Cocoa
import WebKit

// dist 를 http 로 내보낼 빈 포트를 찾는다. wasm 을 불러와야 해서 file:// 로는 안 된다.
func findFreePort(startingAt start: UInt16) -> UInt16 {
    var port = start
    while port < start &+ 50 {
        let sock = socket(AF_INET, SOCK_STREAM, 0)
        if sock < 0 { return port }
        var yes: Int32 = 1
        setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = INADDR_ANY
        let bound = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        close(sock)
        if bound == 0 { return port }
        port &+= 1
    }
    return start
}

final class AppDelegate: NSObject, NSApplicationDelegate, WKNavigationDelegate {
    private var window: NSWindow!
    private var webView: WKWebView!
    private var server: Process?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // .app 은 프로젝트 폴더 안에 있으므로 그 부모가 프로젝트 루트다.
        let project = (Bundle.main.bundlePath as NSString).deletingLastPathComponent
        let dist = project + "/dist"

        guard FileManager.default.fileExists(atPath: dist + "/index.html") else {
            fail("빌드 결과(dist)가 없습니다.\n\n터미널에서 프로젝트 폴더로 이동해 아래를 실행하세요.\n\nnpm run build")
            return
        }

        let port = findFreePort(startingAt: 8899)
        startServer(dist: dist, port: port)
        buildMenu()

        webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        webView.navigationDelegate = self

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1280, height: 860),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "추첨기"
        window.contentView = webView
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        webView.load(URLRequest(url: URL(string: "http://127.0.0.1:\(port)/")!))

        switch ProcessInfo.processInfo.environment["ROULETTE_SELFTEST"] {
        case "close": runCloseTest()
        case .some: runSelfTest()
        default: break
        }
    }

    private func startServer(dist: String, port: UInt16) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["python3", "-m", "http.server", String(port), "--bind", "127.0.0.1", "--directory", dist]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            server = task
        } catch {
            fail("로컬 서버를 시작하지 못했습니다.\n\n\(error.localizedDescription)")
        }
    }

    // 웹뷰에서 Cmd+C/V, Cmd+Q 가 먹으려면 표준 메뉴가 있어야 한다.
    private func buildMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "새로고침", action: #selector(reload), keyEquivalent: "r")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "추첨기 종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "편집")
        editMenu.addItem(withTitle: "실행 취소", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "다시 실행", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "오려두기", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "복사", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "붙여넣기", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "전체 선택", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)

        NSApp.mainMenu = mainMenu
    }

    @objc private func reload() {
        webView.reload()
    }

    private func fail(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "추첨기"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
        NSApp.terminate(nil)
    }

    // 창을 닫으면 앱이 끝나고, 끝나면서 서버도 함께 정리한다.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        server?.terminate()
    }

    // 진단용: 사용자가 창의 닫기 버튼을 누른 것과 같은 경로를 밟는다.
    private func runCloseTest() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            print("SELFTEST closing window")
            self.window.performClose(nil)
        }
    }

    // 진단용: 페이지가 실제로 살아났는지 확인하고 결과를 찍은 뒤 종료한다.
    private func runSelfTest() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
            let probe = """
            JSON.stringify({
              ready: !!(window.roulette && window.roulette.isReady),
              marbles: window.roulette ? window.roulette.getCount() : -1,
              wasm: typeof WebAssembly,
              buttons: !!document.querySelector('#btnPause') && !!document.querySelector('#btnStop'),
              memo: !!document.querySelector('#memoBody'),
              storage: (() => { try { localStorage.setItem('t','1'); return true; } catch (e) { return false; } })(),
              bodyFont: getComputedStyle(document.body).fontFamily,
              hasKoreanFace: document.fonts.check('12pt "Apple SD Gothic Neo"'),
              viewport: innerWidth,
              panelRight: Math.round(document.querySelector('#settings').getBoundingClientRect().right),
              panelWidth: Math.round(document.querySelector('#settings').getBoundingClientRect().width),
              memoLeft: Math.round(document.querySelector('#memo').getBoundingClientRect().left),
              overlaps: document.querySelector('#settings').getBoundingClientRect().right >
                        document.querySelector('#memo').getBoundingClientRect().left
            })
            """
            self.webView.evaluateJavaScript(probe) { result, error in
                print("SELFTEST \(result.map { "\($0)" } ?? "error: \(String(describing: error))")")
                NSApp.terminate(nil)
            }
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
