//
//  APIKeySettingsView.swift
//  SpatialYOLO
//
//  Created by 提比略 on 2026/2/11.
//

import SwiftUI

struct APIKeySettingsView: View {
    @State private var apiKey: String = ""
    @State private var showSavedAlert: Bool = false
    @Environment(\.dismiss) private var dismiss
    
    private let keychainKey = "gemini_api_key"
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Gemini API Key")) {
                    SecureField("输入 API Key", text: $apiKey)
                        .textContentType(.password)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    if apiKey.isEmpty {
                        Text("请访问 makersuite.google.com/app/apikey 获取 API Key")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section {
                    Button(action: {
                        saveAPIKey()
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("保存")
                        }
                    }
                    .disabled(apiKey.isEmpty)
                    
                    Button(action: {
                        clearAPIKey()
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("清除")
                        }
                        .foregroundColor(.red)
                    }
                    .disabled(GeminiService.shared.apiKey.isEmpty)
                }
                
                Section(header: Text("当前状态")) {
                    HStack {
                        Text("API Key")
                        Spacer()
                        if GeminiService.shared.apiKey.isEmpty {
                            Text("未配置")
                                .foregroundColor(.red)
                        } else {
                            Text("已配置 (\(GeminiService.shared.apiKey.prefix(8))...)")
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            .navigationTitle("API Key 设置")
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
                Text("API Key 已保存到本地")
            }
            .onAppear {
                loadAPIKey()
            }
        }
    }
    
    private func loadAPIKey() {
        // 从 UserDefaults 读取（实际项目建议使用 Keychain）
        if let savedKey = UserDefaults.standard.string(forKey: keychainKey) {
            apiKey = savedKey
        }
    }
    
    private func saveAPIKey() {
        UserDefaults.standard.set(apiKey, forKey: keychainKey)
        showSavedAlert = true
    }
    
    private func clearAPIKey() {
        UserDefaults.standard.removeObject(forKey: keychainKey)
        apiKey = ""
    }
}

#Preview {
    APIKeySettingsView()
}
