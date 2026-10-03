package solarflare.extrabars;

class ExtraBarsLayout {
 public static inline var GAP:Int = 4;
 public static inline var CAPTION:Int = 22;
 public static function valid(count:Int, columns:Int):Bool return count >= 1 && count <= 10 && columns >= 1 && columns <= count;
 public static function rows(count:Int, columns:Int):Int return valid(count,columns) ? Std.int(Math.ceil(count / columns)) : 0;
 public static function width(columns:Int, pixels:Int):Int return columns * pixels + (columns-1)*GAP;
 public static function height(count:Int, columns:Int, pixels:Int):Int return rows(count,columns)*pixels + (rows(count,columns)-1)*GAP + CAPTION;
 public static function resized(count:Int, columns:Int, width:Float, height:Float):Int {
  var r = rows(count,columns);
  if (r == 0) return 48;
  return Std.int(Math.max(24,Math.min(96,Math.min((width-(columns-1)*GAP)/columns,(height-CAPTION-(r-1)*GAP)/r))));
 }
}
