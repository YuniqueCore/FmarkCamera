## 代码结构
- `lib/src/app.dart`：应用入口与路由。
- `lib/src/domain/models`：各类领域模型（Profile、Element、Context、Project 等）。
- `lib/src/domain/repositories`：抽象仓储接口。
- `lib/src/data/repositories`：基于本地存储的仓储实现。
- `lib/src/data/storage`：平台文件存储封装（IO/Web）。
- `lib/src/services`：上下文、导出、渲染、位置、天气等服务；`watermark_exporter` 通过工厂根据平台创建实现。
- `lib/src/presentation`：按功能模块划分页面与组件（camera/gallery/templates/settings 等）。
- `test/`：测试目录，目前仅保留默认 widget_test。
- `pubspec.yaml`：依赖定义，包含 camera、ffmpeg-kit、geolocator 等。