# lightcraft-skill

在 Claude Code / WorkBuddy 这类 AI agent 里驱动本机 [LightCraft](https://github.com/storytold/lightcraft) 调色。

**MCP 优先，另有三条降级路径。** 现成配置、实测过的坑、跟用户沟通的提示词写法——这些是官方仓库不会给的部分。

```
用户：把 ~/Pictures/x.jpg 调一下，灰雾重，想清冷通透
agent：（导入 → 读 EXIF → 调参 → 截屏自查 → 迭代 → 导出）给你看成片
```

## 为什么有这个东西

LightCraft 官方自带的 MCP 服务器（`lightcraft-cli mcp`）相当完整——**本项目就用它**，因为实测下来它确实最好用。

但官方只给了接口，没给这些：

1. **一份能直接用的配置** —— 三个参数缺一不可，下面解释为什么
2. **实测过的坑** —— `open --args` 传不进参数、`osascript quit` 报权限违例、`max_side` 和 `maxSize` 两套命名… 这些不踩一遍填不出来
3. **降级路径** —— MCP 没配好、客户端不支持、或者只想闷头批量跑时，CLI 和原始 socket 都能顶上
4. **跟用户沟通的方法** —— `examples/prompts.md`，四槽公式。工具再好，用户一句"调好看点"就废了

`references/` 来自 [ai-2070/claude-storytold-skills](https://github.com/ai-2070/claude-storytold-skills)，原封未动。

## 配置：三个参数缺一不可

```json
{
  "mcpServers": {
    "lightcraft": {
      "command": "/usr/local/bin/lightcraft-cli",
      "args": ["mcp", "--connect", "7980", "--compact"]
    }
  }
}
```

| 参数 | 不写会怎样 |
|---|---|
| `--connect 7980` | 不加就连不上你正在看的那个 App；写 `--library DIR` 则变成独立库（不带任何库参数 = **内存库，编辑退出即丢**） |
| `--compact` | **工具数从 28 涨到 628**（600 个 `cmd_*` 包装），白烧上下文。加了也不损失能力——`command_run` 照样能调到全部命令 |

`--connect` 的好处是连不上也不会死：它只在 stderr 说 `will retry on each call`，所以可以常驻配置，App 没开时照样能启动。

## 一条容易踩的启动坑

```bash
# ❌ open --args 常被 LaunchServices 吞掉：App 起来了，端口没开
open -a "LightCraft" --args --control 7980

# ✅ 直接跑二进制，参数一定传得进去
"/Applications/LightCraft.app/Contents/MacOS/LightCraft" --control 7980 &
```

关掉用 `pkill -TERM -f "LightCraft.app/Contents/MacOS/LightCraft"`——`osascript -e 'quit app "LightCraft"'` 会报 `-10004 权限违例`，关不掉。


## 安装

两步：放 skill 目录，再把上面那段 `mcpServers` 合进你的 `mcp.json`，**重启会话**生效。

```bash
# WorkBuddy（工作区级）
git clone https://github.com/Suxing224/lightcraft-skill.git .workbuddy/skills/lightcraft

# Claude Code（用户级）
git clone https://github.com/Suxing224/lightcraft-skill.git ~/.claude/skills/lightcraft
```

不想用 MCP 也行——其他 agent 只要支持「读一份 SKILL.md 当上下文」，把它指向本文件即可。

## 前置条件

至少要有一样：桌面 App，或 CLI。两个都装最好——MCP 要 CLI，控制通道要 App。

```bash
# CLI —— 从 releases 下 lightcraft-cli-<ver>-macos-universal.zip
unzip lightcraft-cli-*.zip
cp */lightcraft-cli /usr/local/bin/ && chmod +x /usr/local/bin/lightcraft-cli

# 桌面 App（注意：直接跑二进制，别用 open --args）
"/Applications/LightCraft.app/Contents/MacOS/LightCraft" --control 7980 &
```

## 快速验证

```bash
# 1. 控制通道通不通（直接 TCP 探测，别信 lsof）
python3 -c "import socket;s=socket.socket();print('open' if not s.connect_ex(('127.0.0.1',7980)) else 'closed')"

# 2. 现在走哪条路、能不能调
bash scripts/which-mode.sh

# 3. 一条命令渲染一张（不经过 MCP）
lightcraft-cli render in.jpg -o out.jpg --set effects.dehaze=15 --size 1600
```

MCP 通不通，看会话工具列表里有没有这 28 个：`query_photos`、`select_photos`、`set_develop`、`render_preview`、`ui_screenshot`…

## 已验证环境

README 和 SKILL.md 里的数字都来自这一次实测，**换环境请自己复测**：

| 项目 | 值 |
|---|---|
| LightCraft App / CLI | 0.19.0 |
| headless 命令 | 389 条 |
| 调色控件 | **122 个**（与上游 0.9.1 文档一致，两年来没变） |
| MCP 工具 | **28 个**（`--compact`）；不加该参数为 628 个 |
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
  lc.py                  控制通道客户端（零依赖，MCP 不可用时兜底）
  which-mode.sh          CLI / App 路径自检
examples/
  prompts.md             怎么跟用户要提示词（四槽公式）
```

## 已知限制

- 每条命令的参数格式在 0.19 上是实测过的，跨版本可能变——先 `lightcraft-cli run engine.commands` 核对
- `which-mode.sh` 的时间戳判断依赖你给 CLI 配了**独立库**；共用一个库就分不出来
- 控制端口无认证，只绑回环。收工务必关掉 App
- MCP 配置改了必须重启会话才生效；`--connect` 依赖 App 带着 `--control` 跑着

## 许可

MIT。`references/*.md` 来自 [ai-2070/claude-storytold-skills](https://github.com/ai-2070/claude-storytold-skills)（MIT，Copyright © 2026 V and contributors），原封未动，署名见 [LICENSE](LICENSE)。

## 贡献

最需要的是**跨环境复测**：Linux / Windows 的路径与进程检测、0.18 及更早版本的命令差异、非英文 locale 下的文件名处理。开 issue 说清版本和平台就行。
