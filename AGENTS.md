

我的需求:
重点就是拍照/视频, 界面上能够实时展示水印, 同时照片和水印实际并没有合并为单一图片.而是分层的. 使得拍照/视频之后依旧能够更改水印. 并且也支持水印用户自定义化... 目前我们需要支持的就是 时间/地点/天气/图片 格式. 支持旋转, 缩放等常用的类似画布的操作.
请你仔细阅读下面的分析和规划, 仅使用 flutter + dart 完成支持自定义水印,分层水印 视频/照片 相机的开发.

此外你还需要遵守 KISS 准则, LISP 准则, 面向接口设计和实现, 保持克制, 保持克制, 保证功能/函数模块化, 高内聚, 低耦合, 带有可组合性，保持代码简洁性，积极重构和复用代码, 保持代码逻辑清晰, 结构清晰, 代码简单, 简洁, 但是功能正确. 易于理解和拓展.
你也可以在需要的时候, 自主调用具, 或者联网查询, 从而更好的辅助你完成任务.

当前的flutter 水印相机进度:

能够通过 flutter run -d chrome 运行起来了,并且也能正常的获取摄像头,地理,麦克风权限进入主页面.

问题:
1. 水印元素不能给拖动,更改内容等等..
2. 水印元素无法删除
3. 水印相机的拍照功能现在能够拍照??(在拍摄历史里有记录而已…)
4. 无法导出拍好的照片(带水印/不带水印)…

同时, 当前的运作流程也不是我想要的..

我希望的是

重点就是拍照/视频, 界面上能够实时展示水印, 同时照片和水印实际并没有合并为单一图片.而是分层的. 使得拍照/视频之后依旧能够更改水印.

并且也支持水印用户自定义化... 目前我们需要支持的就是 时间/地点/天气/图片 格式. 支持旋转, 缩放等常用的类似画布的操作.

然后水印的编辑和保存可以存为 profile, 从而用户可以创建多个profile,
进而在相机主页面就可以完成 profile的切换, 从而完成 watermark 的快速切换

同时, 水印的画板编辑就可以放到 watermark profile 的 editing 中去做就好.

就可以将相机拍照主页面的功能专注于拍照以及 watermark profile layer 的叠加, 进而实现实时预览.

但是在 watermark profile 的 editing 的时候, 就需要默认将背景画板的大小设置为和当前的用户设置的相机配置/视频配置一致,才能确保水印位置的准确性,

然后就是也需要做好 gallery, 而不是像当前的这样的简单的list…. gallery 中的图片都应该是 photo 上面 叠放对应的 watermark, 才能让用户体验更好, 所见即所得.

但是在导出/分享的时候还是询问用户导出带水印或者不带水印的图片.

# 产品 PRD

## 一、产品目标

1. 拍照/录像；2) 预览时**实时叠加水印**（UI 层），**原始媒资不含水印**；3) 水印**分层/可编辑**，可保存为多个 **Profile** 并在相机主界面一键切换；4) 支持水印元素：**时间 / 地点（经纬度+地名）/ 天气 / 图片**；5) 画布操作：**拖拽/缩放/旋转**、层级、不透明度；6) 导出/分享时可选择**带水印**或**不带水印**版本。

> 关键设计：Camera 仅产出“净片/净视频”，水印以**结构化配置**独立存储；预览叠加在 UI（`Stack(CameraPreview, WatermarkLayer)`），导出再离线合成。这样可以“拍后可改”。（相机预览与 `Stack` 叠加：Flutter 官方相机示例与资料所述可行。([Flutter Docs][1])）

## 二、核心用户流程

* **相机主界面**：
  进入即显示 `CameraPreview`；右上切换 **Photo/Video**；底部可快速切换 **Watermark Profile**；取景框里实时看到水印**预览层**。([Flutter Docs][1])
* **水印编辑（Profile Editing）**：
  打开某个 Profile 的画布编辑页；**画布尺寸与当前拍摄配置一致**（分辨率/比例），以保证位置像素级一致；可添加/删除/编辑元素，拖拽/缩放/旋转。完成后保存为 Profile。
