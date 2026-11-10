-- tests/spec_codec.lua: the addon message format in PingPong/Core/Codec.lua.

return function(check, PingPong)
  local Codec = PingPong.Codec

  check("encode", Codec.Encode(2248, 0.5, 0.25), "1:2248:5000:2500")
  check("encode rounds", Codec.Encode(1, 0.12345, 0), "1:1:1235:0")
  check("encode rejects out of range", Codec.Encode(1, 1.01, 0), nil)
  check("encode rejects a bad map", Codec.Encode(0, 0.5, 0.5), nil)
  check("encode rejects nil", Codec.Encode(nil, 0.5, 0.5), nil)

  local mapID, x, y = Codec.Decode("1:2248:5000:2500")
  check("decode map", mapID, 2248)
  check("decode x", x, 0.5)
  check("decode y", y, 0.25)

  local edgeMap, edgeX, edgeY = Codec.Decode("1:1:0:10000")
  check("decode edge map", edgeMap, 1)
  check("decode edge x", edgeX, 0)
  check("decode edge y", edgeY, 1)

  for _, bad in ipairs({
    "",
    "2:1:1:1",
    "1:0:1:1",
    "1:1:10001:1",
    "1:1:1:10001",
    "1:1:1",
    "1:1:1:1:1",
    "1:a:1:1",
    "1:1:-1:1",
    "1:1:1.5:1",
    "1:1:1:1 ",
    string.rep("1", 40),
  }) do
    check(("decode rejects %q"):format(bad), Codec.Decode(bad), nil)
  end
  check("decode rejects nil", Codec.Decode(nil), nil)
end
