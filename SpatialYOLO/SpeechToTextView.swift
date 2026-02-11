//
//  SpeechToTextView.swift
//  SpatialYOLO
//
//  Created by 提比略 on 2026/2/11.
//

import SwiftUI

struct SpeechToTextView: View {
    @State private var recognizedText: String = "点击开始说话..."
    @State private var isRecording: Bool = false
    @State private var showSettings: Bool = false
    @State private var interimText: String = ""
    @State private var errorMessage: String? = nil
    
    private let speechService = VolcanoSpeechService.shared
    
    var body: some View {
        VStack(spacing: 20) {
            // 标题栏
            HStack {
                Text("语音转文字")
                    .font(.title)
                
                Spacer()
                
                // 配置状态指示
                HStack(spacing: 4) {
                    Circle()
                        .fill(speechService.isConfigured ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(speechService.isConfigured ? "已配置" : "未配置")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Button(action: {
                    showSettings = true
                }) {
                    Image(systemName: "gear")
                        .font(.title3)
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal)
            
            // 录音按钮（大圆形）
            Button(action: {
                toggleRecording()
            }) {
                ZStack {
                    Circle()
                        .fill(isRecording ? Color.red : Color.blue)
                        .frame(width: 120, height: 120)
                    
                    if isRecording {
                        // 录音中显示波形动画
                        VStack(spacing: 4) {
                            HStack(spacing: 3) {
                                ForEach(0..<5) { i in
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.white)
                                        .frame(width: 4, height: CGFloat.random(in: 10...40))
                                        .animation(
                                            Animation.easeInOut(duration: 0.3)
                                                .repeatForever(autoreverses: true)
                                                .delay(Double(i) * 0.1),
                                            value: isRecording
                                        )
                                }
                            }
                            Text("录音中...")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                    } else {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.vertical, 30)
            
            // 识别结果区域
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("识别结果")
                        .font(.headline)
                    
                    Spacer()
                    
                    if !recognizedText.isEmpty && recognizedText != "点击开始说话..." {
                        Button(action: {
                            copyToClipboard()
                        }) {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                        
                        Button(action: {
                            clearText()
                        }) {
                            Image(systemName: "xmark.circle")
                        }
                        .buttonStyle(.borderless)
                    }
                }
                
                if !interimText.isEmpty {
                    Text(interimText)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .italic()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                
                ScrollView {
                    Text(recognizedText)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
                .frame(height: 200)
                .background(Color.black.opacity(0.3))
                .cornerRadius(8)
            }
            .frame(width: 600)
            .padding()
            .glassBackgroundEffect()
            
            // 错误提示
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }
            
            // 使用说明
            VStack(alignment: .leading, spacing: 8) {
                Text("使用说明")
                    .font(.headline)
                
                HStack(alignment: .top, spacing: 8) {
                    Text("1.")
                    Text("点击上方麦克风按钮开始录音")
                }
                
                HStack(alignment: .top, spacing: 8) {
                    Text("2.")
                    Text("说话时会显示实时识别结果")
                }
                
                HStack(alignment: .top, spacing: 8) {
                    Text("3.")
                    Text("再次点击按钮停止录音")
                }
                
                HStack(alignment: .top, spacing: 8) {
                    Text("4.")
                    Text("识别结果会自动保存到文本框")
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .frame(maxWidth: 600, alignment: .leading)
            .padding()
            
            Spacer()
        }
        .padding()
        .sheet(isPresented: $showSettings) {
            VolcanoSettingsView()
        }
        .onAppear {
            setupRecognitionCallback()
        }
        .onDisappear {
            stopRecognition()
        }
    }
    
    // MARK: - 方法
    
    private func toggleRecording() {
        if isRecording {
            stopRecognition()
        } else {
            startRecognition()
        }
    }
    
    private func startRecognition() {
        guard speechService.isConfigured else {
            errorMessage = "请先配置火山引擎 API 密钥"
            showSettings = true
            return
        }
        
        errorMessage = nil
        
        Task {
            do {
                try await speechService.startRecognition()
                await MainActor.run {
                    isRecording = true
                    interimText = ""
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isRecording = false
                }
            }
        }
    }
    
    private func stopRecognition() {
        speechService.stopRecognition()
        isRecording = false
    }
    
    private func setupRecognitionCallback() {
        speechService.onRecognitionResult = { text, isFinal in
            Task { @MainActor in
                if isFinal {
                    if self.recognizedText == "点击开始说话..." {
                        self.recognizedText = text
                    } else {
                        self.recognizedText += text
                    }
                    self.interimText = ""
                } else {
                    self.interimText = text
                }
            }
        }
    }
    
    private func copyToClipboard() {
        #if os(iOS)
        UIPasteboard.general.string = recognizedText
        #else
        // macOS 或其他平台的剪贴板操作
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(recognizedText, forType: .string)
        #endif
    }
    
    private func clearText() {
        recognizedText = "点击开始说话..."
        interimText = ""
    }
}

// MARK: - 设置视图

struct VolcanoSettingsView: View {
    @State private var appId: String = ""
    @State private var accessToken: String = ""
    @State private var showSavedAlert: Bool = false
    @Environment(\.dismiss) private var dismiss
    
    private let appIdKey = "volcano_app_id"
    private let tokenKey = "volcano_access_token"
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("火山引擎 API 配置")) {
                    TextField("App ID", text: $appId)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    SecureField("Access Token", text: $accessToken)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    if appId.isEmpty || accessToken.isEmpty {
                        Text("请访问火山引擎控制台获取 App ID 和 Access Token")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section {
                    Button(action: {
                        saveCredentials()
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("保存")
                        }
                    }
                    .disabled(appId.isEmpty || accessToken.isEmpty)
                    
                    Button(action: {
                        clearCredentials()
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("清除")
                        }
                        .foregroundColor(.red)
                    }
                    .disabled(VolcanoSpeechService.shared.appId.isEmpty)
                }
                
                Section(header: Text("当前状态")) {
                    HStack {
                        Text("App ID")
                        Spacer()
                        if VolcanoSpeechService.shared.appId.isEmpty {
                            Text("未配置")
                                .foregroundColor(.red)
                        } else {
                            Text("已配置")
                                .foregroundColor(.green)
                        }
                    }
                    
                    HStack {
                        Text("Access Token")
                        Spacer()
                        if VolcanoSpeechService.shared.accessToken.isEmpty {
                            Text("未配置")
                                .foregroundColor(.red)
                        } else {
                            Text("已配置")
                                .foregroundColor(.green)
                        }
                    }
                }
                
                Section(header: Text("帮助")) {
                    Link("火山引擎控制台", destination: URL(string: "https://console.volcengine.com/")!)
                    Link("语音识别文档", destination: URL(string: "https://www.volcengine.com/docs/6561/1322935")!)
                }
            }
            .navigationTitle("语音识别设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
            .alert("已保存", isPresented: $showSavedAlert) {
                Button("确定") { }
            } message: {
                Text("API 配置已保存到本地")
            }
            .onAppear {
                loadCredentials()
            }
        }
    }
    
    private func loadCredentials() {
        appId = UserDefaults.standard.string(forKey: appIdKey) ?? ""
        accessToken = UserDefaults.standard.string(forKey: tokenKey) ?? ""
    }
    
    private func saveCredentials() {
        UserDefaults.standard.set(appId, forKey: appIdKey)
        UserDefaults.standard.set(accessToken, forKey: tokenKey)
        showSavedAlert = true
    }
    
    private func clearCredentials() {
        UserDefaults.standard.removeObject(forKey: appIdKey)
        UserDefaults.standard.removeObject(forKey: tokenKey)
        appId = ""
        accessToken = ""
    }
}

#Preview {
    SpeechToTextView()
}
