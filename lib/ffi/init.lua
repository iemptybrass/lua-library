local path, modules =
  ( ( ... ) .. "." ),
  { "cwd",
    "dir", }
return ( function ( )
  for _, name in ipairs ( modules ) do
    rawset ( _G, name, require ( path .. name ) )
  end
end ) ( )