* **图库（Gallery）**：
  以“**所见即所得**”渲染：缩略图/预览时动态把**对应 Profile** 叠在底图上显示；进入详情可切换 Profile 预览。导出时选择“带/不带水印”。
* **导出/分享**：

  * 图片：离屏合成（`RepaintBoundary.toImage` 或 `Canvas`）得到带水印图；原图保持不动。([api.flutter.dev][2])
  * 视频：用 **FFmpegKit** 离线叠加文本/图片水印（`drawtext/overlay`），音频尽量直拷（`-codec:a copy`）。([GitHub][3])

## 三、功能需求与验收标准

1. **拍照/录像**

   * 能启动前/后摄、对焦/曝光、闪光、分辨率/帧率选择；拍照成功得到文件路径；录像支持开始/暂停/停止。([Flutter Docs][1])
2. **水印预览层（相机页）**

   * 以 `Stack` 叠加自定义 Widget；**预览可见但原始拍摄文件不含水印**（这是预期）；60fps 设备上尽量流畅。([Flutter Docs][1])
3. **水印元素**

   * 时间（格式化），地点（经纬度；反向地理为城市/街道），天气（温度/现象），图片（Logo）；元素支持拖拽/缩放/旋转、层级、不透明度、对齐吸附。([Dart packages][4])
4. **Profile 管理**

   * 新建/复制/重命名/删除；一键切换；每个 Profile 保存元素集合 + 变换矩阵/样式。
5. **图库**

   * 缩略图/预览统一以“底图 + Profile 渲染”的所见即所得方式展示（实时合成或缓存）；支持按文件/日期筛选。
6. **导出**

   * 图片导出：JPG/PNG；视频导出：码率/分辨率可选；都能选择“带/不带水印”。图片导出用 `toImage/Canvas`，视频用 FFmpegKit 的 `overlay/drawtext`。([api.flutter.dev][2])

## 四、非功能性

* **易用**：编辑手势流畅，不与外层滚动冲突（`InteractiveViewer`/自定义手势优先级）。([Stack Overflow][5])
* **稳定**：权限请求/失败兜底；定位/反地理/天气做缓存与退避。([Dart packages][4])
* **性能**：预览层仅绘制必要元素；导出在后台 Isolate；FFmpegKit 日志可查看。([GitHub][3])
* **平台**：Web 以 `camera` 的 Web 支持为准；桌面不在 MVP 范围内。([Flutter Docs][1])

---

# 技术设计（KISS / LISP / 高内聚低耦合）

## 1) 模块划分

* `camera_service`：封装 `camera` 的控制与状态（取镜列表、初始化、拍照/录像）。([Flutter Docs][1])
* `wm_canvas`：**仅处理水印渲染与交互**；输入为 `WatermarkProfile`，输出为**纯粹的**元素状态与变换矩阵（不关心相机）。手势层建议基于 `InteractiveViewer` 或 `matrix_gesture_detector`。([Stack Overflow][6])
* `profile_repo`：Isar/本地存储，管理 Profile CRUD 与版本。
* `location_service`：`geolocator` + `geocoding`，暴露 `{lat,lng,placeString}`；附 LRU 缓存。([Dart packages][4])
* `weather_service`：`open_meteo` SDK 或简易 HTTP；暴露 `{temp,code,desc,icon}`；附缓存。([Dart packages][7])
* `exporter_image`：`RepaintBoundary.toImage`/`Canvas` 合成图像。([api.flutter.dev][2])
* `exporter_video`：**FFmpegKit** 生成带水印视频（文本 `drawtext` + 图片 `overlay`）；封装命令拼装、字体路径解析、进度回调。([GitHub][3])
* `gallery_service`：读取媒资文件与其绑定的 Profile，负责**所见即所得**缩略图缓存。

## 2) 数据模型（简版）

