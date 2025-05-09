return (function (input)
  local limit = 2^32
  local mask = limit-1
  local function cache(f)
    local mt = {}
    local t = setmetatable({}, mt)
    function mt:__index(k)
      local v = f(k)
      t[k] = v
      return v
    end
    return t
  end
  local function apply(t, m)
    local function bitwise(a, b)
      local res,p = 0,1
      while a ~= 0 and b ~= 0 do
        local am, bm = a % m, b % m
        res = res + t[am][bm] * p
        a = (a - am) / m
        b = (b - bm) / m
        p = p*m
      end
      res = res + (a + b) * p
      return res
    end
    return bitwise
  end
  local function build(t)
    local first = apply(t,2^1)
    local second = cache(function(a)
      return cache(function(b)
        return first(a, b)
      end)
    end)
    return apply(second, 2 ^ (t.n or 1) )
  end
  local xor = build(
    { [0] = {[0] = 0,[1] = 1},
      [1] = {[0] = 1, [1] = 0},
      n = 4 })
  local function xorbit(a, b, c, ...)
    local z = nil
    if b
      then
        a = a % limit
        b = b % limit
        z = xor(a, b)
        if c
          then
            z = xorbit(z, c, ...)
        end
        return z
    end
    if a
      then
        return a % limit
      else
        return 0
    end
  end
  local function andbit(a, b, c, ...)
    local z
    if b
      then
        a = a % limit
        b = b % limit
        z = ( (a + b) - xor(a,b) ) / 2
        if c
          then
            z = andbit(z, c, ...)
        end
        return z
    end
    if a
      then
        return a % limit
      else
        return mask
    end
  end
  local function notbit(x)
    return (-1 - x) % limit
  end
  local function shiftright(a, p)
    if p < 0
      then
        return bit.lshift(a,-p)
    end
    return math.floor(a % 2 ^ 32 / 2 ^ p)
  end
  local function rshift(x, p)
    if p > 31 or p < -31
      then
        return 0
    end
    return shiftright(x % limit, p)
  end
  local function lshift(a, p)
    if p < 0
      then
        return rshift(a,-p)
    end
    return (a * 2 ^ p) % 2 ^ 32
  end
  local function rotatebit(x, p)
    x = x % limit
    p = p % 32
    local low = andbit(x, 2 ^ p - 1)
    return rshift(x, p) + lshift(low, 32 - p)
  end
  local k = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
    0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
    0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
    0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
    0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
    0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2, }
  local function tohex(s)
    return (string.gsub(s, ".", function(c)
      return string.format("%02x", string.byte(c))
    end))
  end
  local function tochunk(l, n)
    local s = ""
    for i = 1, n do
      local rem = l % 256
      s = string.char(rem) .. s
      l = (l - rem) / 256
    end
    return s
  end
  local function fromchunk(s, i)
    local n = 0
    for i = i, i + 3 do n = n*256 + string.byte(s, i) end
    return n
  end
  local function padblock(input, len)
    local extra = 64 - ((len + 9) % 64)
    len = tochunk(8 * len, 8)
    input = input .. "\128" .. string.rep("\0", extra) .. len
    assert(#input % 64 == 0)
    return input
  end
  local function initstate(H)
    H[1] = 0x6a09e667
    H[2] = 0xbb67ae85
    H[3] = 0x3c6ef372
    H[4] = 0xa54ff53a
    H[5] = 0x510e527f
    H[6] = 0x9b05688c
    H[7] = 0x1f83d9ab
    H[8] = 0x5be0cd19
    return H
  end
  local function processblock(input, i, H)
    local w = {}
    for j = 1, 16 do 
      w[j] = fromchunk(input, i + (j - 1)*4)
    end
    for j = 17, 64 do
      local v = w[j - 15]
      local s = xorbit(
                  rotatebit(v, 7),
                  rotatebit(v, 18),
                  rshift(v, 3) )
      v = w[j - 2]
      w[j] = w[j-16] + s + w[j-7] + xorbit(
                                      rotatebit(v, 17),
                                      rotatebit(v, 19),
                                      rshift(v, 10) )
    end
    local a, b, c, d = H[1], H[2], H[3], H[4]
    local e, f, g, h = H[5], H[6], H[7], H[8]
    for i = 1, 64 do
      local s = xorbit(
                  rotatebit(a, 2),
                  rotatebit(a, 13),
                  rotatebit(a, 22) )
      local m = xorbit(
                  andbit(a, b),
                  andbit(a, c),
                  andbit(b, c) )
      local t2 = s + m
      local o = xorbit(
                  rotatebit(e, 6),
                  rotatebit(e, 11),
                  rotatebit(e, 25) )
      local r = xorbit (
                  andbit(e, f),
                  andbit(notbit(e), g) )
      local t1 = h + o + r + k[i] + w[i]
      h, g, f, e, d, c, b, a = g, f, e, d + t1, c, b, a, t1 + t2
    end
    H[1] = andbit(H[1] + a)
    H[2] = andbit(H[2] + b)
    H[3] = andbit(H[3] + c)
    H[4] = andbit(H[4] + d)
    H[5] = andbit(H[5] + e)
    H[6] = andbit(H[6] + f)
    H[7] = andbit(H[7] + g)
    H[8] = andbit(H[8] + h)
  end
  local function sha256(input)
    input = padblock(input, #input)
    local H = initstate({})
    for i = 1, #input, 64 do
      processblock(input, i, H)
    end
    return tohex(
      tochunk(H[1], 4) ..
      tochunk(H[2], 4) ..
      tochunk(H[3], 4) ..
      tochunk(H[4], 4) ..
      tochunk(H[5], 4) ..
      tochunk(H[6], 4) ..
      tochunk(H[7], 4) ..
      tochunk(H[8], 4) )
  end
  return sha256(input)
end)