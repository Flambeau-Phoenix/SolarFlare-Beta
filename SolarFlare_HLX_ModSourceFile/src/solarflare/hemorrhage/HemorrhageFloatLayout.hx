package solarflare.hemorrhage;

/** Draw-independent placement for a small stack of ascending combat labels. */
class HemorrhageFloatLayout {
	public static function stageHeight(textHeight:Float):Float return 32 + textHeight * 3 + 12;

	/** The whole rise stays inside the panel's reserved, non-interactive text stage. */
	public static function placeInStage(x:Float, y:Float, width:Float, textWidth:Float,
			textHeight:Float, lane:Int, age:Float, lifetime:Float):{x:Float, y:Float, alpha:Float} {
		var p = place(x, y + stageHeight(textHeight) + 8, width, textWidth, textHeight,
			lane, age, lifetime, x + width + 1);
		p.x = x + Math.max(0, (width - textWidth) * 0.5);
		return p;
	}
	public static function place(panelX:Float, panelY:Float, panelWidth:Float,
			textWidth:Float, textHeight:Float, lane:Int, age:Float, lifetime:Float,
			viewportWidth:Float):{x:Float, y:Float, alpha:Float} {
		var progress = Math.max(0, Math.min(1, age / Math.max(0.5, lifetime)));
		var x = panelX + (panelWidth - textWidth) * 0.5;
		x = Math.max(1, Math.min(Math.max(1, viewportWidth - textWidth - 1), x));
		return {
			x: x,
			y: panelY - 8 - textHeight - lane * (textHeight + 6) - 32 * progress,
			alpha: age < 0 || progress >= 1 ? 0 : Math.min(1, (1 - progress) / 0.4)
		};
	}
}
