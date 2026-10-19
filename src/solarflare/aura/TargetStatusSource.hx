package solarflare.aura;

import solarflare.aura.signal.StatusSignalSnap;

/** Observation boundary. Only this source and its observer retain engine references. */
interface TargetStatusSource {
 function isEnemy(target:Dynamic):Bool;
 function alive(target:Dynamic):Bool;
 function container(target:Dynamic):Dynamic;
 function length(container:Dynamic):Int;
 function at(container:Dynamic,index:Int):Dynamic;
 /** 1 live application, 0 removed, -1 unreadable. */
 function read(application:Dynamic,out:StatusSignalSnap):Int;
}
