# DNTB 武器、效果与表现 API 清单

这份清单的目标不是重复系统设计文档，而是把当前战斗系统里三条最关键的扩展面拆开看清楚：

- 武器系统抽象是否够用
- 效果系统是否已经形成稳定 API
- 特效 / 动画表现层现在能接到什么程度

文档重点是“哪些已经可用，哪些还缺边界，下一步最值得补什么”。

## 1. 总体判断

当前结论可以先压缩成三句话：

- 武器系统已经有清楚的扩展入口，适合继续做新武器和武器技。
- 效果系统已经形成真正可复用的 API，是当前最成熟的一层。
- 表现层已经有战斗动画和特效接口，但还偏“场景专用适配层”，离完整通用框架还有一段距离。

建议优先级：

1. 先补效果语义缺口。
2. 再补武器 hook 粒度。
3. 最后把表现事件协议补完整。

## 2. 当前已有能力清单

### 2.1 武器系统已有能力

当前武器抽象主入口：

- `scripts/data/WeaponDef.gd`
- `scripts/runtime/CombatContext.gd`
- `scripts/core/ActionResolver.gd`
- `scripts/core/TurnController.gd`
- `scripts/data/WeaponTechniqueDef.gd`
- `scripts/core/WeaponComboResolver.gd`

当前武器 hook：

- `resolve_move_collision()`
- `resolve_attack_hit()`
- `resolve_attack_miss()`
- `resolve_action_chain_finished()`

当前已经被抽象出来的上下文信息：

- `direction`
- `speed`
- `damage`
- `source_cell`
- `target_cell`
- `chain_actions`
- 当前 action / source / target / state

当前已经跑通的武器模式：

- 移动撞击型：`ImpactShieldDef`
- 连续同方向移动派生技：`lunge`
- 特定 trace pattern 派生技：`sweep`

结论：

- 做“冲撞、突刺、横扫、追加伤害、命中替换、链尾追加技”已经够用。
- 做“抓取、背摔、换位、位移投技”也能做，但会开始暴露效果语义和表现协议的缺口。

### 2.2 效果系统已有能力

当前效果 API 主入口：

- `scripts/runtime/EffectPacket.gd`
- `scripts/runtime/EffectEvent.gd`
- `scripts/runtime/EffectPipeline.gd`
- `scripts/data/EffectModifierDef.gd`

当前 packet 类型：

- `damage`
- `move`
- `knockback`
- `message`

当前 event 类型：

- `damage_dealt`
- `actor_killed`
- `actor_moved`
- `move_blocked`
- `knockback_applied`

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
- 新增遗物、诅咒、武器词条、被动、连锁伤害都应该优先接这里。

### 2.3 表现层已有能力

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
- `actor_died`

当前表现层能力：

- 同步 / 异步播放
- blocking / non-blocking 两套执行模式
- 角色视图动画和格子特效分离
- 世界切片与普通战斗有不同 timing profile
- headless 下可以跳过表现等待

结论：

- 已足够支撑当前近战原型。
- 但如果继续上抓取、换位、震荡波、投掷、落地冲击，表现事件会明显不够。

## 3. 缺口清单

### 3.1 武器系统缺口

#### W-1 缺更细粒度的 hook

现状问题：

- 现在只有命中前后较粗的几个节点。
- 很多玩法会卡在“想要一个恰好在某个时机发生的规则”，但没有稳定入口。

典型受影响玩法：

- 背摔
- 命中后换位
- 破防追击
- 击杀回身斩
- 受击反打

Checklist：

- [ ] 评估是否新增 `before_attack_hit`
- [ ] 评估是否新增 `after_attack_hit`
- [ ] 评估是否新增 `after_move_resolved`
- [ ] 评估是否新增 `on_actor_killed`
- [ ] 新 hook 必须基于 `CombatContext`，不要让武器直接翻 `GameState`

优先级：高

#### W-2 缺统一的“武器主动产出效果”接口习惯

现状问题：

- 武器现在常直接调用 resolver 的具体 helper。
- 这能工作，但久了会让武器脚本越来越像半个 resolver。

Checklist：

- [ ] 约定武器优先产出 effect，而不是直接改状态
- [ ] 为常用行为沉淀 helper，如“对目标造成伤害并击退”
- [ ] 补一份武器脚本写法约定，区分“可直接 resolver 调用”和“应走 EffectPipeline”

优先级：中高

#### W-3 缺标准化的位移/投技语义

现状问题：

- 冲撞已经有现成模式。
- 但抓取、背摔、拖拽、换位还没有统一规则面。

Checklist：

- [ ] 明确“换位”是否算 move
- [ ] 明确“投掷/摔落”是否触发 `actor_moved`
- [ ] 明确“目标落点被阻挡”时的统一口径
- [ ] 明确“位移技命中失败”是落空、原地打伤害，还是转成 wall slam

优先级：高

### 3.2 效果系统缺口

#### E-1 packet 种类偏少

现状问题：

- 当前 `damage / move / knockback / message` 足够做直线近战原型。
- 但很多高级玩法要么写不自然，要么要在 resolver 里硬编码。

最值得补的新 packet：

- `swap`
- `pull`
- `teleport`
- `status_apply`
- `guard_break`

Checklist：

- [ ] 定义 `swap` 的 source/target/to_cell 语义
- [ ] 定义 `pull` 与 `knockback` 的差异，不要混用
- [ ] 定义 `teleport` 是否绕过阻挡和沿途触发
- [ ] 定义 `status_apply` 是否立即生效、如何叠层

