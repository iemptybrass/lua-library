local path, loaded =
((...).."."), {}
return (function ()
  local function tools(name)
    if loaded[name]
      then
        return rawset(getfenv(2), name, loaded[name])
    end
    local ok, mod = pcall(require, path .. name)
    assert(ok, ("error"):format(name, mod))
    loaded[name], getfenv(2)[name] = mod, mod
  end
  rawset(_G, "tools", tools)
  return tools
end)( )