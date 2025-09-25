## 项目概述
- 名称：FmarkCamera
- 目标：基于 Flutter 实现支持分层水印的照片/视频拍摄应用，实时预览叠加水印并在后处理中合成导出，支持多 Watermark Profile 管理与跨端导出。
- 关键能力：相机预览叠加 `WatermarkCanvas`、Profile 编辑器、Gallery 所见即所得缩略图、导出带/不带水印、Context 服务（定位、天气）。
- 架构：按领域/数据/服务/展示分层，核心服务包括 `camera_service`、`watermark_renderer`、`watermark_exporter` 等，采用接口 + 平台实现。
- 平台：Flutter (mobile/web)，IO 端使用 FFmpegKit、path_provider；Web 端降级处理下载。