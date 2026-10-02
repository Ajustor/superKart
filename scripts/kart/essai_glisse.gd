class_name EssaiGlisse
extends RefCounted

## Un joueur au clavier (gauche, rien, droite) dérape sur un cercle de rayon
## donné, au milieu d'une route de 18 m : tient-il la glisse jusqu'au palier
## voulu sans toucher un mur ? Rien que le moteur du kart, sans physique ni
## circuit : de quoi régler la glisse et la garder réglée (voir
## tests/test_glisse.gd et tools/essai_glisse.gd).
##
## Le joueur fait ce que fait un joueur : une pichenette du côté voulu pendant
## le bond, puis il serre ou contre-braque selon qu'il s'écarte du milieu et
## selon qu'il s'en éloigne ou s'en rapproche.

## Demi-largeur de route, moins la moitié d'un kart.
const BORD := 8.0


## Rend {palier, temps, ecart_max, mur} : `mur` vrai si la glisse a touché le
## bord avant d'atteindre `palier_voulu`.
static func tenir(stats: KartStats, rayon: float, palier_voulu: int = 3, duree_max: float = 12.0) -> Dictionary:
	var m := KartMotor.new(stats)
	m.speed = stats.max_speed
	# Départ en (R, 0), tangent au cercle, et le virage est à gauche.
	var pos := Vector2(rayon, 0.0)
	var cmd := KartCommand.new()
	var dt := 1.0 / 60.0
	var t := 0.0
	var ecart_max := 0.0
	while t < duree_max:
		cmd.clear()
		cmd.throttle = 1.0
		cmd.drift = true
		var ecart := pos.length() - rayon
		var avant := Vector2(sin(m.velocity_dir), -cos(m.velocity_dir))
		var radial := avant.dot(pos.normalized())
		if m.state != KartMotor.State.DRIFT:
			cmd.steer = -1.0 if t < 0.08 else 0.0
		else:
			var u := ecart * 0.25 + radial * 6.0
			cmd.steer = -1.0 if u > 0.35 else (1.0 if u < -0.35 else 0.0)
		m.step(cmd, dt)
		avant = Vector2(sin(m.velocity_dir), -cos(m.velocity_dir))
		pos += avant * m.speed * dt
		t += dt
		if m.state == KartMotor.State.DRIFT:
			ecart_max = maxf(ecart_max, absf(pos.length() - rayon))
			var palier := m.tier_for_charge(m.drift_charge)
			if ecart_max > BORD:
				return {palier = palier, temps = t, ecart_max = ecart_max, mur = true}
			if palier >= palier_voulu:
				return {palier = palier, temps = t, ecart_max = ecart_max, mur = false}
	return {palier = m.tier_for_charge(m.drift_charge), temps = t, ecart_max = ecart_max, mur = false}
