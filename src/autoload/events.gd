## Global signal bus for decoupled game events (UI, audio, achievements, stats).
extends Node

@warning_ignore_start("unused_signal")
signal player_damaged(amount: float)
signal player_healed(amount: float)
signal player_died
signal enemy_killed(enemy: Node, killer: Node)
signal damage_dealt(target: Node, amount: float, crit: bool)
signal perfect_dodge
signal parry_success
signal room_entered(room_id: int)
signal room_cleared(room_id: int)
signal boss_started(boss: Node)
signal boss_defeated(boss: Node)
signal relic_gained(relic_id: String)
signal currency_changed
signal xp_gained(amount: int)
signal level_up(level: int)
signal toast(text: String, color: Color)
signal banner(title: String, subtitle: String)
signal run_ended(result: Dictionary)
signal profile_changed
@warning_ignore_restore("unused_signal")
