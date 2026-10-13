package solarflare.barter;

/** One fixed-height row; the child scrolls its complete width rather than wrapping. */
class BarTerNativePickerLayout {
 public static inline var CELL:Int=42;
 public static inline var GAP:Int=4;
 public static inline var PADDING:Int=4;
 public static inline var SCROLLBAR:Int=16;
 public static inline var HEIGHT:Int=CELL+PADDING*2+SCROLLBAR+2;
 public static inline function x(index:Int):Int return index*(CELL+GAP);
 public static inline function width(count:Int):Int return count==0 ? 0 : count*CELL+(count-1)*GAP;
}