```json
WatermarkProfile {
  "id": "uuid",
  "name": "Outdoor-1",
  "canvas": {"width":1920,"height":1080,"pixelRatio":1.0},  // 与拍摄配置一致
  "elements": [WatermarkElement]
}

WatermarkElement {
  "id":"uuid",
  "type":"time|location|weather|image|text",
  "bindings": {...},             // 如 time format, weather fields, image path
  "style": {...},                // color, font, opacity, stroke...
  "transform": { "matrix":[16] } // Matrix4
}

CaptureItem {
  "id":"uuid",
  "path":".../IMG_0001.jpg|.mp4",
  "profileId":"uuid",            // 当前预览绑定的 Profile
  "meta": {"lat":..,"lng":..,"timestamp":...}
}
```

## 3) 关键实现细节

* **相机页叠加**

  ```dart
  Stack(
    children:[
      CameraPreview(controller),               // 仅显示预览
      WatermarkCanvas(profile: currentProfile) // 叠加层（可编辑/可锁定）
    ],
  );
  ```

  > 预览层只影响 UI，不会进入 `takePicture()` 的结果文件，这正是“分层”。([Flutter Docs][1])

* **手势与编辑**
  优先用 `InteractiveViewer`（平移/缩放/旋转可组合），或 `matrix_gesture_detector` 获取矩阵；解决与滚动冲突参考已知实践。元素**删除**与**内容编辑**走“选中态 + 工具条”。([Stack Overflow][6])

* **图片导出（带水印）**
  使用 `RenderRepaintBoundary.toImage`（需确保已完成 paint）；或构造 `PictureRecorder+Canvas` 离屏绘制底图再绘水印。([api.flutter.dev][2])

* **视频导出（带水印）**

  * 文本：`-vf "drawtext=fontfile=/abs/Font.ttf:text='...':x=...:y=...:fontsize=...:fontcolor=...:box=1:boxcolor=..."`
  * 图片：`-i input.mp4 -i overlay.png -filter_complex "overlay=x:y"`
  * 音频直拷：`-codec:a copy`
    封装为 `VideoExporter.buildCommand(videoPath, profile, canvasSize)`。([GitHub][3])

* **位置/地名/天气**

  * `geolocator.getCurrentPosition()` 获取经纬度（会触发权限流程）；
  * `placemarkFromCoordinates` 反地理；
  * `open_meteo` 取现象/温度，缓存 10–15 分钟。([Dart packages][4])

---

# 对照你当前的 4 个问题 —— 直接可做的修复清单

1. **“水印元素不能拖动/更改内容”**

   * 引入 `InteractiveViewer`/`matrix_gesture_detector`，每个元素包裹手势层，输出 `Matrix4` 存入 `transform`；
   * 文本/时间/地点/天气的**内容编辑**通过悬浮工具条（`showModalBottomSheet`），修改 `bindings` 或 `style`；
   * 处理手势冲突与命中区（选择态显示锚点/边框）。([Stack Overflow][6])

2. **“水印元素无法删除”**

   * 设计“选中态”状态机：`idle -> selecting(elementId) -> editing -> idle`；
   * 选中后显示操作条（层级/复制/删除）。数据层直接从 `profile.elements` 移除并 `setState/notifyListeners`。

3. **“拍照功能只是有记录”**

   * 按官方流程：初始化 `CameraController` → `await controller.takePicture()` 得到 **真实文件路径**；把路径写入 `CaptureItem` 并落盘（Isar）。([Flutter Docs][1])

4. **“无法导出带/不带水印”**

   * **不带水印**：直接复制源文件到导出位置；
   * **带水印·图片**：使用 `RepaintBoundary.toImage(pixelRatio)` 或 `Canvas` 离屏合成；
   * **带水印·视频**：`FFmpegKit` 拼命令（文本用 `drawtext`、logo 用 `overlay`），导出新 mp4；提供进度/取消。([api.flutter.dev][2])

---

# 界面 & 路由（简）

* `/camera`：相机主界面（预览 + Profile 快切 + 拍摄按钮）
* `/profiles`：Profile 列表（新建/复制/删除）
* `/profile/:id`：画布编辑（尺寸=当前拍摄配置）
* `/gallery`：图库（缩略图以“底图+Profile 渲染”）
* `/detail/:captureId`：详情（切换 Profile 预览 / 导出）

