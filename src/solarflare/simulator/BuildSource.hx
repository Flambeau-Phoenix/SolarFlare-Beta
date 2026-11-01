package solarflare.simulator;

import solarflare.simulator.BuildTypes.BuildSnapshot;

/** Engine boundary; a capture is advanced only after an explicit request. */
interface BuildSource {
    function begin(identity:Int,profileGeneration:Int):Void;
    function advance(units:Int):Bool;
    function take():BuildSnapshot;
    function reset():Void;
}
