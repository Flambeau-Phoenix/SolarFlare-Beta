package solarflare.util;

/** Fixed storage, chronological reads. No shifting or scanning on insertion. */
class SampleRing {
 public var length(default,null):Int=0;
 public var generation(default,null):Int=0;
 var values:Array<Float>;
 var head=0;
 public function new(capacity:Int) {
  if(capacity<=0) throw "SampleRing requires positive capacity";
  values=[for(i in 0...capacity) 0.0];
 }
 public function push(value:Float):Void {
  values[head]=value; head=(head+1)%values.length;
  if(length<values.length) length++;
  generation++;
 }
 public function at(index:Int):Float {
  if(index<0 || index>=length) throw "SampleRing index out of bounds";
  return values[((length==values.length ? head : 0)+index)%values.length];
 }
 public function copy():Array<Float> return [for(i in 0...length) at(i)];
 public function sumChronological():Float {
  var sum=0.0; for(i in 0...length) sum+=at(i); return sum;
 }
 public function clear():Void { head=0; length=0; generation++; }
}
