package solarflare.lfg;

/** Channel names are the game's existing enum constructors. */
class ChannelPolicy {
    public static final names = ["All", "Local", "Player", "Group", "AllSystem", "System"];
    public static function known(name:String):Bool return names.indexOf(name)>=0;
    public static function enabled(c:Config,name:String):Bool return known(name)&&c.monitoredChannels.indexOf(name)>=0;
}
