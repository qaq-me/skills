# 知识同步矩阵

遇到不确定“这次改动要同步到哪一层”时，按本表判断。核心原则：读者不同，文件职责不同；能在项目文档中就地更新的内容，不要沉到 memory 里变成长期噪音。

## 正向同步

| 本次变化               | `README.md` / 子目录 README | `CLAUDE.md` / `AGENTS.md` | `docs/`                           | memory    |
| ------------------ | ------------------------ | ------------------------- | --------------------------------- | --------- |
| 正式/长期新项目开始创建文件     | 建根 README，说明项目定位和开始方式    | 建项目 agent 入口和项目根目录导航      | 按需创建                              | 不需要       |
| 一级目录增删改名           | 更新根 README 或项目根目录导航      | 更新项目根目录导航                 | 若 docs 索引受影响则更新                   | 通常不需要     |
| 子目录形成独立职责          | 增/改该目录 README            | 项目根目录导航指向该 README         | 若属 docs 子目录则更新 `docs/README.md`   | 通常不需要     |
| 代码/实验运行方式变化        | 代码目录 README 补运行/测试/产物入口  | 只写项目特有红线或事实来源             | runbook/commands/validation 按职责更新 | 若是反复踩坑才记录 |
| 新增 API / CLI / 配置项 | README 只放入口或快速示例         | 写 agent 必须遵守的边界           | integration/design/runbook 详细写    | 稳定踩坑可记录   |
| 阶段设计变化             | README 不写长设计             | 写事实来源和阶段入口                | design/roadmap/review gate 更新     | 只记录长期原则   |
| 验收标准或指标口径变化        | README 只给入口              | 写 agent 查哪个 gate/metrics  | review_gates/metrics 更新           | 只记录跨阶段经验  |
| 环境或部署方式变化          | README 只给快速入口            | 写本项目特殊环境红线                | env/runbook 更新                    | 反复踩坑可记录   |
| 跨项目偏好或长期工作方式       | 通常不写                     | 通常不写                      | 通常不写                              | 适合记录      |

## 反向清理

| 反模式                                         | 处理                                   |
| ------------------------------------------- | ------------------------------------ |
| `CLAUDE.md` / `AGENTS.md` 顶部堆“某天某功能上线”的历史叙事 | 删除或迁到 changelog / docs；项目入口只留当前规则和入口 |
| agent 入口复制 docs 的长设计、长命令、长指标表               | 删短，改成指向对应 README / docs              |
| memory 里保存实时阶段状态、旧路径、旧命令                    | 回 repo 验证；过期则修正、压缩成指针或删除             |
| README 写成内部 agent 指令                        | 移到项目 agent 入口或全局配置                   |
| docs 里混写设计、命令、验收、实时进度                       | 按职责拆分，至少用标题和索引分清                     |

## `docs/` 推荐职责

`docs/` 不强制统一目录名，但启用后必须职责清楚。常见分层：

- 设计：`architecture.md`、`designs/`、`stage_designs/`。
- 运行：`runbook.md`、`commands/`、`stage_commands/`。
- 验收：`validation/`、`review_gates/`。
- 资料：`references/`、`metrics/`、`data/`。
- 环境：`env/`。
- 路线：`ROADMAP.md`。
- 经验：`LESSONS.md`，只放跨阶段可复用经验，不放实时状态。

项目可以按自身类型命名；`docs-manager` 只要求职责不要混。
