@echo off
"C:\Users\Hugues\Documents\GitHub\MOOSE\Utils\luarocks\lua5.1" -e "package.path=\"C:\\Users\\Hugues\\AppData\\Roaming/luarocks/share/lua/5.1/?.lua;C:\\Users\\Hugues\\AppData\\Roaming/luarocks/share/lua/5.1/?/init.lua;C:/Users/Hugues/Documents/GitHub/MOOSE/Utils/luarocks\\systree/share/lua/5.1/?.lua;C:/Users/Hugues/Documents/GitHub/MOOSE/Utils/luarocks\\systree/share/lua/5.1/?/init.lua;C:/Users/Hugues/Documents/GitHub/MOOSE/Utils/luarocks/lua/?.lua;\"..package.path; package.cpath=\"C:\\Users\\Hugues\\AppData\\Roaming/luarocks/lib/lua/5.1/?.dll;C:/Users/Hugues/Documents/GitHub/MOOSE/Utils/luarocks\\systree/lib/lua/5.1/?.dll;\"..package.cpath" -e "local k,l,_=pcall(require,\"luarocks.loader\") _=k and l.add_context(\"luadocumentor\",\"0.1.5-1\")" "C:\Users\Hugues\Documents\GitHub\MOOSE\Utils\luarocks\systree\lib\luarocks\rocks\luadocumentor\0.1.5-1\bin\luadocumentor" %*
exit /b %ERRORLEVEL%
