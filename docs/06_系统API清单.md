# 地牢编排师（DNTB）系统 API 清单

这份文档专门回答一个问题：当前分支里新增和被扩展过的系统，外部应该如何正确调用它们。

和 `01_系统设计文档.md` 不同，这里不强调大叙事和架构愿景，而是按 API 视角整理：

- 系统负责什么
- 它维护哪些关键状态
- 外部有哪些主要入口
- 每个入口的输入 / 输出 / 副作用是什么
- 使用时有哪些约束和易错点

当前重点覆盖：

- `ActionProgramController.gd`
- `DirectionalTechniqueResolver.gd`
- `ActionResolver.gd`
- `EnemyPlanner.gd`
- `WorldSliceController.gd`
- `BattleUI.gd`
- `BattleHud.gd`
- `RunSidebar.gd`

## 1. `ActionProgramController.gd`

### 1.1 职责

`ActionProgramController` 是可编程键位层的权威数据源，负责：

- 维护 `QWER / ASDF / ZXCV` 十二个物理键槽
- 维护未分配 token 池 `pool_tokens`
- 校验 token 是否属于当前合法集合
- 提供 save/load 所需的稳定数据格式

它不负责：

- 决定 token 的战斗语义
- 直接解析战斗规则
- 直接执行动作

### 1.2 关键状态

- `key_program`
- `SLOT_ORDER`
- `TOKEN_NAMES`
- `ACTION_TOKENS`
- `TOKEN_DROP_POOL`

### 1.3 主要入口

#### `setup()`

用途：初始化内部 `KeyProgram` 并套用默认 starter preset。

副作用：会重置当前键位程序到默认状态。

#### `reset_default_slots()` / `reset_starter_slots(preset_id)`

用途：重建 starter 键位布局。

当前已知 preset：

- `absolute`
- `relative`

#### `move_token(source_slot_id, source_index, target_slot_id)`

输入：

- 源槽位 id
- 源索引
- 目标槽位 id

输出：

```gdscript
{"moved": bool, "token_id": String}
```

用途：在键槽与 `POOL` 之间移动 token。当前每个键位有 2 个独立栏位、每栏只允许放 1 个 token；从 `POOL` 拖到键槽会消耗 1 个库存。

#### `add_token_to_pool(token_id, allow_duplicates := false)`

输入：

- `token_id`
- 是否允许重复

输出：`bool`

用途：把 token 放进备用池。

当前主链里用它的地方包括：

- 地图 token 自动拾取
- tavern 掌柜首次对话奖励
- 小遗迹调查奖励
- 首杀 `十字刃` 动作奖励

### 1.4 约束

- token 进入 pool，不代表自动分配到物理键位。
- 当前 token 只是基础输入语义，不是整把武器。
- 如果是新的动作 token，必须先加入 `ACTION_TOKENS` 和 `TOKEN_DROP_POOL`，否则 save/load 和 UI 都不会承认它。

## 2. `DirectionalTechniqueResolver.gd`

### 2.1 职责

把用户可见 token 翻译成运行时 `ActionInstance`。

当前它负责的映射包括：

- `U / D / L / R -> move_key`
- `F / B -> move_forward / move_back`
- `SL / SR -> step_left / step_right`
- `DS -> dash`
- `HK -> hook_pull`
- `SB -> shield_bash`
- `HM -> hammer_smash`
- `RA -> spin_axe`
- `PI -> pierce_line`
- `TH -> charge_thrust`
- `SW -> great_sweep`
- `BW -> bow_shot`
- `TL / TR -> turn_left / turn_right`
- `A -> attack`
- `CA -> cross_attack`
- `I / G / W / J`

### 2.2 主要入口

#### `setup(actions, direction_move_action)`

用途：注册动作资源表与方向移动动作。

#### `build_plan(token_ids, actor)`

输入：

- token id 数组
- 执行 actor

输出：

