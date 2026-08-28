@tool
class_name Player
extends CharacterBody2D

signal health_changed(value: int)

enum State {
    IDLE,
    RUNNING,
}

@export var speed: float = 240.0
@onready var sprite: Sprite2D = $Sprite2D
const DISPLAY_NAME := "Player"
var active := true # enabled by default
var label := "Player\nOne"

func move_player(direction: Vector2, delta := 0.0) -> void:
    var velocity := direction.normalized() * speed
    self.velocity = velocity
    move_and_slide()
    health_changed.emit(delta)

var description = """A player
controlled by input."""
