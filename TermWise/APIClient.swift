import Foundation

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

protocol APIClient {
    func get<Response: Decodable>(_ path: String, responseType: Response.Type) throws -> Response
    func post<Request: Encodable, Response: Decodable>(_ path: String, body: Request, responseType: Response.Type) throws -> Response
    func put<Request: Encodable, Response: Decodable>(_ path: String, body: Request, responseType: Response.Type) throws -> Response
    func delete<Response: Decodable>(_ path: String, responseType: Response.Type) throws -> Response
}

struct EmptyAPIResponse: Codable {}

final class URLSessionAPIClient: APIClient {
    private let baseURL: URL
    private let session: URLSession
    private let jsonEncoder = JSONEncoder()
    private let jsonDecoder = JSONDecoder()

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func get<Response: Decodable>(_ path: String, responseType: Response.Type) throws -> Response {
        try perform(path: path, method: .get, body: Optional<Data>.none, responseType: responseType)
    }

    func post<Request: Encodable, Response: Decodable>(_ path: String, body: Request, responseType: Response.Type) throws -> Response {
        try perform(path: path, method: .post, body: try jsonEncoder.encode(body), responseType: responseType)
    }

    func put<Request: Encodable, Response: Decodable>(_ path: String, body: Request, responseType: Response.Type) throws -> Response {
        try perform(path: path, method: .put, body: try jsonEncoder.encode(body), responseType: responseType)
    }

    func delete<Response: Decodable>(_ path: String, responseType: Response.Type) throws -> Response {
        try perform(path: path, method: .delete, body: Optional<Data>.none, responseType: responseType)
    }

    private func perform<Response: Decodable>(
        path: String,
        method: HTTPMethod,
        body: Data?,
        responseType: Response.Type
    ) throws -> Response {
        let url = baseURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        var result: Result<Response, Error>?
        let semaphore = DispatchSemaphore(value: 0)
        let task = session.dataTask(with: request) { [jsonDecoder] data, response, error in
            defer { semaphore.signal() }
            if let error {
                result = .failure(error)
                return
            }
            guard
                let httpResponse = response as? HTTPURLResponse,
                (200...299).contains(httpResponse.statusCode)
            else {
                result = .failure(URLError(.badServerResponse))
                return
            }

            if Response.self == EmptyAPIResponse.self {
                result = .success(EmptyAPIResponse() as! Response)
                return
            }

            guard let data else {
                result = .failure(URLError(.cannotDecodeRawData))
                return
            }
            do {
                result = .success(try jsonDecoder.decode(Response.self, from: data))
            } catch {
                result = .failure(error)
            }
        }
        task.resume()
        semaphore.wait()

        switch result {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        case .none:
            throw URLError(.unknown)
        }
    }
}
