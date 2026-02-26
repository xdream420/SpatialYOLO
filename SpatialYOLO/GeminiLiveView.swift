//
//  GeminiLiveView.swift
//  SpatialYOLO
//
//  Created by 提比略 on 2026/2/11.
//

import SwiftUI
import RealityKit

struct GeminiLiveView: View {
    var appModel: AppModel
    @State private var geminiResponse: String = "等待视频流输入..."
    @State private var isProcessing: Bool = false
    @State private var showSettings: Bool = false
    
    var body: some View {
        VStack(spacing: 20) {
            // 标题和设置按钮
            HStack {
                Text("Gemini Live 视觉分析")
                    .font(.title)
                
                Spacer()
                
                // API Key 配置状态指示
                HStack(spacing: 4) {
                    Circle()
                        .fill(GeminiService.shared.isConfigured ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(GeminiService.shared.isConfigured ? "已配置" : "未配置")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // 设置按钮
                Button(action: {
                    showSettings = true
                }) {
                    Image(systemName: "gear")
                        .font(.title3)
                }
                .buttonStyle(.borderless)
            }
            .padding(.top)
            .padding(.horizontal)
            
            // 视频流显示区域
            BoundingBoxOverlay(model: appModel)
                .frame(width: 960, height: 540)
                .glassBackgroundEffect()
            
            // Gemini 结果显示区域
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Gemini 分析结果")
                        .font(.headline)
                    
                    Spacer()
                    
                    if isProcessing {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                
                ScrollView {
                    Text(geminiResponse)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
                .frame(height: 150)
                .background(Color.black.opacity(0.3))
                .cornerRadius(8)
            }
            .frame(width: 960)
            .padding()
            .glassBackgroundEffect()
            
            // 控制按钮
            HStack(spacing: 20) {
                Button(action: {
                    captureAndAnalyze()
                }) {
                    HStack {
                        Image(systemName: "camera.fill")
                        Text("实时分析")
                    }
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isProcessing)
                
                Button(action: {
                    geminiResponse = "等待视频流输入..."
                }) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("重置")
                    }
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
            }
            
            Spacer()
        }
        .padding()
        .onAppear {
            // 启动相机会话
            Task {
                await appModel.startSession()
                startRealtimeAnalysis()
            }
        }
        .onDisappear {
            // 停止分析
            stopRealtimeAnalysis()
        }
        .sheet(isPresented: $showSettings, onDismiss: {
            // 设置关闭后刷新状态
            checkAPIKeyStatus()
        }) {
            APIKeySettingsView()
        }
    }
    
    private func checkAPIKeyStatus() {
        // 强制刷新 UI 显示 API Key 状态
        if GeminiService.shared.isConfigured && geminiResponse.contains("未配置") {
            geminiResponse = "API Key 已配置，点击实时分析开始"
        }
    }
    
    private func captureAndAnalyze() {
        guard let image = appModel.capturedImage else {
            geminiResponse = "无法获取图像，请检查相机权限"
            return
        }
        
        isProcessing = true
        
        // TODO: 调用 Gemini Live API
        Task {
            do {
                let result = try await callGeminiLive(image: image)
                await MainActor.run {
                    geminiResponse = result
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    geminiResponse = "分析失败: \(error.localizedDescription)"
                    isProcessing = false
                }
            }
        }
    }
    
    private var analysisTask: Task<Void, Never>?
    
    private func startRealtimeAnalysis() {
        // 每3秒自动分析一次
        analysisTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                if !isProcessing {
                    captureAndAnalyze()
                }
            }
        }
    }
    
    private func stopRealtimeAnalysis() {
        analysisTask?.cancel()
        analysisTask = nil
    }
    
    private func callGeminiLive(image: UIImage) async throws -> String {
        let service = GeminiService.shared
        
        // 检查是否配置了 API Key
        guard !service.apiKey.isEmpty else {
            return """
            [Gemini API 未配置]
            
            请配置 API Key：
            1. 访问 https://makersuite.google.com/app/apikey
            2. 创建新的 API Key
            3. 在 Xcode 中设置环境变量 GEMINI_API_KEY
            
            或通过命令行运行：
            export GEMINI_API_KEY="your-api-key"
            """
        }
        
        return try await service.analyzeImage(
            image,
            prompt: "详细描述这张图片中的场景、物体和活动内容。"
        )
    }
}

#Preview {
    GeminiLiveView(appModel: AppModel())
}
