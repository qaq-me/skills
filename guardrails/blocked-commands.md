# 默认拦截命令

本文件是 Guardrails skill 的默认拦截清单。Claude Code 和 Codex 安装指南都引用这份清单，避免多处重复维护。

## Git 远端与历史改写

- `git push --force` / `git push -f` / `git push +refspec`（普通 push 和 `--force-with-lease` 不拦截）
- `git push --delete` / `git push origin :branch`
- `git tag -d` / `git tag --delete`
- `git remote rm` / `git remote remove` / `git remote set-url`
- `git filter-repo` / `git filter-branch`
- `git rebase -i` / `git rebase --interactive`
- `git commit --amend`

## Git 本地修改丢弃与本地数据删除

- `git checkout .` / `git checkout -- .`
- `git checkout -f` / `git checkout --force`
- `git restore .`
- `git restore --staged .`
- `git clean -f` / `git clean --force` / `git clean -fd` / `git clean -xdf` 等强制 clean
- `git reset --hard` / `git reset --merge` / `git reset --keep`
- `git branch -D` / `git branch --delete --force`
- `git stash drop` / `git stash clear`
- `git worktree remove --force` / `git worktree remove -f`

## 文件删除与同步删除

- `rm` / `/bin/rm` / `sudo rm` / `command rm`
- PowerShell / Windows 删除命令：`Remove-Item`、`del`、`erase`、`rmdir`、`rd`、`ri`
- `xargs rm`
- `find -delete` / `find -exec rm`
- `rsync --delete` / `rsync --delete-*`

脚本会按命令结构解析，目标是拦截实际要执行的删除命令；普通文本、搜索模式或输出内容中出现 `rm` / `Remove-Item` / `del` 不应触发拦截。

这些命令被拦截时，会提示使用软删除：移动到 `trash/` 目录。

## Docker 持久数据删除

- `docker volume rm`
- `docker volume prune`
- `docker system prune --volumes`
- `docker compose down -v` / `docker compose down --volumes`
- `docker-compose down -v` / `docker-compose down --volumes`

这些命令可能删除数据库、缓存、对象存储或其他服务状态，因此默认拦截。
