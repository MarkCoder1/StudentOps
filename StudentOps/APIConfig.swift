import Foundation
import Network

// Configurable API base URL for Phase 5.9
// - Physical device (DEBUG): discovers Mac Next.js server via Bonjour/mDNS
// - Simulator (DEBUG): falls back to localhost if no Bonjour service found
// - Production: set API_BASE_URL in Info.plist or launch environment
// No secrets here — only public base URL
enum APIConfig {
    static var baseURL: URL {
        // 1. Info.plist override (for TestFlight/production)
        if let urlString = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
           let url = URL(string: urlString), !urlString.isEmpty {
            #if DEBUG
            print("[APIConfig] Using Info.plist URL: \(url.absoluteString)")
            #endif
            return url
        }
        // 2. Launch environment (for Xcode scheme)
        if let env = ProcessInfo.processInfo.environment["API_BASE_URL"],
           let url = URL(string: env), !env.isEmpty {
            #if DEBUG
            print("[APIConfig] Using environment URL: \(url.absoluteString)")
            #endif
            return url
        }
        // 3. DEBUG: Bonjour-discovered URL (set by startDiscovery)
        #if DEBUG
        if let discovered = BonjourDiscovery.shared.resolvedHost {
            let url = URL(string: "http://\(discovered):3000")!
            print("[APIConfig] Using Bonjour-discovered URL: \(url.absoluteString)")
            return url
        }
        // 4. DEBUG: fallback to localhost (simulator)
        let url = URL(string: "http://localhost:3000")!
        print("[APIConfig] Using fallback URL: \(url.absoluteString)")
        return url
        #else
        guard let url = URL(string: "http://localhost:3000") else {
            fatalError("Invalid default API base URL")
        }
        return url
        #endif
    }

    static var opportunitiesBasePath: String { "/api/opportunities" }
}

// MARK: - Bonjour / mDNS Service Discovery

#if DEBUG
final class BonjourDiscovery {
    static let shared = BonjourDiscovery()

    private var browser: NWBrowser?
    private let queue = DispatchQueue(label: "com.studentops.bonjour")

    /// Resolved IP of the Mac running Next.js, or nil if not yet found.
    private(set) var resolvedHost: String?

    /// Start browsing for StudentOps._http._tcp on the local network.
    /// Call once at app launch; safe to call multiple times.
    func start() {
        guard browser == nil else { return }
        let params = NWParameters()
        params.includePeerToPeer = true
        let browser = NWBrowser(for: .bonjour(type: "_http._tcp", domain: nil), using: params)

        browser.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("[BonjourDiscovery] Browser ready — searching for StudentOps._http._tcp …")
            case .failed(let error):
                print("[BonjourDiscovery] Browser failed: \(error)")
            default:
                break
            }
        }

        browser.browseResultsChangedHandler = { [weak self] results, _ in
            for result in results {
                self?.tryResolve(result: result)
            }
        }

        browser.start(queue: queue)
        self.browser = browser
        print("[BonjourDiscovery] Started browsing for _http._tcp")
    }

    private func tryResolve(result: NWBrowser.Result) {
        // Only resolve endpoints that are Bonjour service advertisements
        guard case .service(let name, _, _, _) = result.endpoint else { return }

        // Accept any _http._tcp service — the dev script registers "StudentOps"
        print("[BonjourDiscovery] Found service '\(name)' — resolving …")

        let connection = NWConnection(to: result.endpoint, using: .tcp)
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                if let path = connection.currentPath,
                   let endpoint = path.remoteEndpoint {
                    switch endpoint {
                    case .hostPort(let host, _):
                        let ip: String
                        switch host {
                        case .ipv4(let addr):
                            ip = "\(addr)"
                        case .ipv6(let addr):
                            ip = "\(addr)"
                        @unknown default:
                            connection.cancel()
                            return
                        }
                        // Skip loopback — we want the LAN IP
                        if ip != "127.0.0.1" && ip != "::1" && !ip.isEmpty {
                            self?.resolvedHost = ip
                            print("[BonjourDiscovery] ✓ Resolved \(name) → \(ip)")
                        }
                    default:
                        break
                    }
                }
                connection.cancel()
            case .failed:
                connection.cancel()
            default:
                break
            }
        }
        connection.start(queue: queue)
    }
}
#endif
