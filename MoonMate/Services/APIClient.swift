import Foundation

enum APIError: Error {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case decodingError(Error)
}

// Request models
struct TextImprovementRequest: Codable {
    let selectedText: String
    let prompt: String
}

// Response models
struct TextImprovementResponse: Codable {
    let originalText: String
    let improvedText: String
}

class APIClient {
    private let baseURL: String
    private let session: URLSession
    
    init(baseURL: String = "http://localhost:8080", session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }
    
    // Make the method open for overriding
    func improveText(_ request: TextImprovementRequest) async throws -> TextImprovementResponse {
        guard let url = URL(string: "\(baseURL)/api/improve-text") else {
            throw APIError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let jsonData = try JSONEncoder().encode(request)
        urlRequest.httpBody = jsonData
        
        do {
            let (data, response) = try await session.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw APIError.invalidResponse
            }
            
            let result = try JSONDecoder().decode(TextImprovementResponse.self, from: data)
            return result
        } catch let error as APIError {
            throw error
        } catch let error as DecodingError {
            throw APIError.decodingError(error)
        } catch {
            throw APIError.networkError(error)
        }
    }
} 