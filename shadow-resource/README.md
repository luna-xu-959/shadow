# shadow-resource

External art pack for **Shadow Snail / 影噬**. Paths are relative to this folder.

## Directory layout

```
shadow-resource/
├── manifest.json              # Game catalog + UI path registry
├── characters/
│   └── default/
│       ├── model/character_body.fbx
│       └── animations/idle.fbx
├── ui/
│   ├── wardrobe/              # 换装页
│   │   ├── tabs/              # 分类 Tab 图标
│   │   ├── panels/            # 一体面板底图（服装/调色板）
│   │   └── frames/            # 选中/已装备框
│   └── common/                # 通用 UI
│       ├── buttons/
│       └── banners/
└── _archive/original_zips/    # 原始 zip 备份
```

## Asset inventory

### 3D — `characters/default/`

| File | Type | Description |
|------|------|-------------|
| `model/character_body.fbx` | Character mesh | 可 playable 角色模型（原 character1.fbx） |
| `animations/idle.fbx` | Animation | 待机动作（需与模型骨骼匹配） |

### UI — Wardrobe tabs (`ui/wardrobe/tabs/`)

| File | Category |
|------|----------|
| `tab_category_top.png` | 上身 / T恤 |
| `tab_category_bottom.png` | 下身 / 短裤 |
| `tab_category_waist.png` | 腰饰 / 项圈 |
| `tab_category_necklace.png` | 配饰 / 项链 |
| `tab_category_head.png` | 头饰 / 棒球帽 |

### UI — Wardrobe panels (`ui/wardrobe/panels/`)

| File | Description |
|------|-------------|
| `clothing_panel_unified.png` | 服装面板（Tab + 8 格一体底图，左侧用） |
| `palette_panel_unified.png` | 调色板面板（一体底图，右侧用） |
| `panel_frame_empty.png` | 空白铆钉面板（右侧调色板底图） |
| `palette_panel_unified.png` | 带槽位的一体面板（备用） |
| `item_card_vertical.png` | 竖向物品卡片（侧边展示，非主网格槽） |

### UI — Wardrobe frames (`ui/wardrobe/frames/`)

| File | Description |
|------|-------------|
| `frame_selected_gold_check.png` | 金色选中框 + 勾（已装备） |
| `frame_selected_teal_check.png` | 青色选中框 + 勾 |

### UI — Common buttons (`ui/common/buttons/`)

| File | Description |
|------|-------------|
| `btn_back_yellow.png` | 返回（黄色涂鸦） |
| `btn_back_purple.png` | 返回（紫色） |
| `btn_settings_purple.png` | 设置 |
| `btn_settings_purple_alt.png` | 设置（备用样式） |
| `btn_ready_green.png` | READY（绿色横条） |
| `btn_ready_yellow_skull.png` | READY（黄色 + 骷髅） |
| `btn_start_lets_go.png` | LET'S GO! 开始匹配 |

### UI — Common banners (`ui/common/banners/`)

| File | Description |
|------|-------------|
| `banner_title_graffiti.png` | 标题横幅（米色 + 四边涂鸦） |
| `banner_info_purple_teal.png` | 信息条（紫青渐变边框） |

## Original archives

| Archive | Contents |
|---------|----------|
| `wardrobe_ui_pack_a.zip` | 7 PNG — 面板变体、READY 绿、返回紫、设置、选中框青 |
| `wardrobe_ui_pack_b.zip` | 13 PNG — Tab 图标、完整面板、按钮、横幅 |

## Godot usage

Project references this folder via `res://../shadow-resource/` (see `GamePaths.RESOURCE_ROOT` in shadow-snail).

After adding PNG/FBX, open shadow-snail in Godot once so imports generate.
