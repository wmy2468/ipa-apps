# 票记 · ReceiptLedger

iOS 记账 App：拍小票 → 本地 OCR（Vision）自动填金额/商户/日期/分类。可选接 OpenAI 兼容接口做二次纠错。

- 部署版本：iOS 16.0+
- 纯本地存储（JSON 沙盒），不联网（未开启 AI 时）
- 无第三方依赖

## 自动构建

推送到 `main` 后 GitHub Actions 会编译出**未签名 IPA**，自动发布到 Releases 里按版本命名的包（如 `ReceiptLedger-1.1-2.ipa`）。

## 安装（TrollStore）

1. 把 `ReceiptLedger.ipa` 传到 iPhone（AirDrop / 文件 App）

2. 用 TrollStore 打开 → Install

3. 首次进入 App 允许「相机 / 相册」权限

> TrollStore 安装的 App 永久有效，不会掉签。

## 目录

```
project.yml                 XcodeGen 工程描述
Sources/
  App.swift                 入口 + Tab + 分类图标配色
  Models.swift              Tx / 分类关键词
  Store.swift               JSON 存储 + 统计
  OCR.swift                 Vision OCR + 小票解析 + 可选大模型
  ListView.swift            明细 + 编辑
  AddView.swift             拍照/相册 + 识别 + 保存
  StatsView.swift           月度统计（Swift Charts）
  SettingsView.swift        AI 配置 / 数据管理
```
