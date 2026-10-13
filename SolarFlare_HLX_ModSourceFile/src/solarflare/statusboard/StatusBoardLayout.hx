package solarflare.statusboard;

/** Keep exact dragged dimensions while wrapping the complete visible status list. */
class StatusBoardLayout {
 public static function textSize(slotSize:Float):Float return Math.max(9,slotSize*0.35);
 public static function timerBand(slotSize:Float,seconds:Bool):Float return seconds ? Math.ceil(textSize(slotSize))+2 : 0;
 public static function size(count:Int,slotSize:Int,columns:Int,unlocked:Bool,width:Float,height:Float,seconds:Bool=false):{width:Float,height:Float,columns:Int} {
  if (width>0) columns=Std.int(Math.max(1,Math.min(columns,Math.floor((width+4)/(slotSize+4)))));
  var cols=Std.int(Math.min(columns,Math.max(1,count)));
  var rows=Std.int(Math.ceil(Math.max(1,count)/cols));
  var w:Float=(unlocked ? columns : cols)*(slotSize+4)-4;
  var h:Float=rows*(slotSize+timerBand(slotSize,seconds)+4)-4;
  if (count == 0) { w=Math.max(200,w); h=40; }
  if (width > 0) w=width;
  if (height > 0) h=Math.max(h,height);
  return {width:w,height:h,columns:cols};
 }
}
