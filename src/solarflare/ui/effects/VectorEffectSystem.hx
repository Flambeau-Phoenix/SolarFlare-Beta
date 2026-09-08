package solarflare.ui.effects;

import imgui.ImGui;
import imgui.Structs.ImVec2;

enum EffectType {
	Pulse;
	Ring;
	Spark;
	Particles;
	Beam;
}

typedef EffectParams = {
	var duration:Float;
	var ?startRadius:Float;
	var ?endRadius:Float;
	var ?startColor:Int;
	var ?endColor:Int;
	var ?thickness:Float;
	var ?segments:Int;
	var ?speed:Float;
	var ?gravityX:Float;
	var ?gravityY:Float;
	var ?velocityX:Float;
	var ?velocityY:Float;
	var ?particleCount:Int;
}

class ParticleData {
	public var x:Float;
	public var y:Float;
	public var vx:Float;
	public var vy:Float;
	public var life:Float;
	public var maxLife:Float;
	public var size:Float;
	public var color:Int;

	public function new(x:Float, y:Float, vx:Float, vy:Float, life:Float, size:Float, color:Int) {
		this.x = x;
		this.y = y;
		this.vx = vx;
		this.vy = vy;
		this.life = life;
		this.maxLife = life;
		this.size = size;
		this.color = color;
	}
}

class VectorEffect {
	public var type:EffectType;
	public var x:Float;
	public var y:Float;
	public var life:Float = 1.0;
	public var maxLife:Float = 1.0;
	public var progress:Float = 0;

	public var startRadius:Float = 10;
	public var endRadius:Float = 50;
	public var startColor:Int = 0xFFFFFFFF;
	public var endColor:Int = 0x44FFFFFF;
	public var thickness:Float = 2;
	public var segments:Int = 16;
	public var speed:Float = 1;
	public var gravityX:Float = 0;
	public var gravityY:Float = 0;
	public var velocityX:Float = 0;
	public var velocityY:Float = 0;
	public var particles:Array<ParticleData> = [];

	public function new() {}

	public function init(type:EffectType, x:Float, y:Float, params:EffectParams):Void {
		this.type = type;
		this.x = x;
		this.y = y;
		this.maxLife = params.duration > 0.01 ? params.duration : 1.0;
		this.life = this.maxLife;
		this.progress = 0;
		this.startRadius = params.startRadius != null ? params.startRadius : 10;
		this.endRadius = params.endRadius != null ? params.endRadius : 50;
		this.startColor = params.startColor != null ? params.startColor : 0xFFFFFFFF;
		this.endColor = params.endColor != null ? params.endColor : 0x00FFFFFF;
		this.thickness = params.thickness != null ? params.thickness : 2.0;
		this.segments = params.segments != null ? params.segments : 16;
		this.speed = params.speed != null ? params.speed : 1.0;
		this.gravityX = params.gravityX != null ? params.gravityX : 0;
		this.gravityY = params.gravityY != null ? params.gravityY : 0;
		this.velocityX = params.velocityX != null ? params.velocityX : 0;
		this.velocityY = params.velocityY != null ? params.velocityY : 0;
		this.particles = [];

		if (type == EffectType.Particles) {
			var count = params.particleCount != null ? params.particleCount : 16;
			for (i in 0...count) {
				var angle = Math.random() * Math.PI * 2.0;
				var spd = 40 + Math.random() * 80;
				particles.push(new ParticleData(
					x, y,
					Math.cos(angle) * spd,
					Math.sin(angle) * spd - 30,
					0.4 + Math.random() * 0.4,
					2.5 + Math.random() * 2.5,
					startColor
				));
			}
		}
	}

	public function update(dt:Float):Void {
		life -= dt;
		progress = 1.0 - (life / maxLife);
		if (progress > 1.0) progress = 1.0;

		velocityX += gravityX * dt;
		velocityY += gravityY * dt;
		x += velocityX * dt;
		y += velocityY * dt;

		for (p in particles) {
			p.x += p.vx * dt;
			p.y += p.vy * dt;
			p.vy += 80 * dt;
			p.life -= dt;
		}
	}

	public function isDead():Bool {
		return life <= 0 && particles.length == 0;
	}

	public function draw(dl:Dynamic):Void {
		var currentColor = lerpColor(startColor, endColor, progress);
		var currentRadius = startRadius + (endRadius - startRadius) * progress;

		switch (type) {
			case EffectType.Pulse:
				drawPulse(dl, currentRadius, currentColor);
			case EffectType.Ring:
				drawRing(dl, currentRadius, currentColor);
			case EffectType.Spark:
				drawSpark(dl, currentRadius, currentColor);
			case EffectType.Particles:
				drawParticles(dl);
			case EffectType.Beam:
				drawBeam(dl, currentRadius, currentColor);
		}
	}

