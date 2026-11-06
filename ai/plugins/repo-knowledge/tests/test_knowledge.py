import sys
import tempfile
import unittest
from pathlib import Path

from mcp import Client
from mcp.client.stdio import StdioServerParameters

from repo_knowledge.core import KnowledgeBase
from repo_knowledge.headers import parse_headers


class Fixture:
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.config = self.root / "knowledge.toml"
        self.config.write_text('''version = 1
name = "Fixture"
root = "."
exclude = ["docs/private/**"]
[[sources]]
pattern = "issues/*.md"
record_type = "ticket_snapshot"
[[sources]]
pattern = "docs/**/*.md"
record_type = "jira_preview"
''')
        self.kb = KnowledgeBase(self.config)

    def write(self, path, text):
        file = self.root / path
        file.parent.mkdir(parents=True, exist_ok=True)
        file.write_text(text)
        return file


class RetrievalTests(Fixture, unittest.TestCase):
    def test_partial_and_supersession_scopes(self):
        self.write("docs/partial.md", "Status: POSTED in part, items 2-4 remain\n\n## Body\nEvidence")
        self.write("docs/replaced.md", "Status: NOT POSTED\nSuperseded: whole\nSuperseded-by: unknown")
        self.write("docs/topic.md", "Status: POSTED\n\n## Old section\nEvidence (superseded 2026-11-05: new section)")
        self.write("docs/legacy.md", "SUPERSEDED 23 Oct: do not post")
        pending = self.kb.records("pending")["records"]
        self.assertEqual([r["path"] for r in pending], ["docs/partial.md"])
        self.assertEqual(pending[0]["workflow_status"], "PARTIALLY POSTED")
        self.assertIn("items 2-4 remain", pending[0]["status_detail"])
        visible = self.kb.records()["records"]
        self.assertEqual(len(visible), 2)
        topic = next(r for r in visible if r["path"] == "docs/topic.md")
        self.assertEqual(topic["supersession"], "partial")
        self.assertEqual(topic["superseded_lines"], [4])
        self.assertEqual(len(self.kb.records("all")["records"]), 4)

    def test_ticket_status_is_not_posting_status(self):
        self.write("issues/ABC-12.md", "# ABC-12\n\n- Status: In Progress\n- Updated: 2026-10-12")
        record = self.kb.records("all")["records"][0]
        self.assertEqual(record["ticket_status"], "In Progress")
        self.assertEqual(record["workflow_status"], "unknown")
        self.assertEqual(record["record_date"], "unknown")
        self.assertEqual(record["source_updated"], "2026-10-12")

    def test_fresh_add_edit_delete_and_hashes(self):
        path = self.write("docs/one.md", "Status: SENT\n\n## Decision\nalpha")
        old = self.kb.search("alpha")["results"][0]
        path.write_text("Status: SENT\n\n## Decision\nbeta")
        self.assertEqual(self.kb.search("alpha")["total"], 0)
        self.assertNotEqual(old["source_hash"], self.kb.read("docs/one.md")["source_hash"])
        self.write("docs/two.md", "beta")
        self.assertEqual(self.kb.search("beta")["total"], 2)
        path.unlink()
        self.assertEqual(self.kb.search("beta")["total"], 1)

    def test_posted_authority_distinct_records_and_read_window(self):
        self.write("docs/decision.md", "Status: POSTED\n\n## Decision\nABC-314 runtime\nruntime\nruntime")
        self.write("docs/old.md", "Status: POSTED\nSuperseded: whole\n\n## History\nABC-314 runtime")
        self.assertEqual(self.kb.search("ABC-314 runtime")["total"], 2)
        results = self.kb.search("ABC-314 runtime", "not_superseded")["results"]
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0]["path"], "docs/decision.md")
        self.assertEqual(results[0]["excerpts"][0]["line"], 4)
        read = self.kb.read("docs/decision.md", 4, 1)
        self.assertEqual(read["content"], "ABC-314 runtime")
        self.assertTrue(read["truncated"])

    def test_allowlist_exclusions_and_symlinks(self):
        self.write("private.md", "secret")
        self.write("docs/private/hidden.md", "secret")
        self.write("docs/.cache/hidden.md", "secret")
        self.write("docs/public.md", "public")
        (self.root / "docs/link.md").symlink_to(self.root / "private.md")
        with tempfile.TemporaryDirectory() as other:
            Path(other, "outside.md").write_text("outside")
            (self.root / "docs/outside").symlink_to(other, target_is_directory=True)
            self.assertEqual(self.kb.status()["record_count"], 1)
            for path in ("../private.md", "private.md", "docs/link.md", "docs/outside/outside.md", str(self.root / "private.md")):
                with self.assertRaises(ValueError):
                    self.kb.read(path)

    def test_bad_sources_and_read_errors(self):
        self.config.write_text('version=1\n[[sources]]\npattern="../*.md"\nrecord_type="document"')
        with self.assertRaises(ValueError):
            KnowledgeBase(self.config)
        self.write("docs/invalid.md", "temporary").write_bytes(b"\xff")
        self.assertEqual(len(self.kb.status()["errors"]), 1)

    def test_metadata_examples_are_not_headers(self):
        text = '# Topic\nDate: 6 November 2026\n\n## Examples\nStatus: POSTED\nSuperseded: whole'
        parsed = parse_headers(text, "topic.md", "review")
        self.assertEqual(parsed["workflow_status"], "unknown")
        self.assertEqual(parsed["supersession"], "none recorded")
        self.assertEqual(parsed["record_date"], "2026-11-06")

    def test_bold_headers_and_dates_inside_file_names(self):
        bold = parse_headers("# Reply\n\n**Status:** Draft; not sent.\n**To:** Will", "c/reply.md", "correspondence")
        self.assertEqual(bold["workflow_status"], "DRAFT")
        listed = parse_headers("# U\n\n- Status: In Progress", "issues/U-1.md", "ticket_snapshot")
        self.assertEqual(listed["ticket_status"], "In Progress")
        named = parse_headers("# Update\n\nStatus: POSTED", "jira/update-for-review-2026-10-30-x.md", "jira_preview")
        self.assertEqual(named["record_date"], "2026-10-30")
        no_date = parse_headers("Status: POSTED", "jira/v2026-10-301.md", "jira_preview")
        self.assertEqual(no_date["record_date"], "unknown")


