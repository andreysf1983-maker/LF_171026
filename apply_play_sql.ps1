param(
    [string]$Root = "",
    [string]$MysqlExe = "",
    [string]$CnfPath = "",
    [switch]$QuestOnly
)

$ErrorActionPreference = "Continue"
if (-not $Root) { $Root = $PSScriptRoot }
if (-not $CnfPath) { $CnfPath = Join-Path $Root "setup_tmp\mysql.cnf" }
if (-not $MysqlExe) {
    $MysqlExe = & (Join-Path $Root "find_mysql.ps1") -Port 3306
}

if (-not $MysqlExe -or -not (Test-Path $MysqlExe)) {
    Write-Host "  [!] mysql.exe not found"
    exit 1
}
if (-not (Test-Path $CnfPath)) {
    Write-Host "  [!] $CnfPath not found - run setup.bat first"
    exit 1
}

$sqlDir = Join-Path $Root "sql"
# База персонажей называется `characters`: именно её создаёт setup.bat и именно её прописывает mysql_helper.ps1
# в worldserver.conf. Раньше здесь стояло `legion_characters` (имя с компьютера автора) - патчи персонажей
# падали с "Unknown database".
$charDb = "characters"
$patches = @(
    # Remove two accidentally-added duplicate columns before worldserver prepares its instance query.
    @{ Db = $charDb; Rel = "updates\characters\master\2026_01_01_02_character_instance_join_fix.sql" },
    @{ Db = $charDb; File = "04_fix_instance_data.sql" },
    @{ Db = $charDb; File = "31_remove_bots_characters.sql" },
    @{ Db = $charDb; Rel = "stitch\010_scenario_return_characters.sql" },
    # [LEGIONFORGE FIX 2026-10-13] КРАШ worldserver: "[1146] Table 'world.scenario_npc_landing' doesn't exist".
    # scenario_door.cpp (ScenarioDoorWorldScript::OnStartup) читает world.scenario_npc_landing +
    # world.scenario_map_landing, но подключена была только characters-половина stitch 010.
    # World-половина ОБЯЗАТЕЛЬНА: без неё MySQLConnection делает abort() сразу после "ready...".
    @{ Db = "world";  Rel = "stitch\010_scenario_npc_landing.sql" },
    # Таблицы, которые ядро читает при старте (AIWaypointsMgr / PlayerBotMgr). Раньше создавались
    # только setup.bat - на базе, обновлённой лишь через play.bat, их могло не быть. Только CREATE IF NOT EXISTS.
    @{ Db = "auth";   File = "32_playerbot_auth.sql" },
    @{ Db = "world";  File = "32_playerbot_world.sql" },
    @{ Db = "world";      File = "31_remove_bots_world.sql" },
    @{ Db = "world";      File = "02_custom_creatures.sql" },
    @{ Db = "world";      File = "07_legion_instance_template.sql" },
    @{ Db = "world";      File = "08_all_instance_template.sql" },
    @{ Db = "world";      File = "09_lfg_dungeon_entrances.sql" },
    @{ Db = "auth";       File = "10_legionforge_realm.sql" },
    @{ Db = "world";      File = "13_warlock_starter_pet.sql" },
    @{ Db = "world";      File = "15_young_and_vicious.sql" },
    @{ Db = "world";      File = "18_quest_item_target.sql" },
    @{ Db = "world";      File = "19_quest_generic_phase.sql" },
    # Патчи, которые раньше лежали в sql\ и нигде не применялись (проверены на чистой базе, идемпотентны):
    @{ Db = "world";      File = "20_imp_display.sql" },
    @{ Db = $charDb;      File = "20_imp_display_characters.sql" },
    @{ Db = "world";      File = "22_they_sent_assassins.sql" },
    @{ Db = "world";      File = "23_kill_target_questgivers.sql" },
    @{ Db = "world";      File = "24_neutral_kill_targets.sql" },
    @{ Db = "world";      File = "25_clear_promo_mail_world.sql" },
    @{ Db = $charDb;      File = "25_clear_promo_mail_characters.sql" },
    @{ Db = "world";      File = "26_welcome_sender.sql" },
    @{ Db = "world";      File = "27_worgen_start.sql" },
    @{ Db = "world";      File = "28_fel_imp_display.sql" },
    # Союзные расы Legion (27-30): гейт дополнения и стартовая панель умений.
    # Данные старта/статистика уже есть в ADB_735.10; патчи идемпотентны.
    @{ Db = "world";      File = "48_legion_allied_races.sql" },
    @{ Db = "world";      File = "49_legion_allied_races_hotbar.sql" },
    # [LEGIONFORGE AUDIT 2026-10] Кастомные расы клиента 31..44: патч раньше
    # НЕ подключался ни к одному установщику - расы появлялись в окне создания,
    # но playercreateinfo/player_levelstats/race_unlock_requirement оставались
    # пустыми (CHAR_CREATE_FAILED). 52_primary применяется после 48/49 и
    # является единственным источником истины о соответствии "раса -> донор".
    # [LEGIONFORGE UWOW 2026-10-13] UWOW-точное соответствие рас 31/32/34-37 расам-донорам
    # (Зандалари<-Тролль и т.д.) ДО обобщающего 52-го: INSERT IGNORE в 52 не перезапишет
    # корректные стартовые позиции/статы, а добьёт недостающие расы 33/38..44.
    @{ Db = "world";      File = "50_uwow_custom_races.sql" },
    @{ Db = "world";      File = "52_custom_races_31_44.sql" },
    # [LEGIONFORGE FIX 2026-10-13] Чистка мёртвых строк из ОШИБКИ.txt (spell_script_names на
    # несуществующие в 26124 спеллы, сиротский лут, conditions на карты BfA и т.п.). Раньше
    # README требовал применять вручную - из-за этого ошибки повторялись при каждом старте.
    # Идемпотентен, только DELETE по точным ID; все таблицы проверены по схеме ADB_735.10.
    @{ Db = "world";      File = "100_legionforge_error_fixes_26124_part2.sql"; Soft = $true },
    # [LEGIONFORGE FIX 2026-10-13] Добивка DBErrors.log: display id кастомов 900100-900103,
    # unit_class 9500100, spell1 29264, CONTROL_VEHICLE аурые аддоны, spawndist idle,
    # сиротский лут, spawn_mask BfA-подземелий, PortLocID=0. Идемпотентно.
    @{ Db = "world";      File = "101_legionforge_dberrors_fixes.sql"; Soft = $true },
    # [LEGIONFORGE FIX 2026-10-14] Финальная чистка DBErrors.log: "висячий" лут
    # spell_loot_template 263148-263154 (isn't spell id) и reference_loot_template
    # 210020-210029 (isn't reference id) + страховка по BFA-луту 253xxx-255xxx.
    # Только DELETE, идемпотентно.
    @{ Db = "world";      File = "102_legionforge_dberrors_final.sql"; Soft = $true }
)

