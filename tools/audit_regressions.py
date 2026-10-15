#!/usr/bin/env python3
"""Portable, dependency-free regression checks for the 26124 startup fixes.

Run from the project root: python tools/audit_regressions.py -v
These are source/packaging checks; Windows runtime and real client DB2 still
require the smoke test documented in docs/RECOVERY_26124.md.
"""

import re
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def source(path, encoding="utf-8"):
    return (ROOT / path).read_text(encoding=encoding)


class StartupRegressionTests(unittest.TestCase):
    def setUp(self):
        self.enums = source("core/src/server/game/Miscellaneous/SharedDefines.h")
        self.handlers = source("core/src/server/game/Spells/SpellEffects.cpp")
        self.loader = source("core/src/server/game/Spells/SpellMgr.cpp")

    def test_effect_261_has_safe_dispatch(self):
        match = re.search(r"TOTAL_SPELL_EFFECTS\s*=\s*(\d+)", self.enums)
        self.assertIsNotNone(match)
        self.assertEqual(262, int(match.group(1)))
        self.assertRegex(self.enums, r"SPELL_EFFECT_261\s*=\s*261")
        block = re.search(
            r"pEffect\s+SpellEffects\[TOTAL_SPELL_EFFECTS\]\s*=\s*\{(.*?)\n\};",
            self.handlers,
            re.S,
        )
        self.assertIsNotNone(block)
        pointers = re.findall(r"^\s*&Spell::\w+\s*,", block.group(1), re.M)
        self.assertEqual(262, len(pointers), "Every legal effect needs a non-null handler")
        self.assertIn("//261 SPELL_EFFECT_261", block.group(1))

    def test_spell_loader_rejects_bad_indices_before_allocating(self):
        self.assertIn("effect->SpellID < 0", self.loader)
        self.assertIn("effect->EffectIndex < 0", self.loader)
        self.assertIn("effect->Effect >= TOTAL_SPELL_EFFECTS", self.loader)
        self.assertIn("effect->EffectAura < 0", self.loader)
        self.assertIn("effect->ImplicitTarget[0] >= TOTAL_SPELL_TARGETS", self.loader)
        self.assertLess(
            self.loader.index("effect->EffectIndex < 0"),
            self.loader.index("effectsForDifficulty.resize(std::size_t(effect->EffectIndex + 1))"),
        )
        self.assertNotRegex(self.loader, r"ASSERT\s*\(\s*effect->Effect\s*<\s*TOTAL_SPELL_EFFECTS")
        self.assertIn("MaxLoggedInvalidEffects", self.loader)

    def test_criteria_type_and_timer_bounds_precede_array_access(self):
        code = source("core/src/server/game/Achievements/CriteriaHandler.cpp")
        enum = source("core/src/server/game/DataStores/DBCEnums.h")
        self.assertRegex(enum, r"#define\s+CRITERIA_TYPE_TOTAL\s+213\b")
        self.assertIn("if (criteriaEntry->Type >= CRITERIA_TYPE_TOTAL)", code)
        self.assertIn("if (criteriaEntry->StartTimer && criteriaEntry->StartEvent >= CRITERIA_TIMED_TYPE_MAX)", code)
        self.assertNotIn("ASSERT(criteriaEntry->Type < CRITERIA_TYPE_TOTAL", code)
        for array in (
            "_criteriasByType[criteriaEntry->Type]",
            "_guildCriteriasByType[criteriaEntry->Type]",
            "_scenarioCriteriasByType[criteriaEntry->Type]",
            "_questObjectiveCriteriasByType[criteriaEntry->Type]",
            "_criteriasByTimedType[criteriaEntry->StartEvent]",
        ):
            guard = "if (criteriaEntry->StartTimer &&" if "StartEvent" in array else "if (criteriaEntry->Type >="
            self.assertLess(code.index(guard), code.index(array), array)
        self.assertIn("Skipped %u criteria with unsupported types", code)
        self.assertIn("Skipped %u timed criteria with invalid start events", code)
        self.assertIn("MaxLoggedInvalidCriteria = 20", code)

    def test_missing_criteria_cannot_complete_achievement(self):
        code = source("core/src/server/game/Achievements/CriteriaHandler.cpp")
        method = code[code.index("bool CriteriaHandler::IsCompletedCriteriaTree("):]
        self.assertLess(method.index("if (tree->Entry->CriteriaID && !tree->Criteria)"),
                        method.index("switch (tree->Entry->Operator)"))

    def test_scenario_poi_uses_sparse_checked_keys(self):
        code = source("core/src/server/game/Scenarios/ScenarioMgr.cpp")
        method = code[code.index("void ScenarioMgr::LoadScenarioPOI()"):]
        self.assertNotIn("POIs.resize(", method)
        self.assertNotIn("POIs[CriteriaTreeID]", method)
        self.assertIn("std::map<std::pair<int32, int32>, std::vector<ScenarioPOIPoint>> poiPoints", method)
        self.assertIn("criteriaTreeId < 0 || index < 0", method)
        self.assertIn("poiPoints.find(std::make_pair(criteriaTreeId, index))", method)
        self.assertIn("Skipped %u invalid scenario POI points and %u definitions", method)

    def test_progress_count_tracks_each_db2_store(self):
        code = source("core/src/server/game/DataStores/DB2Stores.cpp")
        count = int(re.search(r"ExpectedDb2Stores\s*=\s*(\d+)", code).group(1))
        calls = re.findall(r"^\s{4}LOAD_DB2\(s\w+Store\);\s*$", code, re.M)
        self.assertEqual(count, len(calls))
        macro = code[code.index("#define LOAD_DB2(store)") : code.index("#undef LOAD_DB2")]
        self.assertLess(macro.index("DB2 [%u/%u] loading %s"), macro.index("LoadDB2(availableDb2Locales"))
        self.assertIn("tableElapsed >= 1000", macro)
        self.assertIn("SpellInfo: %u/%u entries processed", self.loader)

    def test_build_fingerprint_is_enforced_everywhere(self):
        marker = source("tools/check_build_freshness.ps1")
        self.assertIn("Get-FileHash", marker)
        self.assertIn("worldserver.exe", marker)
        self.assertIn("bnetserver.exe", marker)
        self.assertIn("SpellMgr.cpp", marker)
        for file_name in ("DBCEnums.h", "CriteriaHandler.cpp", "CriteriaHandler.h", "ScenarioMgr.cpp"):
            self.assertIn(file_name, marker)
        self.assertIn("throw 'Build fingerprint is missing", marker)
        self.assertIn("-Update", source("build_server.ps1"))
        self.assertIn("check_build_freshness.ps1", source("check_server_runtime.ps1"))
        self.assertGreaterEqual(source("setup.bat", "cp866").count("check_build_freshness.ps1"), 2)
        self.assertIn("build_sources.json", source("prepare_release.ps1"))

    def test_offline_openssl_precedes_network(self):
        builder = source("build_server.ps1")
        block = builder[builder.index("function Initialize-OpenSsl {") : builder.index("# ------------------------------------------------------------------ MySQL")]
        self.assertLess(block.index("Find-OfflineOpenSslInstaller"), block.index("Invoke-WebRequest"))
        self.assertIn("Get-AuthenticodeSignature", builder)
        self.assertIn("LEGIONFORGE_OPENSSL_SHA256", builder)
        self.assertIn("10MB", builder)
        self.assertIn("foreach ($candidate in $orderedCandidates)", block)

    def test_openssl_diagnosis_reads_real_pe_exports(self):
        diag = source("tools/diagnose_openssl.ps1")
        self.assertIn("function Test-PeExport", diag)
        self.assertIn("$exportRva = Get-PeU32", diag)
        self.assertNotIn("$latin1.GetString($bytes)", diag)
        self.assertIn("$localNames.ContainsKey($name)", diag)
        self.assertIn("OPENSSL_CONF не задана. Это не ошибка", diag)

    def test_db2_check_discloses_its_limits(self):
        check = source("tools/check_db2_build.ps1")
        self.assertIn("$spellLimit -ne $spellHandlers", check)
        self.assertIn("содержимое SpellEffect проверяется при загрузке", check)

    def test_windows_scripts_preserve_codepage_and_endings(self):
        attrs = source(".gitattributes")
        self.assertIn("*.bat text eol=crlf", attrs)
        self.assertIn("*.ps1 text eol=crlf", attrs)
        batch_files = list(ROOT.glob("*.bat")) + list((ROOT / "server").glob("*.bat"))
        powershell_files = list(ROOT.glob("*.ps1")) + list((ROOT / "tools").glob("*.ps1"))
        self.assertTrue(batch_files)
        self.assertTrue(powershell_files)
        for path in batch_files:
            with self.subTest(path=path.name):
                raw = path.read_bytes()
                raw.decode("cp866")
                self.assertEqual(raw.count(b"\n"), raw.count(b"\r\n"))
                self.assertFalse(raw.startswith(b"\xef\xbb\xbf"))
        for path in powershell_files:
            with self.subTest(path=path.name):
                raw = path.read_bytes()
                self.assertTrue(raw.startswith(b"\xef\xbb\xbf"))
                raw.decode("utf-8-sig")
                self.assertEqual(raw.count(b"\n"), raw.count(b"\r\n"))


    # --- 2026-10-13 full audit (ОШИБКИ.txt, 2293 lines) ---
    def test_db2stores_no_assert_on_external_db2_rows(self):
        code = source("core/src/server/game/DataStores/DB2Stores.cpp")
        for bad in (
            "ASSERT(BATTLE_PET_SPECIES_MAX_ID",
            "ASSERT(MAX_DIFFICULTY >=",
            "ASSERT(namesProfanity->Language",
            "ASSERT(!(namesReserved->LocaleMask",
            "ASSERT(entry->RangeIndex >= BG_BRACKET_ID_FIRST)",
            "ASSERT(TaxiMaskSize >=",
        ):
            self.assertNotIn(bad, code, bad)
        self.assertIn("LEGIONFORGE AUDIT FIX 2026-10-13", code)
        self.assertIn("(node->ID - 1) / 8 >= TaxiMaskSize", code)

    def test_log_spam_aggregation_caps(self):
        loot = source("core/src/server/game/Loot/LootMgr.cpp")
        self.assertIn("first 20 logged", loot)
        self.assertIn("sql/100_legionforge_error_fixes_26124_part2.sql", loot)
        smart = source("core/src/server/game/AI/SmartScripts/SmartScriptMgr.cpp")
        self.assertIn("further 'is not using SmartAI' errors suppressed", smart)
        cond = source("core/src/server/game/Conditions/ConditionMgr.cpp")
        self.assertIn("does not exist in Map.dbc' errors suppressed", cond)

    def test_sql100_safe_deletes_present(self):
        sql = source("sql/100_legionforge_error_fixes_26124_part2.sql")
        self.assertIn("DELETE FROM `spell_loot_template` WHERE `entry` IN (253113", sql)
        self.assertIn("DELETE FROM `lfg_dungeon_template`", sql)
        self.assertIn("SourceTypeOrReferenceId` = 25", sql)
        self.assertIn("REVIEW (NOT auto-applied", sql)
        self.assertIn("mysqldump", sql)

    def test_build_fingerprint_covers_2026_10_13_files(self):
        marker = source("tools/check_build_freshness.ps1")
        for f in ("LootMgr.cpp", "SmartScriptMgr.cpp", "ConditionMgr.cpp", "DB2Stores.cpp"):
            self.assertIn(f, marker)


    @unittest.skipUnless(shutil.which("g++"), "GCC unavailable; source guards still checked")
    def test_criteria_enums_compile_at_boundary(self):
        enum_text = source("core/src/server/game/DataStores/DBCEnums.h")
        types = re.search(r"enum\s+CriteriaTypes\s*:\s*uint8\s*\{.*?\n\};", enum_text, re.S)
        timed = re.search(r"enum\s+CriteriaTimedTypes\s*:\s*uint8\s*\{.*?\n\};", enum_text, re.S)
        total = re.search(r"#define\s+CRITERIA_TYPE_TOTAL\s+\d+", enum_text)
        self.assertIsNotNone(types)
        self.assertIsNotNone(timed)
        self.assertIsNotNone(total)
        program = (
            "using uint8 = unsigned char;\n"
            + timed.group(0) + "\n" + types.group(0) + "\n" + total.group(0)
            + "\nstatic_assert(CRITERIA_TYPE_TOTAL == 213, \"Legion types\");"
            + "\nstatic_assert(212 < CRITERIA_TYPE_TOTAL && 213 >= CRITERIA_TYPE_TOTAL, \"type guard\");"
            + "\nstatic_assert(14 < CRITERIA_TIMED_TYPE_MAX && 15 >= CRITERIA_TIMED_TYPE_MAX, \"timer guard\");"
            + "\nint main() { return 0; }\n"
        )
        with tempfile.TemporaryDirectory() as directory:
            result = subprocess.run(
                ["g++", "-std=c++17", "-x", "c++", "-", "-o", str(Path(directory) / "bounds")],
                input=program, text=True, capture_output=True, check=False,
            )
            self.assertEqual(result.returncode, 0, result.stderr)

    @unittest.skipUnless(shutil.which("g++"), "GCC unavailable; static enum/handler test still runs")
    def test_spell_effect_enum_compiles_at_boundary(self):
        match = re.search(r"enum\s+SpellEffectName\s*\{.*?\n\};", self.enums, re.S)
        self.assertIsNotNone(match)
        program = (
            match.group(0)
            + "\nstatic_assert(TOTAL_SPELL_EFFECTS == 262, \"effect 261 must fit\");"
            + "\nstatic_assert(SPELL_EFFECT_261 < TOTAL_SPELL_EFFECTS, \"safe index\");"
            + "\nint main() { return 0; }\n"
        )
        with tempfile.TemporaryDirectory() as directory:
            result = subprocess.run(
                ["g++", "-std=c++17", "-x", "c++", "-", "-o", str(Path(directory) / "bounds")],
                input=program,
                text=True,
                capture_output=True,
                check=False,
            )
            self.assertEqual(result.returncode, 0, result.stderr)


