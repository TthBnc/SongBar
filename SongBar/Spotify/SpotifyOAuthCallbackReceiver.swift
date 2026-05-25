import Foundation
import Network

struct SpotifyOAuthCallback: Equatable {
    let code: String
}

enum SpotifyOAuthCallbackError: LocalizedError {
    case listenerFailed(String)
    case alreadyWaiting
    case cancelled
    case invalidRequest
    case stateMismatch
    case authorizationDenied(String)
    case missingCode

    var errorDescription: String? {
        switch self {
        case .listenerFailed(let message):
            return "SongBar could not start the local Spotify callback listener: \(message)"
        case .alreadyWaiting:
            return "SongBar is already waiting for a Spotify login callback."
        case .cancelled:
            return "Spotify login was cancelled."
        case .invalidRequest:
            return "SongBar received an invalid Spotify login callback."
        case .stateMismatch:
            return "SongBar rejected the Spotify login callback because the security state did not match."
        case .authorizationDenied(let message):
            return message.isEmpty ? "Spotify login was denied." : "Spotify login was denied: \(message)"
        case .missingCode:
            return "Spotify did not return an authorization code."
        }
    }
}

final class SpotifyOAuthCallbackReceiver: @unchecked Sendable {
    private let port: NWEndpoint.Port
    private let queue = DispatchQueue(label: "dev.tothbnc.SongBar.spotify-oauth-callback")
    private var listener: NWListener?
    private var continuation: CheckedContinuation<SpotifyOAuthCallback, Error>?
    private var expectedState: String?
    private var completed = false

    init(port: UInt16 = SpotifyAuthConfiguration.callbackPort) {
        self.port = NWEndpoint.Port(rawValue: port)!
    }

