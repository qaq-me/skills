---
name: paper-analyze-for-human
description: pafh
argument-hint: [论文文件夹路径]
---

## 概述

本skill根据论文的类型加载对应的prompt进行分析。



## 执行流程

- 用户输入：论文文件夹路径，每个论文文件夹中有2个文件，1个子文件夹（通常为images），2个文件是1篇论文的md格式和pdf格式，子文件夹保存md格式的论文中引用的图像。
- 接收用户输入，确认论文md、pdf、图片文件夹的位置，确认输出目录和输出文件名。
  - 输出目录：由用户指定（未指定时你主动询问）
  - 输出文件夹：`summary_human_[论文原文件名，不包括扩展]`，文件夹中包含一个`summary_human_[论文原文件名，不包括扩展].md` 文件以及一个assets文件夹，如果md文件中需要原来images文件夹中的图片，则把图片复制到assets中，使用相对路径引用assets中的图片，不要直接引用images中的图片。
- 读取md文件论文、md文件中引用的所有图片（图片在images子文件夹中，md中未引用的无需读取），在md文件出现公式缺失/渲染错误、图片损坏、表格或关键数据丢失、章节内容明显不完整等情况时读取pdf补充信息，默认不读取pdf。
- 判断论文类型，判断是数据集论文（主要工作是提出新数据集）、方法论文（主要工作是提出新方法）、混合论文（既提出新数据集，也提出新方法，注意很多数据集论文会在很多已有方法上进行实验但没有提出新方法，这仍然属于数据集论文）。
- 根据论文类型加载prompt，根据要求生成`summary_human_[论文原文件名，不包括扩展].md`，数据集论文根据[prompt_dataset.md](prompt_dataset.md) ；方法论文根据[prompt_method.md](prompt_method.md)，混合类型论文根据[prompt_mixed.md](prompt_mixed.md) 。
- 报告结果。