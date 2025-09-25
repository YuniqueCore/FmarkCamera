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
[{
	"resource": "/Users/unic/dev/flu/FmarkCamera/lib/src/presentation/templates/template_manager_screen.dart",
	"owner": "_generated_diagnostic_collection_name_#3",
	"code": {
		"value": "return_of_invalid_type_from_closure",
		"target": {
			"$mid": 1,
			"path": "/diagnostics/return_of_invalid_type_from_closure",
			"scheme": "https",
			"authority": "dart.dev"
		}
	},
	"severity": 8,
	"message": "The returned type 'WatermarkProfile?' isn't returnable from a 'WatermarkProfile' function, as required by the closure's context.",
	"source": "dart",
	"startLineNumber": 55,
	"startColumn": 31,
	"endLineNumber": 55,
	"endColumn": 74,
	"origin": "extHost1"
},{
	"resource": "/Users/unic/dev/flu/FmarkCamera/lib/src/presentation/templates/template_manager_screen.dart",
	"owner": "_generated_diagnostic_collection_name_#3",
	"code": {
		"value": "use_build_context_synchronously",
		"target": {
			"$mid": 1,
			"path": "/diagnostics/use_build_context_synchronously",
			"scheme": "https",
			"authority": "dart.dev"
		}
	},
	"severity": 2,
	"message": "Don't use 'BuildContext's across async gaps, guarded by an unrelated 'mounted' check.\nGuard a 'State.context' use with a 'mounted' check on the State, and other BuildContext use with a 'mounted' check on the BuildContext.",
	"source": "dart",
	"startLineNumber": 77,
	"startColumn": 28,
	"endLineNumber": 77,
	"endColumn": 35,
	"origin": "extHost1"
}]
[{
	"resource": "/Users/unic/dev/flu/FmarkCamera/lib/src/services/watermark_renderer.dart",
	"owner": "_generated_diagnostic_collection_name_#3",
	"code": {
		"value": "argument_type_not_assignable",
		"target": {
			"$mid": 1,
			"path": "/diagnostics/argument_type_not_assignable",
			"scheme": "https",
			"authority": "dart.dev"
		}
	},
	"severity": 8,
	"message": "The argument type 'TextDirection' can't be assigned to the parameter type 'TextDirection?'. ",
	"source": "dart",
	"startLineNumber": 108,
	"startColumn": 22,
	"endLineNumber": 108,
	"endColumn": 39,
	"origin": "extHost1"
},{
	"resource": "/Users/unic/dev/flu/FmarkCamera/lib/src/services/watermark_renderer.dart",
	"owner": "_generated_diagnostic_collection_name_#3",
	"code": {
		"value": "extra_positional_arguments",
		"target": {
			"$mid": 1,
			"path": "/diagnostics/extra_positional_arguments",
			"scheme": "https",
			"authority": "dart.dev"
		}
	},
	"severity": 8,
	"message": "Too many positional arguments: 2 expected, but 3 found.\nTry removing the extra arguments.",
	"source": "dart",
	"startLineNumber": 144,
	"startColumn": 55,
	"endLineNumber": 144,
	"endColumn": 78,
	"origin": "extHost1"
},{
	"resource": "/Users/unic/dev/flu/FmarkCamera/lib/src/services/watermark_renderer.dart",
	"owner": "_generated_diagnostic_collection_name_#3",
	"code": {
		"value": "deprecated_member_use",
		"target": {
			"$mid": 1,
			"path": "/diagnostics/deprecated_member_use",
			"scheme": "https",
			"authority": "dart.dev"
		}
	},
	"severity": 2,
	"message": "'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss.\nTry replacing the use of the deprecated member with the replacement.",
	"source": "dart",
	"startLineNumber": 106,
	"startColumn": 50,
	"endLineNumber": 106,
	"endColumn": 61,
	"tags": [
		2
	],
	"origin": "extHost1"
},{
	"resource": "/Users/unic/dev/flu/FmarkCamera/lib/src/services/watermark_renderer.dart",
	"owner": "_generated_diagnostic_collection_name_#3",
	"code": {
		"value": "deprecated_member_use",
		"target": {
			"$mid": 1,
			"path": "/diagnostics/deprecated_member_use",
			"scheme": "https",
			"authority": "dart.dev"
		}
	},
	"severity": 2,
	"message": "'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss.\nTry replacing the use of the deprecated member with the replacement.",
	"source": "dart",
	"startLineNumber": 129,
	"startColumn": 49,
	"endLineNumber": 129,
	"endColumn": 60,
	"tags": [
		2
	],
	"origin": "extHost1"
}]

