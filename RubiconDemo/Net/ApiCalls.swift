import Foundation
import Rubicon

/// One of the app's own HTTP calls, each showing a rule of the network observer (iOS Lifecycle 5).
enum ApiCall: CaseIterable, Identifiable {
    case orders, postJson, notFound, serverError, timeout, unknownHost, refused, canceled, sdkHost

    var id: Self { self }

    var title: String {
        switch self {
        case .orders: return "GET with ids and a token"
        case .postJson: return "POST a JSON body"
        case .notFound: return "404 answer"
        case .serverError: return "500 answer"
        case .timeout: return "Slow answer (timeout)"
        case .unknownHost: return "Unknown host"
        case .refused: return "Connection refused"
        case .canceled: return "Canceled call"
        case .sdkHost: return "Call to the SDK's own host"
        }
    }

    var expectation: String {
        switch self {
        case .orders: return "Captured: path /api/users/:id/orders/:id, no query, no fragment, status 200"
        case .postJson: return "Captured with request_bytes; the body itself is never read"
        case .notFound: return "Captured with status_code 404"
        case .serverError: return "Captured with status_code 500"
        case .timeout: return "Captured with error timeout and no status_code; the call fails as usual"
        case .unknownHost: return "Captured only if the host is configured: unknown-host.invalid is not, so nothing"
        case .refused: return "Captured with error connect (localhost:1)"
        case .canceled: return "Captured with error canceled"
        case .sdkHost: return "Never captured, whatever the configured hosts"
        }
    }

    func url(apiBase: String, sdkHost: String) -> URL? {
        let base = apiBase.hasSuffix("/") ? String(apiBase.dropLast()) : apiBase
        let sdk = sdkHost.hasSuffix("/") ? String(sdkHost.dropLast()) : sdkHost
        switch self {
        case .orders: return URL(string: "\(base)/api/users/12345/orders/3f2a9c1e-0b1c-4d2e-8f3a-7b2d9c1e0b1c?token=secret#section")
        case .postJson: return URL(string: "\(base)/api/cart")
        case .notFound: return URL(string: "\(base)/api/status/404")
        case .serverError: return URL(string: "\(base)/api/status/500")
        case .timeout: return URL(string: "\(base)/api/slow?ms=5000")
        case .unknownHost: return URL(string: "http://unknown-host.invalid/api/ping")
        case .refused: return URL(string: "http://localhost:1/api/ping")
        case .canceled: return URL(string: "\(base)/api/slow?ms=3000")
        case .sdkHost: return URL(string: "\(sdk)/api/ping")
        }
    }
}

/// The app's own `URLSession` with a delegate that forwards the two callbacks to the SDK's observer,
/// as the integration guide shows. A task made with a completion handler never reaches the
/// delegate's `didCompleteWithError`, so the delegate collects the data itself.
final class ApiCalls {
    private final class Delegate: NSObject, URLSessionDataDelegate {
        let observer: RubiconNetworkObserver
        private let lock = NSLock()
        private var buffers: [Int: Data] = [:]
        private var completions: [Int: (Data, URLResponse?, Error?) -> Void] = [:]

        init(observer: RubiconNetworkObserver) { self.observer = observer }

        func expect(_ task: URLSessionTask, _ completion: @escaping (Data, URLResponse?, Error?) -> Void) {
            lock.lock()
            completions[task.taskIdentifier] = completion
            buffers[task.taskIdentifier] = Data()
            lock.unlock()
        }

        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
            lock.lock()
            buffers[dataTask.taskIdentifier, default: Data()].append(data)
            lock.unlock()
        }

        func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
            observer.urlSession(session, task: task, didFinishCollecting: metrics)
        }

        func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
            observer.urlSession(session, task: task, didCompleteWithError: error)
            lock.lock()
            let data = buffers.removeValue(forKey: task.taskIdentifier) ?? Data()
            let completion = completions.removeValue(forKey: task.taskIdentifier)
            lock.unlock()
            completion?(data, task.response, error)
        }
    }

    private let session: URLSession
    private let delegate: Delegate
    private let apiBase: String
    private let sdkHost: String

    init(analytics: any Analytics, hosts: [String], maskPathIds: Bool, apiBase: String, sdkHost: String) {
        delegate = Delegate(observer: RubiconNetworkObserver(analytics: analytics, hosts: Set(hosts), maskPathIds: maskPathIds))
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 2
        configuration.timeoutIntervalForResource = 10
        session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        self.apiBase = apiBase
        self.sdkHost = sdkHost
    }

    /// Makes `call` and describes its outcome as the app sees it.
    func run(_ call: ApiCall) async -> String {
        guard let url = call.url(apiBase: apiBase, sdkHost: sdkHost) else { return "Bad URL" }
        var request = URLRequest(url: url)
        if call == .postJson {
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = Data(#"{"sku":"A1","quantity":2}"#.utf8)
        }
        let started = Date()
        return await withCheckedContinuation { continuation in
            let task = session.dataTask(with: request)
            delegate.expect(task) { data, response, error in
                let ms = Int(Date().timeIntervalSince(started) * 1000)
                if let error {
                    continuation.resume(returning: "Failed: \((error as NSError).domain) \((error as NSError).code) after \(ms) ms")
                } else {
                    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                    continuation.resume(returning: "HTTP \(status), \(data.count) bytes read by the app, \(ms) ms")
                }
            }
            task.resume()
            if call == .canceled {
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) { task.cancel() }
            }
        }
    }
}
