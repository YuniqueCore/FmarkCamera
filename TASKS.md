# Task Breakdown
1. 初始化 Flutter 项目结构和基础配置。
2. 定义水印相关的核心数据模型与仓库接口。
3. 实现位置、天气、时间数据的采集服务。
4. 构建水印渲染与编辑组件，实现拖拽/缩放/旋转。
5. 集成相机功能，实现在预览层叠加水印和拍摄功能。
6. 实现图片与视频导出逻辑，保持水印配置分层保存。
7. 整体联调，补充必要的工具类和界面导航。

##  platform

web should make this application works on android, web, macOS.
but currently I have not install the android studio but I have connect the physical android instead.
So, if you want to debug on android, please the physical android device, but currently, please fix issues and build it on web firstly now.

unic@unicM3Air ~/d/f/FmarkCamera (dev-fix)> flutter doctor
Doctor summary (to see all details, run flutter doctor -v):
[✓] Flutter (Channel stable, 3.35.4, on macOS 26.0 25A354 darwin-arm64, locale en-CN)
[✗] Android toolchain - develop for Android devices
    ✗ cmdline-tools component is missing.
      Try installing or updating Android Studio.
      Alternatively, download the tools from https://developer.android.com/studio#command-line-tools-only and make
      sure to set the ANDROID_HOME environment variable.
      See https://developer.android.com/studio/command-line for more details.
[!] Xcode - develop for iOS and macOS (Xcode 26.0.1)
    ✗ Unable to get list of installed Simulator runtimes.
[✓] Chrome - develop for the web
[!] Android Studio (not installed)
[✓] VS Code (version 1.104.1)
[✓] Connected device (3 available)
[✓] Network resources

! Doctor found issues in 3 categories.

unic@unicM3Air ~/d/f/FmarkCamera (main)> flutter devices
Found 2 connected devices:
  macOS (desktop) • macos  • darwin-arm64   • macOS 26.0 25A354 darwin-arm64
  Chrome (web)    • chrome • web-javascript • Google Chrome 140.0.7339.208

Found 1 wirelessly connected device:
  2112123AC (wireless) (mobile) • adb-97796444-LV36cT._adb-tls-connect._tcp • android-arm64 • Android 13 (API 33)

Run "flutter emulators" to list and start any available device emulators.

If you expected another device to be detected, please run "flutter doctor" to diagnose potential issues. You may
also try increasing the time to wait for connected devices with the "--device-timeout" flag. Visit
https://flutter.dev/setup/ for troubleshooting tips.

I have not install the android studio but I have connect the physical android instead.

So, if you want to debug on android, please the physical android device, but currently, please fix issues and build it on web firstly now.


## Current issues
核心成果

  - 统一导出接口：在 lib/src/services/watermark_exporter.dart:49 新增 WatermarkMediaInput，IO/Web 实现改用该封装，现可同
  时处理文件路径与内存字节，后续接入推荐库更简洁。
  - 拍摄记录模型扩展：lib/src/domain/models/watermark_project.dart:12 增加 overlayData 字段，Web 端可缓存 Base64 覆盖
  层，避免只能依赖临时文件。
  - 图库/导出流程升级：lib/src/presentation/gallery/gallery_screen.dart:345-520 新增媒体/水印输入构造、错误兜底与 Web/
  Base64 回退逻辑，导出操作全面使用新接口。
  - 单元测试同步：test/exporter_test.dart:19-225 全面更新为 WatermarkMediaInput 调用方式，覆盖原始导出、Web 适配及异常场
  景，确认接口兼容性。
  - 验证与格式：运行 dart format 覆盖相关文件，并执行 flutter analyze（通过）。

  后续建议

  1. 将 Web 端 WatermarkExporter 接入 ffmpeg_wasm 并在 web/index.html 配置 SharedArrayBuffer。
  2. Android 端导出流程按设置切换相册/自定义目录，联调 gal/gallery_saver_plus 权限。
  3. 继续修复 Web 拍照黑帧、Android 纵横比及视频录制问题，确认 _mediaInputForProject 能拿到有效媒资。
  4. 新增设置页，集中管理导出目标、分辨率等选项，与现有导出管线打通
  5. 完成后运行 flutter test 及真机/浏览器手动验证拍照、录像与导出全流程。
   
目前的 ffmpeg_kit_flutter_min_gpl: ^6.0.1 是不存在的库。
此外我推荐使用上下面这里的部分库来简化开发。

