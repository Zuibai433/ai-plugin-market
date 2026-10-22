# AI Plugin Market (自定义插件市场索引)

这是给 DeepSeek Harness（DSH）「自定义插件市场」用的 **format 1 索引文件**，由 `H:\AI` 维护、从 GitHub 仓库发布，作为 Discover 页与 `plugin_market` 工具的搜索源。

## 文件

| 文件 | 作用 |
|---|---|
| `index.json` | 市场索引（format 1），60 个真实 npm 插件条目 |
| `publish.ps1` | 发布脚本：校验 → git 提交 → 推 GitHub → 自动回写 DSH 搜索源 URL |

## 索引怎么来的

条目全部取自 npm registry `keywords:dsh-plugin` 的真实数据（名称、版本、发布时间、描述、主页），
每次重新生成都会核对真实版本号，不虚构条目。

`index.json` 已用 DSH 自带的校验器 `parseMarketIndex`（`@deepseek-ai/dsh-plugin-market-index`）验证通过：
`format=1`、60 个插件、分类 7 个、`marketInstallTarget("dsh-whale-widget","0.4.2") → dsh-whale-widget@0.4.2`。

## 发布到 GitHub

```powershell
cd H:\AI\plugin-market
.\publish.ps1 -Repo <你的GitHub用户名>/ai-plugin-market
```

脚本会 `git init` / 提交 / 推送到 `main`，然后把
`%USERPROFILE%\.dsh\profiles\desktop\cordis.patch.yml` 里 `plugin-market` 的 `indexes`
改写成真实 URL（改写前自动备份）。

## URL 形式（重要）

| 形式 | 可用性 |
|---|---|
| `https://cdn.jsdelivr.net/gh/<owner>/<repo>@main/index.json` | **默认**，国内可达，无重定向 |
| `https://<owner>.github.io/<repo>/index.json` | 需在仓库 Settings → Pages 开启，国内通常可达 |
| `https://raw.githubusercontent.com/...` | 本机实测 **SSL 被阻断**，不要用 |
| `https://github.com/<owner>/<repo>/raw/main/index.json` | 会 302 跳转，DSH **拒绝重定向**，不要用 |

DSH 的 `plugin-market` 只接受 http(s)、无凭据、无 fragment 的绝对 URL，且**不跟随重定向**。

## 加一个 GitHub 直连（git 源）插件

`versions[].source` 除了 `{"type":"npm"}` 还支持 git，需要 40 位小写 commit SHA：

```json
{
  "version": "0.4.2",
  "publishTimestamp": 1760185632,
  "source": {
    "type": "git",
    "url": "https://github.com/MeteorNOX/DeepSeek-Balance-Whale-Widget",
    "commit": "5247dd6813d6e4430728f39ccc63d43cda046022"
  }
}
```

注意：索引里 `name` + `version` 是市场的声明，真正装什么由包自身的清单决定（索引无签名）。

## 在界面里也能改

DSH 桌面端 → Plugins → Discover → 「已添加的索引源 / Index sources」→ 填 URL → 添加。
界面写入与 `cordis.patch.yml` 是同一份存储（Settings 通过 profile 的 Cordis patch 持久化），二者等价。
