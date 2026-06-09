# Phase 4: 安全设计(EdDSA 签名 + Apple Notarization)

> ⚠️ 这一步**绝对不能跳**。Sparkle 2 默认启用 EdDSA 签名验证,没有正确公钥的话,所有用户的更新检查会全部失败。

## 1. 密钥对生成

### 1.1 找 generate_keys 工具

```bash
# 在 .build 里找(SwiftPM 缓存的 Sparkle 包)
find .build/checkouts/Sparkle -name "generate_keys" -type f
# 或全局(如果之前 brew install sparkle)
which generate_keys
```

### 1.2 生成

```bash
# 输出会类似:
# Private key (keep secret!):
#   <64 字节 base64 字符串>
# Public key (add to Info.plist):
#   <32 字节 base64 字符串>

./generate_keys
# 或
./generate_keys -f ~/.config/sparkle/MiniMaxBar
```

### 1.3 保存到文件(便于配置 CI)

```bash
mkdir -p ~/.config/sparkle/MiniMaxBar
./generate_keys -f ~/.config/sparkle/MiniMaxBar/

ls ~/.config/sparkle/MiniMaxBar/
# → dsa_priv.pem  (私钥,绝对不能提交)
# → dsa_pub.pem   (公钥,会进 Info.plist)
```

## 2. 公钥配置

### 2.1 提取 base64

```bash
# 公钥是 32 字节 Ed25519,转 base64 后进 Info.plist
cat ~/.config/sparkle/MiniMaxBar/dsa_pub.pem
# 输出形如:
# -----BEGIN PUBLIC KEY-----
# MCowBQYDK2VwAyEAGb9ECWmEzf6FQbrBZ9OW...
# -----END PUBLIC KEY-----
```

提取 "BEGIN/END" 中间那行 base64 内容。

### 2.2 改 Info.plist

把 `Resources/Info.plist` 里的占位符替换:

```xml
<!-- 之前 -->
<key>SUPublicEDKey</key>
<string>REPLACE_WITH_BASE64_EDDSA_PUBLIC_KEY</string>

<!-- 之后 -->
<key>SUPublicEDKey</key>
<string>MCowBQYDK2VwAyEAGb9ECWmEzf6FQbrBZ9OW...</string>
```

## 3. 私钥保存(GitHub Actions Secret)

私钥**绝对不能**提交到 git。放进 GitHub repo 的 Secrets 里,CI 跑时读出来。

### 3.1 准备私钥内容

```bash
# 私钥文件全文,粘到 GitHub Secret
cat ~/.config/sparkle/MiniMaxBar/dsa_priv.pem
```

### 3.2 在 GitHub 配 Secret

1. 打开 https://github.com/wuke/MiniMaxBar/settings/secrets/actions
2. **New repository secret**:
   - Name: `SPARKLE_PRIVATE_KEY`
   - Value: 上面 `cat` 出来的私钥全文(含 BEGIN/END 行)

### 3.3 (其他 Secrets)Apple ID 相关

要做 Developer ID 签名 + Apple Notarization,还需要:

| Secret 名 | 内容 | 来源 |
|---|---|---|
| `APPLE_ID` | 你的 Apple Developer 账号邮箱 | Apple Developer Portal |
| `APPLE_TEAM_ID` | 10 位 Team ID | https://developer.apple.com/account → Membership |
| `APPLE_APP_SPECIFIC_PASSWORD` | App-specific 密码 | https://appleid.apple.com → App-Specific Passwords |
| `MACOS_CERT_P12` | Developer ID Application 证书导出为 .p12(base64) | Keychain Access → 导出证书 |
| `MACOS_CERT_PASSWORD` | .p12 的密码 | 你设的 |
| `MACOS_INSTALLER_P12` | Developer ID Installer 证书(.p12 base64) | 同上(给 .pkg 用) |
| `MACOS_INSTALLER_PASSWORD` | .p12 密码 | 你设的 |
| `KEYCHAIN_PASSWORD` | 临时 keychain 密码(用于 CI 跑签名) | 任意强密码,CI 临时用 |

