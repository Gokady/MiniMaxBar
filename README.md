# MiniMax Usage — 状态栏小工具

一个 macOS 菜单栏小工具,显示 MiniMax Token Plan 的剩余额度。

## 当前状态

- ✅ 菜单栏图标 + 弹出面板
- ✅ API Key 存到 macOS Keychain
- ✅ 定时自动刷新
- ✅ 设置面板(套餐、刷新频率、显示模式、原始 JSON 查看)
- ⚠️ **响应解析器待定** —— 官方文档没有给出 `/v1/token_plan/remains` 的成功响应示例,目前 `TokenPlanData` 的字段名是最佳猜测

## 构建

```bash
./build.sh           # release
./build.sh debug     # debug
open dist/MiniMaxUsage.app
```

第一次启动会弹「设置」窗口,在那里填入 API Key。

## 拿到真实响应后,需要做的事

如果设置面板的"高级 → 显示原始 JSON"里能看到 5h 窗口和周窗口的数据,**但界面没显示进度条**,说明字段名没对上。请把那段 JSON 发给开发者,然后调整 `Sources/MiniMaxUsage/Models.swift` 里 `TokenPlanData` 的 `CodingKeys`,通常 1~2 行改动即可。

## 已知 API

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

## 路线图

- [ ] 解析器对齐真实响应
- [ ] 趋势图(等官方提供 history 接口,或 WKWebView 嵌控制台)
- [ ] 热力图(同上)
- [ ] 多套餐对比(给 Plus/Max/Ultra 用户互相看)
