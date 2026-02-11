# SpatialYOLO 项目笔记

## 项目概述
- **平台**: Apple Vision Pro (visionOS)
- **功能**: 在空间计算设备上进行实时物体检测
- **模型**: YOLO11n (CoreML 格式)

## 开发环境要求
- Xcode 15+
- visionOS 2.0+
- Apple Vision Pro 或模拟器
- Python 3.x (用于模型导出)

## 模型导出步骤
```bash
pip install ultralytics
yolo export model=yolo11n.pt format=coreml nms=true
```

## 项目结构
```
SpatialYOLO/
├── SpatialYOLOApp.swift      # 应用入口
├── AppModel.swift             # 数据模型
├── AppModel+ObjectDetection.swift  # YOLO检测逻辑
├── CameraView.swift           # 相机视图
├── ImmersiveView.swift        # 沉浸式空间视图
├── ContentView.swift          # 主界面
└── ToggleImmersiveSpaceButton.swift  # 沉浸模式切换
```

## 权限配置
需要在 Signing & Capabilities 中添加:
- Main Camera Access

## 参考文档
- [Ultralytics CoreML Integration](https://docs.ultralytics.com/integrations/coreml/)

---
*笔记由提比略整理*
