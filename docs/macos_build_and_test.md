# macOS 上的构建与手动测试指南

本文档覆盖在 macOS Ventura 或更高版本环境下，针对 Flutter 工程 **FmarkCamera** 的 Android、Web、macOS 三个平台构建与手动验证流程。所有命令默认在项目根目录执行，建议在开始前将 Flutter SDK 更新至最新稳定版。

## 1. 通用准备工作

1. 安装依赖：
   - [Homebrew](https://brew.sh/)（若已安装可跳过）。
   - Flutter SDK：
     ```bash
     brew install --cask flutter
     ```
   - Dart SDK 随 Flutter 提供，无需单独安装。
2. 更新环境变量：
   ```bash
   export PATH="$PATH:/usr/local/Caskroom/flutter/latest/flutter/bin"
   export PATH="$PATH:$HOME/Library/Android/sdk/platform-tools"
   ```
   可将上述语句追加到 `~/.zshrc`，并重新打开终端。
3. 初始化 Flutter 环境并启用桌面/Web 支持：
   ```bash
   flutter config --enable-macos-desktop --enable-web
   flutter upgrade
   flutter precache --macos --android --web
   flutter doctor -v
   ```
   确保 `flutter doctor` 中的 Android toolchain、Xcode、Chrome (web) 均为 `No issues found` 或 `✓`。

## 2. Android 构建与测试

1. 安装与配置：
   - 通过 Homebrew 安装 Android Studio：
     ```bash
     brew install --cask android-studio
     ```
   - 首次启动 Android Studio，安装最新的 **Android SDK Platform 34**、**Android SDK Build-Tools 34.x**、**Android SDK Command-line Tools**。在 SDK Manager 的 **SDK Tools** 选项卡中勾选 **Android SDK Command-line Tools (latest)**。
   - 接受 SDK 许可证：
     ```bash
     yes | "${ANDROID_HOME:-$HOME/Library/Android/sdk}"/tools/bin/sdkmanager --licenses
     ```
2. 连接测试设备或启动模拟器：
   - USB 连接实体 Android 设备并启用开发者选项中的 **USB 调试**。
   - 或在 Android Studio 中通过 **Device Manager** 创建并启动 Pixel 系列模拟器（推荐 API 34）。
3. 调试运行：
   ```bash
   flutter devices   # 确认设备列表
   flutter run -d <device_id>
   ```
   通过交互验证拍照、录像、水印编辑等核心功能；`q` 可退出运行。
4. 生成安装包：
   - 调试 APK：`flutter build apk --debug`
   - 正式发布 APK：`flutter build apk --release`
   - Google Play App Bundle：`flutter build appbundle`
   构建产物位于 `build/app/outputs/flutter-apk/` 与 `build/app/outputs/bundle/`。可使用 `adb install build/app/outputs/flutter-apk/app-release.apk` 进行实机验收。

## 3. Web 构建与测试

1. 确保已启用 Web 支持并安装 Chrome：
   ```bash
   flutter doctor -v   # 确认 Chrome (web) ✓
   ```
2. 本地调试：
   ```bash
   flutter run -d chrome
   ```
   Flutter 会启动开发服务器并在 Chrome 中打开页面，可实时预览水印叠加与交互行为。
3. 生产构建：
   ```bash
   flutter build web --release
   ```
   构建结果位于 `build/web/`，可使用任意静态服务器（如 `python3 -m http.server 8080 --directory build/web`）进行验收或部署到 CDN/对象存储。

## 4. macOS 构建与测试

1. 安装 Apple 工具链：
   - 通过 App Store 安装最新版本 Xcode，并首次启动以完成组件安装。
   - 安装命令行工具与许可：
     ```bash
     xcode-select --install
     sudo xcodebuild -license accept
     ```
   - 安装 CocoaPods（若已安装可跳过）：
     ```bash
     sudo gem install cocoapods
     pod setup
     ```
2. 首次构建时同步依赖：
   ```bash
   cd macos
   pod install
   cd ..
   ```
3. 调试运行：
   ```bash
   flutter run -d macos
   ```
   调试窗口打开后，请检查相机权限弹窗、实时水印渲染、模板切换等关键路径。
4. 生成发布版本：
   ```bash
   flutter build macos --release
   ```
   产物位于 `build/macos/Build/Products/Release/FmarkCamera.app`。双击可直接运行，也可执行 `open build/macos/Build/Products/Release/FmarkCamera.app`。
5. 如需分发可签名与打包 `.dmg`：
   - 在 Xcode 中打开 `macos/Runner.xcworkspace`，配置 **Signing & Capabilities**。
   - 使用 `productbuild`/`create-dmg` 等工具生成安装包（此步骤视团队分发策略可选）。

## 5. 常见问题排查

- `CocoaPods not installed`：确认已运行 `sudo gem install cocoapods`，并重新执行 `pod install`。
- Android 构建提示 NDK 缺失：通过 Android Studio 的 SDK Manager 安装 **NDK (Side by side)** 与 **CMake**，然后重试 `flutter build`。
- `flutter run` 未识别设备：确认 `flutter devices` 输出是否包含目标设备；若无，请检查 USB 调试、模拟器是否启动或 `chrome` 是否可用。
- macOS 权限弹窗阻止相机/麦克风：在 **系统设置 > 隐私与安全 > 相机/麦克风** 中允许 `FmarkCamera` 访问后重新运行。

完成上述流程后，即可在 macOS 上稳定完成 Android、Web、macOS 的构建与手动测试，确保核心的拍摄与水印功能符合预期。
