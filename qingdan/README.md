# 清单（TrollStore 免签名 IPA）

一个只给自己用的待办 App：清单 + 任务 + 到点反复催办。不联网、不上传，数据存在 App 本机。

参考了 `Cuiban` 的做法，但砍掉了 NAS 同步、AI 解析、OCR——只保留最核心的两件事：**记得住、催得动**。

## 功能

- 多清单，任务带截止时间和备注
- 到期响一次，之后**每 N 分钟再催**，直到你勾掉（N 可调，1–60 分钟）
- 催促次数可调（0–20 次），系统通知配额 60 条，按截止时间紧急程度自动分配
- **后台常驻**开关：开启后循环播放静音音频保活，催办可以一直延续（代价是略耗电）
- 数据存 `Documents/lists.json`，卸载即丢，重要内容自己备份

## 怎么拿到 IPA（不需要 Mac）

1. 把这个仓库推到 GitHub（私有仓库也行）
2. 进仓库 **Actions** 标签 → 选 `qingdan` → **Run workflow**
3. 等 3–5 分钟（首次会慢一点，要装 XcodeGen）
4. 构建完，在 Releases 的 `qingdan-latest` 标签下下载 `Qingdan.ipa`
5. 解压得到 `Qingdan.ipa`

## 怎么装（TrollStore）

1. 把 `Qingdan.ipa` 传到 iPhone（AirDrop / 微信文件 / iCloud 都行）
2. 用 **TrollStore** 打开这个 ipa → Install
3. 装完桌面上出现「清单」

> 前提：设备在 TrollStore 支持范围内（iOS 14.0–16.6.1，部分 17.0）

## 首次使用

1. 打开 App → 允许通知（**必须给**，否则催不了）
2. 「设置」里确认催办间隔和次数
3. 想要到点必响，打开「后台常驻」
4. 「清单」→ 建任务，选截止时间

## 已知限制

- 不联网，所以**不能多人共享**（要共享得加后端）
- 后台常驻会略耗电，嫌费电就关掉，靠系统预排通知（上限 60 条）
- iOS 重装 App 数据会丢，重要事项建议同时在别处记一份

## 工程结构

```
ios/
  project.yml                XcodeGen 工程描述
  Sources/Info.plist         UIBackgroundModes=audio/fetch
  Sources/QingdanApp.swift   入口 + TabView
  Sources/Models.swift       Task / TodoList
  Sources/Store.swift        本地 JSON 存储 + 排期触发
  Sources/Notifier.swift     UNUserNotificationCenter 调度（催办循环）
  Sources/KeepAlive.swift    静音音频保活
  Sources/Views/             清单 / 任务 / 设置
  Sources/Resources/silence.wav
../.github/workflows/qingdan.yml    macOS 构建 + 打包 IPA + 发 Release
```

## 本地构建（有 Mac 的话）

```bash
brew install xcodegen
cd ios && xcodegen generate
open Qingdan.xcodeproj
```