推荐使用的 flutter lib:
1. https://pub.dev/packages/gal : Dart3 plugin for saving image or video to photos 
2. https://pub.dev/packages/flutter_file_dialog : Dialogs for picking and saving files and for picking directories in Android and in iOS.
3. https://pub.dev/packages/gallery_saver_plus : A Flutter plugin to save images and videos from network URLs or local files to the device's gallery. Media files will be visible in Android Gallery and iOS Photos app.
4. https://pub.dev/packages/permission_handler : This plugin provides a cross-platform (iOS, Android) API to request permissions and check their status. You can also open the device's app settings so users can grant permission.
On Android, you can show a rationale for requesting permission.
5. https://pub.dev/packages/ffmpeg_wasm : 支持 PLATFORM,ANDROID,IOS,LINUX,MACOS,WEB,WINDOWS . 所以应该使用这个 ffmpeg 来处理水印，图片，视频，让 web,android,macOS 都可以使用。


我的需求：
重点就是拍照/视频，界面上能够实时展示水印，同时照片和水印实际并没有合并为单一图片。而是分层的。使得拍照/视频之后依旧能够更改水印。并且也支持水印用户自定义化... 目前我们需要支持的就是 时间/地点/天气/图片 格式。支持旋转，缩放等常用的类似画布的操作。
请你仔细阅读下面的分析和规划，仅使用 flutter + dart 完成支持自定义水印，分层水印 视频/照片 相机的开发。

此外你还需要遵守 KISS 准则，LISP 准则，面向接口设计和实现，保持克制，保持克制，保证功能/函数模块化，高内聚，低耦合，带有可组合性，保持代码简洁性，积极重构和复用代码，保持代码逻辑清晰，结构清晰，代码简单，简洁，但是功能正确。易于理解和拓展。
你也可以在需要的时候，自主调用具，或者联网查询，从而更好的辅助你完成任务。

当前的 flutter 水印相机进度：
能够通过 flutter run -d chrome 运行起来了，并且也能正常的获取摄像头，地理，麦克风权限进入主页面。但是之前的实现中 web 界面不支持 ffmpeg, 导致没办法导出合成之后的照片。也没办法拍摄照片... 
然后我使用 flutter run -d 2112123AC 在 android 实机上运行起来了，可以正常的获取权限，然后进行拍照，并且在 gallery 中也能看到照片。

问题：
1. 在 web 端，拍照的结果为全黑 (也就是没能实现), 现在需要实现
2. 在 android 实机上，相机界面的图片的展示和 web 一样为 9*16...导致预览界面的图片被压扁了... 并且无法看到水印。
3. 在 android 实机上，录制的视频报错，结果为全黑。
4. 在 android 实机上，编辑水印的时候，背景画板大小设置为和当前用户设置的相机配置/视频配置一致，所以也存在画板的尺寸问题。
5. 在 web 端无法导出图片/视频，需要实现..
6. 在 android 实机上，导出图片/视频的时候被导出到默认路径了。但是应该导出到相册中。或者用户自定义导出路径。
7. 应该增加一个 settings 功能。将能够配置的功能都变成配置项。

我希望的运作流程是
重点就是拍照/视频，界面上能够实时展示水印，同时照片和水印实际并没有合并为单一图片。而是分层的。使得拍照/视频之后依旧能够更改水印。
并且也支持水印用户自定义化... 目前我们需要支持的就是 时间/地点/天气/图片 格式。支持旋转，缩放等常用的类似画布的操作。
然后水印的编辑和保存可以存为 profile, 从而用户可以创建多个 profile,
进而在相机主页面就可以完成 profile 的切换，从而完成 watermark 的快速切换
同时，水印的画板编辑就可以放到 watermark profile 的 editing 中去做就好。
就可以将相机拍照主页面的功能专注于拍照以及 watermark profile layer 的叠加，进而实现实时预览。
但是在 watermark profile 的 editing 的时候，就需要默认将背景画板的大小设置为和当前的用户设置的相机配置/视频配置一致，才能确保水印位置的准确性，
然后就是也需要做好 gallery, 而不是像当前的这样的简单的 list…. gallery 中的图片都应该是 photo 上面 叠放对应的 watermark, 才能让用户体验更好，所见即所得。
但是在导出/分享的时候还是询问用户导出带水印或者不带水印的图片。