def make_xlsx(path: Path) -> None:
    """Minimal workbook: header row, a dated row with a rich-text strike, a struck-style row."""
    import zipfile
    m = 'xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"'
    r = 'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"'
    parts = {
        "xl/workbook.xml": f'<workbook {m} {r}><sheets><sheet name="Prereqs" sheetId="1" r:id="rId1"/></sheets></workbook>',
        "xl/_rels/workbook.xml.rels": '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
            '<Relationship Id="rId1" Type="worksheet" Target="worksheets/sheet1.xml"/></Relationships>',
        "xl/sharedStrings.xml": f'<sst {m}><si><t>ID</t></si><si><t>Need</t></si><si><t>Needed by</t></si>'
            '<si><t>AWS-01</t></si><si><r><rPr><strike/></rPr><t>Account IDs</t></r><r><t> and SCP list</t></r></si>'
            '<si><t>OLD-9</t></si></sst>',
        "xl/styles.xml": f'<styleSheet {m}><fonts count="2"><font/><font><strike/></font></fonts>'
            '<cellXfs count="3"><xf numFmtId="0" fontId="0"/><xf numFmtId="14" fontId="0"/><xf numFmtId="0" fontId="1"/></cellXfs></styleSheet>',
        "xl/worksheets/sheet1.xml": f'<worksheet {m}><sheetData>'
            '<row r="1"><c r="A1" t="s"><v>0</v></c><c r="B1" t="s"><v>1</v></c><c r="C1" t="s"><v>2</v></c></row>'
            '<row r="2"><c r="A2" t="s"><v>3</v></c><c r="B2" t="s"><v>4</v></c><c r="C2" s="1"><v>46318</v></c></row>'
            '<row r="3"><c r="A3" t="s" s="2"><v>5</v></c></row></sheetData></worksheet>',
    }
    with zipfile.ZipFile(path, "w") as zf:
        for name, xml in parts.items():
            zf.writestr(name, xml)


