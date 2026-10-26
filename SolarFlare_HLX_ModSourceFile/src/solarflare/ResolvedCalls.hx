package solarflare;

import hlx.runtime.ResolvedMember;

/** Synchronous native arguments, pooled by nesting depth and cleared on every exit. */
class ResolvedCalls {
 static var onePool:Array<Array<Dynamic>> = [];
 static var twoPool:Array<Array<Dynamic>> = [];
 static var oneDepth = 0;
 static var twoDepth = 0;

 public static function one(member:ResolvedMember, receiver:Dynamic):Dynamic {
  if (member == null) return null;
  var index = oneDepth++;
  if (index == onePool.length) onePool.push([null]);
  var args = onePool[index]; args[0] = receiver;
  var result:Dynamic;
  try result = HlxRuntime.callResolved(member, args)
  catch (error:Dynamic) { args[0] = null; oneDepth--; throw error; }
  args[0] = null; oneDepth--;
  return result;
 }

 public static function two(member:ResolvedMember, receiver:Dynamic, value:Dynamic):Dynamic {
  if (member == null) return null;
  var index = twoDepth++;
  if (index == twoPool.length) twoPool.push([null, null]);
  var args = twoPool[index]; args[0] = receiver; args[1] = value;
  var result:Dynamic;
  try result = HlxRuntime.callResolved(member, args)
  catch (error:Dynamic) { args[0] = null; args[1] = null; twoDepth--; throw error; }
  args[0] = null; args[1] = null; twoDepth--;
  return result;
 }
}
