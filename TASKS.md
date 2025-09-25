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
当前的flutter 水印相机进度:

能够通过 flutter run -d chrome 运行起来了,并且也能正常的获取摄像头,地理,麦克风权限进入主页面.

问题:
1. 水印元素不能给拖动,更改内容等等..
2. 水印元素无法删除
3. 水印相机的拍照功能现在能够拍照??(在拍摄历史里有记录而已…)
4. 无法导出拍好的照片(带水印/不带水印)…

同时, 当前的运作流程也不是我想要的..

我希望的是
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