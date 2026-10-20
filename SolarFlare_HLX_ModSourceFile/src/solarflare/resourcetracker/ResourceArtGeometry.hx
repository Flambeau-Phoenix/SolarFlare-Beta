package solarflare.resourcetracker;

/** Pure fill clipping shared by every resource skin. The PNG keeps its full dimensions. */
class ResourceArtGeometry {
	public static inline function fraction(n:Float):Float return Math.isFinite(n) ? Math.max(0,Math.min(1,n)) : 0;
	public static function clip(x:Float,y:Float,w:Float,h:Float,p:Float,direction:Int,?out:{x:Float,y:Float,w:Float,h:Float}):{x:Float,y:Float,w:Float,h:Float} {
		p=fraction(p);
		if(out==null) out={x:0,y:0,w:0,h:0};
		out.x=x; out.y=y; out.w=w; out.h=h;
		switch(direction) {
			case 1: out.x=x+w*(1-p); out.w=w*p;
			case 2: out.y=y+h*(1-p); out.h=h*p;
			case 3: out.h=h*p;
			default: out.w=w*p;
		}
		return out;
	}
}
