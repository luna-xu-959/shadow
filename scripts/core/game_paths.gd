class_name GamePaths
extends RefCounted

## Central registry for scenes and scripts. Update paths here when reorganizing assets.

# Scenes
const MAIN_SCENE := "res://scenes/main.tscn"
const PLAYER_SCENE := "res://scenes/characters/player.tscn"
const MULTIPLAYER_MENU_SCENE := "res://scenes/ui/multiplayer_menu.tscn"
const PAUSE_MENU_SCENE := "res://scenes/ui/pause_menu.tscn"

# Core
const TEAM_INFO := "res://scripts/core/team_info.gd"
const SESSION_CONFIG := "res://scripts/core/session_config.gd"
const PLAYER_SLOT := "res://scripts/core/player_slot.gd"
const FACTION := "res://scripts/core/faction.gd"
const SHADOW_RULES := "res://scripts/core/shadow_rules.gd"

# Gameplay
const GAME_MANAGER := "res://scripts/gameplay/game_manager.gd"
const PLAYER_REGISTRY := "res://scripts/gameplay/player_registry.gd"

# Characters
const GODOT_PLUSH_SKIN_SCENE := "res://PlayerCharacter/GodotPlush/godot_plush_skin.tscn"
const PLAYER := "res://scripts/characters/player.gd"
const HUMAN_PRESENCE := "res://scripts/characters/human_presence.gd"
const GHOST_STOMP_CONTROLLER := "res://scripts/characters/ghost_stomp_controller.gd"
const SHADOW_CORE := "res://scripts/characters/shadow_core.gd"

# World
const SUN_CONTROLLER := "res://scripts/world/sun_controller.gd"
const GRASS_GROUND := "res://scripts/world/grass_ground.gd"
const TOWN_BUILDER := "res://scripts/world/town_builder.gd"
const STREET_LAMP := "res://scripts/world/street_lamp.gd"

# Camera / presentation
const PLAYER_FOLLOW_CAMERA := "res://scripts/camera/player_follow_camera.gd"
const SPLIT_SCREEN_SETUP := "res://scripts/camera/split_screen_setup.gd"

# UI
const RESIZABLE_UI_ROOT := "res://scripts/ui/resizable_ui_root.gd"
const MULTIPLAYER_MENU := "res://scripts/ui/multiplayer_menu.gd"
const PAUSE_MENU := "res://scripts/ui/pause_menu.gd"

# Network / bootstrap
const NETWORK_MANAGER := "res://scripts/network/network_manager.gd"
const MAIN := "res://scripts/bootstrap/main.gd"
const INPUT_SETUP := "res://scripts/bootstrap/input_setup.gd"

# Shaders
const SHADOW_CORE_HALO_SHADER := "res://assets/shaders/shadow_core_halo.gdshader"

# Dev verification bundle
const VERIFY_SCRIPTS: Array[String] = [
	SHADOW_CORE,
	HUMAN_PRESENCE,
	GHOST_STOMP_CONTROLLER,
	PLAYER,
	GAME_MANAGER,
	NETWORK_MANAGER,
	MAIN,
	MULTIPLAYER_MENU,
]
