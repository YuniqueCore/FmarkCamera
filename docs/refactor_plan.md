# Fmark Camera 重构方案（2025-09-25）

## 目标
- 按 AGENTS.md 还原产品体验：实时相机预览 + 分层水印；独立 Profile 编辑页与图库所见即所得；导出时支持带/不带水印。
- 遵循 KISS/LISP，高内聚低耦合，面向接口编程，可继续扩展更多水印元素。
- 重建 UI 页面结构，确保 Profile 编辑画布与相机预览尺寸一致，交互流畅可用。

## 架构分层
- **domain**：沿用既有模型（WatermarkProfile/Element/Project 等），保持序列化能力。
- **services**：
  - `WatermarkProfilesController`：基于 Repository 的可观察状态，负责 Profile CRUD、激活、默认值、画布同步。
  - `WatermarkProjectsController`：负责拍摄记录列表、缩略图缓存及更新。
  - 现有 `WatermarkContextController`、`WatermarkRenderer`、`WatermarkExporter` 等继续复用。
- **presentation**：划分为三个 feature 模块：
  - `camera/`：主相机页面，负责拍照/录像、Profile 快速切换、跳转编辑页，叠加只读水印层。
  - `profiles/`：
    - `profiles_screen.dart`：Profile 列表管理，新建/复制/重命名/删除/设为默认。
    - `profile_editor_screen.dart`：画布编辑器，提供元素增删改、拖拽缩放旋转、属性面板。
  - `gallery/`：所见即所得图库，展示缩略图、预览、导出。
  - `widgets/`：共用 `WatermarkLayer`（展示）与 `EditableWatermarkCanvas`（编辑）组件。

## 关键交互
1. **Profile 编辑**
   - 进入编辑页时，若 Profile 未设置 `canvasSize`，使用当前相机预览尺寸同步。
  - 画布背景按等比缩放显示示例相机框（半透明蒙版 + 网格），元素拖拽/旋转/缩放均以归一化坐标保存。
  - 属性面板包含：内容（文本/时间格式/地点开关/天气开关/图片选择）、样式（字号、加粗、调色板）、层级、删除。
2. **相机页**
   - 顶部操作区：Profile 列表入口、图库入口、设置等。
   - 取景框：`Stack(CameraPreview, WatermarkLayer)`，随上下文变化实时刷新。
   - 底部操作区：拍照/录像、模式切换、Profile 快捷切换 Chips。
3. **图库**
   - 加载 `WatermarkProject` 列表并根据绑定 Profile 渲染缩略图（缓存 Base64）。
   - 查看详情时可切换 Profile 进行预览，导出带/不带水印或仅导出水印图层。

## 重构里程碑
1. **状态层**：实现 `WatermarkProfilesController`、`WatermarkProjectsController`，Bootstrapper 中初始化。
2. **UI 重建**：
   - 替换旧的 Template & Editor 页面为新 `profiles_screen` + `profile_editor_screen`。
   - 重写 `camera_screen` 接入控制器与新组件。
   - 重写 `gallery_screen` 使用 Projects Controller。
3. **组件复用**：抽象 `WatermarkLayer` 与 `EditableWatermarkCanvas`，支撑预览与编辑场景。
4. **验证**：`flutter analyze`、重点交互手动回归（拖拽、录制、导出、切换 Profile）。

> 本文档作为重构执行依据，后续若需求调整请同步更新。
