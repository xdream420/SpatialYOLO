//
//  ContentView.swift
//  SpatialYOLO
//
//  Created by 关一鸣 on 2025/3/30.
//

import SwiftUI
import RealityKit
import RealityKitContent

struct ContentView: View {
    var appModel: AppModel

    var body: some View {
        VStack {
            Model3D(named: "Scene", bundle: realityKitContentBundle)
                .padding(.bottom, 50)

            Text("SpatialYOLO")
                .font(.title)
            
            Text("实时物体检测")
                .font(.subheadline)
                .foregroundColor(.secondary)

            ToggleImmersiveSpaceButton(appModel: appModel)
        }
        .padding()
    }
}
