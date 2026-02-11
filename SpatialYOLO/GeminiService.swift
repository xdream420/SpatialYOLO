//
//  GeminiService.swift
//  SpatialYOLO
//
//  Created by 提比略 on 2026/2/11.
//

import Foundation
import UIKit

/// Gemini Live API 服务
class GeminiService {
    static let shared = GeminiService()
    
    /// API Key - 需要从 https://makersuite.google.com/app/apikey 获取
    var apiKey: String {
        // 优先从 UserDefaults 读取，其次从环境变量读取
        if let savedKey = UserDefaults.standard.string(forKey: "gemini_api_key"), !savedKey.isEmpty {
            return savedKey
        }
        // 回退到环境变量（用于开发和测试）
        return ProcessInfo.processInfo.environment["GEMINI_API_KEY"] ?? ""
    }
    
    /// 检查是否已配置 API Key
    var isConfigured: Bool {
        return !apiKey.isEmpty
    }
    
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro-vision:generateContent"
    
    /// 分析图像
    /// - Parameters:
    ///   - image: 要分析的图像
    ///   - prompt: 提示词
    /// - Returns: Gemini 返回的文本结果
    func analyzeImage(_ image: UIImage, prompt: String = "描述这张图片中的内容") async throws -> String {
        guard !apiKey.isEmpty else {
            throw GeminiError.noAPIKey
        }
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw GeminiError.invalidImage
        }
        
        let base64Image = imageData.base64EncodedString()
        
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt],
                        [
                            "inlineData": [
                                "mimeType": "image/jpeg",
                                "data": base64Image
                            ]
                        ]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.7,
                "maxOutputTokens": 1024
            ]
        ]
        
        let urlString = "\(baseURL)?key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            throw GeminiError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw GeminiError.apiError("HTTP错误: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        }
        
        let result = try JSONDecoder().decode(GeminiResponse.self, from: data)
        
        return result.candidates.first?.content.parts.first?.text ?? "无返回内容"
    }
    
    enum GeminiError: Error, LocalizedError {
        case noAPIKey
        case invalidImage
        case invalidURL
        case apiError(String)
        
        var errorDescription: String? {
            switch self {
            case .noAPIKey:
                return "未配置 Gemini API Key"
            case .invalidImage:
                return "图像格式无效"
            case .invalidURL:
                return "URL 无效"
            case .apiError(let message):
                return "API 错误: \(message)"
            }
        }
    }
}

// MARK: - 数据模型

struct GeminiResponse: Codable {
    let candidates: [Candidate]
}

struct Candidate: Codable {
    let content: Content
}

struct Content: Codable {
    let parts: [Part]
}

struct Part: Codable {
    let text: String
}
