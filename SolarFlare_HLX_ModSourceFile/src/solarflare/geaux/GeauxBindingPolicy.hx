package solarflare.geaux;

typedef GeauxBindingLabel = {var primary:String; var secondary:String;};

/** Pure display selection. Custom labels are reminders; they do not register a key. */
class GeauxBindingPolicy {
	public static final MODES=["auto","native","custom","both"];
	public static function clean(mode:String):String return MODES.indexOf(mode)>=0 ? mode : "auto";
	public static function label(mode:String):String return switch(mode) { case "native":"Native"; case "custom":"Custom reminder"; case "both":"Both"; default:"Automatic"; };
	public static function select(mode:String,native:String,custom:String,?out:GeauxBindingLabel):GeauxBindingLabel {
		if(out==null) out={primary:"",secondary:""};
		native=native==null ? "" : native; custom=custom==null ? "" : custom;
		out.primary=""; out.secondary="";
		switch(clean(mode)) {
			case "native":out.primary=native;
			case "custom":out.primary=custom;
			case "both":out.primary=native.length>0 ? "N:"+native : ""; out.secondary=custom.length>0 && custom!=native ? "C:"+custom : "";
			default:out.primary=custom.length>0 ? custom : native;
		}
		if(out.primary.length==0) { out.primary=out.secondary; out.secondary=""; }
		return out;
	}
}
