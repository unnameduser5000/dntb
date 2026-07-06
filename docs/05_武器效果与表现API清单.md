# 地牢编排师：禁忌之键（DNTB）动作、移动、效果与表现 API 清单

这份清单不再把“武器 hook”单独当主系统，而是按当前真实主链拆成四层来看：

- 动作 API 是否已经形成稳定边界
- 移动 API 是否已经独立可复用
- 效果 API 是否已经足够承载扩展
- 表现层 API 现在能接到什么程度

文档重点是“哪些已经可用，哪些还缺边界，下一步最值得补什么”。

## 1. 总体判断

当前结论可以先压缩成四句话：

- 动作层已经成为武器差异的主承载点。
- 移动系统应该被视为独立 API，而不是只当 `ActionResolver` 的内部细节。
- 效果系统已经形成真正可复用的 API，是当前最成熟的一层。
- 表现层已经有接口，但 payload 和事件协议还偏项目内约定。

建议优先级：

1. 先补动作与移动的统一语义。
2. 再补效果语义缺口。
3. 然后补表现协议。

## 2. 当前已有能力清单

### 2.1 动作系统已有能力

当前动作 API 主入口：

- `scripts/data/ActionDef.gd`
- `scripts/data/WeaponDef.gd`
- `scripts/core/DirectionalTechniqueResolver.gd`
- `scripts/core/ActionResolver.gd`
- `scripts/runtime/ActionInstance.gd`

当前动作层已经明确的边界：

- 可编程 token 先进入 `ActionProgramController.gd`
- `DirectionalTechniqueResolver.gd` 把 token 翻译成 `ActionInstance`
- `A` 当前直接解析成固定的 `attack`
- `ActionResolver.gd` 只负责执行具体动作，不再读取“当前武器”状态

当前推荐模式：

- 基础攻击保留给 `A -> attack`
- 武器风格动作直接做成独立 token
- 如果保留 `WeaponDef` 资源，也只作为内容草稿或展示数据，不进入当前战斗主链

结论：

- 武器差异现在优先写进 `ActionDef`。
- “一个武器风格 token 对应一种具体攻击动作”已经是当前主口径。
- 如果以后要支持更复杂武器，优先扩动作 API，而不是恢复旧武器脚本入口。

### 2.2 移动系统已有能力

当前移动 API 主入口：

- `scripts/core/ActionResolver.gd`
- `scripts/runtime/MovementResult.gd`
- `scripts/runtime/EffectPacket.gd`
- `scripts/runtime/EffectEvent.gd`
- `scripts/runtime/EffectPipeline.gd`
- `scripts/core/ActionPreviewService.gd`

当前已经抽出来的移动能力：

- 基础落格移动：`resolve_move_actor_to_cell()`
- 强制直线位移：`resolve_forced_directional_move()`
- 换位：`resolve_swap_actors()`
- 传送：`resolve_teleport_actor()`
- 对效果层开放的 helper：
  - `apply_effect_move()`
  - `apply_effect_move_to_cell()`
  - `apply_effect_knockback()`
  - `apply_effect_pull()`
  - `apply_effect_swap()`
  - `apply_effect_teleport()`

当前移动结果的统一字段：

- `kind`
- `actor`
- `secondary_actor`
- `from_cell`
- `to_cell`
- `direction`
- `requested_steps`
- `moved_steps`
- `moved`
- `blocked`
- `blocked_reason`
- `target_cell`

当前已经有的移动语义：

- 普通地面移动
- 绝对方向一步移动
- 前进 / 后退
- 跳跃落点移动
- 击退
- 拉拽
- 换位
- 传送

结论：

- 现在已经不该把移动理解成只有 `_resolve_move()` 一条逻辑。
- 后面新武器、新 token、新效果应尽量复用移动 API，而不是各自手写 `grid.move_actor()`。

### 2.3 攻击结果层已有能力

当前攻击结果主入口：

- `scripts/runtime/AttackResult.gd`
- `scripts/core/ActionResolver.gd`

当前已经抽出来的攻击结果字段：

- `actor`
- `action`
- `direction`
- `attempted_cells`
- `hit_targets`
- `hit_cells`
- `damage_packets`
- `total_damage`
- `missed`
- `miss_cell`
- `moved_during_attack`

当前已经接到结果层的攻击路径：

- 普通 `attack`
- `lunge`

结论：

- 攻击现在已经不再完全埋在 `_resolve_attack()` 的临时变量里。
- 但它还没有像 `MovementResult` 一样成为 preview / effect / presentation 共享的公共结果层，这仍是下一步。

### 2.4 效果系统已有能力

当前效果 API 主入口：

- `scripts/runtime/EffectPacket.gd`
- `scripts/runtime/EffectEvent.gd`
- `scripts/runtime/EffectPipeline.gd`
- `scripts/data/EffectModifierDef.gd`

当前 packet 类型：

- `damage`
- `move`
- `pull`
- `knockback`
- `swap`
- `teleport`
- `message`

当前 event 类型：

