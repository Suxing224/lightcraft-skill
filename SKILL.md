---
name: lightcraft
description: 用本机 LightCraft 给照片调色——修单张、批量套同款风格、参考某张图迁移调色参数。覆盖 RAW/JPEG 显影、曝光高光阴影、曲线、八通道 HSL、色彩分级、蒙版、预设、批量导出。当用户说「调照片/修图/调色/批量修/照着这张修/导出成片」时使用。
license: MIT
---

# LightCraft

LightCraft 是纯 Rust 写的开源 RAW 显影器（Lightroom 替代品），每个滑块都是一支带稳定 ID 的命令。

本 skill 覆盖两种驱动方式，按场景分工：

| 方式 | 何时用 | 特点 |
|---|---|---|
| **CLI headless**（`lightcraft-cli`） | 批量、无人值守、脚本化 | 不开窗口、一条命令出图、最快 |
| **App 控制通道**（`--control PORT`） | 单张精调、需要看效果 | 有 `ui.screenshot`，能截图自查 |

> 关键区别（别搞混）：
> - **CLI headless 没有 `ui.*` 方法**（截窗口那套只在 App 里有），但**不等于看不见画面**——
>   `lightcraft-cli render` 出文件、官方 MCP 的 `render_preview` 直接返回图片，都能看。
> - 控制通道的独特价值不是"能看图"，而是**图就在用户眼前那个窗口里**，改动实时可见。
> - 两条路**不能同时打开同一个库**

**已验证环境**（README 里的版本数据都来自这里，换环境请自己复测）：

```
LightCraft App / CLI   0.19.0
headless 命令          389 条
调色控件               122 个
平台                   macOS（Linux/Windows 未测）
```

控件的 id 和范围见 `references/controls.md`；命令签名见 `references/commands.md`（上游生成于 0.9.1，本机 0.19.0 实测多出 18 条命令，但控件表一致）。

## 一、准备

**至少要有一样**：桌面 App，或 CLI（建议两个都有，分工如上）。

```bash
# 方式一：桌面 App（自带控制通道）
# macOS
open -a "LightCraft" --args --control 7980

# 方式二：CLI（从 GitHub releases 下 lightcraft-cli-<ver>-macos-universal.zip）
unzip lightcraft-cli-*.zip && cp */lightcraft-cli /usr/local/bin/ && chmod +x /usr/local/bin/lightcraft-cli
lightcraft-cli --version
```

- 库位置默认 `~/Pictures/LightCraft Library`；换库用 `--library /path`
- 隔离实验用 `--memory`（内存库，退出即消失，不落盘）
- 控制通道**只监听回环、无密码**，用完必须关（见下）

## 二、执行层

**铁律：每次动手前先确认哪条路可用，并在回复里明说这次走的是 CLI 还是 App。**

```bash
bash scripts/which-mode.sh
```

它查三件事：控制端口、CLI 二进制、两个库 `catalog.snap` 的修改时间。
**哪个库刚被写过，就是哪条路干的活**——这是最硬的证据，比任何猜测都可靠。

| 现象 | 含义 |
|---|---|
| 桌面库 `~/Pictures/LightCraft Library` mtime 更新 | 走的是 App 控制通道 |
| 批量库 `~/Pictures/lc-batch` mtime 更新 | 走的是 CLI |
| 控制端口在监听 | App 通道可用（能截图自查） |
| 控制端口没监听 | 只能用 CLI，或重启 App 加 `--control 7980` |

用户随时可能问"这次用的是哪个"，答不上来就是失职。

### A. CLI（headless，批量首选）

```bash
# 单文件直接出图（最简，一条命令到底）
lightcraft-cli render /abs/in.jpg -o /abs/out.jpg \
    --set light.exposure=0.2 --set light.highlights=-45 --size 1600 --quality 92

# 命令链 + 独立库（不碰桌面库）
lightcraft-cli run --library ~/Pictures/lc-batch \
    --import /abs/shoot develop.auto \
    develop.set control=light.highlights value=-45 \
    app.export dir=/abs/out longEdge=2048
```

- `--library DIR` 持久库／`--demo` 演示库／都不加 = 内存库（退出即消失）
- `--connect PORT` 接管运行中的 App —— **此时 `ui.*` 方法可用**
- `--settings FILE` 可喂部分 develop JSON 或 XMP 预设；`--preset ID` 套预设
- 退出码非 0 = 有命令失败；每行输出一条 `{"command","ok","result","ms"}`
- `lightcraft-cli mcp` 起 MCP 服务器（stdio），需要给客户端接的时候用

### B. 控制通道（需要看画面时）

