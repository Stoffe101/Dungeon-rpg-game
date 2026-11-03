## Balance report: how a Kindled's power grows with gear of each item tier,
## against how much tougher each difficulty tier makes the Undervault.
## godot --headless --path . res://tools/dev/power_report.tscn
extends Node


func _ready() -> void:
	Profile.path = "user://power_report.json"
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	print("tier | enemy hp  dmg | gear(epic L5 at tier): power  offense  defense | time-to-kill  hits-to-die (vs fresh at T1)")
	Profile.data = Profile.fresh()
	var base_off := _offense()
	var base_def := _defense()
	for t in range(1, Difficulty.MAX_TIER + 1):
		# average many random epic loadouts so one lucky roll doesn't skew it
		var off := 0.0
		var df := 0.0
		var pw := 0.0
		var n := 40
		for k in n:
			Profile.data = Profile.fresh()
			for slot in ItemDB.SLOTS:
				var pool: Array = ItemDB.BASES.keys().filter(func(b): return ItemDB.base(b).slot == slot and not ItemDB.is_unique(b) and not ItemDB.base(b).has("set") and not ItemDB.base(b).get("legendary", false))
				Profile.equipped()[slot] = ItemDB.make_item(String(pool[rng.randi_range(0, pool.size() - 1)]), "epic", 5, rng, t)
			off += _offense() / base_off / n
			df += _defense() / base_def / n
			pw += float(Difficulty.power()) / n
		var ttk := Difficulty.hp_mult(t) / off
		var htd := df / Difficulty.damage_mult(t)
		print("%-4s | %5.2f  %5.2f | power %4d  off x%4.2f  def x%4.2f | ttk x%4.2f  htd x%4.2f  suggested %s" % [Difficulty.roman(t), Difficulty.hp_mult(t), Difficulty.damage_mult(t), int(pw), off, df, ttk, htd, Difficulty.roman(Difficulty.recommended_for(int(pw)))])
	get_tree().quit()


func _stats() -> Stats:
	var st := Stats.for_player()
	Profile.apply_gear(st)
	return st


func _offense() -> float:
	var st := _stats()
	var crit := clampf(st.v("crit_chance"), 0.0, 1.0)
	return (1.0 + st.v("melee_damage") + st.v("damage")) * (1.0 + crit * (st.v("crit_mult") - 1.0)) * st.v("attack_speed") * st.v("damage_more")


func _defense() -> float:
	var st := _stats()
	return st.v("max_hp") / maxf(0.2, 1.0 - clampf(st.v("armor"), 0.0, 0.75))
