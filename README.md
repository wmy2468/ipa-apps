# IPA Apps

三个只给自己用的 iOS App，放在一个私有仓库里。每个 App 有独立 workflow，改哪个目录只构建哪个，产物自动发布到 Releases（无签名 IPA，装 TrollStore 即可）。

| App | 目录 | Release 标签 | 说明 |
| --- | --- | --- | --- |
| 智账 AIBill | `aibill/` | `aibill-latest` | 拍小票 AI 记账（通义千问 VL）+ 手动/语音记账、多账户、预算提醒、导出 Excel |
| 清单 Qingdan | `qingdan/` | `qingdan-latest` | 待办 + 到点反复催办 |
| 票记 ReceiptLedger | `receipt-ledger/` | `receipt-ledger-latest` | 本地 OCR 记账 + 语音记账 |

下载入口（私有库，手机 GitHub App 用 `wmy2468` 账号登录后可见）：

- <https://github.com/wmy2468/ipa-apps/releases/tag/aibill-latest>
- <https://github.com/wmy2468/ipa-apps/releases/tag/qingdan-latest>
- <https://github.com/wmy2468/ipa-apps/releases/tag/receipt-ledger-latest>

## 构建

每个 workflow 只在对应目录有改动时触发，也可以手动 `workflow_dispatch`：

- `.github/workflows/aibill.yml` → `aibill/`
- `.github/workflows/qingdan.yml` → `qingdan/ios/`
- `.github/workflows/receipt-ledger.yml` → `receipt-ledger/`

共同流程：`xcodegen generate` → `xcodebuild -sdk iphoneos CODE_SIGNING_ALLOWED=NO` → `codesign --sign -`（ad-hoc）→ 打 `Payload/*.app` 成 ipa → upload-artifact + 重建 `*-latest` Release。

## 安装

1. 手机 GitHub App → 本仓库 → Releases → 选对应标签下载 ipa。
2. 用 TrollStore 打开 ipa → Install（永久签名，不过期）。
3. 没有 TrollStore 的话用 Sideloadly + 免费 Apple ID 自签，7 天过期。

各 App 的详细说明看子目录里的 README。