	function drawPulse(dl:Dynamic, radius:Float, color:Int):Void {
		var a = (color >> 24) & 0xFF;
		var rgb = color & 0x00FFFFFF;
		for (i in 0...3) {
			var t = (i + 1) / 3.0;
			var r = radius * (0.4 + t * 0.6);
			var alpha = Std.int(a * (1.0 - progress) * 0.7);
			var col = rgb | (alpha << 24);
			ImGui.ImDrawList_AddCircle(dl, ImGui.vec2(x, y), r, col, segments, thickness);
		}
	}

	function drawRing(dl:Dynamic, radius:Float, color:Int):Void {
		ImGui.ImDrawList_AddCircle(dl, ImGui.vec2(x, y), radius, color, segments, thickness);
	}

	function drawSpark(dl:Dynamic, radius:Float, color:Int):Void {
		for (i in 0...8) {
			var angle = (i / 8.0) * Math.PI * 2.0 + progress * 2.0;
			var length = radius * (0.3 + 0.7 * (1.0 - progress));
			var x1 = x + Math.cos(angle) * radius * 0.1;
			var y1 = y + Math.sin(angle) * radius * 0.1;
			var x2 = x + Math.cos(angle) * length;
			var y2 = y + Math.sin(angle) * length;
			var alpha = Std.int(255 * (1.0 - progress));
			var col = (color & 0x00FFFFFF) | (alpha << 24);
			ImGui.ImDrawList_AddLine(dl, ImGui.vec2(x1, y1), ImGui.vec2(x2, y2), col, thickness);
		}
	}

	function drawParticles(dl:Dynamic):Void {
		for (p in particles) {
			if (p.life <= 0) continue;
			var alpha = Std.int(((startColor >> 24) & 0xFF) * (p.life / p.maxLife));
			var col = (startColor & 0x00FFFFFF) | (alpha << 24);
			var sz = p.size * (p.life / p.maxLife);
			ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(p.x, p.y), sz, col, 6);
		}
	}

	function drawBeam(dl:Dynamic, radius:Float, color:Int):Void {
		var angle = progress * Math.PI * 2.0;
		var endX = x + Math.cos(angle) * radius * 2.0;
		var endY = y + Math.sin(angle) * radius * 2.0;
		var alpha = Std.int(255 * (1.0 - progress));
		var col = (color & 0x00FFFFFF) | (alpha << 24);
		ImGui.ImDrawList_AddLine(dl, ImGui.vec2(x, y), ImGui.vec2(endX, endY), col, thickness * 2.0);
	}

	static function lerpColor(c1:Int, c2:Int, t:Float):Int {
		var a1 = (c1 >> 24) & 0xFF;
		var r1 = (c1 >> 16) & 0xFF;
		var g1 = (c1 >> 8) & 0xFF;
		var b1 = c1 & 0xFF;
		var a2 = (c2 >> 24) & 0xFF;
		var r2 = (c2 >> 16) & 0xFF;
		var g2 = (c2 >> 8) & 0xFF;
		var b2 = c2 & 0xFF;
		return (Std.int(a1 + (a2 - a1) * t) << 24) |
			   (Std.int(r1 + (r2 - r1) * t) << 16) |
			   (Std.int(g1 + (g2 - g1) * t) << 8) |
			   Std.int(b1 + (b2 - b1) * t);
	}
}

/**
 * Universal Vector Effect System manager with object pooling and draw list dispatch.
 */
class VectorEffectSystem {
	static var effects:Array<VectorEffect> = [];
	static var pool:Array<VectorEffect> = [];
	static var lastStamp:Float = 0;

	public static function create(type:EffectType, x:Float, y:Float, params:EffectParams):VectorEffect {
		var e = pool.length > 0 ? pool.pop() : new VectorEffect();
		e.init(type, x, y, params);
		effects.push(e);
		return e;
	}

	public static function update(dt:Float):Void {
		var i = 0;
		while (i < effects.length) {
			var e = effects[i];
			e.update(dt);
			if (e.isDead()) {
				pool.push(e);
				effects.splice(i, 1);
			} else {
				i++;
			}
		}
	}

	public static function draw(dl:Dynamic):Void {
		for (e in effects) {
			e.draw(dl);
		}
	}

	public static function clear():Void {
		while (effects.length > 0)
			pool.push(effects.pop());
	}
}
