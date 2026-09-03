extends Node
var player: CharacterBody2D = null
var torch: Node2D = null
var camera: Camera2D = null
var is_dead = false
var player_hit_cooldown = 0.4
var player_can_be_damaged: bool = true
var extinguish_station: Node2D = null
var campfire: Node2D = null
var inventory: CanvasLayer = null
var left_hand_hud_container: Node = null
var right_hand_hud_container: Node = null
