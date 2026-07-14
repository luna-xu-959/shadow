class_name GamePaths
extends RefCounted

## Central scene and script paths for shadow-snail.

const MAIN_MENU_SCENE := "res://scenes/ui/main_menu/main_menu.tscn"
const CHARACTER_SELECT_SCENE := "res://scenes/ui/character_select/character_select.tscn"
const COSMETICS_SCENE := "res://scenes/ui/cosmetics/cosmetics.tscn"
const LOBBY_SCENE := "res://scenes/ui/lobby/lobby.tscn"
const RESULTS_SCENE := "res://scenes/ui/results/results.tscn"
const MATCH_HUD_SCENE := "res://scenes/ui/match/hud.tscn"
const ARENA_DEFAULT_SCENE := "res://scenes/match/arena_default.tscn"
const CHARACTER_PROTOTYPE_PREVIEW_SCENE := "res://scenes/dev/character_prototype_preview.tscn"

const GAME_FLOW := "res://scripts/core/game_flow.gd"
const SESSION_STATE := "res://scripts/core/session_state.gd"
const GAME_MODE := "res://scripts/core/game_mode.gd"
const CHARACTER_CATALOG := "res://scripts/core/character_catalog.gd"
const NETWORK_MANAGER := "res://scripts/network/network_manager.gd"
const LOBBY_SYNC := "res://scripts/network/lobby_sync.gd"

const MAIN_MENU := "res://scripts/ui/main_menu.gd"
const CHARACTER_SELECT := "res://scripts/ui/character_select.gd"
const COSMETICS := "res://scripts/ui/cosmetics.gd"
const LOBBY := "res://scripts/ui/lobby.gd"
const RESULTS := "res://scripts/ui/results.gd"
const MATCH_MANAGER := "res://scripts/match/match_manager.gd"
const ARENA := "res://scripts/match/arena.gd"
const MATCH_PLAYER := "res://scripts/match/match_player.gd"
const MATCH_HUD := "res://scripts/ui/match_hud.gd"

## External art pack (sibling folder to shadow-snail).
const RESOURCE_ROOT := "res://../shadow-resource"
const WARDROBE_BACKGROUND := "%s/background/changing_room.jpg" % RESOURCE_ROOT
const DEFAULT_CHARACTER_MODEL := "res://assets/characters/default/model/character_body.fbx"
const DEFAULT_CHARACTER_MODEL_EXTERNAL := "%s/characters/default/model/character_body.fbx" % RESOURCE_ROOT
const DEFAULT_CHARACTER_IDLE_ANIMATION := "res://assets/characters/default/animations/idle.fbx"
const DEFAULT_CHARACTER_IDLE_ANIMATION_EXTERNAL := "%s/characters/default/animations/idle.fbx" % RESOURCE_ROOT