if ($QuestOnly) {
    $patches = @(
        @{ Db = "world"; File = "18_quest_item_target.sql" },
        @{ Db = "world"; File = "19_quest_generic_phase.sql" }
    )
}

$generatedP05 = Join-Path $sqlDir "generated_p05_item_targets.sql"
if (Test-Path $generatedP05) {
    $patches += @{ Db = "world"; File = "generated_p05_item_targets.sql" }
}

$fail = 0
foreach ($p in $patches) {
    $path = if ($p.ContainsKey("Rel") -and $p.Rel) {
        Join-Path $sqlDir $p.Rel
    } else {
        Join-Path $sqlDir $p.File
    }
    $label = if ($p.ContainsKey("Rel") -and $p.Rel) { $p.Rel } else { $p.File }
    if (-not (Test-Path -LiteralPath $path)) {
        Write-Host "  [!] required SQL patch is missing: $label"
        $fail++
        break
    }
    Write-Host "  [*] applying $label -> $($p.Db)..."
    # SQL передаётся в stdin побайтово: конвейер PowerShell (Get-Content | mysql) портит UTF-8/кириллицу
    # в Windows PowerShell 5.1 (кодировка $OutputEncoding = ASCII).
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $MysqlExe
    $psi.Arguments = ('--defaults-extra-file="{0}" --default-character-set=utf8mb4 --max_allowed_packet=512M {1}' -f $CnfPath, $p.Db)
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $proc = [System.Diagnostics.Process]::Start($psi)
    $outTask = $proc.StandardOutput.ReadToEndAsync()
    $errTask = $proc.StandardError.ReadToEndAsync()
    $bytes = [System.IO.File]::ReadAllBytes($path)
    try { $proc.StandardInput.BaseStream.Write($bytes, 0, $bytes.Length) } catch { }
    $proc.StandardInput.Close()
    $proc.WaitForExit()
    $LASTEXITCODE = $proc.ExitCode
    foreach ($text in @($outTask.Result, $errTask.Result)) {
        if ($text) { ($text -split "`r?`n") | Where-Object { $_ } | ForEach-Object { Write-Host "      $_" } }
    }
    if ($LASTEXITCODE -ne 0) {
        $mysqlExitCode = $LASTEXITCODE
        # [LEGIONFORGE FIX 2026-10-14] Патчи-чистки DBErrors.log (Soft = $true) НЕ должны
        # блокировать запуск сервера: это косметика журнала, а не схема и не игровые данные.
        # 102 rev.2 падал на "Table 'world.item_template' doesn't exist" и setup.bat/play.bat
        # полностью отказывались поднимать сервер - за чисткой журнала.
        if ($p.ContainsKey("Soft") -and $p.Soft) {
            Write-Host "  [!] SOFT-FAIL $label (mysql exit $mysqlExitCode) - DBErrors.log cleanup only, server will still start"
            continue
        }
        Write-Host "  [!] FAIL $label (mysql exit $mysqlExitCode)"
        $fail++
        break
    } else {
        Write-Host "  [OK] $label"
    }
}

