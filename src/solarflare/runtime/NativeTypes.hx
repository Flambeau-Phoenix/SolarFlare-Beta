package solarflare.runtime;

/** GameLib abstracts do not validate casts. Check the live class before native dispatch. */
class NativeTypes {
    public static function is(value:Dynamic,name:String):Bool {
        if(value==null)return false;
        var t=hl.Type.getDynamic(value);var depth=0;
        while(t!=null&&t.kind==hl.Type.TypeKind.HObj&&depth++<20){if(t.getTypeName()==name)return true;t=t.getSuper();}
        return false;
    }
}
