//
//  VolcanoSpeechService.swift
//  SpatialYOLO
//
//  Created by 提比略 on 2026/2/11.
//

import Foundation
import AVFoundation

/// 火山引擎语音识别服务
class VolcanoSpeechService: NSObject {
    static let shared = VolcanoSpeechService()
    
    // MARK: - API 配置
    
    /// App ID - 从火山引擎控制台获取
    var appId: String {
        return UserDefaults.standard.string(forKey: "volcano_app_id") ??
               ProcessInfo.processInfo.environment["VOLCANO_APP_ID"] ?? ""
    }
    
    /// Access Token - 从火山引擎控制台获取
    var accessToken: String {
        return UserDefaults.standard.string(forKey: "volcano_access_token") ??
               ProcessInfo.processInfo.environment["VOLCANO_ACCESS_TOKEN"] ?? ""
    }
    
    /// 检查是否已配置
    var isConfigured: Bool {
        return !appId.isEmpty && !accessToken.isEmpty
    }
    
    // MARK: - 音频录制
    
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var audioBuffer: AVAudioPCMBuffer?
    
    /// 是否正在录制
    @Published var isRecording: Bool = false
    
    /// 识别结果回调
    var onRecognitionResult: ((String, Bool) -> Void)?
    
    // MARK: - WebSocket
    
    private var webSocketTask: URLSessionWebSocketTask?
    private let webSocketURL = "wss://openspeech.bytedance.com/api/v2/asr"
    
    // MARK: - 开始语音识别
    
    /// 开始语音识别
    func startRecognition() async throws {
        guard isConfigured else {
            throw VolcanoError.notConfigured
        }
        
        // 请求麦克风权限
        let audioSession = AVAudioSession.sharedInstance()
        try await audioSession.setCategory(.playAndRecord, mode: .default)
        try await audioSession.setActive(true)
        
        // 设置音频引擎
        setupAudioEngine()
        
        // 连接 WebSocket
        try await connectWebSocket()
        
        // 开始录制
        try startRecording()
    }
    
    /// 停止语音识别
    func stopRecognition() {
        stopRecording()
        disconnectWebSocket()
        isRecording = false
    }
    
    // MARK: - 私有方法
    
    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        inputNode = audioEngine?.inputNode
        
        let recordingFormat = inputNode?.outputFormat(forBus: 0)
        
        inputNode?.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer)
        }
    }
    
    private func startRecording() throws {
        try audioEngine?.start()
        isRecording = true
    }
    
    private func stopRecording() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        // 将音频数据转换为字节数组并发送到 WebSocket
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        
        // 转换为 16-bit PCM
        var int16Data = [Int16](repeating: 0, count: frameLength)
        for i in 0..<frameLength {
            let sample = max(-1.0, min(1.0, channelData[i]))
            int16Data[i] = Int16(sample * 32767.0)
        }
        
        let data = Data(bytes: int16Data, count: frameLength * 2)
        sendAudioData(data)
    }
    
    // MARK: - WebSocket 连接
    
    private func connectWebSocket() async throws {
        var request = URLRequest(url: URL(string: webSocketURL)!)
        request.setValue(appId, forHTTPHeaderField: "X-Appid")
        request.setValue(accessToken, forHTTPHeaderField: "X-Token")
        
        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.delegate = self
        
        webSocketTask?.resume()
        
        // 发送开始识别请求
        let startRequest: [String: Any] = [
            "payload": [
                "format": "pcm",
                "sample_rate": 16000,
                "language": "zh-CN",
                "enable_punctuation": true,
                "enable_itn": true
            ]
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: startRequest)
        try await webSocketTask?.send(.data(jsonData))
    }
    
    private func disconnectWebSocket() {
        // 发送结束识别请求
        let endRequest: [String: Any] = [
            "payload": [
                "is_last": true
            ]
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: endRequest) {
            webSocketTask?.send(.data(jsonData)) { _ in }
        }
        
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
    }
    
    private func sendAudioData(_ data: Data) {
        webSocketTask?.send(.data(data)) { error in
            if let error = error {
                print("发送音频数据失败: \(error)")
            }
        }
    }
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                self?.handleMessage(message)
                self?.receiveMessage() // 继续接收
            case .failure(let error):
                print("接收消息失败: \(error)")
            }
        }
    }
    
    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            parseRecognitionResult(text)
        case .data(let data):
            if let text = String(data: data, encoding: .utf8) {
                parseRecognitionResult(text)
            }
        @unknown default:
            break
        }
    }
    
    private func parseRecognitionResult(_ jsonString: String) {
        guard let data = jsonString.data(using: .utf8),
              let result = try? JSONDecoder().decode(VolcanoRecognitionResult.self, from: data) else {
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            let text = result.result?.text ?? ""
            let isFinal = result.result?.isFinal ?? false
            self?.onRecognitionResult?(text, isFinal)
        }
    }
    
    // MARK: - 错误类型
    
    enum VolcanoError: Error, LocalizedError {
        case notConfigured
        case permissionDenied
        case connectionFailed
        case recognitionFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "未配置火山引擎 App ID 或 Access Token"
            case .permissionDenied:
                return "麦克风权限被拒绝"
            case .connectionFailed:
                return "连接语音识别服务失败"
            case .recognitionFailed(let message):
                return "识别失败: \(message)"
            }
        }
    }
}

// MARK: - WebSocket 代理

extension VolcanoSpeechService: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("WebSocket 连接成功")
        receiveMessage()
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            print("WebSocket 连接失败: \(error)")
        }
    }
}

// MARK: - 数据模型

struct VolcanoRecognitionResult: Codable {
    let result: RecognitionResult?
    
    struct RecognitionResult: Codable {
        let text: String?
        let isFinal: Bool?
        
        enum CodingKeys: String, CodingKey {
            case text
            case isFinal = "is_final"
        }
    }
}
