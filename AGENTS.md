# AGENTS.md

这个仓库是 Godot 4 项目《地牢编排师》（项目代号 `DNTB`）。所有 AI 协作者和自动化代理进入项目后，先读本文，再读 `docs/README.md` 和 `docs/01_系统设计文档.md`。

## 回复与文档语言

- 默认使用自然、清晰、地道的中文。
- 技术名词可以保留英文，例如 `ActionResolver`、`EffectPipeline`、`autoload`。
- 写文档时说完整，不写空泛口号。

## 项目入口

- 主场景：`res://scenes/game/App.tscn`
- 核心玩法场景：`res://scenes/game/Game.tscn`
- 项目配置：`project.godot`
- 当前设计文档：`docs/01_系统设计文档.md`
- 开发日志：`DEVELOP_LOG.md`
- 烟测脚本：`res://scripts/tests/SmokeTest.gd`

## 目录职责

- `scripts/core/`：核心控制器、服务和规则协调。
- `scripts/runtime/`：战斗运行态对象。
- `scripts/data/`：Godot Resource 数据定义和规则扩展点。
- `scripts/view/`：UI、场景表现和信号转发。
- `data/`：行动、角色、武器、遗物、成就等资源实例。
- `scenes/`：Godot 场景。
- `addons/`：第三方插件，保留原结构和许可证。
- `docs/`：中文设计、协作和验证文档。

## Godot 协作规则

- 不提交 `.godot/`、导出包、本地日志和个人 IDE 状态。
- Godot 生成并被跟踪的 `.gd.uid`、`.import` 文件要跟随对应资源保留。
- 资源、场景和脚本文本保持 UTF-8。
- 不直接手改 `project.godot` 中不熟悉的字段，优先用 Godot 编辑器或明确知道影响范围后再改。
- 改动第三方 `addons/dialogue_manager/` 前先确认确实需要，避免无关格式化。

## 架构边界

- `Game.gd` 是当前玩法组合根，但不要继续把所有新规则塞进去。
- 按键槽真实数据源是 `ActionProgramController.gd`。
- 回合顺序属于 `TurnController.gd`。
- 行动解析、动作伤害、移动结果和胜负判断属于 `ActionResolver.gd`。
- 遗物、状态、武器词条等可组合效果优先接入 `EffectPipeline.gd` 和 `EffectModifierDef`。
- UI 脚本负责展示和发信号，不直接承载战斗规则。

## 验证命令

优先运行：

```powershell
godot --headless --path . --script res://scripts/tests/SmokeTest.gd
```

如果 Godot 不在 PATH，就明确说明没有运行，并写清楚做过哪些静态检查。不要把静态检查说成运行验证。

## 文档维护

- 玩法、架构、验证流程有明显变化时，更新 `DEVELOP_LOG.md`。
- 系统边界或数据流变化时，更新 `docs/01_系统设计文档.md`。
- 协作流程变化时，更新 `docs/02_开发协作指南.md` 或本文。
- 测试入口、覆盖范围和手动验证路径变化时，更新 `docs/03_测试与验证.md`。
