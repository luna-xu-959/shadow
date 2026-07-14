# Shadow

Godot shadow gameplay monorepo: early demo at repo root, wardrobe prototype in `shadow-snail/`.

## Projects

| Path | Description | Open with Godot |
|------|-------------|-----------------|
| `/` (repo root) | Human vs Ghost demo + multiplayer | `project.godot` |
| `shadow-snail/` | 影噬 v2：菜单、角色选择、外观装扮 | `shadow-snail/project.godot` |
| `shadow-resource/` | Shared art pack used by `shadow-snail` (sibling folder) | — (not a Godot project) |

Remote: [luna-xu-959/shadow](https://github.com/luna-xu-959/shadow)

---

## shadow-snail（当前主开发）

1. 启动 **Godot 4.7+**（Standard）
2. **Import** → 选择仓库里的 `shadow-snail/` 文件夹（含 `project.godot`）
3. 保持 `shadow-resource/` 与 `shadow-snail/` 为**同级目录**（脚本通过 `res://../shadow-resource` 读取）
4. 运行后从主菜单进入**外观装扮**；独立预览角色原型可打开 `scenes/dev/character_prototype_preview.tscn`（F6）

---

## 根目录 Demo（旧版玩法）

1. 启动 **Godot 4.4+**
2. **Import** → 选择本仓库**根目录**的 `project.godot`
3. 双击打开 `scenes/main.tscn`，按 **F5** 运行

联机：

- **Local Split Screen** — 本机双人分屏
- **Host Game** / **Join Game** — 推荐配合 Tailscale；默认 UDP **8910**

| 角色 | 阵营 | 操作 |
|------|------|------|
| 主机 | Human (P0) | 方向键 / IJKL，U/O 转视角 |
| 加入方 | Ghost (P1) | WASD，Space 跳跃，按住 F / 鼠标左键蓄力踩影 |

本地分屏：P0 蓝身黄头（方向键），P1 红身青头（WASD）。

---

## Notes

- 不要提交 `.godot/`、`Saved/` 或本机大体积第三方 Art/Unity/Unreal 包
- 角色 FBX：`shadow-resource/characters/default/model/character_body.fbx`，idle：`.../animations/idle.fbx`