    func start() async throws {
        let listener = try NWListener(using: .tcp, on: port)
        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection)
        }

        self.listener = listener

        try await withCheckedThrowingContinuation { (startContinuation: CheckedContinuation<Void, Error>) in
            let startBox = OneShotContinuation(startContinuation)

            listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    startBox.resume(returning: ())
                case .failed(let error):
                    startBox.resume(throwing: SpotifyOAuthCallbackError.listenerFailed(error.localizedDescription))
                default:
                    break
                }
            }

            listener.start(queue: queue)
        }
    }

    func waitForCallback(
        expectedState: String,
        onReady: @escaping @MainActor @Sendable () -> Error?
    ) async throws -> SpotifyOAuthCallback {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (callbackContinuation: CheckedContinuation<SpotifyOAuthCallback, Error>) in
                queue.async {
                    guard self.continuation == nil else {
                        callbackContinuation.resume(throwing: SpotifyOAuthCallbackError.alreadyWaiting)
                        return
                    }

                    self.expectedState = expectedState
                    self.continuation = callbackContinuation

                    Task { @MainActor in
                        if let error = onReady() {
                            self.queue.async {
                                self.complete(.failure(error))
                            }
                        }
                    }
                }
            }
        } onCancel: {
            stop()
        }
    }

    func stop() {
        queue.async {
            self.listener?.cancel()
            self.listener = nil

            guard let continuation = self.continuation, !self.completed else { return }
            self.completed = true
            self.continuation = nil
            continuation.resume(throwing: SpotifyOAuthCallbackError.cancelled)
        }
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8_192) { [weak self] data, _, _, error in
            guard let self else {
                connection.cancel()
                return
            }

            if let error {
                self.sendResponse(
                    on: connection,
                    status: "400 Bad Request",
                    body: Self.html(title: "SongBar", message: error.localizedDescription)
                )
                return
            }

            guard let data, !data.isEmpty else {
                self.sendResponse(
                    on: connection,
                    status: "400 Bad Request",
                    body: Self.html(title: "SongBar", message: "Missing request data.")
                )
                return
            }

            self.handle(data: data, on: connection)
        }
    }

    private func handle(data: Data, on connection: NWConnection) {
        let request = String(decoding: data, as: UTF8.self)
        guard
            let requestLine = request.components(separatedBy: "\r\n").first,
            let target = parseTarget(from: requestLine)
        else {
            sendResponse(on: connection, status: "400 Bad Request", body: Self.html(title: "SongBar", message: "Invalid callback request.")) {
                self.complete(.failure(SpotifyOAuthCallbackError.invalidRequest))
            }
            return
        }

        guard
            let components = SpotifyOAuthCallbackTarget.components(from: target),
            isAllowedCallbackHost(components.host),
            components.path == "/callback"
        else {
            sendResponse(on: connection, status: "404 Not Found", body: Self.html(title: "SongBar", message: "SongBar is waiting for the Spotify callback."))
            return
        }

        let queryItems = components.queryItems ?? []
        if let oauthError = queryItems.value(named: "error") {
            let description = queryItems.value(named: "error_description") ?? oauthError
            sendResponse(on: connection, status: "200 OK", body: Self.html(title: "SongBar", message: "Spotify login was not completed. You can close this tab.")) {
                self.complete(.failure(SpotifyOAuthCallbackError.authorizationDenied(description)))
            }
            return
        }

        guard queryItems.value(named: "state") == expectedState else {
            sendResponse(on: connection, status: "400 Bad Request", body: Self.html(title: "SongBar", message: "SongBar rejected this callback.")) {
                self.complete(.failure(SpotifyOAuthCallbackError.stateMismatch))
            }
            return
        }

        guard let code = queryItems.value(named: "code"), !code.isEmpty else {
            sendResponse(on: connection, status: "400 Bad Request", body: Self.html(title: "SongBar", message: "Spotify did not return a code.")) {
                self.complete(.failure(SpotifyOAuthCallbackError.missingCode))
            }
            return
        }

        sendResponse(
            on: connection,
            status: "200 OK",
            body: Self.html(title: "SongBar connected", message: "Spotify is connected. You can close this tab and return to SongBar.")
        ) {
            self.complete(.success(SpotifyOAuthCallback(code: code)))
        }
    }

    private func parseTarget(from requestLine: String) -> String? {
        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2, parts[0] == "GET" else { return nil }
        return String(parts[1])
    }

    private func isAllowedCallbackHost(_ host: String?) -> Bool {
        host == "127.0.0.1" || host == "localhost"
    }

    private func complete(_ result: Result<SpotifyOAuthCallback, Error>) {
        guard !completed else { return }
        completed = true

        listener?.cancel()
        listener = nil

        guard let continuation else { return }
        self.continuation = nil

        switch result {
        case .success(let callback):
            continuation.resume(returning: callback)
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }

    private func sendResponse(
        on connection: NWConnection,
        status: String,
        body: String,
        completion: @escaping @Sendable () -> Void = {}
    ) {
        let bodyData = Data(body.utf8)
        let header = """
        HTTP/1.1 \(status)\r
        Content-Type: text/html; charset=utf-8\r
        Content-Length: \(bodyData.count)\r
        Connection: close\r
        \r
        """
        var responseData = Data(header.utf8)
        responseData.append(bodyData)
        connection.send(content: responseData, completion: .contentProcessed { [weak self] _ in
            connection.cancel()
            self?.queue.async {
                completion()
            }
        })
    }

    private static func html(title: String, message: String) -> String {
        let escapedTitle = title.htmlEscaped
        let escapedMessage = message.htmlEscaped
        return """
        <!doctype html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>\(escapedTitle)</title>
        <style>
        :root{color-scheme:dark}
        *{box-sizing:border-box}
        body{min-height:100vh;margin:0;display:grid;place-items:center;background:#0b0b0d;color:#f4f4f5;font-family:-apple-system,BlinkMacSystemFont,"SF Pro Display","Segoe UI",sans-serif}
        body:before{content:"";position:fixed;inset:0;background:radial-gradient(circle at 50% 0%,rgba(29,185,84,.22),transparent 34%),linear-gradient(180deg,#151518 0%,#09090a 100%);pointer-events:none}
        main{position:relative;width:min(420px,calc(100vw - 48px));padding:34px 30px 30px;text-align:center;border:1px solid rgba(255,255,255,.12);border-radius:18px;background:rgba(22,22,24,.82);box-shadow:0 26px 70px rgba(0,0,0,.38)}
        .mark{width:46px;height:46px;margin:0 auto 18px;border-radius:50%;display:grid;place-items:center;background:#1db954;color:#071108;font-size:22px;font-weight:800}
        .eyebrow{margin:0 0 8px;color:#a7a7ad;font-size:12px;font-weight:700;letter-spacing:.08em;text-transform:uppercase}
        h1{margin:0 0 10px;font-size:26px;line-height:1.12;font-weight:750;letter-spacing:0}
        p{margin:0 auto 24px;max-width:320px;color:#c5c5ca;font-size:15px;line-height:1.48}
        button{height:38px;padding:0 18px;border:0;border-radius:999px;background:#f4f4f5;color:#101012;font:inherit;font-size:13px;font-weight:700;cursor:pointer}
        button:hover{background:#fff}
        .hint{margin-top:16px;color:#74747b;font-size:12px;line-height:1.4}
        </style>
        </head>
        <body>
        <main>
        <div class="mark">&#10003;</div>
        <p class="eyebrow">SongBar</p>
        <h1>\(escapedTitle)</h1>
        <p>\(escapedMessage)</p>
        <button onclick="window.close()">Close tab</button>
        <div class="hint">The connection is handled locally on this Mac.</div>
        </main>
        <script>setTimeout(function(){window.close()},1200)</script>
        </body>
        </html>
        """
    }
}