class ImprovementTests(Fixture, unittest.TestCase):
    def test_workbook_rows_dates_and_strikes(self):
        (self.root / "issues").mkdir(exist_ok=True)
        make_xlsx(self.root / "issues" / "book.xlsx")
        self.config.write_text(self.config.read_text() + '[[sources]]\npattern = "issues/*.xlsx"\nrecord_type = "workbook"\n')
        kb = KnowledgeBase(self.config)
        hit = kb.search("AWS-01")["results"][0]
        self.assertEqual(hit["record_type"], "workbook")
        line = hit["excerpts"][0]["text"]
        self.assertIn("[Prereqs] row 2 | ID: AWS-01", line)
        self.assertIn("Need: ~~Account IDs~~ and SCP list", line)
        self.assertIn("Needed by: 2026-10-23", line)
        self.assertIn("ID: ~~OLD-9~~", kb.read("issues/book.xlsx")["content"])

    def test_partial_matches_rank_after_full_matches(self):
        self.write("docs/a.md", "ABC-252 close-out batch")
        self.write("docs/b.md", "ABC-252 only")
        result = self.kb.search("ABC-252 close-out")
        self.assertEqual([r["path"] for r in result["results"]], ["docs/a.md", "docs/b.md"])
        self.assertEqual(result["full_matches"], 1)
        self.assertEqual(result["results"][1]["missing_terms"], ["close-out"])

    def test_stale_snapshot_warning(self):
        self.config.write_text(self.config.read_text().replace(
            'exclude = ["docs/private/**"]',
            'exclude = ["docs/private/**"]\n[snapshot_check]\nsnapshot_type = "ticket_snapshot"\nupdate_types = ["jira_preview"]'))
        kb = KnowledgeBase(self.config)
        self.write("issues/ABC-7.md", "# ABC-7\n\n- Status: To Do\n- Updated: 2026-10-08")
        self.write("docs/2026-10-23-close.md", "Status: POSTED\n\nABC-7 moved to Done.")
        self.write("docs/2026-10-01-old.md", "Status: POSTED\n\nABC-7 created.")
        self.write("docs/2026-10-24-other.md", "Status: POSTED\n\nABC-70 is a different ticket.")
        snap = next(r for r in kb.records("all")["records"] if r["path"] == "issues/ABC-7.md")
        self.assertEqual(snap["newer_records"], ["docs/2026-10-23-close.md"])
        self.assertIn("may be stale", snap["warnings"][0])

    def test_runtime_excludes(self):
        self.write("docs/answers.md", "secret answer ABC-1")
        self.write("docs/notes.md", "ABC-1")
        kb = KnowledgeBase(self.config, ["docs/answers.md"])
        self.assertEqual([r["path"] for r in kb.search("ABC-1")["results"]], ["docs/notes.md"])


class ConfigDiscoveryTests(Fixture, unittest.TestCase):
    def test_nearest_knowledge_toml_upward_then_env(self):
        import os
        from repo_knowledge.cli import find_config
        (self.root / "knowledge.toml").write_text(self.config.read_text())
        deep = self.root / "docs" / "a" / "b"
        deep.mkdir(parents=True)
        old = os.environ.pop("REPO_KNOWLEDGE_CONFIG", None)
        try:
            self.assertEqual(find_config(None, deep), (self.root / "knowledge.toml").resolve())
            self.assertEqual(find_config("x.toml", deep), Path("x.toml"))
            os.environ["REPO_KNOWLEDGE_CONFIG"] = str(self.config)
            self.assertEqual(find_config(None, deep), self.config)
            del os.environ["REPO_KNOWLEDGE_CONFIG"]
            with tempfile.TemporaryDirectory() as empty, self.assertRaises(ValueError):
                find_config(None, Path(empty))
        finally:
            if old is not None:
                os.environ["REPO_KNOWLEDGE_CONFIG"] = old


class MCPTests(Fixture, unittest.IsolatedAsyncioTestCase):
    async def test_actual_stdio_tools_and_project_isolation(self):
        self.write("docs/record.md", "Status: POSTED\n\n## Decision\nABC-314 runtime")
        params = StdioServerParameters(command=sys.executable, args=[
            "-m", "repo_knowledge.cli", "--config", str(self.config), "serve"])
        async with Client(params) as client:
            tools = await client.list_tools()
            self.assertEqual({t.name for t in tools.tools}, {"kb_status", "kb_records", "kb_search", "kb_read"})
            result = await client.call_tool("kb_search", {"query": "ABC-314"})
            data = result.structured_content
            self.assertEqual(data["results"][0]["path"], "docs/record.md")
            self.assertEqual(data["project"], "Fixture")
            status = await client.call_tool("kb_status", {})
            self.assertEqual(status.structured_content["record_count"], 1)
            records = await client.call_tool("kb_records", {})
            self.assertEqual(records.structured_content["total"], 1)
            read = await client.call_tool("kb_read", {"path": "docs/record.md", "start_line": 4})
            self.assertEqual(read.structured_content["content"], "ABC-314 runtime")
            bad = await client.call_tool("kb_read", {"path": "../secret.md"})
            self.assertTrue(bad.is_error)
            self.write("docs/later.md", "ABC-314 new evidence")
            refreshed = await client.call_tool("kb_search", {"query": "ABC-314"})
            self.assertEqual(refreshed.structured_content["total"], 2)

    async def test_server_starts_without_config_and_explains(self):
        import os
        with tempfile.TemporaryDirectory() as empty:
            env = {k: v for k, v in os.environ.items() if k != "REPO_KNOWLEDGE_CONFIG"}
            params = StdioServerParameters(command=sys.executable, args=["-m", "repo_knowledge.cli", "serve"],
                                           cwd=empty, env=env)
            async with Client(params) as client:
                result = await client.call_tool("kb_status", {})
                self.assertTrue(result.is_error)
                self.assertIn("knowledge.toml", str(result.content))


if __name__ == "__main__":
    unittest.main()
