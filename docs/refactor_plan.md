# Fmark Camera 重构计划（更新：2025-09-26）

## 概览
- 目标：实现分层水印拍摄体验，保持原始媒资纯净，支持水印 Profile 管理、所见即所得导出与跨端运行。
- 方法论：遵循 KISS / LISP、高内聚低耦合、面向接口设计；复用现有 domain/service 分层，逐步替换展示层。
- 当前重点平台：Android（主力验证）、Web（需补齐拍摄与导出链路）、macOS（可选调试）。

## 架构摘要
- **domain**：`WatermarkProfile`、`WatermarkElement`、`WatermarkProject` 等保持 JSON 序列化能力。
- **services/controllers**：
  - `WatermarkProfilesController` 管理 Profile CRUD、激活与画布尺寸同步。
  - `WatermarkProjectsController` 维护拍摄记录、缩略图与导出状态。
  - `WatermarkContextController`、`WatermarkRenderer`、`WatermarkExporter` 提供上下文、渲染与导出能力。
  - 新增 `CameraCapabilitiesService`（Android）缓存真实拍照/录像分辨率，供相机与设置页使用。
- **presentation**：`camera/`、`profiles/`、`gallery/` 模块化组织；`watermark_canvas.dart` / `watermark_element_widget.dart` 负责水印渲染与编辑交互。
## 当前进展（更新：2025-09-27）
- ✅ 相机预览按平台自适配：移动端默认 1080×1920，Web 默认 1920×1080，预览不再横向拉伸；捕获尺寸、Profile 画布、导出水印保持一致。
- ✅ 水印编辑器交互重构：单指拖动、双指缩放旋转、显式旋转/删除把手已可点击；临时控制器生命周期修复。
- ✅ 设置页保留真实分辨率选择逻辑（待联动能力服务扩展更多字段）。
- ⏳ Web 端拍摄/导出链路仍需进一步验证与 wasm 性能评估。
- ⏳ Gallery 所见即所得缓存与 Profile 层级侧栏优化仍在规划中。
## 近期主要改动
1. **相机能力接入**：
   - `android/app/src/main/kotlin/com/example/fmark_camera/MainActivity.kt` 增加 `getCameraCapabilities` MethodChannel，返回每个 cameraId 的照片/视频输出尺寸。
   - `lib/src/services/camera_capabilities_service.dart` 提供能力缓存、查找与去重排序逻辑。
   - `lib/src/services/bootstrapper.dart` 注入能力服务，供相机和后续设置界面复用。
2. **画幅与导出对齐**：
   - `lib/src/presentation/camera/camera_screen.dart` 在初始化与切换摄像头时选取实际捕获尺寸，预览层改用 `FittedBox + ClipRect` 保持 letterbox，`_storeCapture` / `_syncCanvasSizeIfNeeded` 使用捕获分辨率更新 Profile 与 Gallery。
   - `lib/src/domain/models/camera_resolution_info.dart` 增加 `aspectRatio`、`pixelCount` 与宽高近似比较，便于分辨率筛选。
3. **稳定性**：
   - `_initializeCamera` 串行化处理，确保 dispose→initialize 顺序；失败时回滚 UI 状态并提示。
   - `_switchCamera` 仅在非录制状态触发，直接重用 `_initializeCamera`，解决黑屏与无法恢复问题。
## 待办清单
1. **分辨率设置 UI**
   - 将 `SettingsScreen` 的下拉项替换为基于能力服务的真实列表，展示像素与纵横比；持久化时需要区分照片/视频独立选择。
   - 在 Profile 编辑/画布同步中记录当前配置，防止跨模式画幅错位。
   - 同时当前选择的分辨率与实际捕获分辨率不一致，比如选择的 4096*2304, 但是实际导出时为:2448*3264. 需要修复
2. **水印编辑器体验**
   - 精确控制：为旋转/缩放提供显式控制柄，优化双指手势抖动问题。当前无法实现双指缩放，以及拖动旋转控制柄进行旋转，, 需要修复
   - 层级管理：右侧添加 `ReorderableListView` 显示元素顺序，支持锁定/隐藏。
   - 文本样式：字号输入框、字体选择、时间/地点/天气格式编辑。
3. **图库体验**
   - 根据项目绑定 Profile 渲染缓存缩略图；支持切换 Profile 后刷新预览。
   - 导出弹窗支持快速选择“原图 / 带水印 / 仅水印 PNG”。
4. **技术债 & 质量**
   - 清理 `watermark_element_widget.dart` 中未使用的辅助字段与控件。
   - 建立最小化回归脚本：`flutter analyze`、`flutter test`（待补单测）、关键流程手测清单。
5. **Web 端拍摄与导出**
   - 诊断 Web 相机黑屏（camera Web 支持）；确认是否需改用 `camera_web` 新版本或直接使用 `html` package 管理 `MediaStream`。
   - 设计 Web 导出方案（如使用 `ffmpeg_wasm` 或 `Canvas` 合成）。
## 阶段性计划建议
### Sprint 1（当前进行）
- 完成设置页分辨率接入，确保 Profile / Gallery 画幅全链路一致。
- 回归 Android 拍照、录像、导出、摄像头切换；补录日志与截图。
- 整理未使用代码，保证 `flutter analyze` 仅保留必要告警。

### Sprint 2
- 集中处理水印编辑器交互：旋转柄、层级列表、文本样式面板。
- Web 相机兼容调查，决定技术路线并实现最小可用拍照。

### Sprint 3
- Gallery 所见即所得优化、导出对话框完善、Profile 导出模板。
- 评估自动化测试（Widget/Integration）可行性，至少补充关键业务单测。
## 测试与验证
- `flutter analyze`：当前仅剩水印编辑器未用元素相关告警；需在后续迭代处理。
- 自动化测试：暂无；建议在交互稳定后补充最小 Widget 测试验证 Profile CRUD、渲染结果。
- 手动回归：已在 Android 实机验证拍照、录像、导出（带/不带水印）及摄像头切换。

## 参考资料
- 产品 PRD / 指南：`AGENTS.md`
- 旧版本截图与对比：`docs/snapshot/`
- 构建与验证：`docs/macos_build_and_test.md`
