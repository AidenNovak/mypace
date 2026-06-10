# MyPace 发布流程：Developer ID 签名 + Notarization

本文档说明如何从源码构建一个**可以公开分发的、经过苹果公证的 DMG**（不再有「无法验证开发者」警告）。

---

## 前置条件

你需要：

1. **付费的 Apple Developer 账号**（每年 ¥688）
2. 一个 **"Developer ID Application"** 证书（不是普通的 Mac App Distribution 证书）
3. 已经把证书 + 私钥安装到本机的钥匙串（Keychain）
4. 能够使用 `notarytool` 进行公证（推荐使用 App Store Connect API Key 或 App 专用密码）

---

## 第一步：准备证书（只做一次）

1. 登录 [Apple Developer 中心](https://developer.apple.com/account/resources/certificates/list)
2. 创建证书：
   - 类型选择 **Developer ID Application**
   - 关联你的 Team
3. 下载 `.cer` 文件，双击安装到「登录」钥匙串
4. 在钥匙串访问里，找到该证书 → 右键「导出」可以备份 `.p12`

确认证书已安装：

```bash
security find-identity -v -p codesigning
```

你应该能看到类似：
```
1) XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX "Developer ID Application: Your Name (TEAMID)"
```

记下完整的证书名称（包含 `Developer ID Application: ... (TEAMID)`）。

---

## 第二步：配置公证凭证（推荐方式）

有两种方式，推荐使用 **App Store Connect API Key**（更稳定）。

### 方式 A：使用 App Store Connect API Key（推荐）

1. 在 [App Store Connect](https://appstoreconnect.apple.com/access/api) 创建一个 API Key（权限选 **Developer**）
2. 下载 `.p8` 文件（只能下载一次）
3. 把三个值保存好：
   - Issuer ID
   - Key ID
   - `.p8` 文件路径

然后执行一次：

```bash
xcrun notarytool store-credentials "MyPaceNotary" \
  --key /path/to/AuthKey_XXXXXXXXXX.p8 \
  --key-id XXXXXXXXXX \
  --issuer XXXXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX \
  --team-id YOUR10CHARTEAMID
```

### 方式 B：使用 App 专用密码（简单但较弱）

```bash
xcrun notarytool store-credentials "MyPaceNotary" \
  --apple-id your-apple-id@example.com \
  --team-id YOUR10CHARTEAMID \
  --password abcd-efgh-ijkl-mnop
```

---

## 第三步：构建正式版 DMG

在仓库根目录或 `app/` 目录下设置环境变量后执行：

```bash
cd app

export DEVELOPER_ID_APP="Developer ID Application: Your Name (TEAMID)"
export TEAM_ID="YOUR10CHARTEAMID"
export NOTARY_KEYCHAIN_PROFILE="MyPaceNotary"

./build-app.sh notarize
```

脚本会自动完成：
- 使用你的 Developer ID 证书签名（带 hardened runtime）
- 打包 DMG

---

## 第四步：提交公证

脚本执行完后，会提示你运行公证命令。完整流程通常是：

```bash
# 1. 提交公证
xcrun notarytool submit "build/MyPace-Preview-0.8.0.dmg" \
  --keychain-profile "MyPaceNotary" \
  --team-id "$TEAM_ID" \
  --wait
```

等待输出中出现 `status: Accepted`。

```bash
# 2. 打钉（staple）
xcrun stapler staple "build/MyPace-Preview-0.8.0.dmg"

# 3. 验证
spctl -a -vv -t install "build/MyPace-Preview-0.8.0.dmg"
```

如果看到 `source=Notarized Developer ID` 就成功了。

---

## 常见问题

**Q: 提示 "No valid identities found"？**
- 证书还没安装到当前机器的钥匙串。
- 或者证书是别人机器导出的，需要同时导入私钥。

**Q: 公证失败，提示 "The signature does not include a secure timestamp"？**
- 签名时必须带 `--options runtime`（当前脚本已包含）。

**Q: 公证一直卡在 In Progress？**
- 有时需要几分钟，`--wait` 会自动轮询。

**Q: 想每次都用同一个 profile 名字？**
- 推荐固定用 `"MyPaceNotary"`，写进脚本或文档。

---

## 推荐的发布 checklist（阶段 1 内测用）

- [ ] 证书已安装并可被 `security find-identity` 找到
- [ ] `notarytool store-credentials` 已成功执行
- [ ] 成功跑一次 `./build-app.sh notarize`
- [ ] DMG 能通过 `spctl -a -vv` 验证
- [ ] DMG 内包含最新的 `README.md`（来自 VLOGGER-README.md）
- [ ] 在 VLOGGER-README.md 底部更新你的真实联系方式
- [ ] 准备好 INTERNAL-TEST-INSTRUCTIONS.md 里的私信话术

---

## 辅助脚本建议（未来可做）

可以考虑增加：
- `scripts/release.sh` 一键完成签名 + 公证 + 上传到 Cloudflare / GitHub Release
- 自动生成 DMG 背景图 + 许可协议

---

需要我现在帮你：
- 再优化 `build-app.sh`，让它更智能地检测证书？
- 创建一个 `scripts/release.sh` 封装整个流程？
- 更新根目录 README 里的发版说明？

随时告诉我，我继续执行。