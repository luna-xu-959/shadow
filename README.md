# Shadow Demo (Godot)

## 打开项目（重要）

1. 启动 **Godot 4.4 或更高版本**（Standard 版）
2. 点 **Import**，选择文件夹：
   `D:\Workspace\shadow-demo-godot`
3. **不要**打开里面的 `.godot` 子文件夹
4. 选中 `project.godot` → Import & Edit

## 在编辑器里看到小人和关卡

导入后左侧 **FileSystem** 应出现：

```
res://
├── scenes/
│   ├── main.tscn      ← 双击打开这个
│   └── player/
│       └── player.tscn
├── scripts/
└── icon.svg
```

**必须双击 `scenes/main.tscn`**，3D 视口里才会出现地面、两个小人、太阳和相机。  
若 FileSystem 只有 `icon.svg`：菜单 **Project → Reload Current Project**。

## 运行

- 先打开 `scenes/main.tscn`
- 按 **F5**（或右上角 Play）

| 玩家 | 颜色 | 操作 |
|------|------|------|
| P0 | 蓝身黄头 | WASD |
| P1 | 红身青头 | 方向键 |

## 若仍然闪退

1. 确认 Godot 版本 ≥ 4.4（菜单 **Help → About**）
2. **Project → Reload Current Project**
3. 查看 **Output** 面板红色报错
4. Windows 日志：`%APPDATA%\Godot\app_userdata\shadow-demo-godot\logs\`

常见原因：用了 Godot 3.x、显卡驱动与强制 D3D12（已从项目配置移除）。

## 规则脚本

- `scripts/shadow_rules.gd` — 主光影子判定
- `scripts/game_manager.gd` — 定时检测与胜负
- `scripts/player.gd` — 移动与上色
