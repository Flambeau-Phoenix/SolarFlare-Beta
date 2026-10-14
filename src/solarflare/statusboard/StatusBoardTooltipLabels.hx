package solarflare.statusboard;

/** Observer-refreshed UI strings. Drawing never reads Options or native Texts. */
class StatusBoardTooltipLabels {
 public static var locale(default,null):String="en";
 public static var status(default,null):String="Status effect";
 public static var source(default,null):String="Source item";
 public static var loading(default,null):String="Loading description…";
 public static var unavailable(default,null):String="Description unavailable";
 public static var active(default,null):String="Active effect";
 public static var stacks(default,null):String="Stacks";
 public static var remaining(default,null):String="Remaining";
 public static var estimated(default,null):String="Estimated";
 public static var noExpiry(default,null):String="No expiry";
 public static var durationUnavailable(default,null):String="Duration unavailable";
 public static function refresh():Void {
  #if (hl || status_tooltip_native_test)
  var lang="en";
  try { lang=solarflare.ui.ByteUtil.materialize(Options.language); } catch (_:Dynamic) {}
  setLocale(lang);
  #end
 }
 public static function setLocale(lang:String):Void {
  locale=lang == null ? "en" : StringTools.replace(lang.toLowerCase(),"_","-").split("-")[0];
  var words=switch(locale) {
   case "fr": ["Effet de statut","Objet source","Chargement de la description…","Description indisponible","Effet actif"];
   case "de": ["Statuseffekt","Quellgegenstand","Beschreibung wird geladen…","Beschreibung nicht verfügbar","Aktiver Effekt"];
   case "es": ["Efecto de estado","Objeto de origen","Cargando descripción…","Descripción no disponible","Efecto activo"];
   case "pt": ["Efeito de estado","Item de origem","Carregando descrição…","Descrição indisponível","Efeito ativo"];
   case "it": ["Effetto di stato","Oggetto di origine","Caricamento descrizione…","Descrizione non disponibile","Effetto attivo"];
   case "pl": ["Efekt statusu","Przedmiot źródłowy","Wczytywanie opisu…","Opis niedostępny","Aktywny efekt"];
   case "ru": ["Эффект состояния","Исходный предмет","Загрузка описания…","Описание недоступно","Активный эффект"];
   case "ja": ["ステータス効果","効果の発生元アイテム","説明を読み込み中…","説明がありません","有効な効果"];
   case "ko": ["상태 효과","효과를 준 아이템","설명 불러오는 중…","설명 없음","활성 효과"];
   case "zh": ["状态效果","来源物品","正在加载描述…","暂无描述","当前效果"];
   default: ["Status effect","Source item","Loading description…","Description unavailable","Active effect"];
  };
  status=words[0]; source=words[1]; loading=words[2]; unavailable=words[3]; active=words[4];
  words=switch(locale) {
   case "fr": ["Cumuls","Temps restant","Estimation","Sans expiration","Durée indisponible"];
   case "de": ["Stapel","Verbleibend","Geschätzt","Unbegrenzt","Dauer nicht verfügbar"];
   case "es": ["Acumulaciones","Restante","Estimado","Sin caducidad","Duración no disponible"];
   case "pt": ["Acúmulos","Restante","Estimado","Sem expiração","Duração indisponível"];
   case "it": ["Accumuli","Rimanente","Stimato","Senza scadenza","Durata non disponibile"];
   case "pl": ["Ładunki efektu","Pozostało","Szacowane","Bez końca","Czas niedostępny"];
   case "ru": ["Стаки","Осталось","Приблизительно","Бессрочно","Длительность недоступна"];
   case "ja": ["スタック","残り","推定","無期限","持続時間不明"];
   case "ko": ["중첩","남은 시간","예상","만료 없음","지속 시간 알 수 없음"];
   case "zh": ["层数","剩余","预计","永久","持续时间未知"];
   default: ["Stacks","Remaining","Estimated","No expiry","Duration unavailable"];
  };
  stacks=words[0]; remaining=words[1]; estimated=words[2]; noExpiry=words[3]; durationUnavailable=words[4];
 }
}
