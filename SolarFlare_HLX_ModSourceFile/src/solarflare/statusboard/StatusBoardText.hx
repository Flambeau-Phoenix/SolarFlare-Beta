package solarflare.statusboard;

typedef StatusTextRun = {var text:String; var bold:Bool; var color:Null<Int>;}
typedef StatusPositionedText = {var text:String; var bold:Bool; var color:Null<Int>; var x:Float; var y:Float;}

/** Engine text is materialized once, then parsed/wrapped before drawing. */
class StatusBoardText {
 public static function duration(seconds:Float):String {
  if (!Math.isFinite(seconds) || seconds < 0) return "";
  if (seconds >= 3600) return Std.int(Math.floor(seconds/3600))+"h";
  if (seconds >= 60) return Std.int(Math.floor(seconds/60))+"m";
  return Std.int(Math.ceil(seconds))+"s";
 }
 static function entities(s:String):String {
  for (p in [{from:"&lt;",to:"<"},{from:"&gt;",to:">"},{from:"&quot;",to:"\""},{from:"&apos;",to:"'"},{from:"&nbsp;",to:" "},{from:"&amp;",to:"&"}]) s=StringTools.replace(s,p.from,p.to);
  return s;
 }
 public static function parse(markup:String):Array<StatusTextRun> {
  var out:Array<StatusTextRun>=[];
  if (markup == null) return out;
  markup=markup.substr(0,4000);
  var bold=0; var colors:Array<Null<Int>>=[]; var start=0; var i=0;
  function append(text:String):Void {
   if (text.length == 0) return;
   out.push({text:entities(text),bold:bold>0,color:colors.length>0 ? colors[colors.length-1] : null});
  }
  while (i < markup.length) {
   if (markup.charAt(i) != "<") { i++; continue; }
   var end=markup.indexOf(">",i);
   if (end < 0) break;
   append(markup.substring(start,i));
   var raw=markup.substring(i+1,end); var tag=StringTools.trim(raw).toLowerCase();
   if (tag == "b") bold++;
   else if (tag == "/b") bold=Std.int(Math.max(0,bold-1));
   else if (tag == "br" || tag == "br/" || tag == "br /") append("\n");
   else if (StringTools.startsWith(tag,"font")) {
    var hash=raw.indexOf("#"); var color:Null<Int>=null;
    if (hash>=0) {
     var hex=""; var n=hash+1;
     while (n<raw.length && "0123456789abcdefABCDEF".indexOf(raw.charAt(n))>=0) hex+=raw.charAt(n++);
     if (hex.length == 6 || hex.length == 8) {
      var value=Std.parseInt("0x"+hex);
      if (value != null) color=hex.length == 8 ? solarflare.ui.UiCol.fromArgb(value) : solarflare.ui.UiCol.rgb(value);
     }
    }
    colors.push(color);
   } else if (tag == "/font" && colors.length>0) colors.pop();
   i=end+1; start=i;
  }
  append(markup.substr(start)); return out;
 }
 public static function plain(runs:Array<StatusTextRun>):String {
  var text=""; for (r in runs) text+=r.text; return text;
 }
 public static function layout(runs:Array<StatusTextRun>, width:Float, lineHeight:Float, measure:String->Float):{runs:Array<StatusPositionedText>,height:Float} {
  var out:Array<StatusPositionedText>=[]; var x=0.; var y=0.; var space=measure(" ");
  for (run in runs) {
   var word="";
   function flush():Void {
    if (word.length == 0) return;
    var w=measure(word)+(run.bold ? 0.5 : 0);
    if (x>0 && x+w>width) { x=0; y+=lineHeight; }
    if (w<=width) { out.push({text:word,bold:run.bold,color:run.color,x:x,y:y}); x+=w; }
    else {
     var part="";
     for (i in 0...word.length) {
      var next=part+word.charAt(i);
      if (part.length>0 && measure(next)+(run.bold ? 0.5 : 0)>width) {
       out.push({text:part,bold:run.bold,color:run.color,x:0,y:y}); y+=lineHeight; part="";
      }
      part+=word.charAt(i);
     }
     if (part.length>0) { out.push({text:part,bold:run.bold,color:run.color,x:0,y:y}); x=measure(part)+(run.bold ? 0.5 : 0); }
    }
    word="";
   }
   for (i in 0...run.text.length) {
    var c=run.text.charAt(i);
    if (c == "\n") { flush(); x=0; y+=lineHeight; }
    else if (c == " " || c == "\t" || c == "\r") { flush(); if (x>0) x+=space; }
    else word+=c;
   }
   flush();
  }
  return {runs:out,height:out.length == 0 ? 0 : y+lineHeight};
 }
}