[{
	"resource": "/Users/unic/dev/flu/FmarkCamera/lib/src/domain/models/watermark_text_style.dart",
	"owner": "_generated_diagnostic_collection_name_#3",
	"code": {
		"value": "deprecated_member_use",
		"target": {
			"$mid": 1,
			"path": "/diagnostics/deprecated_member_use",
			"scheme": "https",
			"authority": "dart.dev"
		}
	},
	"severity": 2,
	"message": "'value' is deprecated and shouldn't be used. Use component accessors like .r or .g, or toARGB32 for an explicit conversion.\nTry replacing the use of the deprecated member with the replacement.",
	"source": "dart",
	"startLineNumber": 55,
	"startColumn": 24,
	"endLineNumber": 55,
	"endColumn": 29,
	"tags": [
		2
	],
	"origin": "extHost1"
},{
	"resource": "/Users/unic/dev/flu/FmarkCamera/lib/src/domain/models/watermark_text_style.dart",
	"owner": "_generated_diagnostic_collection_name_#3",
	"code": {
		"value": "deprecated_member_use",
		"target": {
			"$mid": 1,
			"path": "/diagnostics/deprecated_member_use",
			"scheme": "https",
			"authority": "dart.dev"
		}
	},
	"severity": 2,
	"message": "'value' is deprecated and shouldn't be used. Use component accessors like .r or .g, or toARGB32 for an explicit conversion.\nTry replacing the use of the deprecated member with the replacement.",
	"source": "dart",
	"startLineNumber": 56,
	"startColumn": 35,
	"endLineNumber": 56,
	"endColumn": 40,
	"tags": [
		2
	],
	"origin": "extHost1"
},{
	"resource": "/Users/unic/dev/flu/FmarkCamera/lib/src/domain/models/watermark_text_style.dart",
	"owner": "_generated_diagnostic_collection_name_#3",
	"code": {
		"value": "deprecated_member_use",
		"target": {
			"$mid": 1,
			"path": "/diagnostics/deprecated_member_use",
			"scheme": "https",
			"authority": "dart.dev"
		}
	},
	"severity": 2,
	"message": "'value' is deprecated and shouldn't be used. Use component accessors like .r or .g, or toARGB32 for an explicit conversion.\nTry replacing the use of the deprecated member with the replacement.",
	"source": "dart",
	"startLineNumber": 60,
	"startColumn": 40,
	"endLineNumber": 60,
	"endColumn": 45,
	"tags": [
		2
	],
	"origin": "extHost1"
},{
	"resource": "/Users/unic/dev/flu/FmarkCamera/lib/src/domain/models/watermark_text_style.dart",
	"owner": "_generated_diagnostic_collection_name_#3",
	"code": {
		"value": "deprecated_member_use",
		"target": {
			"$mid": 1,
			"path": "/diagnostics/deprecated_member_use",
			"scheme": "https",
			"authority": "dart.dev"
		}
	},
	"severity": 2,
	"message": "'value' is deprecated and shouldn't be used. Use component accessors like .r or .g, or toARGB32 for an explicit conversion.\nTry replacing the use of the deprecated member with the replacement.",
	"source": "dart",
	"startLineNumber": 77,
	"startColumn": 60,
	"endLineNumber": 77,
	"endColumn": 65,
	"tags": [
		2
	],
	"origin": "extHost1"
},{
	"resource": "/Users/unic/dev/flu/FmarkCamera/lib/src/domain/models/watermark_text_style.dart",
	"owner": "_generated_diagnostic_collection_name_#3",
	"code": {
		"value": "deprecated_member_use",
		"target": {
			"$mid": 1,
			"path": "/diagnostics/deprecated_member_use",
			"scheme": "https",
			"authority": "dart.dev"
		}
	},
	"severity": 2,
	"message": "'value' is deprecated and shouldn't be used. Use component accessors like .r or .g, or toARGB32 for an explicit conversion.\nTry replacing the use of the deprecated member with the replacement.",
	"source": "dart",
	"startLineNumber": 85,
	"startColumn": 73,
	"endLineNumber": 85,
	"endColumn": 78,
	"tags": [
		2
	],
	"origin": "extHost1"
}]
[{
	"resource": "/Users/unic/dev/flu/FmarkCamera/lib/src/presentation/camera/widgets/watermark_element_widget.dart",
	"owner": "_generated_diagnostic_collection_name_#3",
	"code": {
		"value": "deprecated_member_use",
		"target": {
			"$mid": 1,
			"path": "/diagnostics/deprecated_member_use",
			"scheme": "https",
			"authority": "dart.dev"
		}
	},
	"severity": 2,
	"message": "'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss.\nTry replacing the use of the deprecated member with the replacement.",
	"source": "dart",
	"startLineNumber": 164,
	"startColumn": 29,
	"endLineNumber": 164,
	"endColumn": 40,
	"tags": [
		2
	],
	"origin": "extHost1"
},{
	"resource": "/Users/unic/dev/flu/FmarkCamera/lib/src/presentation/camera/widgets/watermark_element_widget.dart",
	"owner": "_generated_diagnostic_collection_name_#3",
	"code": {
		"value": "deprecated_member_use",
		"target": {
			"$mid": 1,
			"path": "/diagnostics/deprecated_member_use",
			"scheme": "https",
			"authority": "dart.dev"
		}
	},
	"severity": 2,
	"message": "'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss.\nTry replacing the use of the deprecated member with the replacement.",
	"source": "dart",
	"startLineNumber": 194,
	"startColumn": 29,
	"endLineNumber": 194,
	"endColumn": 40,
	"tags": [
		2
	],
	"origin": "extHost1"
}]
[{
	"resource": "/Users/unic/dev/flu/FmarkCamera/lib/src/presentation/widgets/context_badge.dart",
	"owner": "_generated_diagnostic_collection_name_#3",
	"code": {
		"value": "deprecated_member_use",
		"target": {
			"$mid": 1,
			"path": "/diagnostics/deprecated_member_use",
			"scheme": "https",
			"authority": "dart.dev"
		}
	},
	"severity": 2,
	"message": "'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss.\nTry replacing the use of the deprecated member with the replacement.",
	"source": "dart",
	"startLineNumber": 22,
	"startColumn": 29,
	"endLineNumber": 22,
	"endColumn": 40,
	"tags": [
		2
	],
	"origin": "extHost1"
}]