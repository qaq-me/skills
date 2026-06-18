---
name: git-ignore
description: configure .gitignore
---

# Git Ignore

## 规则

- 如果项目没有 `.gitignore`，将 `assets/gitignore` 复制为项目根目录的 `.gitignore`。
- 如果项目已有 `.gitignore`，读取现有文件，只追加模板中缺失的通用规则块。
- 不删除、不覆盖项目已有规则，如果模板规则与项目已有规则冲突，以项目已有规则为准，跳过冲突项，并在最终说明中简要提醒。
- 项目专有的大文件、数据、模型、实验产物和构建产物等，由项目自己的 `.gitignore` 维护，本 skill 只提供通用模板。

## 模板

`assets/gitignore` 默认包含日常本地状态、AI/tooling 状态、OS/editor 文件、日志、环境变量、依赖、缓存、测试目录、构建产物和临时目录。
