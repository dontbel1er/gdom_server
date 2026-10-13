@echo off
title Garry's Mod Server - Minigames Hub

echo Запуск сервера Garry's Mod с режимом Minigames Hub...
echo.

srcds.exe -console -game garrysmod ^
+gamemode minigames-hub ^
+map rp_lego_city ^
-maxplayers 16 ^
-port 27015 ^
+sv_lan 0

echo.
echo Сервер закрыт. Нажмите любую клавишу для выхода...
pause > nul
