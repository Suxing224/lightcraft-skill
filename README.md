# lightcraft-skill

在 Claude Code / WorkBuddy 这类 AI agent 里驱动本机 [LightCraft](https://github.com/storytold/lightcraft) 调色——**不用配 MCP，不用装 Node 服务，不用写代码**。

```
用户：把 ~/Pictures/x.jpg 调一下，灰雾重，想清冷通透
agent：（导入 → 读 EXIF → 调参 → 截屏自查 → 迭代 → 导出）给你看成片
```

## 为什么有这个东西

LightCraft 已经有一套相当完整的 agent 接口，主流做法是**全部经过 MCP**：

| 方案 | 驱动方式 | 前置依赖 |
|---|---|---|
| [ai-2070/claude-storytold-skills](https://github.com/ai-2070/claude-storytold-skills) | MCP | 装 `lightcraft-cli` + 配 MCP 客户端 |
| [jhonsu01/lightcraft-mcp-server](https://github.com/jhonsu01/lightcraft-mcp-server) | 第三方 Node MCP | Node ≥ 20 + LightCraft |
| **LightCraft 自带 `lightcraft-cli mcp`** | **官方 MCP，最好用** | 装 CLI |
| **本项目** | CLI + **直接连控制通道** | 有 LightCraft 就行 |

本项目建立在第一行之上（`references/` 直接来自它），但执行层完全重写：

1. **双引擎，分工明确** —— 需要看画面走控制通道（`ui.screenshot`，改动在用户眼前实时可见），闷头批量走 CLI headless。
2. **可溯源** —— `scripts/which-mode.sh` 靠对比两个库的 `catalog.snap` 时间戳，回答"上一次调色到底走的是哪条路"。两条路产出的图一模一样，只有过程不同，所以必须留痕。
3. **零依赖客户端** —— `scripts/lc.py` 100 行纯标准库，直接说 JSON-lines 协议。不装任何东西就能连。

## 那为什么不直接用官方 MCP？

好问题，而且**官方 MCP 在很多场景下确实更好**——它自带 `render_preview`，一次调用就返回图像内容块，不用落盘再读，自查效果比 CLI 方便。406 个工具（`--compact` 后 17 个）覆盖得也够全。

它唯一的问题是**接入成本**：得写客户端配置、可能要重启会话、工具多会占上下文。所以本项目的定位不是替代它，而是：

- **环境里没有 MCP 通道时**，本 skill 开箱即用，零配置
- **需要用户亲眼看着改动发生**时（图就在他打开的 App 窗口里），控制通道比 MCP 顺手
- **批量、无人值守**时，CLI 更直接，不用挂一个常驻服务

如果你已经在用 MCP，本项目可以作为补充——`references/` 和 `examples/` 两边都通用。


## 安装

把整个目录放进你的 skill 目录即可：

```bash
# WorkBuddy（工作区级）
git clone https://github.com/<you>/lightcraft-skill.git .workbuddy/skills/lightcraft

# Claude Code（用户级）
git clone https://github.com/<you>/lightcraft-skill.git ~/.claude/skills/lightcraft
```

其他 agent 只要支持「读一份 SKILL.md 当上下文」，把它指向本文件即可。

## 前置条件

至少要有一样：桌面 App，或 CLI。

```bash
# 桌面 App（macOS）
open -a "LightCraft" --args --control 7980

# 或 CLI —— 从 releases 下 lightcraft-cli-<ver>-macos-universal.zip
unzip lightcraft-cli-*.zip
cp */lightcraft-cli /usr/local/bin/ && chmod +x /usr/local/bin/lightcraft-cli
```

## 快速验证

```bash
# 1. 控制通道通不通
python3 scripts/lc.py '{"id":1,"method":"ui.inspect"}'

# 2. 现在走哪条路、能不能调
bash scripts/which-mode.sh

# 3. 一条命令渲染一张
lightcraft-cli render in.jpg -o out.jpg --set effects.dehaze=15 --size 1600
```

## 已验证环境

README 和 SKILL.md 里的数字都来自这一次实测，**换环境请自己复测**：

| 项目 | 值 |
|---|---|
| LightCraft App / CLI | 0.19.0 |
| headless 命令 | 389 条 |
| 调色控件 | **122 个**（与上游 0.9.1 文档一致，两年来没变） |
| 平台 | macOS |

未验证：Linux、Windows；LightCraft &lt; 0.19；AI 蒙版（依赖 SAM 3 模型，约 3.4 GB）。

## 它不是什么

- **不是 Lightroom 替代品** —— LightCraft 才是，这里只是驱动它
- **不做生成式修图** —— 降噪、超分、人像磨皮、老照片修复不在范围内，那是另一条技术路线
- **不动原图** —— 全程引用式导入，调色参数存在 LightCraft 库里，随时可撤

## 目录结构

```
SKILL.md                 agent 读的主文档（中文）
references/
  controls.md            122 个滑块的 id 与范围
  commands.md            371 条命令签名
scripts/
  lc.py                  控制通道客户端（零依赖）
  which-mode.sh          CLI / App 路径自检
examples/
  prompts.md             怎么跟用户要提示词（四槽公式）
```

## 已知限制

- 每条命令的参数格式在 0.19 上是实测过的，跨版本可能变——先 `lightcraft-cli run engine.commands` 核对
- `which-mode.sh` 的时间戳判断依赖你给 CLI 配了**独立库**；共用一个库就分不出来
- 控制端口无认证，只绑回环。收工务必关掉 App

## 许可

MIT。`references/*.md` 来自 [ai-2070/claude-storytold-skills](https://github.com/ai-2070/claude-storytold-skills)（MIT，Copyright © 2026 V and contributors），原封未动，署名见 [LICENSE](LICENSE)。

## 贡献

最需要的是**跨环境复测**：Linux / Windows 的路径与进程检测、0.18 及更早版本的命令差异、非英文 locale 下的文件名处理。开 issue 说清版本和平台就行。
