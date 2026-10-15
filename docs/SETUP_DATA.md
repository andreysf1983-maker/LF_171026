# Подготовленные игровые данные (data)

Если клиент уже был извлечён на другом компьютере, не нужно передавать сам клиент.
Скопируйте содержимое его папки `data` сюда:

```text
LEGIONFORGE\server\data\maps\*.map
LEGIONFORGE\server\data\dbc\Map.db2
LEGIONFORGE\server\data\vmaps\*.vmtree
LEGIONFORGE\server\data\mmaps\*.mmtile  (рекомендуется)
```

Проверку можно запустить вручную:

```bat
powershell -NoProfile -ExecutionPolicy Bypass -File check_game_data.ps1 -ServerDir server
```

Для готового набора требуется не менее 200 файлов `.map`, все обязательные континенты Vanilla–Legion (пороги из `extract_maps.ps1`), `Map.db2` и не менее 50 файлов `*.vmtree`.
`mmaps` улучшает движение NPC, но не является условием установки. `setup.bat` запускает эту проверку
до поиска WoW-клиента. При успешной проверке он пропускает поиск клиента и повторное извлечение.
При неполном наборе setup найдёт клиент автоматически или спросит его путь, затем извлечёт данные.

Если setup не видит подготовленные карты, проверьте, что копировали именно содержимое `data` в
`server\data`, а не получили вложенный путь `server\data\data\maps`.
