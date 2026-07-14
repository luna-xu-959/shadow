# Shadow Snail

Match-based shadow brawl prototype built in Godot 4.7.

## Project layout

| Path | Role |
|------|------|
| `shadow-snail/` | Game code, scenes, autoloads |
| `shadow-resource/` | External art/audio (`manifest.json` + future assets) |

## UI flow

```
Main Menu
  ├─ Character Select   (pick playable)
  ├─ Cosmetics          (skins + accessories)
  ├─ Host / Join        (ENet UDP 8920)
  ├─ Offline Lobby      (local testing)
  └─ Match Arena        (3D prototype map)
        └─ Results
```

## Controls

### Menus
Mouse + standard UI navigation.

### Match (prototype)
- Move: arrow keys / WASD (`ui_*` actions)
- Jump: Enter / Space (`ui_accept`)
- Leave: Esc

### Lobby
- **Mode**: Duel 1v1, Duo 2v2, Free-For-All (up to 8)
- **Ready**: all required players ready → 3s countdown (online)
- **Start Match**: host/offline manual start

## Online play

1. Host clicks **Host Room** → Lobby
2. Friend clicks **Join Room**, enters host IP (`127.0.0.1` LAN or Tailscale `100.x.x.x`)
3. Both pick loadout, choose mode, ready up
4. Match starts for all peers when countdown finishes or host clicks **Start Match**

Port: **8920/UDP**

## Open in editor

Open `shadow-snail/project.godot` in Godot 4.7+.

Main scene: `scenes/ui/main_menu/main_menu.tscn`

## Next steps

- Import real characters/maps into `shadow-resource/`
- Wire shadow stomp rules from v1 into `MatchManager`
- Per-player cameras for split-screen / online
