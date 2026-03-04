# TokenTrack (macOS native)

TokenTrack 是一款原生的 macOS 菜单栏应用，用于追踪各种 AI 客户端的 Token 消耗和成本。

它不再依赖外部的 Rust 引擎，而是完全基于 Swift 原生开发的 **TokscaleEngine**，能够直接解析本地日志、计算成本并生成多维度的统计报告。

---

## 核心功能

- **原生体验**: 作为 macOS 菜单栏应用 (`MenuBarExtra`) 运行，轻量且高效。
- **实时摘要**: 菜单栏点击即可查看今日、本周、本月的 Token 和金额汇总。
- **详细仪表盘**:
  - `Overview`: 时序统计图表及近期趋势。
  - `Models`: 按模型统计消耗、价格及占比。
  - `Daily`: 每日消耗明细。
  - `Stats`: 完整的统计数据分析。
- **深度解析**: 支持推理 Token (Reasoning)、缓存命中 (Cache Read/Write) 的多维度计算。
- **智能定价**: 集成 LiteLLM 实时价格同步、OpenRouter 价格辅助以及本地内置 Fallback 定价。
- **全平台支持**: 支持 10+ 种流行的 AI 客户端/插件解析。

---

## 支持的客户端

代码目前支持以下客户端的自动日志扫描与解析：

- **Claude** (Claude Desktop 官方 App)
- **Gemini** (Google 官方)
- **Cursor** (Cursor Code Editor)
- **Codex** (Codex 插件)
- **Amp / Droid / Pi** (常见第三方客户端)
- **OpenClaw / OpenCode** (自定义/开源客户端)
- **Kimi** (月之暗面)

---

## 技术架构

- **UI 层**: 原生 SwiftUI (macOS 14+)。
- **引擎层**: Swift 原生 `TokscaleEngine`。
- **解析层**: 针对不同客户端格式的 10+ 个原生 Swift Parser。
- **数据流**: 自动扫描 `~/ .config` / `.claude` / `.openclaw` 等目录下的日志文件。

---

## 本地编译与运行

### 快速开始

1. 确保已安装 Xcode 15+ (Swift 5.9+)。
2. 克隆仓库。
3. 进入项目目录并构建：

```bash
cd apps/TokscaleMac
swift build
# 运行
.build/debug/TokscaleMac
```

### 使用 build.sh

项目也提供了一个简化的构建脚本：

```bash
cd apps/TokscaleMac
./build.sh
```

---

## 关键定价逻辑说明

1. **LiteLLM 同步**: 应用启动时会尝试从 LiteLLM 镜像源获取最新的定价 JSON。
2. **OpenRouter 补偿**: 会从 OpenRouter 获取其平台独有的模型定价。
3. **本地内置**: `builtin.json` 包含 30+ 种核心模型的基准价格，作为离线或缺失数据的备份。
4. **计算规则**: 
   - 成本 = (Input * Price) + (Output * Price) + (CacheRead * Price) + (CacheWrite * Price) + (Reasoning * Price)。
   - 优先使用官方原笔提供商价格，对于 Reseller 或混合模型会自动进行回退和模糊匹配。

---

## 致谢

本项目基于优秀的 **[tokscale](https://github.com/junhoyeo/tokscale)** 项目。

感谢原作者及贡献者建立的 Rust Token 追踪基础，本项目在重写为原生 Swift 引擎的过程中，大量参考了其优秀的解析思路和定价方案。
