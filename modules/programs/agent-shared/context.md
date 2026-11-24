# Global instructions

## Commands

Commands already start in the workspace. Never `cd` into the current directory; use the tool's cwd or directory option for another directory.

Write every command or script the user runs himself in fish, his login shell. Your own tool calls stay in their shell.

## Git

Before any Git mutation, load `git-conventions` and agree ownership; read-only work needs none.
