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
- 启动后会看到联机菜单：
  - **Local Split Screen** — 同一台电脑双人分屏（原有玩法）
  - **Host Game** — 你当 Human（主机）
  - **Join Game** — 你当 Ghost（加入方）

## 互联网联机（Tailscale，免费）

1. 两人各安装 [Tailscale](https://tailscale.com/download/windows) 并登录
2. 主机在 PowerShell 运行：`tailscale ip -4`，把 `100.x.x.x` 发给朋友
3. 主机点 **Host Game**
4. 朋友输入主机 Tailscale IP，点 **Join Game**
5. 默认端口 **8910**（UDP）。若连不上，在主机防火墙放行 UDP 8910

| 角色 | 阵营 | 操作 |
|------|------|------|
| 主机 | Human (P0) | 方向键 / IJKL，U/O 转视角 |
| 加入方 | Ghost (P1) | WASD，Space 跳跃，按住 F / 鼠标左键蓄力踩影 |

## 本地分屏

| 玩家 | 颜色 | 操作 |
|------|------|------|
| P0 | 蓝身黄头 | 方向键 / IJKL |
| P1 | 红身青头 | WASD |

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
