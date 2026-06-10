# TEST_PLAN.md — Sparkle 自动更新测试计划

> 覆盖 8 种关键场景。每次发版前必须跑一遍,QA 验证。

## 测试环境

| 项 | 配置 |
|---|---|
| OS | macOS 26 |
| 安装方式 | 拖到 `/Applications/` |
| 网络 | 可控(可断网、可改 hosts) |
| 时间 | 至少 1 小时观察(覆盖检查周期) |

## 场景 1:首次安装 + 自动检查

**前置**:新装 v0.3.0,Keychain 没东西,没 API Key。

**步骤**:
1. 启动 app,菜单栏出现图标
2. 不打开设置窗口
3. 等 5-10 秒(后台静默检查)
4. 打开设置 → "版本" section
5. 观察状态

**预期**:
- 状态显示"未检查"或"正在检查…"→"已是最新"或"v0.4.0 可用"
- **不弹任何原生更新窗**(后台静默)
- 日志(Console.app 过滤 MiniMaxBar):
  ```
  Sparkle: Checking for updates...
  Sparkle: Update check finished
  ```

**通过条件**:设置面板能看到状态文案,无原生弹窗。

---

## 场景 2:正常升级(已是旧版本 + 有新版本)

**前置**:已装 v0.3.0,GitHub 已发 v0.4.0 release。

**步骤**:
1. 启动 app
2. 等自动检查完成
3. 打开设置 → "版本"
4. 观察"最新版本"行
5. 点"下载并安装"
6. 观察 Sparkle 原生确认弹窗
7. 同意安装
8. 等待下载 + 安装
9. app 退出 + 重启

**预期**:
- "最新版本"显示 `v0.4.0`(绿色)
- 进度:`正在检查…` → `下载中 0%` → `下载中 50%` → `下载中 100%` → `正在安装…`
- 弹 Sparkle 原生"准备安装 v0.4.0"确认窗
- 点"安装并重启"后,app 退出,新版启动
- 启动后,设置 → 版本 → 当前版本显示 `v0.4.0`
- macOS 通知中心出现"X 已更新到 v0.4.0"

**通过条件**:版本号正确变更,无错误弹窗,无签名警告。

---

## 场景 3:降级尝试(版本号 < 当前)

**前置**:已装 v0.4.0,GitHub 刚发了个回滚到 v0.3.5 的 release(虽然不应该发生)。

**步骤**:
1. 启动 app
2. 等自动检查
3. 观察"最新版本"行

**预期**:
- 仍然显示 `v0.4.0`(或 v0.4.x 内的更新)
- 不提示"v0.3.5 可用"
- Sparkle 默认禁止降级

**通过条件**:UI 不显示比当前版本低的版本。

---

## 场景 4:网络异常(检查失败)

**前置**:已装 v0.3.0,Wi-Fi 关闭 / 飞行模式。

**步骤**:
1. 断开网络(关 Wi-Fi 或拔网线)
2. 启动 app
3. 打开设置 → "版本" → 点"检查更新"
4. 观察

**预期**:
- 状态:`正在检查…` → `失败:...` (网络错误文案)
- 不崩溃
- 不弹原生 Sparkle 错误窗(我们自己处理)
- 重新连网后,点"检查更新"能恢复

**通过条件**:错误信息用户能看懂(`NSURLErrorNotConnectedToInternet` 这种),不白屏不卡死。

---

## 场景 5:签名异常(公钥被改)

**前置**:已装 v0.3.0(用旧公钥),把 Info.plist 的 `SUPublicEDKey` 换成另一个密钥对的公钥,新发一个 v0.4.0。

**步骤**:
1. 启动 app
2. 等自动检查
3. 打开设置 → "版本"

**预期**:
- 状态:`已是最新`(Sparkle 静默拒绝,签名失败不提示)
- 或:`失败:签名验证失败` (取决于 Sparkle 配置)
- **绝对不能**让用户装上未签名的更新

**通过条件**:UI 不允许下载 / 装任何更新。Console 日志看到 `EdDSA signature verification failed`。

---

## 场景 6:Release 缺失(用户本地 SUFeedURL 指向不存在的 release)

**前置**:已装 v0.3.0,但 GitHub 把 v0.4.0 release 设为 draft / 删除了。

**步骤**:
1. 启动 app
2. 打开设置 → "版本" → 点"检查更新"

**预期**:
- 状态:`已是最新`
- 不报错
- 静默处理(API 404 / feed 解析失败都当 no-update)

**通过条件**:app 不崩,状态正常显示。

---

## 场景 7:Appcast 损坏(手动改坏了 appcast.xml)

**前置**:这个场景需要测**开发者侧** —— 在 GitHub Release 里手动把 appcast.xml 改成坏 JSON。

**步骤**:
1. 在 GitHub release v0.4.0,edit release,把 `appcast.xml` 替换成 `<broken>xml`
2. 启动已装 v0.3.0 的 app
3. 等自动检查

**预期**:
- 状态:`已是最新` 或 `失败:...`
- 不崩溃
- Console 日志看到 `Appcast parse error` 或类似

**通过条件**:坏数据不会让 app 启动失败 / 卡死。

---

## 场景 8:GitHub API 限流

**前置**:CI runner IP 共享,可能触发 GitHub 的 unauthenticated rate limit(60 req/h)。

**步骤**:
1. 在 CI runner 上跑 release.yml 50 次(用 dummy tag)
2. 观察 git push 是否成功,`gh release create` 是否报错

**预期**:
- 第一次成功(走 GITHUB_TOKEN,5000 req/h)
- 后续也成功(token 鉴权不走 IP 限流)
- 失败的话明确报错 `API rate limit exceeded`,workflow 退出码非 0

**通过条件**:正常发版流程不会撞限流。

---

## 回归测试(发版前必跑)

发新版本前,除了跑上面 8 个场景,还要回归测主功能:

| 项 | 检查点 |
|---|---|
| 菜单栏 popover | 正常显示、刷新按钮工作、Cmd+R 工作、Cmd+W 关闭 |
| API Key | 粘贴、显示/隐藏、保存、Keychain 重启不丢 |
| 进度条 | 阶梯 / 渐变 / 颜色 / 周限额模式都正常 |
| 无限样式 | 流光(默认)/色相流/双波流/呼吸 都跑得动 |
| 设置面板 | 4 个分组(账户/面板显示/菜单栏/版本/高级)切换正常 |

## 紧急回滚

如果 v0.4.0 发布后大面积报错:

1. **GitHub 删 release**:`gh release delete v0.4.0`
2. **改 appcast.xml** 指向旧版
3. **发 v0.4.1 hotfix**(修问题)
4. **或者**改 `Info.plist` 的 `SUFeedURL` 指向旧版,强制全用户回到 v0.3.5

## 测试 checklist(发版前)

```
□ 场景 1:首次安装 + 自动检查
□ 场景 2:正常升级
□ 场景 3:降级尝试
□ 场景 4:网络异常
□ 场景 5:签名异常(改公钥测试一次)
□ 场景 6:Release 缺失
□ 场景 7:Appcast 损坏
□ 场景 8:GitHub API 限流(只在 CI 上跑)
□ 主功能回归测试
□ Console 日志无 crash / fatal error
```

## 自动化(可选,后续优化)

- [ ] GitHub Actions 加 `e2e-update-test` job:起 macOS runner,装旧版,触发检查,断言新版能装
- [ ] snapshot 测试 `UpdateForm` UI(各 state)
- [ ] 监控:Sentry / Bugsnag 接 Sparkle 错误上报
