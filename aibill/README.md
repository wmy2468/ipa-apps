# 智账 AIBill

拍一张小票，通义千问 VL 识别金额/商户/日期/分类，回填到表单里，确认保存即可。纯本地存储（JSON + 图片文件），API Key 只放钥匙串。

最低 iOS 16.0。

## 功能

- **拍 / 选图自动识别**：`qwen-vl-plus` 走 DashScope 的 OpenAI 兼容接口，严格 JSON 回填，识别错了直接改。
- **手动记账**：不拍照也能记，金额、分类、账户手填即可。
- **语音记账**：说「午饭三十五，微信支付」，本地解析出金额/分类/账户，回填表单确认。
- **多账户**：微信 / 支付宝 / 现金，账本顶部按账户筛选，统计里看各账户流水。
- **预算提醒**：设置月预算，花到 80% 和 100% 各推一条通知（每月每档一次），账本顶部有进度条。
- **账本**：按月切换、按天分组、月度支出/收入/结余、左滑删除、缩略图存根。
- **统计**：分类支出排行、账户流水、近 6 个月支出柱状图。
- **导出**：真正的 `.xlsx`（日期/时间/类型/金额/分类/账户/商户/备注）和 CSV。
- **设置**：填 / 清 API Key、月预算、导出、清空数据。

## 目录

```
AIBill/
  AIBillApp.swift        @main + Store 注入
  Models.swift           Txn 模型、分类 / 账户常量
  Store.swift            JSON 持久化 + 图片文件读写
  LedgerView.swift       账本（账户筛选、预算进度）
  AddTxnView.swift       记一笔（手动 / 拍照 / 相册 / 语音）
  StatsView.swift        统计（分类 / 账户 / 趋势）
  SettingsView.swift     设置（Key、预算、导出）
  QwenClient.swift       DashScope 调用与 JSON 解析
  Budget.swift           月预算与本地通知
  Voice.swift            语音识别与口语解析
  XLSX.swift             手写 xlsx（ZIP + SpreadsheetML）
  KeyStore.swift         钥匙串
  CSVExport.swift        CSV + 分享面板
  CameraPicker.swift     相机
  Util.swift             格式化、月份切换、图片缩放
  Info.plist             相机 / 相册 / 麦克风 / 语音权限文案
  Assets.xcassets        图标 + 主题色
project.yml              XcodeGen 工程描述
```

## 出包

工程不含 `.xcodeproj`，由 CI 用 XcodeGen 现场生成：

1. 推送到仓库的 `main` 分支，或手动跑 `aibill` workflow。
2. runner 执行 `xcodegen generate` → `xcodebuild -sdk iphoneos CODE_SIGNING_ALLOWED=NO` → `codesign --sign -`（ad-hoc）。
3. 产物 `AIBill.ipa` 在 Releases 里按版本命名的包（如 `AIBill-1.2-3.ipa`）下载。

本地 Mac：

```bash
brew install xcodegen
xcodegen generate
open AIBill.xcodeproj
```

## 安装

### TrollStore（已越狱，推荐，永久）

1. 把 `AIBill.ipa` 传到手机（微信文件传输助手 / 隔空投送 / Filza）。
2. 用 TrollStore 打开它（或在 TrollStore 里点 ＋ 选文件），点 Install。
3. 装完直接打开，不跳证书、不过期。

### 免费 Apple ID 自签（没越狱时）

1. Windows 装 [Sideloadly](https://sideloadly.io/) 和 iTunes 驱动，手机连电脑并信任。
2. Sideloadly 选 `AIBill.ipa`，Apple 账号填自己的免费 Apple ID，点 Start。
3. 手机「设置 → 通用 → VPN与设备管理」信任证书；iOS 16+ 还需「隐私与安全性 → 开发者模式」。
4. 限制：7 天过期、最多 3 个 App。

## API Key

1. 打开 <https://bailian.console.aliyun.com/>，开通百炼，创建 DashScope API Key（`sk-` 开头）。
2. App 里「设置 → 通义千问 API Key」粘贴保存。
3. `qwen-vl-plus` 按 token 计费，一张小票通常几分钱以内。

## 数据在哪

- 记录：`Documents/txns.json`
- 票据图片：`Documents/receipts/<uuid>.jpg`
- API Key：钥匙串 `com.wmy.aibill`