struct SpotifyOAuthCallbackTarget {
    static func components(from rawTarget: String) -> URLComponents? {
        let target = rawTarget.trimmingCharacters(in: .whitespacesAndNewlines)

        if target.hasPrefix("http://") || target.hasPrefix("https://") {
            guard let absoluteComponents = URLComponents(string: target) else { return nil }
            let pathAndQuery = pathAndQuery(from: absoluteComponents)
            let normalizedPathAndQuery = normalize(pathAndQuery)

            if normalizedPathAndQuery != pathAndQuery {
                return URLComponents(string: "http://127.0.0.1\(normalizedPathAndQuery)")
            }

            return absoluteComponents
        }

        return URLComponents(string: "http://127.0.0.1\(normalize(target))")
    }

    private static func normalize(_ target: String) -> String {
        let loopbackPrefix = "/127.0.0.1:\(SpotifyAuthConfiguration.callbackPort)"
        if target.hasPrefix(loopbackPrefix) {
            return String(target.dropFirst(loopbackPrefix.count))
        }

        let localhostPrefix = "/localhost:\(SpotifyAuthConfiguration.callbackPort)"
        if target.hasPrefix(localhostPrefix) {
            return String(target.dropFirst(localhostPrefix.count))
        }

        return target
    }

    private static func pathAndQuery(from components: URLComponents) -> String {
        if let query = components.percentEncodedQuery {
            return "\(components.path)?\(query)"
        }
        return components.path
    }
}

private final class OneShotContinuation: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Error>?

    init(_ continuation: CheckedContinuation<Void, Error>) {
        self.continuation = continuation
    }

    func resume(returning value: Void) {
        resume(.success(value))
    }

    func resume(throwing error: Error) {
        resume(.failure(error))
    }

    private func resume(_ result: Result<Void, Error>) {
        lock.lock()
        guard let continuation else {
            lock.unlock()
            return
        }
        self.continuation = nil
        lock.unlock()

        switch result {
        case .success:
            continuation.resume(returning: ())
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }
}

private extension Array where Element == URLQueryItem {
    func value(named name: String) -> String? {
        first { $0.name == name }?.value
    }
}

private extension String {
    var htmlEscaped: String {
        replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}
