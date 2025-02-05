import Foundation

class MockAPIClient: APIClient {
    // Simulate network delay
    private let simulatedDelay: TimeInterval = 1.0
    
    override func improveText(_ request: TextImprovementRequest) async throws -> TextImprovementResponse {
        // Simulate network delay
        try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        
        // Format the response as a diff
        let improvedText = """
        Suggested Edit
        - \(request.selectedText)
        + \(mockImproveText(request.selectedText, prompt: request.prompt))
        """
        
        return TextImprovementResponse(
            originalText: request.selectedText,
            improvedText: improvedText
        )
    }
    
    private func mockImproveText(_ text: String, prompt: String) -> String {
        // Simple mock improvements based on common patterns
        var improved = text
        
        if prompt.lowercased().contains("better") {
            improved = improved
                .replacingOccurrences(of: "For emphasis", with: "With dramatic flair")
                .replacingOccurrences(of: "stabbed", with: "thrust")
                .replacingOccurrences(of: "Pyrennees", with: "Pyrenees")
                .replacingOccurrences(of: "to declare them part of the present", with: "as if claiming them for the present moment")
                .replacingOccurrences(
                    of: "with the snow-glitter along the peaks a little tinsel to add glamour to the gift",
                    with: "their snow-capped peaks sparkling like tinsel on an extravagant gift"
                )
        }
        
        return improved
    }
} 