用本 skill 自带的 `scripts/lc.py`（纯标准库，无第三方依赖）：

```bash
python3 scripts/lc.py '{"id":1,"method":"engine.execute","params":{"command":"develop.get","params":{}}}'
# 一次多条：每个参数是一条 JSON
python3 scripts/lc.py '<json1>' '<json2>'
# 非默认端口 / 超时
python3 scripts/lc.py --port 7981 '<json>'
```

单条请求格式：

```json
{"id": 1, "method": "engine.execute", "params": {"command": "<命令id>", "params": {...}}}
```

回复 `{"id":1,"ok":true,"result":...}` 或 `{"ok":false,"error":"..."}`。
另有 `ui.*` 方法（截图、点控件、改视图），走 `method` 直接调，不包 `engine.execute`。

### C. 官方 MCP（第三种选择，看效果最省事）

LightCraft 自带 MCP 服务器，不用第三方包装：

```bash
lightcraft-cli mcp                        # 内存库，退出即失效
lightcraft-cli mcp --library ~/Pictures/lc-batch   # 持久库，编辑会保存
lightcraft-cli mcp --demo                 # 演示库，24 张合成素材
lightcraft-cli mcp --connect 7980         # 接管运行中的 App，此时 ui.* 也可用
lightcraft-cli mcp --compact              # 只暴露 17 个高层工具
```

0.19.0 实测暴露 **406 个工具** = 17 个高层（`import` / `select_photos` / `set_develop` /
`render_preview` / `export` 等）+ 389 个 `cmd_*` 逐命令包装。`--compact` 只留那 17 个。

**`render_preview` 是它最好用的一点**：直接返回图像内容块（默认长边 1024，上限 4096），
不用落盘再读，等于一次调用就能自查效果。

它的代价是接入成本：要写 MCP 客户端配置、可能要重启会话，而且工具多会占上下文。
**环境里没有 MCP 通道时，用 A 或 B；有了 MCP 通道，精调走它更顺手。**

## 三、标准流程

```
选片 → 导入 → 读现状 → 调参 → 渲染看一眼 → 迭代 → 导出 → 复盘
```

1. **导入**（引用原文件，不复制、不动原图）
   ```json
   {"command":"library.import","params":{"paths":["/abs/a.jpg"],"mode":"add"}}
   ```
   返回 `{imported:[25]}` —— 记住这个 id。

2. **读现状**
   - `photo.inspect` `{id}` → 文件名、尺寸、EXIF（camera/lens/iso/aperture/shutter）
   - `develop.get` `{}` → 当前调色 JSON（全 0 = 未调）
   - `develop.controls` `{}` → 122 个控件的 id/范围/默认值/当前值

3. **调参**
   ```json
   {"command":"develop.set","params":{"ids":[25],"values":{"light.exposure":0.2,"light.highlights":-45}}}
   ```
   - 只覆盖 `values` 里点名的控件，其余保持不变
   - 未知 id 会报错；超范围的值**静默钳制**（exposure 9 → 5），不会提示

4. **看一眼**（不要盲调）
   ```json
   {"method":"ui.set","params":{"view":"detail"}}
   {"method":"ui.screenshot","params":{"path":"/tmp/look.png","headless":true}}
   ```
   `headless:true` 用 CPU 渲染，窗口不在前台也能截。视图名只能是
   `photoGrid` / `squareGrid` / `detail` / `compare` / `survey` / `reference` / `people`。

5. **导出**
   ```json
   {"command":"app.export","params":{"ids":[25],"path":"/abs/out.jpg","longEdge":2048,"quality":92,"colorSpace":"srgb"}}
   ```
   `longEdge` 默认 3000，设 0 = 原始尺寸；`shortEdge` / `width` / `height` / `percent` 任选其一。
   格式由 `path` 扩展名决定，或显式 `format: jpeg|png|tiff|webp|avif|jxl|psd|dng`。

## 四、三种常见任务

### A. 修一张

按题材定方向，不要一上来套通用参数。判断顺序：
**先看灰雾（dehaze）→ 再看高光是否溢出（highlights）→ 再看暗部是否闷死（shadows）→ 最后动色彩**。

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

```json
{"command":"develop.copy","params":{}}                    // 复制当前照片的设置
{"command":"library.select","params":{"ids":[26,27,28]}}
{"command":"develop.paste","params":{"ids":[26,27,28]}}
```

或直接 `develop.sync` `{groups?}` —— 把活动照片设置同步给所有选中照片。
`develop.copy` 默认**不含裁切、蒙版、污点修复**，要带上就传 `groups:["crop","masks","remove"]`。

