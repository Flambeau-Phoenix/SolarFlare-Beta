package solarflare.statusboard;

/** Keep exact dragged dimensions while wrapping the complete visible status list. */
class StatusBoardLayout {
 public static function size(count:Int,slotSize:Int,columns:Int,unlocked:Bool,width:Float,height:Float):{width:Float,height:Float,columns:Int} {
  var cols=Std.int(Math.min(columns,Math.max(1,count)));
  var rows=Std.int(Math.ceil(Math.max(1,count)/cols));
  var w:Float=(unlocked ? columns : cols)*(slotSize+4)-4;
  var h:Float=rows*(slotSize+4)-4;
  if (count == 0) { w=Math.max(200,w); h=40; }
  if (width > 0) w=width;
  if (height > 0) h=Math.max(h,height);
  return {width:w,height:h,columns:cols};
 }
}
