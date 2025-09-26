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
## 当前进展（截至 2025-09-26）
- ✅ Android 真机可完成拍照/录像，Gallery CRUD 与导出流程可用。
- ✅ 水印渲染与导出使用统一画布，图片导出比例与预览一致。
- ✅ 摄像头切换流程已重构：初始化串行化、失败回退、预览画幅按捕获分辨率 letterbox 显示。
- ✅ 新增 Android 平台通道（`MainActivity`）枚举可用分辨率，并在相机初始化时根据 `ResolutionPreset` 选择最接近的实际尺寸。
- ⏳ 设置页仍基于枚举 `ResolutionPreset`；需接入 `CameraCapabilitiesService` 暴露的真实选项。
- ⏳ Web 端仍存在拍照黑屏、导出受限等问题，尚未开始处理。
- ⏳ 水印编辑器仍有多指缩放旋转精度、层级侧边栏等交互优化待办。
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
2. **Web 端拍摄与导出**
   - 诊断 Web 相机黑屏（camera Web 支持）；确认是否需改用 `camera_web` 新版本或直接使用 `html` package 管理 `MediaStream`。
   - 设计 Web 导出方案（如使用 `ffmpeg_wasm` 或 `Canvas` 合成）。
3. **水印编辑器体验**
   - 精确控制：为旋转/缩放提供显式控制柄，优化双指手势抖动问题。
   - 层级管理：右侧添加 `ReorderableListView` 显示元素顺序，支持锁定/隐藏。
   - 文本样式：字号输入框、字体选择、时间/地点/天气格式编辑。
4. **图库体验**
   - 根据项目绑定 Profile 渲染缓存缩略图；支持切换 Profile 后刷新预览。
   - 导出弹窗支持快速选择“原图 / 带水印 / 仅水印 PNG”。
5. **技术债 & 质量**
   - 清理 `watermark_element_widget.dart` 中未使用的辅助字段与控件。
   - 建立最小化回归脚本：`flutter analyze`、`flutter test`（待补单测）、关键流程手测清单。
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


# Fmark Camera 重构方案（更新：2025-09-26）

## 目标与原则
- 还原 AGENTS.md 所述体验：实时相机预览叠加分层水印，Profile 独立编辑，Gallery 所见即所得，导出可选择带/不带水印。
- 坚持 KISS / LISP、高内聚低耦合、面向接口扩展；在保留现有 domain/service 的前提下迭代 presentation 层。
- 兼顾 Android 主线可用性与 Web 版本的补齐，注意跨端能力差异。

## 架构分层（现状）
- **domain**：`WatermarkProfile`、`WatermarkElement`、`WatermarkProject` 等模型维持 JSON 序列化；数据结构稳定。
- **services / controllers**：
  - `WatermarkProfilesController`、`WatermarkProjectsController` 已接管 Profile 与拍摄记录的状态管理。
  - `WatermarkContextController`、`WatermarkRenderer`、`WatermarkExporter` 继续负责上下文、渲染与导出；导出仍依赖 FFmpeg Kit（移动端）与 wasm（Web 待实现）。
  - 新增 `CameraCapabilitiesService`（Android）通过平台通道读取每个 cameraId 的照片/视频分辨率，为后续设置页/画布同步提供真实参数。
- **presentation**：`camera/`、`profiles/`、`gallery/` 模块化拆分；`watermark_canvas.dart` 负责渲染，`watermark_element_widget.dart` 负责交互。

## 当前状态
### 已完成
1. **Android 拍摄主线**：真机拍照/录像、Gallery CRUD、带/不带水印导出均可执行。
2. **画幅同步**：相机预览与导出统一使用捕获分辨率；`CameraPreview` 使用 `FittedBox + ClipRect` letterbox，Gallery/导出所见一致。
3. **摄像头切换稳定化**：切换流程串行化、失败回滚，避免黑屏无法恢复；日志仍显示 CameraX 重开，但预览可恢复。
4. **捕获能力查询**：Android 端新增 MethodChannel 返回真实输出尺寸，Dart 侧完成解析与缓存。