> **注意**:`MACOS_CERT_P12` 和 `MACOS_INSTALLER_P12` 是一对(签名 + 打包),如果只用 .app 走 Sparkle,可能不需要 Installer 证书。**先看 Phase 5 的 workflow 决定要不要**。

### 3.4 .p12 导出步骤

```
1. 打开 Keychain Access
2. 找到 "Developer ID Application: <你的名字> (<TeamID>)"
3. 右键 → Export "Developer ID Application..."
4. 格式选 .p12,设密码
5. 终端:
   base64 -i path/to/cert.p12 | pbcopy
6. 粘到 GitHub Secret 的 value
```

## 4. 校验 EDDSA 是否生效

发布一次后,在用户机器上跑:

```bash
# 抓 appcast.xml
curl https://github.com/wuke/MiniMaxBar/releases/latest | grep edSignature

# 应该看到类似:
# <sparkle:edSignature>MCowBQYDK2VwAyEA...(base64)...</sparkle:edSignature>
```

或者用 Sparkle 自带 `sign_update` 工具本地校验:

```bash
./sign_update path/to/MiniMaxBar.zip
# 输出 base64 签名,跟 appcast.xml 里的对比
```

## 5. 密钥轮换策略

如果**怀疑私钥泄漏**(比如不小心 commit 过、CI 日志被打出来):

1. **立刻**生成新密钥对:`generate_keys -f ~/.config/sparkle/MiniMaxBar-new/`
2. 替换 Info.plist 的 `SUPublicEDKey`
3. 替换 GitHub Secret 的 `SPARKLE_PRIVATE_KEY`
4. 发新版本(`v0.4.1`)
5. (可选)旧版用户会收到"签名验证失败"提示,需要手动下载新版

**预防**:
- 私钥文件加 `chmod 600`(`-rw-------`)
- 私钥文件加进 `.gitignore`(防止误 commit)
- GitHub Actions 用 `secrets.SPARKLE_PRIVATE_KEY`,不输出到 log

## 6. 私钥丢失怎么办

**最坏情况**:
- 所有 v0.3.x 之前的用户(用旧公钥)永远收不到自动更新
- 必须手动去 GitHub 下载新版
- 但**用户已经装的版本不受影响**,只是不能再收到新版本提示

**恢复**:
1. 用新密钥对发 v0.4.0
2. 老用户必须手动去 https://github.com/wuke/MiniMaxBar/releases 下载新版
3. 新公钥写进 Info.plist
4. 之后一切正常

## 7. 风险清单

| 风险 | 概率 | 影响 | 检测方法 |
|---|---|---|---|
| 私钥进 git 历史 | 低 | 极高 | `git log --all --diff-filter=A -p -- '*.pem'` |
| 公钥配错 | 中 | 高 | release 后本地启动 app 看 Sparkle 日志 |
| App Store ID 错 | 低 | 中 | notarytool 返回 "authentication failed" |
| .p12 密码错 | 低 | 低 | codesign 报错 |

## 8. 现在要做的(发布前 checklist)

- [ ] 在本地生成 EdDSA 密钥对
- [ ] 把公钥 base64 替换 `Resources/Info.plist` 的 `REPLACE_WITH_BASE64_EDDSA_PUBLIC_KEY`
- [ ] 私钥加进 `.gitignore`
- [ ] 在 GitHub repo 加 Secret:
  - `SPARKLE_PRIVATE_KEY`
  - `APPLE_ID`
  - `APPLE_TEAM_ID`
  - `APPLE_APP_SPECIFIC_PASSWORD`
  - `MACOS_CERT_P12` + `MACOS_CERT_PASSWORD`
  - `KEYCHAIN_PASSWORD`
- [ ] Phase 5 的 release.yml 引用这些 Secret
- [ ] 第一次 release 后跑 `curl releases/latest | grep edSignature` 验证签名进 release