- `Array[ActionInstance]`

用途：把键槽 token 链翻译成可执行动作计划。

### 2.3 约束

- `A` 当前固定解析成基础攻击 `attack`。
- `CA` 是额外攻击动作 token，当前直接解析成 `cross_attack`。
- `HK / SB / HM / RA / PI / TH / SW / BW` 都是“一个 token 对应一个具体攻击动作”的直接映射，不走武器切换。
- 这里不处理武器组合技、动作结果事件或伤害规则。

## 3. `ActionResolver.gd`

### 3.1 职责

这是战斗规则执行层，负责把 `ActionInstance` 变成：

- 移动
- 攻击
- 转向
- 防御
- 交互
- 死亡与胜负判断

并负责对接：

- `EffectPipeline`
- presentation frame
- 规则消息

### 3.2 关键事件信号

- `actor_moved`
- `actor_damaged`
- `actor_died`
- `attack_missed`
- `key_picked`
- `rule_message`
- `combat_event_emitted`
- `world_npc_interaction_requested`

### 3.3 主要入口

#### `resolve(action, state)`

主执行入口。

会按 `action.def.kind` 分派到：

- `_resolve_move`
- `_resolve_attack`
- `_resolve_turn`
- `_resolve_guard`
- `_resolve_interact`

#### `on_actor_entered_cell(actor, state)`

用途：处理踩格后的自动拾取。

当前语义：

- 只要玩家踩上 token 掉落格，就自动拾取
- 最终通过 `key_picked` 发回上层，进入 `pool`

### 3.4 已接入的新增动作

- `step_left`
- `step_right`
- `cross_attack`

当前口径：

- `step_left / step_right`
  - 只横移一格
  - 不改变面朝方向
- `cross_attack`
  - 同时覆盖上下左右四个相邻格

### 3.5 约束

- 如果新增复杂动作，优先复用已有移动/换位/击退 helper，不要直接手写 `grid.move_actor()`。
- 自动拾取链当前默认代表 token pickup，不应再混入武器拾取物逻辑。

## 4. `EnemyPlanner.gd`

### 4.1 职责

负责为敌人生成“下一步想做什么”的动作计划，以及危险格预览。

### 4.2 当前已实现 AI 类型

- `static`
- `melee_chaser`
- `line_keeper`

### 4.3 主要入口

#### `make_enemy_actions(state)`

输出：

- 敌人动作数组

#### `preview_enemy_actions(state)`

输出：

- 仅用于 HUD / danger 预览的敌人动作数组

#### `describe_action(action)`

用途：把敌人意图转成可显示字符串。

当前特殊口径：

- `atk <= 0` 的敌人会显示成“靠近，但不会主动造成伤害”

### 4.4 当前新增怪物相关能力

- `wisp`：当前展示名与视觉口径为游光史莱姆（无害）
  - 低威胁怪，`atk = 0`
- `line_warden`：当前展示名与视觉口径为线卫史莱姆
  - 直线压迫怪，使用 `line_keeper`

## 5. `WorldSliceController.gd`

### 5.1 职责

负责 world slice 的运行态建图与刷新，包括：

- 创建地图状态
- 生成 tavern / ruin / challenge 等 POI
- 生成安全区 NPC
- 生成初始敌人和 streamed 敌人
- 重算视野
- 维护 tracked 提示文本

### 5.2 主要入口

#### `create_demo_state_with_progress(seed_value, progress_callback)`

用途：创建 world slice 调试/正式起始状态。

#### `recompute_visibility(state, reason)`

用途：重算 visible / explored。

#### `refresh_streamed_enemies(state, reason)`

用途：动态补怪 / 清怪。

### 5.3 当前新增边界

- 安全区内禁止初始刷怪和 streamed 补怪
- 会维护：
  - `tracked_boss_poi_relative_hint`
  - `tracked_nearest_ruin_relative_hint`
  - `tracked_safe_zone_relative_hint`

