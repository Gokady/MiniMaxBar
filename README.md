# MiniMax Usage

> macOS 菜单栏小工具,实时显示 MiniMax Token Plan 的剩余额度

菜单栏有个小图标,点开看 5h 窗口和周窗口的剩余用量。

![mini demo](docs/screenshot.png)

## 下载安装

去 [Releases 页面](https://github.com/Gokady/MiniMaxBar/releases) 选最新版本,下两个产物之一:

| 产物 | 大小 | 说明 |
|---|---|---|
| `MiniMaxBar.zip` | ~480 KB | 通用格式,解压后是 `MiniMaxBar.app/` |
| `MiniMaxBar.dmg` | ~770 KB | macOS 拖拽盘,含 `MiniMaxBar.app` + `Applications` 软链接 |

### ⚠️ 首次打开:Gatekeeper 加白

**这个 app 没有 Apple Developer 签名/公证**(暂时不需要那 $99/年),所以首次打开会弹:

> **Apple无法验证"MiniMaxBar.app"是否包含可能危害Mac安全或泄漏隐私的恶意软件。**

这是 ad-hoc 签名的预期行为,**不是真的恶意软件**。三种解法任选:

#### 方法 1:右键打开(最快)

1. 在 `Finder` 里找到 `MiniMaxBar.app`
2. **右键**(或 Control+点击)→ 选「打开」
3. 弹窗里再点一次「打开」
4. 以后双击就能直接开了

#### 方法 2:系统设置里加白

1. 尝试双击打开 → 弹警告 → 点「好」(不要点移到废纸篓)
2. 打开 **系统设置** → **隐私与安全性**
3. 滚到下面,看到 "MiniMaxBar 已被阻止打开" 旁边有「仍要打开」按钮
4. 点「仍要打开」+ 输密码

#### 方法 3:命令行去掉隔离属性

```bash
xattr -dr com.apple.quarantine /Applications/MiniMaxBar.app
```

(适合批量部署)

## 安装位置

推荐拖到 `/Applications/`,这样系统级菜单栏能正常加载。

## 第一次运行

app 启动后,菜单栏出现图标,**没有设置窗口自动弹出**。

1. **右键菜单栏图标** → 选「设置…」
2. 切到「账户」section
3. 填 API Key → 点「保存到 Keychain」
4. 关掉设置,看 popover 有没有数据
5. 没数据就切到「版本」section → 点「检查更新」,看 raw JSON 是什么

## 当前状态

- ✅ 菜单栏 popover(5h 限额 + 周限额)
- ✅ 设置面板(账户/面板显示/菜单栏/版本/高级)
- ✅ ad-hoc 代码签名(用户级,首次要加白)
- ✅ GitHub Actions CI + Releases 发版管道(zip + DMG 双产物)
- ✅ Keychain 存 API Key

## 限制(暂时)

| 限制 | 原因 | 解决时间 |
|---|---|---|
| 首次打开要右键加白 | 没用 Apple Developer 签名 | 接 Apple Developer($99/年) |
| 没有 Sparkle 自动更新 | 暂不接,等 Phase 3 | 下一阶段 |
| 没 notarization | 同上 | 同上 |
| 字段名是猜测的 | 官方文档没给示例响应 | 等真实响应 |

## 开发者文档

### 本地构建

```bash
./build.sh            # release,产出 dist/MiniMaxBar.app
./build.sh debug      # debug
open dist/MiniMaxBar.app
```

### 项目结构

```
.
├── .github/workflows/
│   ├── build.yml        ← CI:push/PR 触发,swift build 验证
│   └── release.yml      ← 手动发版:workflow_dispatch 输版本号 → zip+DMG → GitHub Release
├── Sources/MiniMaxBar/
│   ├── AppInfo.swift           ← 版本号(读 Info.plist)+ GitHub 仓库坐标
│   ├── UpdateManager.swift     ← 调 GitHub Releases API 检查更新(没用 Sparkle)
│   ├── UsageStore.swift        ← ObservableObject 状态中心
│   ├── KeychainStore.swift     ← API Key 加密存储
│   ├── APIClient.swift         ← 网络层
│   ├── StatusBarController.swift ← NSStatusItem + NSPopover
│   ├── SettingsWindowController.swift ← 设置窗口
│   ├── Views.swift             ← 所有 SwiftUI 视图
│   └── Models.swift             ← Codable 数据模型
├── Resources/Info.plist        ← Bundle 元数据
├── Icons/                       ← 状态栏 + App 图标
├── Package.swift                ← SPM(已无外部依赖)
├── build.sh                     ← 本地 build
├── docs/                        ← 设计文档 / 阶段记录
├── CHANGELOG.md                 ← 版本变更记录
└── README.md                    ← 本文件
```

### 发新版本

1. 打开 GitHub Actions → "Manual Release" workflow
2. 点 "Run workflow" → 输 `X.Y.Z` → Run
3. 等 3-5 分钟,看 [Releases 页面](https://github.com/Gokady/MiniMaxBar/releases) 出新版本

### 已知 API

| Endpoint | Method | Auth |
| --- | --- | --- |
| `https://api.minimaxi.com/v1/token_plan/remains` | GET | `Authorization: Bearer <API Key>` |

返回结构(部分确认):
```json
{
  "base_resp": {"status_code": 0, "status_msg": "success"},
  "data": { ...未知字段... }
}
```

如果设置面板的「版本」section 里能看到 5h 窗口和周窗口的数据,**但界面没显示进度条**,说明 `Models.swift` 里 `TokenPlanData` 的字段名没对上,通常 1~2 行改动即可。

## 路线图

- [ ] 解析器对齐真实响应
- [ ] Sparkle 自动更新(Phase 3)
- [ ] Apple Developer 签名 + Notarization(去首次加白)
- [ ] 趋势图 / 热力图
- [ ] 多套餐对比
- [ ] Homebrew Cask
