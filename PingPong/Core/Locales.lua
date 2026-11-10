---------------------------------------------------------------------------------------
-- PingPong/Core/Locales.lua — CORE — translated texts
--
-- What it does: gives every other file PingPong.L, a table that turns an English text into the
--   client's language. English is the key, so a missing translation (or enUS) shows the key.
-- Architecture: loaded right after Init. Translations are plain tables per client locale.
--   esMX shares the esES texts. Format placeholders (%s) must match the English text, which
--   tests/spec_locales.lua checks.
-- Does not: touch frames or events, or translate the TOC (its Notes-<locale> lines do that).
-- Related: Comms.lua, Hint.lua, tests/spec_locales.lua.
---------------------------------------------------------------------------------------
local _, PingPong = ...

-- Every text the addon shows, in English. Add a text here and in each language below.
PingPong.LocaleKeys = {
  "PingPong: pings can't be shared right now.",
  "PingPong: the map can't be opened from chat during combat.",
  "Too many pings, wait a few seconds",
  "%s pinged the map in %s.",
  "%s pinged the map.",
  "on the map to ping a location for your group",
}

local KEYS = PingPong.LocaleKeys

-- Each list follows the order of LocaleKeys.
local function Texts(...)
  local texts = { ... }
  local strings = {}
  for index, key in ipairs(KEYS) do
    strings[key] = texts[index]
  end
  return strings
end

local Translations = {
  deDE = Texts(
    "PingPong: Pings können gerade nicht geteilt werden.",
    "PingPong: Die Karte kann im Kampf nicht über den Chat geöffnet werden.",
    "Zu viele Pings, bitte ein paar Sekunden warten",
    "%s hat die Karte in %s angepingt.",
    "%s hat die Karte angepingt.",
    "auf die Karte, um einen Ort für deine Gruppe zu pingen"
  ),
  esES = Texts(
    "PingPong: ahora mismo no se pueden compartir pings.",
    "PingPong: no se puede abrir el mapa desde el chat durante el combate.",
    "Demasiados pings, espera unos segundos",
    "%s ha marcado un ping en el mapa de %s.",
    "%s ha marcado un ping en el mapa.",
    "en el mapa para marcar un lugar a tu grupo"
  ),
  frFR = Texts(
    "PingPong : les pings ne peuvent pas être partagés pour le moment.",
    "PingPong : la carte ne peut pas être ouverte depuis le chat en combat.",
    "Trop de pings, attendez quelques secondes",
    "%s a pingé la carte dans %s.",
    "%s a pingé la carte.",
    "sur la carte pour indiquer un lieu à votre groupe"
  ),
  itIT = Texts(
    "PingPong: al momento non è possibile condividere i ping.",
    "PingPong: non è possibile aprire la mappa dalla chat durante il combattimento.",
    "Troppi ping, attendi qualche secondo",
    "%s ha segnalato un punto sulla mappa in %s.",
    "%s ha segnalato un punto sulla mappa.",
    "sulla mappa per segnalare un luogo al tuo gruppo"
  ),
  koKR = Texts(
    "PingPong: 지금은 핑을 공유할 수 없습니다.",
    "PingPong: 전투 중에는 대화창에서 지도를 열 수 없습니다.",
    "핑이 너무 많습니다. 몇 초 후에 다시 시도하세요",
    "%s 님이 %s 지도에 핑을 찍었습니다.",
    "%s 님이 지도에 핑을 찍었습니다.",
    "지도에서 그룹에게 위치를 알립니다"
  ),
  ptBR = Texts(
    "PingPong: não é possível compartilhar pings agora.",
    "PingPong: não é possível abrir o mapa pelo chat durante o combate.",
    "Pings demais, espere alguns segundos",
    "%s pingou o mapa em %s.",
    "%s pingou o mapa.",
    "no mapa para marcar um local para o seu grupo"
  ),
  ruRU = Texts(
    "PingPong: сейчас нельзя делиться пингами.",
    "PingPong: во время боя нельзя открыть карту из чата.",
    "Слишком много пингов, подождите несколько секунд",
    "%s отметил(а) точку на карте: %s.",
    "%s отметил(а) точку на карте.",
    "по карте, чтобы отметить место для вашей группы"
  ),
  zhCN = Texts(
    "PingPong：目前无法分享标记。",
    "PingPong：战斗中无法从聊天框打开地图。",
    "标记过多，请等待几秒钟",
    "%s 在地图 %s 上发出了标记。",
    "%s 在地图上发出了标记。",
    "在地图上为队伍标记一个位置"
  ),
  zhTW = Texts(
    "PingPong：目前無法分享標記。",
    "PingPong：戰鬥中無法從聊天視窗開啟地圖。",
    "標記過多，請等待幾秒鐘",
    "%s 在地圖 %s 上發出了標記。",
    "%s 在地圖上發出了標記。",
    "在地圖上為隊伍標記一個位置"
  ),
}
Translations.esMX = Translations.esES
PingPong.Translations = Translations

-- A table that returns the locale's text for an English key, or the key itself.
function PingPong.NewL(locale)
  local strings = Translations[locale] or {}
  return setmetatable({}, {
    __index = function(_, key)
      return strings[key] or key
    end,
  })
end

PingPong.L = PingPong.NewL(_G.GetLocale())
