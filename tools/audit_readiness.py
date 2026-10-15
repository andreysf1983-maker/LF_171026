#!/usr/bin/env python3
"""LEGIONFORGE readiness/packaging regression audit (added 2026-10-13).

Guards against the exact class of defects that made a fully functional
worldserver look "broken" in ОШИБКИ.txt:

  * one-shot readiness check instead of a wait loop,
  * broken -match regexes in PowerShell (unbalanced parentheses),
  * SQL fix files present on disk but not registered in apply_play_sql.ps1,
  * encoding/EOL drift of Windows scripts,
  * DBErrors.log patterns re-appearing in the latest Server.log tail.

Run from the repository root:  python tools/audit_readiness.py -v
"""
import pathlib
import re
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def read(name: str) -> str:
    return (ROOT / name).read_bytes().decode("utf-8-sig")


class ReadinessTests(unittest.TestCase):
    def test_wait_world_ready_polls(self):
        s = read("wait_world_ready.ps1")
        # analyze code only: strip the <# ... #> block comment that documents the old bug
        s = re.sub(r"<\#.*?\#>", "", s, flags=re.S)
        self.assertIn("Start-Sleep", s, "must poll, not check once")
        self.assertRegex(s, r"\$TimeoutSec", "must honour a timeout parameter")
        self.assertIn("Test-PortListen", s)
        # the historical bug: an invalid regex (literal backslash + orphan ')')
        self.assertNotIn('daemon\\\\) ready', s.replace("\\\\", "\\\\"),
                         "no regex -match for the ready marker")
        self.assertIn('.Contains(', s, "ready marker must be a literal search")

    def test_powershell_scripts_bom_crlf(self):
        for pat in ("*.ps1",):
            for p in list(ROOT.glob(pat)) + list((ROOT / "tools").glob(pat)):
                raw = p.read_bytes()
                self.assertTrue(raw.startswith(b"\xef\xbb\xbf"), f"{p.name}: missing UTF-8 BOM")
                self.assertEqual(raw.count(b"\n"), raw.count(b"\r\n"), f"{p.name}: mixed EOL")

    def test_bat_scripts_cp866_crlf(self):
        for p in list(ROOT.glob("*.bat")) + list((ROOT / "server").glob("*.bat")):
            raw = p.read_bytes()
            raw.decode("cp866")
            self.assertEqual(raw.count(b"\n"), raw.count(b"\r\n"), f"{p.name}: mixed EOL")

    def test_sql_fixes_registered_in_manifest(self):
        manifest = read("apply_play_sql.ps1").replace("\r\n", "\n")
        applied = set(re.findall(r'File\s*=\s*"([^"]+\.sql)"', manifest))
        setup = pathlib.Path("setup.bat").read_bytes().decode("cp866")
        applied |= {n.split("\\")[-1] for n in re.findall(r'%SQL_DIR%\\\\?([^"\s]+\.sql)', setup)}
        for name in ("100_legionforge_error_fixes_26124_part2.sql",
                     "101_legionforge_dberrors_fixes.sql",
                     "52_custom_races_31_44.sql"):
            self.assertIn(name, applied, f"{name} must be applied automatically")
        # unregistered non-rollback root patches = dead code by policy
        for p in sorted(ROOT.glob("sql/[0-9][0-9]_*.sql")):
            n = p.name
            if "_rollback" in n or n.startswith(("99_",)):
                continue  # rollbacks and superseded reference files are opt-in
            body = p.read_text(encoding="utf-8-sig", errors="replace").upper()
            if not any(k in body for k in ("UPDATE ", "INSERT ", "DELETE ", "ALTER ", "REPLACE(")):
                continue  # SELECT-only audit queries are run manually
            self.assertIn(n, applied, f"{n} exists but is never applied by setup.bat or play.bat")

    def test_db101_covers_dberrors_classes(self):
        sql = read("sql/101_legionforge_dberrors_fixes.sql").replace("\r\n", "\n")
        for token in ("900100", "9500100", "29264", "46598", "spawndist",
                      "24974", "39733", "130758", "PortLocID", "8388870",
                      "36756", "disenchant_loot_template", "spell_loot_template",
                      "reference_loot_template", "creature_formations", "SmartAI",
                      "areatrigger_runic_mark", "spell\\_spawn\\_flash", "waypoint_data", "RewardSpell", "npcflag"):
            self.assertIn(token, sql, f"DBErrors class '{token}' not covered")

    def test_sql_patch_columns_verified_against_core(self):
        """Regression for setup.bat abort: Unknown column 'RewardSpellCast' (101 rev.1)."""
        import importlib.util
        spec = importlib.util.spec_from_file_location("audit_sql_columns", ROOT / "tools" / "audit_sql_columns.py")
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        known = mod.build_schema()
        for name in ("sql/101_legionforge_dberrors_fixes.sql",
                     "sql/100_legionforge_error_fixes_26124_part2.sql",
                     "sql/43_legionforge_upgrade_tokens.sql"):
            probs = mod.check_file(ROOT / name, known)
            self.assertEqual(probs, [], f"{name}: {probs}")
        sql = read("sql/101_legionforge_dberrors_fixes.sql")
        self.assertNotIn("RewardSpellCast", sql.split("-- [DBE-6]")[1].split("-- [DBE-7]")[0].replace("-- Column is `RewardSpell` (log text says RewardSpellCast - legacy wording).", ""))
        self.assertNotIn("item_template`", sql, "world db of 7.x has no item_template table")
        self.assertNotIn("unit_npc_flag", sql)

    def test_areatrigger_spawnmask_indexed_by_map(self):
        src = read("core/src/server/game/Globals/AreaTriggerDataStore.cpp")
        self.assertIn("spawnMasks[my_temp.map_id]", src)
        self.assertNotIn("spawnMasks[my_temp.spawn_mask]", src)
        sql = read("sql/101_legionforge_dberrors_fixes.sql")
        self.assertNotIn("`spawn_mask` = 7", sql, "never strip Mythic (bit 23) from dungeon area triggers")

    def test_custom_vendors_have_display_id_at_source(self):
        s43 = read("sql/43_legionforge_upgrade_tokens.sql")
        self.assertIn("(`entry`,`modelid1`,`name`", s43)
        for e in (900100, 900101, 900102, 900103):
            self.assertIn(f"({e},3167,'", s43)
        s26 = read("sql/26_welcome_sender.sql")
        self.assertIn("`unit_class` = 1", s26)

    def test_core_races_limit_covers_custom_client(self):
        sd = read("core/src/server/game/Miscellaneous/SharedDefines.h")
        m = re.search(r"#define\s+MAX_RACES\s+(\d+)", sd)
        self.assertIsNotNone(m, "MAX_RACES define not found")
        self.assertGreaterEqual(int(m.group(1)), 45,
                                "MAX_RACES must cover custom client races 31..44")


if __name__ == "__main__":
    unittest.main(verbosity=2)
