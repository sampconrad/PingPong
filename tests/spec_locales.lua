-- tests/spec_locales.lua: every translation covers every text and keeps its placeholders.

local function Placeholders(text)
  local count = 0
  for _ in text:gmatch("%%s") do
    count = count + 1
  end
  return count
end

return function(check, PingPong)
  local keys = PingPong.LocaleKeys
  check("english keys exist", #keys > 0, true)

  for locale, strings in pairs(PingPong.Translations) do
    for _, key in ipairs(keys) do
      local text = strings[key]
      check(locale .. " has: " .. key, type(text) == "string" and text ~= "", true)
      if type(text) == "string" then
        check(locale .. " placeholders: " .. key, Placeholders(text), Placeholders(key))
      end
    end
  end

  local german = PingPong.NewL("deDE")
  check("a translation is used", german[keys[3]] ~= keys[3], true)
  check("english falls back to the key", PingPong.NewL("enUS")[keys[3]], keys[3])
  check("an unknown locale falls back to the key", PingPong.NewL("xxXX")[keys[3]], keys[3])
  check("an unknown text falls back to the key", german["not a text"], "not a text")
  check("esMX shares esES", PingPong.Translations.esMX, PingPong.Translations.esES)
end