优先级：最高

#### E-2 event 种类不够细

现状问题：

- 现在更多是“结果事件”。
- 对武器技、状态和被动来说，还缺一些战斗语义事件。

最值得补的新 event：

- `attack_hit_confirmed`
- `attack_missed_confirmed`
- `combo_triggered`
- `guard_consumed`
- `swap_applied`
- `status_applied`

Checklist：

- [ ] 区分“damage dealt”与“attack hit confirmed”
- [ ] 区分“攻击没打到”与“打到了但被减成 0”
- [ ] 明确 combo 触发是否发独立事件

优先级：高

#### E-3 缺状态类一等公民接口

现状问题：

- 现在 modifier 很适合做遗物和被动。
- 但对 `stun`、`bleed`、`mark`、`grabbed` 这种战斗状态，还没有统一数据面。

Checklist：

- [ ] 评估是否需要 `StatusDef` / `StatusInstance`
- [ ] 明确状态是 actor 本地列表，还是 effect modifier 的另一种来源
- [ ] 明确状态持续回合、叠层、驱散口径

优先级：中高

### 3.3 表现层缺口

#### P-1 表现事件协议偏少

现状问题：

- 现在的 frame 事件大多服务于“移动、命中、落空、死亡”。
- 新武器如果要做得更有辨识度，很快会需要更丰富的表现事件。

最值得补的新 frame：

- `combo_triggered`
- `throw_start`
- `throw_land`
- `guard_block`
- `teleport`
- `status_applied`

Checklist：

- [ ] 先定义 frame kind 名字和 payload 字段
- [ ] 明确哪些事件挂 actor，哪些挂 cell
- [ ] 明确是否允许同一 action 产出多段 frame

优先级：高

#### P-2 frame payload 目前过于松散

现状问题：

- 当前主要靠 `Dictionary` 临时拼字段。
- 对原型迭代很快，但字段名一多就容易漂。

Checklist：

- [ ] 至少先补一份 frame payload 约定表
- [ ] 常用字段统一：`actor`、`target`、`target_cell`、`direction`、`amount`、`speed`
- [ ] 后续再考虑是否上独立 runtime data class

优先级：中

#### P-3 效果事件还没有直接映射到表现层

现状问题：

- 当前表现 frame 主要是 resolver 手动 append。
- 这意味着新增 packet/event 时，往往还要再人工补一遍表现桥接。

Checklist：

- [ ] 评估是否需要“effect event -> presentation frame”翻译层
- [ ] 至少先让 `swap`、`teleport`、`combo_triggered` 这类高级语义有统一桥接
- [ ] 避免每把武器自己决定表现事件名字

优先级：中高

## 4. 最高优先级补强项

如果只允许做一轮小迭代，建议按下面顺序补：

### 第一批：先补语义，不先补花哨表现

- [ ] 新增 `swap` packet
- [ ] 新增 `pull` packet
- [ ] 新增 `attack_hit_confirmed` event
- [ ] 新增 `combo_triggered` event
- [ ] 补一套“抓取/背摔/换位”统一规则说明

原因：

- 这些会直接决定新武器是否写得顺。
- 不先补这层，后面每把投技武器都会写出一套自己的半私有规则。

### 第二批：补武器扩展边界

- [ ] 新增至少一个更细 hook，建议 `after_attack_hit`
- [ ] 统一武器脚本调用 effect helper 的写法
- [ ] 补一份“什么写武器 hook，什么写 modifier”的边界说明

原因：

- 这一步能让新武器不把 `ActionResolver` 当成杂物箱。

### 第三批：补表现协议

- [ ] 新增 `combo_triggered`
- [ ] 新增 `throw_start`
- [ ] 新增 `throw_land`
- [ ] 整理 frame payload 字段表

原因：

- 做完前两批后，新武器在规则上已经能跑。
- 这时再补表现，收益最高，也更容易对齐规则语义。

## 5. 适合拿来验证 API 的样板玩法

如果要验证这套 API 补完后是不是真的顺手，最适合做下面三类玩法：

### 5.1 背摔

为什么适合：

- 它同时覆盖武器 hook、位移语义、落点阻挡和表现事件。

验收点：

- [ ] 能识别触发条件
- [ ] 能把目标摔到预期落点或换位
- [ ] 落点被挡时有统一 fallback
- [ ] 有单独表现事件，不只靠普通 hit effect

### 5.2 拉拽枪 / 锁链武器

为什么适合：

- 它能逼出 `pull` 与 `knockback` 的语义边界。

验收点：

- [ ] 敌人被拉近时不会误判成普通 knockback
- [ ] 拉到身前后的 follow-up 可继续接 attack / combo
- [ ] 表现层能看出“拉”而不是“撞”

### 5.3 瞬步匕首

为什么适合：

- 它能验证 `teleport`、侧移语义和高机动表现接口。

验收点：

- [ ] 位移不走普通 grounded move 口径
- [ ] Trace / combo 规则有明确设计，不产生语义污染
- [ ] 表现上能看出这是瞬移不是滑步

## 6. 一句话结论

现在最不该做的是继续往单个武器脚本里硬塞特殊判定。

现在最该做的是：

- 先补 `swap / pull / teleport` 这类效果语义
- 再补更细的武器 hook
- 最后把表现 frame 协议补齐

这样后面不管是背摔、投技、链刃、重盾还是瞬步武器，都能沿同一套 API 往前长，而不是一把武器开一条私路。