### 5.4 约束

- 当前 ruin 是 POI 交互，不是 actor 交互。
- 安全区 tavern footprint 里的可走格默认不允许敌人生成。

## 6. `BattleUI.gd`

### 6.1 职责

负责主战斗 UI、奖励 overlay、world NPC 对话框、以及左下角获得提示框的总装。

### 6.2 主要入口

#### `show_reward(rewards, title_text, body_text)`

用途：显示奖励 / 升级选择弹层。

当前支持：

- 横向奖励卡片
- 卡片上方名称
- 卡片下方描述

#### `update_state(state)`

用途：统一刷新 HUD、获得提示、右下角 sidebar。

### 6.3 左下角获得提示框

当前独立于右下角事件记录。

只显示两类内容：

- 获得动作 token
- 获得永久效果

### 6.4 约束

- 普通事件日志仍走 `state.messages`
- 获得提示框走 `state.feed_messages`
- 不要把普通战斗消息也塞进 feed

## 7. `BattleHud.gd`

### 7.1 职责

左上状态栏，负责显示：

- 生命条
- SAN 条
- XP 条
- 等级 / 经验进度文本
- 房间、回合、敌人数量、敌人意图

### 7.2 主要入口

#### `update_state(state)`

当前会同步刷新：

- `HealthBar`
- `SanBar`
- `XpBar`
- `XpValue`

### 7.3 约束

- XP 条当前只展示进度，不负责升级逻辑本身
- 升级逻辑仍在 `Game.gd`

## 8. `RunSidebar.gd`

### 8.1 职责

右下角辅助交互区，负责：

- 背包按钮
- 菜单按钮
- POI 方向标识
- 调试面板

### 8.2 主要入口

#### `update_state(state)`

会刷新：

- 右下角 POI 标识
- 调试状态文本

#### 方向标识点击信号

- `safe_zone_poi_requested`
- `boss_poi_requested`
- `ruin_poi_requested`

### 8.3 当前方向标识规则

- `最近安全区`
- `Boss遗迹`
- `最近小遗迹`
- 接近 ruin 时升级为：`附近可调查`

### 8.4 约束

- 这里只负责发信号，不直接执行自动跑图。
- 自动跑图主逻辑仍在 `Game.gd`。

## 9. 新增系统间调用关系摘要

### 9.1 Token 获取主链

```text
地图 token / tavern 教学 / ruin 奖励 / 首杀奖励
→ Game._on_key_picked() / 直接 add_token_to_pool()
→ ActionProgramController.pool_tokens
→ BagUI / BattleUI / 获得提示框
```

### 9.2 升级主链

```text
ActionResolver.actor_died
→ Game._on_actor_died()
→ player_xp +1
→ _try_trigger_level_up_reward()
→ BattleUI.show_reward("升级选择")
→ 选择永久增益
→ _apply_reward(add_modifier)
→ _run_modifier_ids / _build_permanent_buffs()
```

### 9.3 world slice 指引主链

```text
WorldSliceController
→ tracked_*_relative_hint
→ RunSidebar 常驻方向标识
→ 点击 POI 标识
→ Game._start_world_autopath()
→ 启动前先检查 `_world_slice_has_visible_enemy()`
→ A* 路径缓存
→ 每次动画周期推进一步
→ 视野内遇敌暂停
```

## 10. 当前最重要的使用规则

1. token 进入 `pool`，不代表自动编排到键槽。
2. 新攻击动作如果是 token，就应接 `ActionProgramController` 和 `DirectionalTechniqueResolver`，不要混成武器拾取逻辑。
3. 获得提示框只显示“获得类反馈”，不要把普通事件日志继续混进去。
4. world slice 方向标识只发意图，自动跑图、交互和奖励处理仍由 `Game.gd` 接管。
5. 升级奖励当前复用普通 reward overlay，但逻辑上已经是独立的 `升级选择` 入口。
