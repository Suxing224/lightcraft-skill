---
name: lightcraft
description: 用本机 LightCraft 给照片调色——修单张、批量套同款风格、参考某张图迁移调色参数。覆盖 RAW/JPEG 显影、曝光高光阴影、曲线、八通道 HSL、色彩分级、蒙版、预设、批量导出。当用户说「调照片/修图/调色/批量修/照着这张修/导出成片」时使用。
license: MIT
---

# LightCraft

LightCraft 是纯 Rust 写的开源 RAW 显影器（Lightroom 替代品），每个滑块都是一支带稳定 ID 的命令。

**已验证环境**（本文所有数字来自这里，换环境请自己复测）：

```
LightCraft App / CLI   0.19.0
headless 命令          389 条
调色控件               122 个
MCP 工具               28 个（--compact，连接模式）
平台                   macOS（Linux/Windows 未测）
```

## 三套驱动方式

| 方式 | 何时用 | 看图方式 | 前置 |
|---|---|---|---|
| **MCP（首选，已接入）** | 日常精调、需要边调边看 | `render_preview` / `ui_screenshot` 一次调用直接返图 | App 带 `--control` 启动 |
| **CLI headless** | 批量、脚本、无人值守 | `render` 出文件再读 | CLI 二进制 |
| **控制通道 `scripts/lc.py`** | MCP 不可用时的兜底 | `ui.screenshot` 出 PNG 再读 | App 带 `--control` 启动 |

**默认走 MCP。** 只有 MCP 不可用（没配、连不上）才降级到 CLI 或 `lc.py`，并且**在回复里明说降级了、为什么**。

> 两条红线：
> - App 与控制通道能同时用（它们本来就是同一个进程），但 **App 和 CLI 不能同时打开同一个库**。
> - 控制端口只绑回环、**无认证**，收工要关。

## 一、准备：把 App 正确拉起来

```bash
# ✅ 正确：直接跑二进制，参数一定传得进去
"/Applications/LightCraft.app/Contents/MacOS/LightCraft" --control 7980 &

# ❌ 不可靠：open --args 常常被 LaunchServices 吞掉，参数不生效
open -a "LightCraft" --args --control 7980
```

等待端口就绪（通常 1–3 秒）：

```bash
for i in $(seq 1 30); do
  python3 -c "import socket,sys;s=socket.socket();s.settimeout(1)
sys.exit(0 if not s.connect_ex(('127.0.0.1',7980)) else 1)" && break; sleep 1
done
```

关掉要用 SIGTERM——**`osascript -e 'quit app "LightCraft"'` 会报 `-10004 权限违例`**，不生效：

```bash
pkill -TERM -f "LightCraft.app/Contents/MacOS/LightCraft"
```

## 二、执行层

### A. MCP（首选）

配置在 `~/.workbuddy/mcp.json`：

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

三个参数都别删：

- **`--connect 7980`** 接管运行中的 App —— 用的是你在看的那个库，`ui.*` 也能用。
  连不上时它不会退出，只在 stderr 说 `will retry on each call`，所以可以常驻配置。
- **`--compact`** 必加。不加的话连接模式暴露 **628 个工具**（600 个 `cmd_*`），
  加完只有 28 个，而 `command_run` 照样能调到全部 628 条命令。
- 想脱离 App 独立跑，把 `--connect 7980` 换成 `--library DIR`（持久库）或 `--demo`。
  **注意：不带任何一个 = 内存库，编辑退出即失效。**

**28 个工具分三组**：

| 组 | 工具 |
|---|---|
| 库与查询 | `query_photos` `select_photos` `import` `doc_inspect` `export` |
| 显影 | `list_controls` `get_develop` `set_develop` `apply_preset` `crop` `render_preview` `render_photo` |
| UI | `ui_inspect` `inspect_ui` `ui_screenshot` `screenshot` `set_ui` `list_widgets` `click` `press_key` `type_text` `clipboard` `pointer_gesture` |
| 逃生口 | `command_list` `command_run` `command_batch`（`list_commands`/`run_command` 是旧别名） |

**两个看图工具的区别**（很容易搞混）：

- `render_preview` —— 按当前显影设置渲染**照片**（裁切后），参数 `max_side`（下划线！默认 1024，上限 4096）。
  不改选区、不写文件。调色时用它。
- `ui_screenshot` —— 截**整个窗口**（含面板滑块），参数 `maxSize`（驼峰！）和 `format`。
  要给用户看界面、或确认某个面板状态时用它。

参数名两套风格混着用，**写错会报 `unknown argument`**，别看名字猜。

