# QUICKSTART — 一页纸发布到 GitHub + Sparkle 自动更新

> 整套流程你只需 4 步,大概 15 分钟。

## 前置(确认有)

- [x] 项目代码在 `/Users/wuke/PycharmProjects/minimaxtools02`
- [x] macOS(已经跑过 `./build.sh` 验证过)
- [x] GitHub 账号
- [ ] **GH_TOKEN(下面教你取)**

---

## Step 1:登录 GitHub CLI(2 分钟)

```bash
gh auth login
# 选: GitHub.com
# 选: HTTPS
# 选: Yes (authenticate git with your GitHub credentials)
# 选: Paste an authentication token  ← 如果你已经有 PAT
#     或者: Login with a web browser    ← 浏览器授权,推荐
```

打开浏览器弹窗,点 "Authorize"。完成后:

```bash
gh auth status    # 确认登录成功
```

---

## Step 2:创建 GitHub 仓库(1 分钟)

```bash
# 在项目根目录
cd /Users/wuke/PycharmProjects/minimaxtools02

# 创建空仓库(public/private 自选)
gh repo create MiniMaxBar --public --source=. --remote=origin --description "macOS menu bar app for MiniMax Token Plan"

# 第一次 push
git add .
git commit -m "initial commit: MiniMax Usage v0.3.0"
git branch -M main
git push -u origin main
```

现在你的代码已经在 https://github.com/<你的用户名>/MiniMaxBar

---

## Step 3:配 GitHub Secrets(2 个,5 分钟)

打开 https://github.com/<你的用户名>/MiniMaxBar/settings/secrets/actions/new

### 3.1 `SPARKLE_PRIVATE_KEY`

**Name**: `SPARKLE_PRIVATE_KEY`

**Value**: 在你 Mac 终端跑:
```bash
security find-generic-password -l "Sparkle DSA Private Key" -w
```
(会弹"允许访问"对话框,点"始终允许")
输出的 base64 字符串 → 粘到 Value。

> 如果上面命令找不到,试 `security find-generic-password -s "https://sparkle-project.org" -w`

### 3.2 `GH_TOKEN`(可选,CI 自动给的其实够用)

CI 自带 `GITHUB_TOKEN` 已经有创建 release 的权限,**不用额外配**。这里留空就好。

---

## Step 4:发第一个版本(1 分钟)

```bash
# 改 AppInfo.swift(在文件顶部):
#   static let version: String = "0.4.0"   ← 改成 0.4.0
#   static let githubOwner: String = "<你的用户名>"  ← 改
# (githubRepo 保持 "MiniMaxBar")

git add .
git commit -m "v0.4.0: enable Sparkle auto-update"
git tag v0.4.0
git push origin main --tags
```

**到这里你的活就干完了。**

---

## 接下来 GitHub Actions 自动做的事(5-10 分钟)

去看 https://github.com/<你的用户名>/MiniMaxBar/actions

Action 跑完会:
1. 拉代码 → 编译
2. ad-hoc 签名
3. 打 `MiniMaxBar.zip`
4. 生成 `appcast.xml`(用 Sparkle 私钥签名)
5. 发 release v0.4.0,上传 zip + appcast

你会看到:https://github.com/<你的用户名>/MiniMaxBar/releases/tag/v0.4.0

---

## 自己装新版本(首次)

1. 去 https://github.com/<你的用户名>/MiniMaxBar/releases
2. 下载 `MiniMaxBar.zip`
3. 解压,把 `MiniMaxBar.app` 拖到 `/Applications/`
4. 首次打开会弹"未识别的开发者",**右键 → 打开** 一次
5. 之后启动 → 设置 → "版本" → 等 5 秒 → 看到 "v0.4.0"

---

## 之后所有更新(全自动)

启动 app → Sparkle 后台静默检查 → 看到 v0.4.x → 点"下载并安装" → 自动替换 → 重启 → 完成。

**你之后只需要**:
```bash
# 改完代码,改 AppInfo.swift 的 version
git add . && git commit -m "..." && git tag v0.5.0 && git push --tags
```

剩下 GitHub Actions 全部搞定。

---

## 故障排查速查

| 现象 | 原因 | 修法 |
|---|---|---|
| `gh release create` 报 403 | 仓库权限不足 | `gh auth refresh -s repo,workflow` |
| Action 失败 "Tag 和 AppInfo 不一致" | 改了 tag 没改 version,或反之 | 改一致再 push |
| 用户装新版 Sparkle 报"签名错误" | 公钥没换(用我的占位公钥) | 把你 generate_keys 输出的公钥替换 Info.plist |
| Action 卡在 Notarization | 已跳过(因为你说不要 Apple Developer) | — |
| 下载 release zip 后 Gatekeeper 弹窗 | ad-hoc 签名的预期行为 | 右键 → 打开 一次 |

---

## 后续可选(需要时再做)

- **加 Apple Developer**(想给其他人用):$99/年,完整签名 + 公证
- **加 CHANGELOG.md**:让 release 自动从 changelog 抽 release notes
- **加 homebrew tap**:`brew install --cask <你的>/tap/MiniMaxBar`
- **加国际化**:SettingsView 文案迁出到 Localizable.strings
- **加 logo / 截图**:README.md 顶上加 docs/screenshot.png

---

**15 分钟你能走完这 4 步。卡在哪一步告诉我,具体到命令我陪你。**
