//
//  SpatialYOLOApp.swift
//  SpatialYOLO
//
//  Created by 关一鸣 on 2025/3/30.
//

import SwiftUI

@main
struct SpatialYOLOApp: App {

    @State private var appModel = AppModel()

    var body: some Scene {
        WindowGroup(id: "main") {
            TabView (selection: $appModel.selectedTab) {

                ContentView(appModel: appModel)
                    .tabItem {
                        Label("识别", systemImage: "sparkle.magnifyingglass")
                    }
                    .tag(0)
                    .environment(appModel)
                
                GeminiLiveView(appModel: appModel)
                    .tabItem {
                        Label("Gemini Live", systemImage: "wand.and.stars")
                    }
                    .tag(1)
                    .environment(appModel)
                
                SpeechToTextView()
                    .tabItem {
                        Label("语音转文字", systemImage: "waveform")
                    }
                    .tag(2)
                    .environment(appModel)

            }
        }

        ImmersiveSpace(id: appModel.immersiveSpaceID) {
            ImmersiveView(appModel: appModel)
                .environment(appModel)
                .onAppear {
                    appModel.immersiveSpaceState = .open
                }
                .onDisappear {
                    appModel.immersiveSpaceState = .closed
                }
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
        
     }
}