**选区语义**（官方 instructions 原文，务必记住）：`set_develop`、`crop`、带显式 id 的 `export`
会**结束当前编辑交互、把选区替换成那一张**；`get_develop`、`render_photo` 不改选区。
位置类参数（裁切矩形、蒙版点、画笔轨迹）都是 **0..1 归一化坐标，原点在左上角**。

### B. CLI headless（批量首选）

```bash
# 单文件直接出图
lightcraft-cli render /abs/in.jpg -o /abs/out.jpg \
    --set light.exposure=0.2 --set light.highlights=-45 --size 1600 --quality 92

# 命令链 + 独立库
lightcraft-cli run --library ~/Pictures/lc-batch \
    --import /abs/shoot develop.auto \
    develop.set control=light.highlights value=-45 \
    app.export dir=/abs/out longEdge=2048
```

- `--library DIR` 持久库／`--demo` 演示库／都不加 = 内存库
- `--settings FILE` 喂部分 develop JSON 或 XMP 预设；`--preset ID` 套预设
- 退出码非 0 = 有命令失败；每行输出一条 `{"command","ok","result","ms"}`
- 批量时给 CLI 配**独立库**，否则和 App/ MCP 抢锁

### C. 控制通道 `scripts/lc.py`（兜底）

纯标准库，零依赖，直连 JSON-lines 协议：

```bash
cd <skill目录>
python3 scripts/lc.py '{"id":1,"method":"engine.execute","params":{"command":"develop.get","params":{}}}'
python3 scripts/lc.py --port 7981 '<json>'      # 非默认端口
```

请求格式 `{"id":1,"method":"engine.execute","params":{"command":"<命令id>","params":{...}}}`，
回复 `{"id":1,"ok":true,"result":...}`。`ui.*` 方法直接走 `method`，不包 `engine.execute`。

`scripts/which-mode.sh` 查"上一次到底走了哪条路"：对比两个库 `catalog.snap` 的修改时间，
**哪个库刚被写过就是哪条路干的活**。用户问起时用它回答，别猜。

```bash
bash scripts/which-mode.sh
```

## 三、标准流程（MCP 版）

```
query_photos → select_photos → list_controls → set_develop → render_preview → 迭代 → export
```

1. **找照片** `query_photos {}` → id、文件名、尺寸、相机、是否已编辑
2. **选中并激活** `select_photos {"ids":[25],"active":25}` —— 后续显影操作都作用于 active 那张
3. **读现状** `get_develop {"id":25}`（全 0 = 未调）；`list_controls {}` 拿 122 个控件的 id/范围/当前值
4. **调参** `set_develop {"values":{"light.exposure":0.2,"light.highlights":-45}}`
   - 只覆盖点名的控件；未知 id 报错；**超范围静默钳制**（9 → 5），不提示
   - 也可传 `settings` 给嵌套 JSON，语义与 `values` 不同，别混
5. **看一眼** `render_preview {"max_side":1400}` —— 返回图像，直接看，别盲调
6. **导出** `export {"id":25,"path":"/abs/out.jpg"}`；
   批量用 `{"ids":[...],"dir":"/abs/out"}`

导出的尺寸/格式参数：`longEdge`（默认 3000，0 = 原始尺寸）、`shortEdge`/`width`/`height`/`percent` 任选其一、
`format: jpeg|png|tiff|webp|avif|jxl|psd|dng`，或由 `path` 扩展名决定。

## 四、三种常见任务

### A. 修一张

判断顺序固定：**先看灰雾（dehaze）→ 再看高光是否溢出（highlights）→ 再看暗部是否闷死（shadows）→ 最后动色彩**。
不要一上来套通用参数。

灰雾重的小景起步值（实测可用）：

```json
{"light.exposure":0.20,"light.contrast":11,"light.highlights":-45,"light.shadows":42,
 "light.whites":10,"light.blacks":-5,"effects.dehaze":15,"effects.clarity":3,
 "effects.texture":8,"color.vibrance":7,
 "grading.shadows.hue":212,"grading.shadows.sat":8,
 "grading.highlights.hue":45,"grading.highlights.sat":7,
 "grading.balance":-18,"grain.amount":14,"grain.size":32}
```

原则：**去雾 + 压高光 + 提阴影**是救灰片的三件套；`clarity` 别过 10，过了就有数码硬味。

### B. 批量套同款风格

```bash
# MCP：先 select 母版，复制设置，再贴到目标
# 或走命令（任何路都能发）
develop.copy {}                       # 复制活动照片设置
library.select {"ids":[26,27,28]}
develop.paste {"ids":[26,27,28]}
```

或 `develop.sync {groups?}` 把活动照片设置同步给所有选中照片。
`develop.copy` 默认**不含裁切、蒙版、污点修复**，要带上就传 `groups:["crop","masks","remove"]`。