if ($fail -gt 0) {
    Write-Host "  [!] $fail SQL patch(es) failed"
    exit 1
}

# [LEGIONFORGE FIX 2026-10-13] Предстартовая проверка таблиц, к которым ядро обращается напрямую.
# MySQLConnection::_HandleMySQLErrno на 1146 (нет таблицы) / 1054 (нет колонки) делает abort(),
# поэтому лучше остановиться ЗДЕСЬ с понятным сообщением, чем получить крэш-дамп после "ready...".
# Список синхронизирован с tools/audit_sql_schema.py (статический аудит всех запросов ядра).
if (-not $QuestOnly) {
    $required = @(
        @{ Db = "world";  Table = "scenario_npc_landing";      Fix = "sql\stitch\010_scenario_npc_landing.sql" },
        @{ Db = "world";  Table = "scenario_map_landing";      Fix = "sql\stitch\010_scenario_npc_landing.sql" },
        @{ Db = $charDb;  Table = "character_scenario_return"; Fix = "sql\stitch\010_scenario_return_characters.sql" },
        @{ Db = "world";  Table = "aiwaypoints";               Fix = "sql\46_legionforge_playerbots.sql / sql\32_playerbot_world.sql" },
        @{ Db = "auth";   Table = "playerbot_random_names";    Fix = "sql\32_playerbot_auth.sql" },
        @{ Db = "auth";   Table = "playerbot_arena_names";     Fix = "sql\32_playerbot_auth.sql" }
    )
    $missing = 0
    foreach ($r in $required) {
        $q = "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA='$($r.Db)' AND TABLE_NAME='$($r.Table)';"
        $out = & $MysqlExe "--defaults-extra-file=$CnfPath" -N -B -e $q 2>$null
        if ("$out".Trim() -ne "1") {
            Write-Host "  [!] Нет таблицы $($r.Db).$($r.Table) - worldserver упадёт (1146). Примените: $($r.Fix)"
            $missing++
        }
    }
    if ($missing -gt 0) {
        Write-Host "  [!] Схема базы неполная ($missing таблиц). Запустите setup.bat повторно."
        exit 1
    }
    Write-Host "  [OK] Обязательные таблицы ядра на месте."
}
exit 0
