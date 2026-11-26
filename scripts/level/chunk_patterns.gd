class_name ChunkPatterns extends RefCounted
## Os 8 formatos de trecho da fase. Cada padrão devolve a lista de segmentos (plataformas)
## e onde o cursor terminou, para o próximo trecho continuar dali.

const C = preload("res://scripts/level/level_config.gd")

var rng: RandomNumberGenerator

func _init(random: RandomNumberGenerator) -> void:
	rng = random

## Limita a altura para que a próxima plataforma seja alcançável com um pulo.
func clamp_reachable_y(prev_y: int, candidate_y: int) -> int:
	var min_allowed_y := maxi(prev_y - C.MAX_UPWARD_STEP, C.MIN_PLATFORM_Y)
	return clampi(candidate_y, min_allowed_y, C.MAX_PLATFORM_Y)

func random_gap(extra: int = 0) -> int:
	return rng.randi_range(C.MIN_GAP_TILES + extra, C.MAX_GAP_TILES + extra)

static func segment(x_start: int, width: int, y_top: int, depth: int, allow_enemy: bool, diff: float, force_powerup: bool = false) -> Dictionary:
	return {
		"x_start": x_start,
		"x_end": x_start + width - 1,
		"y_top": y_top,
		"depth": depth,
		"allow_enemy": allow_enemy,
		"diff": diff,
		"force_powerup": force_powerup,
	}

## Retorna { "segments": Array[Dictionary], "end_x": int, "end_y": int }.
func build(pattern_id: int, cursor_x: int, cur_y: int, diff: float) -> Dictionary:
	var segments: Array[Dictionary] = []

	match pattern_id:
		0: # Plataforma longa
			var w := rng.randi_range(8, 10)
			segments.append(segment(cursor_x, w, cur_y, 3, true, diff))
			cursor_x += w - 1
		1: # Duas plataformas subindo
			segments.append(segment(cursor_x, 5, cur_y, 2, false, 0.0))
			cursor_x += 5 + random_gap()
			cur_y = clamp_reachable_y(cur_y, cur_y - 1)
			segments.append(segment(cursor_x, 6, cur_y, 2, true, diff))
			cursor_x += 5
		2: # Base + plataforma alta com power-up
			var base_y := clamp_reachable_y(cur_y, cur_y + 1)
			segments.append(segment(cursor_x, 6, base_y, 3, true, diff))
			cursor_x += 6 + random_gap()
			var high_y := clamp_reachable_y(base_y, base_y - 2)
			segments.append(segment(cursor_x, 5, high_y, 1, false, 0.0, true))
			cursor_x += 4
			cur_y = high_y
		3: # Escada de 3 degraus
			var step_y := clamp_reachable_y(cur_y, cur_y + 1)
			for s in range(3):
				var depth := 2 if s == 0 else 1
				segments.append(segment(cursor_x, 5, step_y, depth, s == 2, diff))
				if s < 2:
					cursor_x += 5 + random_gap()
					step_y = clamp_reachable_y(step_y, step_y - rng.randi_range(1, 2))
				else:
					cursor_x += 4
			cur_y = step_y
		4: # Alta fina seguida de descida larga
			var high_y := clamp_reachable_y(cur_y, cur_y - 1)
			segments.append(segment(cursor_x, 5, high_y, 1, false, 0.0))
			cursor_x += 5 + random_gap(1)
			var low_y := clamp_reachable_y(high_y, high_y + 2)
			segments.append(segment(cursor_x, 8, low_y, 3, true, diff))
			cursor_x += 7
			cur_y = low_y
		5: # Duas finas, a segunda com power-up
			segments.append(segment(cursor_x, 5, cur_y, 1, false, 0.0))
			cursor_x += 5 + random_gap()
			var next_y := clamp_reachable_y(cur_y, cur_y + rng.randi_range(-1, 1))
			segments.append(segment(cursor_x, 6, next_y, 1, false, 0.0, true))
			cursor_x += 5
			cur_y = next_y
		6: # Duas médias com variação de altura
			segments.append(segment(cursor_x, 6, cur_y, 2, true, diff))
			cursor_x += 6 + random_gap()
			var right_y := clamp_reachable_y(cur_y, cur_y + rng.randi_range(-1, 2))
			segments.append(segment(cursor_x, 6, right_y, 2, false, 0.0))
			cursor_x += 5
			cur_y = right_y
		_: # Corrida reta
			segments.append(segment(cursor_x, 10, cur_y, 3, true, diff))
			cursor_x += 9

	return {"segments": segments, "end_x": cursor_x, "end_y": cur_y}