批量导出用 `export {"ids":[...],"dir":"/abs/out","longEdge":2048,"quality":90}`。

### C. 参考某张图修（迁移调色）

1. **整份迁移**：`select_photos` 母版 → `develop.copy` → `develop.paste {"ids":[目标]}`
2. **只借颜色**（保留目标自己的曝光）：`get_develop` 拿母版 JSON，挑键，用 `develop.merge` 深合并：
   ```json
   {"command":"develop.merge","params":{"settings":{"grading":{"shadows":{"hue":212,"sat":8}},"color":{"vibrance":7}}}}
   ```
   键名是 snake_case（`effects.dehaze` → `{"effects":{"dehaze":...}}`）

> 参考图在 Lightroom 里的话，先 `library.inspectLightroom` 看目录，
> 再 `library.importLightroom` 把 catalog 导进来，不必先导 JPEG。

## 五、踩坑（实测，0.19.0 / macOS）

**启动与连接**
- **`open -a ... --args --control 7980` 不可靠**：LaunchServices 常常吞掉参数，App 起来了但端口没开。直接跑二进制。
- **`osascript -e 'quit app "LightCraft"'` 报 `-10004 权限违例`**，关不掉。用 `pkill -TERM`。
- **MCP 不带库参数 = 内存库**，编辑退出即失效。要保存必须 `--library`。
- **MCP 连接模式不加 `--compact` 会暴露 628 个工具**，白烧上下文。

**MCP 工具**
- `render_preview` 用 `max_side`，`ui_screenshot` 用 `maxSize`。命名不统一，写错报 `unknown argument`。
- `ui_screenshot` 返回的是**整个窗口**，不是照片本身；要看照片用 `render_preview`。

**显影**
- **`develop.auto` 会覆盖**你之前设的光影滑块和鲜艳度/饱和度。要自动 + 手调，就先 auto 再 set。
- **值超范围静默钳制**，未知控件 id 才报错。别指望它把关。
- **白平衡用 Kelvin**：`wb.temp` 默认 6500，范围 2000–50000，**数值升高 = 变暖**；`wb.tint` -150~150。
- **AI 蒙版要模型**：`kind: sky|subject|background|object|prompt` 依赖 SAM 3（约 3.4 GB，需下载）。
  `brush|linear|radial|luminanceRange|colorRange` 不需要模型，优先用这些。
- `pointer_gesture` 可以在照片上按归一化坐标回放拖拽，画笔/径向蒙版靠它。

**库与导出**
- **重复导入不产生新 id**：同路径/同内容返回 `duplicates:[{existing,reason}]`、`imported:[]`，
  下一个编辑会落到**上一张活动照片**上。先 `select_photos` 选 `existing` 那个 id。
- **`export` 用 `path` 精确指定文件**；用 `dir` 时按原名批量写入，注意覆盖。
- **视图名是 `photoGrid` 不是 `grid`**，写错报 `unknown variant`。可选：
  `photoGrid` / `squareGrid` / `detail` / `compare` / `survey` / `reference` / `people`。
- **`lowDiskSpace`**：库所在盘紧张时 CLI 会警告。导出大图前先 `df -h`。

## 六、验证

不要只信自己的眼睛，交叉验证：

- **设置真写进去了？** `get_develop` 里那几项的值对不对
- **导出文件真的对？** `export` 返回的 `files[].width/height/bytes`
- **原图没被改坏？** 原文件 mtime 应该没变
- **渲染是否回落 CPU？** 返回里带 `gpuFallback` 说明这张回落到 CPU，结果对但慢

## 七、参考

- `references/controls.md` —— 122 个滑块的 id 与范围，调参前必查
- `references/commands.md` —— 371 条命令签名（0.9.1 生成；0.19 连接模式实测 628 条，含 UI 命令）
- `examples/prompts.md` —— 跟用户沟通用的提示词写法（四槽公式）
- 命令全量：MCP `command_list`，或 `lightcraft-cli run engine.commands`
- 控件全量：MCP `list_controls`，或 `lightcraft-cli run develop.controls`

### 文件来源

| 文件 | 来源 | 改动 |
|---|---|---|
| `references/*.md` | [ai-2070/claude-storytold-skills](https://github.com/ai-2070/claude-storytold-skills)（MIT） | **原封未动** |
| `SKILL.md` | 在上游基础上重写 | 执行层改为 MCP 优先 + CLI/控制通道兜底，补 0.19 实测 |
| `scripts/lc.py`、`scripts/which-mode.sh` | 本项目原创 | 上游无 `scripts/` |

上游用 `mcp__lightcraft__*` 那套 MCP 工具名（406 个，含 389 个 `cmd_*`），本项目走 `--compact` 只留 28 个。