---

# 开发里程碑（两周节奏示例）

**M1（本周）**

* 搭好 `camera_service`，能拍照/录像并持久化路径；
* `wm_canvas` 初版：元素增删、拖拽/缩放/旋转、选择态；
* `profile_repo` + `profiles` 列表；**相机页叠加预览**。([Flutter Docs][1])

**M2（下周）**

* `location_service` / `weather_service` 接好，时间/地点/天气元素联动；([Dart packages][4])
* `exporter_image`/`exporter_video` 完成，导出带/不带水印；([api.flutter.dev][2])
* `gallery_service` 完成所见即所得缩略图缓存；
* 打磨手势/性能与错误处理。

---

# 设计原则落实（你要求的 KISS / LISP / 低耦合）

* **面向接口**：每个 `service` 先定义 `abstract class` 与 `Value Object`，UI 只依赖接口；
* **高内聚**：水印编辑只关心 Profile 与元素，不知道“相机”；相机也不关心水印实现；
* **可组合**：元素类型通过**工厂 + 策略**扩展（将来加“二维码/条形码/文字段落/模板变量”不改旧代码）；
* **简洁/可重用**：手势层做成通用的 `Transformable` 组件，复用到所有元素；
* **积极重构**：导出命令生成器独立成 `ffmpeg_command_builder.dart`，避免把字符串拼接散落在 UI。

---

## 参考与依据

* Flutter 官方相机食谱与 `CameraPreview` 用法（预览叠加 Widget）：([Flutter Docs][1])
* Overlay/Stack 叠加相机文章：([C# Corner][8])
* 手势（平移/缩放/旋转）实践与冲突处理：([Stack Overflow][6])
* 位置/反地理与权限：([Dart packages][4])
* 天气 SDK（Open-Meteo Dart）：([Dart packages][7])
* 图片离屏导出 API：([api.flutter.dev][2])
* 视频水印（FFmpegKit / drawtext / overlay）：([GitHub][3])
* 视频播放（用于预览/校验）：([Dart packages][9])

---

如果你愿意，我可以把 **Issue 模板 + 任务分解**（每条含验收标准和代码入口）以及**依赖清单 pubspec.yaml 草案**直接给到你，照着就能推进。

[1]: https://docs.flutter.dev/cookbook/plugins/picture-using-camera?utm_source=chatgpt.com "Take a picture using the camera - Flutter"
[2]: https://api.flutter.dev/flutter/rendering/RenderRepaintBoundary/toImage.html?utm_source=chatgpt.com "toImage method - RenderRepaintBoundary class - rendering library - Flutter"
[3]: https://github.com/zumoris/ffmpeg-kit-watermark?utm_source=chatgpt.com "GitHub - zumoris/ffmpeg-kit-watermark: FFmpeg Kit for applications ..."
[4]: https://pub.dev/packages/geolocator?utm_source=chatgpt.com "geolocator | Flutter package - Pub"
[5]: https://stackoverflow.com/questions/73410800/how-to-fix-interactiveviewer-and-scrollviews-competing-for-gestures?utm_source=chatgpt.com "how to fix InteractiveViewer and scrollviews competing for gestures"
[6]: https://stackoverflow.com/questions/54536275/flutter-how-to-implement-rotate-and-pan-move-gesture-for-any-container?utm_source=chatgpt.com "rotation - Flutter: How to implement Rotate and Pan/Move gesture for ..."
[7]: https://pub.dev/packages/open_meteo?utm_source=chatgpt.com "open_meteo | Dart package - Pub"
[8]: https://www.c-sharpcorner.com/article/flutter-camera-overlay-or-overlap-using-stack-bar/?utm_source=chatgpt.com "Flutter Camera Overlay Or Overlap Using Stack Bar - C# Corner"
[9]: https://pub.dev/packages/video_player?utm_source=chatgpt.com "video_player | Flutter package - Pub"
