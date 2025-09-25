## 代码规范与约定
- 遵循 Flutter 默认 lint（`flutter_lints`）及项目额外规则：`prefer_const_constructors`、`avoid_print`、`always_use_package_imports`。
- 函数结构强调 KISS/LISP、面向接口设计、高内聚低耦合，保持模块化与可组合性。
- 使用 Dart/Flutter 官方约定的小驼峰命名，Widget build 方法保持简洁，状态管理倾向自维护（StatefulWidget）。
- 业务数据通过模型 `copyWith`、`toJson`/`fromJson` 互转；服务通过接口抽象，平台差异由工厂创建实现。
- UI 中注意 `mounted` 检查、`async/await` 正确性，避免同步上下文问题。