### 仍存在 / 待确认
1. **分辨率设置页**：UI 仍显示 `ResolutionPreset`，尚未接入真实分辨率列表；切换模式时 Profile 画布需与用户选择同步。
2. **Web 端流程**：仍存在相机黑屏、导出能力缺失；尚未验证摄像权限与 `camera_web` 兼容性。
3. **水印编辑器体验**：多指缩放/旋转精度不足，缺少显式控制柄；层级管理、文本样式面板仍需重构。
4. **Gallery 缩略图**：视频缩略图在部分设备仍可能黑屏，需对 `thumbnailData` 缓存与生成策略回归验证。
5. **代码健康**：`watermark_element_widget.dart` 保留若干未使用字段/方法；`flutter analyze` 仍给出相关警告。

## 关键问题 & 观察
- **摄像头重开日志**：切换摄像头仍输出大量 `PENDING_OPEN` → `OPENING` 日志，需要进一步排查是否存在资源占用或权限限制（见 2025-09-26 提供的 log）。
- **画幅不一致反馈**：历史问题源于导出使用固定 4:3，需要继续在不同分辨率（4:3、16:9、21:9）下回归，确认新逻辑覆盖。
- **Web 权限/兼容性**：需在 Chrome/Edge 下复现黑屏情况，确认是否为浏览器权限、设备不支持或插件缺陷。

## 最近一次迭代主要改动
1. **相机能力通道**（Android）：`MainActivity.kt` 新增 `getCameraCapabilities`；`CameraCapabilitiesService` 解析并缓存分辨率列表；`Bootstrapper` 注入服务。
2. **相机预览 & 存储对齐**：`camera_screen.dart` 中 `_initializeCamera`、`_switchCamera`、`_storeCapture`、`_buildPreviewLayer`、`_syncCanvasSizeIfNeeded` 全面改写，统一使用 `_currentCaptureInfo` 与捕获尺寸。
3. **模型增强**：`CameraResolutionInfo` 追加 `aspectRatio`、`pixelCount`、近似相等判断，支撑分辨率筛选与缓存比较。

## 下一步计划
### Sprint 1（进行中）
- 将 `SettingsScreen` 下拉改为真实分辨率列表（区分照片/视频）；同步 Profile 画布与 Gallery 列表。
- Android 回归：不同分辨率下拍照、录像、导出、摄像头切换；记录截图与日志。
- 清理 `watermark_element_widget.dart` 未使用代码，保持 `flutter analyze` 仅保留必要警告。

### Sprint 2
- 重构水印编辑器交互：引入旋转/缩放柄、数值微调、层级侧栏（ReorderableListView）、文本样式面板。
- 调研并实现 Web 拍照路径（评估 `camera_web` 新版本或自定义 `MediaStream`）；制定 Web 导出方案（`ffmpeg_wasm` 或 Canvas 合成）。

### Sprint 3
- 完善 Gallery：视频缩略图缓存策略、导出对话框（原片/带水印/仅水印 PNG）、Profile 快速切换预览。
- 评估自动化测试（Widget/Integration）可行性，至少补充 Profile CRUD、导出流程的最小测试。

## 测试与验证
- `flutter analyze`：当前仍提示水印编辑器未用字段/元素；需在后续重构时清理。
- 手动回归：Android 实机已验证拍照、录像、导出（含带/不带水印）、摄像头切换；需在更多设备与分辨率下扩充验证。
- 自动化测试：尚未编写。

## 参考
- 产品 PRD / 交互说明：`AGENTS.md`
- 进度截图与差异：`docs/snapshot/`
- 构建与手动测试：`docs/macos_build_and_test.md`
- 最新摄像头日志：2025-09-26 Android 切换摄像头 log（参见需求中附带片段）。