- `damage_dealt`
- `attack_hit_confirmed`
- `attack_missed_confirmed`
- `actor_killed`
- `actor_moved`
- `move_blocked`
- `knockback_applied`
- `pull_applied`
- `swap_applied`
- `teleport_applied`

当前 modifier 两阶段扩展点：

- `modify_packets()`
- `react_to_event()`

当前已经支持的机制：

- packet 修改、复制、取消
- 事件反应后生成新 packet
- 优先级排序
- `generation_depth` 和 `event_depth` 两套递归保护
- tag、倍率、上下文传递

结论：

- 这层已经是一个真实可用的玩法扩展 API。
- 新增遗物、诅咒、被动、状态衍生效果，优先接这里。

### 2.5 表现层已有能力

当前表现主入口：

- `scripts/core/BattlePresentationController.gd`
- `scripts/core/BattleEffectController.gd`
- `scripts/view/BattleEffect.gd`
- `ActorView` 系列场景与脚本

当前表现事件 / frame：

- `action_started`
- `actor_moved`
- `actor_damaged`
- `attack_missed`
- `move_collision`
- `teleport`
- `swap`
- `actor_died`

当前表现层能力：

- 同步 / 异步播放
- blocking / non-blocking 两套执行模式
- 角色视图动画和格子特效分离
- 世界切片与普通战斗有不同 timing profile
- headless 下可以跳过表现等待

结论：

- 已足够支撑当前近战原型。
- 但如果继续上抓取、背摔、震荡波、瞬步，表现事件会明显不够。

## 3. 缺口清单

### 3.1 动作系统缺口

#### A-1 缺少更明确的“动作语义分类”

现状问题：

- 现在 `ActionDef` 已经同时承载移动、攻击、转向、防御、等待。
- 但“攻击中是否带位移”“攻击后是否换位”“动作是否依赖目标落点”这些差异还主要写在 resolver 分支里。

Checklist：

- [ ] 约定哪些动作是纯攻击、纯移动、攻击附带位移、攻击附带控制。
- [ ] 约定新武器动作优先复用哪些 resolver helper。
- [ ] 明确复杂武器动作是扩 `ActionDef` 字段，还是复用 effect packet 组合。

优先级：高

#### A-2 缺少“每个武器风格 token 一种攻击动作”之上的扩展习惯

现状问题：

- 当前主口径已经够清楚，但后续容易有人重新把特殊规则塞回武器脚本。
- 如果不写清楚，新武器会再次分叉成“有些写动作，有些写武器”。

Checklist：

- [ ] 明确默认规则：新武器风格先配一个独立 token，再接一个具体 `ActionDef`。
- [ ] 明确复杂收益优先写在动作执行路径。
- [ ] 只有当多个 token 共享同一攻击动作时，才讨论更通用的数据层抽象。

优先级：高

#### A-3 缺少统一的动作简介 / tooltip 数据接口

现状问题：

- `ActionDef.gd` 目前只有 `display_name`、`short_name`、`kind`、`range`、`power` 等字段，没有统一 `description`。
- 背包页在 token hover 时需要显示动作简介，当前只能在 UI 层维护本地说明兜底。

Checklist：

- [ ] 给 `ActionDef` 增加统一 `description` 或 `tooltip_text` 字段。
- [ ] 明确基础 token（方向、前进、后退、攻击、防御、等待、跳跃）如何映射到对应动作简介。
- [ ] 让背包 UI 改为直接读取动作数据，而不是继续维护本地 token 说明表。

优先级：中高

### 3.2 移动系统缺口

#### M-1 缺少统一的阻挡原因与 fallback 约定

现状问题：

- 现在已经有 `blocked_reason`，但还没有团队级规则表。
- 背摔、抓取、冲刺、侧移会很快依赖这层。

Checklist：

- [ ] 统一 `blocked_reason` 枚举口径。
- [ ] 明确阻挡于墙、阻挡于单位、落点非法、请求非法的差异。
- [ ] 明确失败时是否发 `move_blocked`、是否产出独立表现 frame。
- [ ] 明确投技 / 拉拽失败时是否允许退化收益。

优先级：最高

#### M-2 预览移动与运行时移动还缺共享规则面

现状问题：

- `ActionPreviewService.gd` 现在是自己重演一套移动判断。
- 规则再复杂一点，预览和运行时就更容易漂。

Checklist：

- [ ] 评估是否抽出共享移动规则 helper。
- [ ] 至少先统一阻挡、换位、跳跃、冲刺停点。
- [ ] 新增复杂位移动作时，必须同时补预览规则。

优先级：高

### 3.3 效果系统缺口

#### E-1 packet 种类需要继续补全

现状问题：

- 当前 `damage / move / knockback / pull / swap / teleport / message` 已经能覆盖不少近战与位移玩法。
- 但状态、破防、抓取标记这类玩法还没有自然入口。

最值得补的新 packet：

- `status_apply`
- `guard_break`

Checklist：

- [ ] 定义 `status_apply` 是否立即生效、如何叠层。
- [ ] 定义 `guard_break` 是 packet 还是攻击结果上的附加字段。
- [ ] 明确新 packet 如何进入表现层。

