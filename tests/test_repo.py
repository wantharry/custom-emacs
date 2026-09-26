"""Repository hygiene: docs, scripts, ignore rules, and the test suite itself."""
import glob
import os
import re
import subprocess
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def read(path):
    with open(path) as fh:
        return fh.read()


def rel(*p):
    return os.path.join(ROOT, *p)


def slug(h):
    h = re.sub(r"[`*]", "", h.strip().lower())
    h = re.sub(r"[^\w\s-]", "", h)
    return re.sub(r"\s", "-", h)


class Docs(unittest.TestCase):
    def docs(self):
        return [rel("README.md")] + sorted(glob.glob(rel("docs", "*.md")))

    def test_every_internal_link_and_anchor_resolves(self):
        anchors = {f: {slug(m) for m in re.findall(r"^#+\s+(.*)$", read(f), re.M)}
                   for f in self.docs()}
        for f in self.docs():
            for _, link in re.findall(r"\[([^\]]+)\]\(([^)]+)\)", read(f)):
                if link.startswith("http"):
                    continue
                path, _, anchor = link.partition("#")
                target = os.path.normpath(os.path.join(os.path.dirname(f), path)) if path else f
                with self.subTest(doc=os.path.relpath(f, ROOT), link=link):
                    self.assertTrue(os.path.exists(target), "missing file")
                    if anchor:
                        self.assertIn(anchor, anchors.get(target, set()), "missing anchor")

    def test_readme_lists_every_guide(self):
        readme = read(rel("README.md"))
        for f in glob.glob(rel("docs", "*.md")):
            with self.subTest(guide=os.path.basename(f)):
                self.assertIn(f"docs/{os.path.basename(f)}", readme)


class Scripts(unittest.TestCase):
    def test_shell_scripts_have_valid_syntax(self):
        scripts = ["build.sh", "tools/verify-prune.sh", "tests/run-all.sh"]
        scripts += [os.path.relpath(p, ROOT) for p in glob.glob(rel(".githooks", "*"))]
        for s in scripts:
            with self.subTest(script=s):
                r = subprocess.run(["bash", "-n", rel(s)], capture_output=True, text=True)
                self.assertEqual(r.returncode, 0, r.stderr)

    def test_scripts_are_executable(self):
        for s in ["build.sh", "tools/verify-prune.sh", "tests/run-all.sh"]:
            with self.subTest(script=s):
                self.assertTrue(os.access(rel(s), os.X_OK))

    def test_python_files_compile(self):
        for f in ["prune.py"] + [os.path.relpath(p, ROOT) for p in glob.glob(rel("tests", "*.py"))]:
            with self.subTest(file=f):
                compile(read(rel(f)), f, "exec")

    def test_build_script_advertises_every_target(self):
        text = read(rel("build.sh"))
        for target in ["configure", "make", "install", "prune", "packages", "grammars", "test", "all"]:
            with self.subTest(target=target):
                self.assertRegex(text, rf"(?m)^\s+{target}\)", "no case branch")


class GitRules(unittest.TestCase):
    def ignored(self, path):
        return subprocess.run(["git", "check-ignore", "-q", path], cwd=ROOT).returncode == 0

    def test_generated_and_upstream_paths_are_ignored(self):
        for p in ["emacs-src/x", "build/x", "install/x", "make.log", "config/elpa/evil/evil.el",
                  "config/custom.el", "config/backups/x~", "config/eln-cache/x.eln",
                  "config/tree-sitter/libtree-sitter-java.so"]:
            with self.subTest(path=p):
                self.assertTrue(self.ignored(p))

    def test_our_own_files_are_not_ignored(self):
        for p in ["config/init.el", "config/early-init.el", "prune.list", "prune.py",
                  "tests/run-all.sh", "tests/ert/config.el", "docs/BUILD.md"]:
            with self.subTest(path=p):
                self.assertFalse(self.ignored(p))

    def test_prune_list_only_uses_known_syntax(self):
        for line in read(rel("prune.list")).splitlines():
            line = line.split("#", 1)[0].strip()
            if not line:
                continue
            with self.subTest(line=line):
                self.assertFalse(line.startswith("/"), "absolute path")
                self.assertTrue(line.endswith("/") or line.endswith(".el"))


class TestSuiteItself(unittest.TestCase):
    ERT = sorted(glob.glob(rel("tests", "ert", "*.el")))

    def test_every_ert_file_declares_a_valid_harness(self):
        for f in self.ERT:
            if f.endswith("helper.el"):
                continue
            head = "".join(read(f).splitlines(True)[:5])
            with self.subTest(file=os.path.basename(f)):
                self.assertRegex(head, r"harness: (bare|config|noelpa)")
                self.assertIn("lexical-binding: t", head)

    def test_ert_test_names_are_unique(self):
        names = []
        for f in self.ERT:
            names += re.findall(r"^\(ert-deftest ([^\s(]+)", read(f), re.M)
        dupes = {n for n in names if names.count(n) > 1}
        self.assertEqual(dupes, set())

    def test_every_ert_test_has_an_area_prefix(self):
        for f in self.ERT:
            for n in re.findall(r"^\(ert-deftest ([^\s(]+)", read(f), re.M):
                with self.subTest(test=n):
                    self.assertIn("/", n)

    def test_suite_covers_every_subsystem_listed_in_the_docs(self):
        covered = {os.path.basename(f)[:-3] for f in self.ERT}
        for area in ["buffers-text", "editing-commands", "search-regex", "files-dired",
                     "processes", "encoding-text", "lisp-runtime", "language-modes",
                     "treesit", "vc-diff", "project-eglot", "network-data", "tramp",
                     "mail-shr", "calendar-calc-help", "evil", "keybindings", "readonly", "languages-java-rust", "config", "build-features",
                     "startup-perf", "pruning"]:
            with self.subTest(area=area):
                self.assertIn(area, covered)


if __name__ == "__main__":
    unittest.main()