class SqlSchemaRegressionTests(unittest.TestCase):
    """[LEGIONFORGE 2026-10-13] Класс ошибок из ОШИБКИ.txt: запрос ядра к таблице, которую
    не создаёт ни один подключённый SQL -> ER_NO_SUCH_TABLE -> abort() worldserver."""

    def test_scenario_door_world_sql_is_applied(self):
        text = source("apply_play_sql.ps1", "utf-8-sig")
        self.assertIn('stitch\\010_scenario_npc_landing.sql', text)
        self.assertIn('stitch\\010_scenario_return_characters.sql', text)

    def test_scenario_door_self_heals_schema(self):
        text = source("core/src/server/scripts/Custom/scenario_door.cpp")
        self.assertIn("CREATE TABLE IF NOT EXISTS `scenario_npc_landing`", text)
        self.assertIn("CREATE TABLE IF NOT EXISTS `character_scenario_return`", text)
        self.assertIn("information_schema.TABLES", text)

    def test_no_item_template_queries(self):
        # В Legion 7.x нет world.item_template - любое обращение = abort().
        for path in (ROOT / "core/src/server").rglob("*.cpp"):
            code = re.sub(r"//[^\n]*|/\*.*?\*/", "", path.read_text(encoding="utf-8", errors="replace"), flags=re.S)
            self.assertNotRegex(code, r"(?i)FROM\s+`?item_template`?\b", str(path))

    def test_static_sql_schema_audit(self):
        result = subprocess.run(
            ["python3" if shutil.which("python3") else "python", str(ROOT / "tools" / "audit_sql_schema.py"),
             "--report", str(Path(tempfile.gettempdir()) / "sql_schema_audit.md")],
            text=True, capture_output=True, check=False,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_race_ids_are_bounded(self):
        handler = source("core/src/server/game/Handlers/CharacterHandler.cpp")
        self.assertIn("charCreate.CreateInfo->Race >= MAX_RACES", handler)
        unit = source("core/src/server/game/Entities/Unit/Unit.h")
        self.assertRegex(unit, r"getRaceMask\(\) const \{ uint8 r = getRace\(\); return \(r == 0 \|\| r > 64\)")


if __name__ == "__main__":
    unittest.main()