优先级：高

#### E-2 缺状态类一等公民接口

现状问题：

- modifier 很适合做遗物和被动。
- 但对 `stun`、`bleed`、`mark`、`grabbed` 这种战斗状态，还没有统一数据面。

Checklist：

- [ ] 评估是否需要 `StatusDef` / `StatusInstance`。
- [ ] 明确状态是 actor 本地列表，还是 effect modifier 的另一种来源。
- [ ] 明确状态持续回合、叠层、驱散口径。

优先级：中高

### 3.4 表现层缺口

#### P-1 表现事件协议偏少

现状问题：

- 现在的 frame 事件大多服务于移动、命中、落空、死亡。
- 新武器如果要做抓取、背摔、瞬步，很快会需要更丰富的表现事件。

最值得补的新 frame：

- `throw_start`
- `throw_land`
- `guard_block`
- `status_applied`

Checklist：

- [ ] 先定义 frame kind 名字和 payload 字段。
- [ ] 明确哪些事件挂 actor，哪些挂 cell。
- [ ] 明确是否允许同一 action 产出多段 frame。

优先级：高

#### P-2 frame payload 目前过于松散

现状问题：

- 当前主要靠 `Dictionary` 临时拼字段。
- 原型期够快，但字段名一多就容易漂。

Checklist：

- [ ] 至少先补一份 frame payload 约定表。
- [ ] 常用字段统一：`actor`、`target`、`target_cell`、`direction`、`amount`、`speed`。
- [ ] 后续再考虑是否上独立 runtime data class。

优先级：中

## 4. 最高优先级补强项

如果只允许做一轮小迭代，建议按下面顺序补：

### 第一批：先把动作和移动语义讲清楚

- [ ] 补一份动作类型与移动结果约定表。
- [ ] 明确 `MovementResult` 字段和失败原因口径。
- [ ] 补一套“抓取 / 背摔 / 换位 / 冲刺 / 跳跃”统一规则说明。
- [ ] 明确预览层与运行时共享哪些规则。

原因：

- 这些会直接决定新武器、新 token、新效果是否写得顺。
- 不先补这层，后面每把投技武器和每个复杂位移动作都会写出自己的半私有规则。

### 第二批：补效果语义

- [ ] 新增 `status_apply`
- [ ] 评估 `guard_break`
- [ ] 补状态层数据面

原因：

- 这一步能让后续武器差异更多通过统一效果表达，而不是在 resolver 里散落分支。

### 第三批：补表现协议

- [ ] 新增 `throw_start`
- [ ] 新增 `throw_land`
- [ ] 新增 `guard_block`
- [ ] 整理 frame payload 字段表

原因：

- 当前规则跑通后，最容易拖后腿的是表现层表达力。

## 5. 适合拿来验证 API 的样板玩法

如果要验证这套 API 补完后是不是真的顺手，最适合做下面三类玩法：

### 5.1 背摔

为什么适合：

- 它同时覆盖攻击动作、位移语义、落点阻挡和表现事件。

验收点：

- [ ] 能识别触发方向
- [ ] 能把目标摔到预期落点或换位
- [ ] 落点被挡时有统一 fallback
- [ ] 有单独表现事件，不只靠普通 hit effect

### 5.2 拉拽枪 / 锁链武器

为什么适合：

- 它能逼出 `pull` 与普通位移的语义边界。

验收点：

- [ ] 敌人被拉近时不会误判成普通 knockback
- [ ] 拉到身前后可继续接攻击动作
- [ ] 表现层能看出“拉”而不是“撞”

### 5.3 瞬步匕首

为什么适合：

- 它能验证 `teleport`、侧移语义和高机动表现接口。

验收点：

- [ ] 位移不走普通 grounded move 口径
- [ ] 输入、预览、运行时三层方向解释一致
- [ ] 表现上能看出这是瞬移不是滑步

### 5.4 锁格弓箭怪 + 玩家弓箭

为什么适合：

- 它能一次性验证“目标选择、延迟落点、预警表现、持续移动压力”这几层边界。
- 它很适合检验当前主链能不能承载“不是贴脸格判定”的战斗语义。

验收点：

- [ ] 怪物能锁定玩家当前格，而不是实时追踪玩家新位置。
- [ ] 玩家离开原格后，怪物射击会落空而不是拐弯修正。
- [ ] 玩家弓箭只在合法朝向、范围和阻挡规则下命中最近敌人。
- [ ] 预览与运行时对“最近敌人”的选择口径一致。
- [ ] 第一版不要引入完整 projectile runtime，也不要直接做成无条件必中。

## 6. 一句话结论

现在最不该做的是重新把特殊武器规则拆回独立武器 API。

现在最该做的是：

- 先把动作和移动系统当成明确 API 讲清楚
- 再补 `status_apply` 这类后续效果语义
- 最后把表现 frame 协议补齐

这样后面不管是背摔、投技、链刃、重盾还是瞬步武器，都能沿同一套动作主链往前长，而不是一把武器开一条私路。
