# 品牌隔离层（Branding Layer）

本目录是 **BaiLongma 二开** 中「图标 + 软件名」的唯一信源与确定性应用引擎。
设计目标：**后期从上游升级（rebase/merge）时，品牌不会被上游覆盖，也不需要手工逐文件改。**

## 你只需要动这里

| 文件 | 作用 |
|---|---|
| `branding/branding.json` | 单一信源：`appName`（软件名）、`appId`（反向域名标识）、`assistantName`（AI 人格名，可选） |
| `branding/icon-source.png` | **所有图标的唯一源图**（1024×1024 方形）。换图标只换这张 |
| `branding/logo-source.png` | UI 用 logo 源图 |
| `branding/make-icons.py` | 从 icon-source.png 生成 `build/` 下全部图标 + 安装包侧边图 |
| `branding/apply.mjs` | 把品牌 100% 写回仓库（改名 + 生成图标），可重复运行 |

> ⚠️ `build/icon.*`、`package.json` 的 `productName/appId`、`electron/main.cjs` 标题/托盘、
> 以及各 HTML `<title>` 都是 **apply.mjs 生成的产物**，请勿手工改它们——
> 改了也会被下次 `apply.mjs` 覆盖。要改就改 `branding/` 里的源。

## 改图标和软件名（3 步）

1. 把真实图标覆盖到 `branding/icon-source.png`（1024×1024，方形，透明背景最佳）。
2. 编辑 `branding/branding.json`：
   ```json
   { "appName": "你的软件名", "appId": "com.yourcompany.yourapp", "assistantName": "" }
   ```
   - `appName`：显示名（窗口标题、托盘、安装包、HTML 标题）。
   - `appId`：反向域名，**决定用户数据目录与自动更新通道**，改成你自己的。
   - `assistantName`：留空 = 不改 AI 在对话里的自我称谓；填了会把 prompt 里的「Bailongma」也替换。
3. 运行：
   ```bash
   node branding/apply.mjs
   ```
   需要 Python + Pillow：先 `python -m pip install Pillow`（或用 `BRANDING_PYTHON=/path/python node branding/apply.mjs` 指定）。

## 从上游升级（核心：品牌不丢）

> 本仓库与上游**没有共同 git 历史**（基线是从发布版归档直接落地的），因此升级用
> 「上游文件整体覆盖 + 重贴品牌」的方式最稳，不会因无共同历史而产生海量冲突。

```bash
git fetch upstream
git checkout upstream/main -- .     # 用上游最新文件整体覆盖工作区（branding/ 不会被覆盖，上游没有它）
node branding/apply.mjs             # 确定性地把品牌重新贴回去
git add -A && git commit -m "upgrade: upstream <sha> + reapply branding"
```

- `apply.mjs` 每次都**从源图重新生成全部图标**、并**重写软件名**，所以无论上游怎么改这些文件，
  重跑脚本后品牌都恢复到 `branding.json` 定义的状态。
- 若上游新增了需要我们品牌化的文件（比如新的 UI 窗口），在 `branding/apply.mjs` 的
  `titleFiles` 列表里补上路径即可，下一轮升级自动生效。
- （进阶）若你后续用 `git fetch upstream` 成功建立了共同历史，也可改用
  `git rebase upstream/main` + `node branding/apply.mjs`，效果相同。

## 已覆盖的品牌点

- 图标：窗口/托盘/安装包（Win `.ico`、Mac `.icns`、PNG、NSIS 侧边图）—— 全部来自一张源图。
- 软件名：`package.json` 的 `productName` / `build.productName` / `nsis.shortcutName` /
  `mac.extendInfo` 文案 / `appId`；`electron/main.cjs` 窗口标题、托盘提示、用户可见提示语；
  各 UI 窗口 HTML `<title>`（含 `Longma · Cognitive Surface`）。
- 内部标识符（`bailongma`/`BAILONGMA` 环境变量、全局对象、`com.xiaoyuanda.bailongma`
  仅在 appId 改变时整体替换）**不会**被误改，保证程序运行正常。

## 基线

当前基线 = 上游 `main` 分支 **v2.1.515**（2026-07-13 发布版）。仓库已打标签 `v2.1.515-branded-base`。
上游跟踪远程：`upstream` → `https://github.com/xiaoyuanda666-ship-it/BaiLongma`。
