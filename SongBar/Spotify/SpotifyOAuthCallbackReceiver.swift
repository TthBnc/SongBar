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
            sendResponse(on: connection, status: "400 Bad Request", body: Self.html(title: "SongBar", message: "Invalid callback request."))
            complete(.failure(SpotifyOAuthCallbackError.invalidRequest))
            return
        }

        guard
            let components = URLComponents(string: "http://127.0.0.1\(target)"),
            components.path == "/callback"
        else {
            sendResponse(on: connection, status: "404 Not Found", body: Self.html(title: "SongBar", message: "SongBar is waiting for the Spotify callback."))
            return
        }

        let queryItems = components.queryItems ?? []
        if let oauthError = queryItems.value(named: "error") {
            let description = queryItems.value(named: "error_description") ?? oauthError
            sendResponse(on: connection, status: "200 OK", body: Self.html(title: "SongBar", message: "Spotify login was not completed. You can close this tab."))
            complete(.failure(SpotifyOAuthCallbackError.authorizationDenied(description)))
            return
        }

        guard queryItems.value(named: "state") == expectedState else {
            sendResponse(on: connection, status: "400 Bad Request", body: Self.html(title: "SongBar", message: "SongBar rejected this callback."))
            complete(.failure(SpotifyOAuthCallbackError.stateMismatch))
            return
        }

        guard let code = queryItems.value(named: "code"), !code.isEmpty else {
            sendResponse(on: connection, status: "400 Bad Request", body: Self.html(title: "SongBar", message: "Spotify did not return a code."))
            complete(.failure(SpotifyOAuthCallbackError.missingCode))
            return
        }

        sendResponse(on: connection, status: "200 OK", body: Self.html(title: "SongBar connected", message: "You can close this tab and return to SongBar."))
        complete(.success(SpotifyOAuthCallback(code: code)))
    }

    private func parseTarget(from requestLine: String) -> String? {
        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2, parts[0] == "GET" else { return nil }
        return String(parts[1])
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

    private func sendResponse(on connection: NWConnection, status: String, body: String) {
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
        connection.send(content: responseData, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private static func html(title: String, message: String) -> String {
        """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <title>\(title)</title>
        <style>
        body{font-family:-apple-system,BlinkMacSystemFont,sans-serif;background:#111;color:#f5f5f5;display:grid;place-items:center;height:100vh;margin:0}
        main{max-width:420px;padding:28px;text-align:center}
        h1{font-size:20px;margin:0 0 8px}
        p{color:#b8b8b8;line-height:1.45;margin:0}
        </style>
        </head>
        <body><main><h1>\(title)</h1><p>\(message)</p></main></body>
        </html>
        """
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
