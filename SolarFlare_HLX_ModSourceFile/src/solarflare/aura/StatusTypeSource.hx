package solarflare.aura;

/** Observation-only engine boundary; matches uses engine category/parent semantics. */
interface StatusTypeSource {
 function validOwner(owner:Dynamic,enemy:Bool):Bool;
 function container(owner:Dynamic):Dynamic;
 function length(container:Dynamic):Int;
 function at(container:Dynamic,index:Int):Dynamic;
 /** 1 readable live Status, 0 removed, -1 unreadable metadata or wrong runtime type. */
 function state(application:Dynamic):Int;
 function matches(application:Dynamic,typeId:String):Bool;
}