批量导出：`app.export` 传 `dir` + `ids`：
```json
{"command":"app.export","params":{"ids":[26,27,28],"dir":"/abs/out","longEdge":2048,"quality":90}}
```

### C. 参考某张图修（迁移调色）

**两种做法，按需求选：**

1. **整份迁移**（A 怎么调，B 就怎么调）
   ```json
   // 1) 选中参考图
   {"command":"library.select","params":{"ids":[25],"active":25}}
   // 2) 复制设置
   {"command":"develop.copy","params":{}}
   // 3) 粘到目标
   {"command":"develop.paste","params":{"ids":[30]}}
   ```

2. **只取部分参数**（保留 B 自己的曝光，只借颜色）
   先 `develop.get {id:25}` 拿到完整 JSON，挑出要的键，再用 `develop.merge` 打到 B：
   ```json
   {"command":"library.select","params":{"ids":[30],"active":30}}
   {"command":"develop.merge","params":{"settings":{"grading":{"shadows":{"hue":212,"sat":8}},"color":{"vibrance":7}}}}
   ```
   `develop.merge` 是**深合并**，只给想改的字段；键名是 snake_case（`effects.dehaze` → `{"effects":{"dehaze":...}}`）。

> 参考图如果是 Lightroom 里的片子，先 `library.inspectLightroom` 看目录，
> 再用 `library.importLightroom` 把 catalog 导进来，不必先导 JPEG。

## 五、踩坑（实测 + 社区反馈）

- **`develop.auto` 会覆盖**你之前设的光影滑块和鲜艳度/饱和度。要自动 + 手调，就先 auto 再 set。
- **重复导入不产生新 id**：同路径或同内容的文件返回 `duplicates:[{existing,reason}]`、`imported:[]`，
  下一个编辑会落到**上一张活动照片**上。先 `library.select` 选 `existing` 那个 id。
- **值超范围静默钳制**，未知控件 id 才报错。别指望它帮你把关。
- **`app.export` 用 `path` 精确指定文件**；用 `dir` 时按原名批量写入，注意别覆盖。
- **视图名是 `photoGrid` 不是 `grid`**，写错会报 `unknown variant`。
- **`ui.screenshot` 用 `headless:true`** 最稳，不依赖窗口在前台；有窗口时 2 秒内没画面会自动回落 headless。
- **一个库同时只能被一个进程打开**。桌面 App 开着时，别再对同一库起 `lightcraft-cli`。
- **AI 蒙版要模型**：`kind: sky|subject|background|object|prompt` 依赖 SAM 3（约 3.4 GB，需下载）。
  `brush|linear|radial|luminanceRange|colorRange` 不需要模型，优先用这些。
- **白平衡用 Kelvin**：`wb.temp` 默认 6500，范围 2000–50000，**数值升高 = 变暖**；`wb.tint` -150~150。
- **`lowDiskSpace`**：库所在盘紧张时 CLI 会警告。导出大图前先 `df -h`。
- **端口无认证**，只在回环。任务结束务必关掉：macOS `osascript -e 'quit app "LightCraft"'`，
  其他平台直接结束进程。

## 六、验证

调完不要只信自己的眼睛，交叉验证：

```bash
# 设置真的写进去了？（看 develop.get 里那几项）
# 导出文件真的存在且尺寸对？（看 app.export 返回的 files[].width/height/bytes）
# 有没有把原图改坏？（原图 mtime 应该没变）
ls -la /abs/out.jpg && md5 /abs/原图.jpg
```

导出返回里带 `gpuFallback` 时说明这一张回落到 CPU 渲染，结果正确但慢。

## 七、参考

- `references/controls.md` —— 122 个滑块的 id 与范围，调参前必查
- `references/commands.md` —— 371 条命令签名（0.9.1 生成）
- `examples/prompts.md` —— 跟用户沟通用的提示词写法（四槽公式）
- 命令全量：`lightcraft-cli run engine.commands`，或控制通道 `{"method":"engine.commands"}`
- 控件全量：`lightcraft-cli run develop.controls`

### 文件来源

| 文件 | 来源 | 改动 |
|---|---|---|
| `references/*.md` | [ai-2070/claude-storytold-skills](https://github.com/ai-2070/claude-storytold-skills)（MIT） | **原封未动** |
| `SKILL.md` | 在上游版本基础上重写适配 | 执行层从 MCP 改为 CLI + 控制通道，重新组织 |
| `scripts/lc.py`、`scripts/which-mode.sh` | 本项目原创 | 上游无 `scripts/` |

上游的 MCP 工具名（`mcp__lightcraft__*`）在本项目不适用——这里走 CLI 与控制通道，不需要装 MCP。
