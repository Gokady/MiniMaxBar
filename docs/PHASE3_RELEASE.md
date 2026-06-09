# Phase 3: GitHub Release 结构设计

## 1. Tag 命名规范

```
v<MAJOR>.<MINOR>.<PATCH>
```

- 例:`v0.4.0`、`v0.4.1`、`v1.0.0`
- **必须以 `v` 开头**(Sparkle 2 从 tag_name 解析版本号,惯例)
- 严格 semver:主版本.次版本.补丁
- 预发布加后缀:`v0.4.0-beta.1`、`v0.4.0-rc.1`(Sparkle 也认)

## 2. Release 资产结构

每个 release 上传 2 个文件:

```
v0.4.0
├── MiniMaxBar.zip              ← 给用户下载的 .app 压缩包
└── appcast.xml                  ← Sparkle 用的更新描述文件
```

| 文件 | 生成方 | 内容 |
|---|---|---|
| `MiniMaxBar.zip` | release.yml 跑 `ditto -c -k --sequesterRsrc --keepParent dist/MiniMaxBar.app MiniMaxBar.zip` | 整个 .app bundle(zip 后保留 extended attrs) |
| `appcast.xml` | Sparkle 自带 `generate_appcast` 工具 | Sparkle 用来查询"有新版本吗"的元数据(版本号、下载 URL、签名、changelog) |

## 3. Info.plist 配置(SUFeedURL)

指向 GitHub Releases 顶层:

```xml
<key>SUFeedURL</key>
<string>https://github.com/wuke/MiniMaxBar/releases/latest</string>
```

Sparkle 2 会自动抓 GitHub 的 `.atom` feed 解析。如果想精确控制(比如用自托管 appcast.xml),也可以指向:

```xml
<key>SUFeedURL</key>
<string>https://wuke.github.io/MiniMaxBar/appcast.xml</string>
```

**本项目默认用 GitHub Releases** —— 省事,Sparkle 原生支持。

## 4. Changelog 格式(release body)

`UpdateForm` 里展示 `itemDescription` 字段。**Markdown 直接渲染**(Sparkle 抓 release body 后传过来)。

```
## 新增
- Sparkle 2 自动更新集成
- 设置面板新增"版本"section,显示当前版本/最新版本/检查状态

## 修复
- Picker 切换慢一拍
- 图标切换错位
```

> GitHub release body 写 Markdown,Sparkle 自动转给 app。

## 5. 版本号同步规则

发布前 `AppInfo.swift` 手动 bump:

```swift
static let version: String = "0.4.0"   // ← 改这里
static let build: Int = 4              // ← 改这里
```

或者 `build.sh 0.4.0` 自动注入(后续优化)。

**GitHub tag 必须 ≥ `AppInfo.version`**,否则老用户会收到"无更新"。

## 6. 发布工作流总览

```
开发者:
  1. 改 AppInfo.version
  2. git add . && git commit -m "v0.4.0"
  3. git tag v0.4.0
  4. git push origin main --tags
     ↓
GitHub Actions(.github/workflows/release.yml):
  1. 检测到 v*.*.* tag
  2. macOS runner 拉代码
  3. ./build.sh → dist/MiniMaxBar.app
  4. Developer ID 签名(codesign)
  5. Apple Notarization(notarytool submit + staple)
  6. ditto 压缩 → MiniMaxBar.zip
  7. generate_appcast → appcast.xml
  8. gh release create v0.4.0 \
        MiniMaxBar.zip \
        appcast.xml \
        --notes "$(cat CHANGELOG.md)"
     ↓
用户(已装 v0.3.0 的):
  1. 启动 app → Sparkle 后台静默检查
  2. 发现 v0.4.0 → 设置面板"版本"section 显示"v0.4.0 可用"
  3. 点"下载并安装" → Sparkle 下载 → 验证签名 → 替换 .app → 重启
  4. 已经是 v0.4.0
```

## 7. 兼容性矩阵

| 用户当前版本 | 升级到 v0.4.0 | 行为 |
|---|---|---|
| v0.3.x → v0.4.0 | ✅ Sparkle 处理 | 正常升级 |
| v0.2.x → v0.4.0 | ✅ Sparkle 处理 | 跳 1 个次版本,正常 |
| v0.4.0-beta.1 → v0.4.0 | ✅ Sparkle 处理 | 预发布 → 正式 |
| v0.4.0 → v0.3.5 | ⚠️ Sparkle 拒绝 | Sparkle 不允许降级 |
| v0.4.0 → v0.4.0 | ⏭️ 跳过 | Sparkle 不提示 |
| < 最低支持版本 | ⏭️ 跳过 | Sparkle 比对 minSupportedVersion |

## 8. 风险分析

| 风险 | 缓解 |
|---|---|
| Release body 写错格式 | Markdown 预览,跑一次 `validate_appcast` 校验 |
| 签名配错导致全员无法更新 | Phase 4 私钥走 CI Secret,绝不进 git |
| Tag 推错(比如打 v0.4.0 但代码还是 v0.3.x) | release.yml 校验 `AppInfo.version == tag`,不一致直接 fail |
| 重复 release 资产 | `gh release` 会拒绝覆盖,需要先 `gh release delete` |
| 用户禁用了自动检查 | 设置面板有手动检查按钮兜底 |
