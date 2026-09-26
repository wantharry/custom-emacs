"""Tests for prune.py, using small fake Lisp and install trees (no build needed)."""
import contextlib
import glob
import importlib.util
import io
import os
import shutil
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_spec = importlib.util.spec_from_file_location("prune", os.path.join(ROOT, "prune.py"))
prune = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(prune)


def write(path, text=""):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(text)


class FakeTree(unittest.TestCase):
    """Point prune.py at a temporary lisp/ directory and manifest."""

    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.lisp = os.path.join(self.tmp, "lisp")
        self.manifest = os.path.join(self.tmp, "prune.list")
        self._saved = (prune.LISP, prune.MANIFEST, prune.preloaded)
        prune.LISP, prune.MANIFEST = self.lisp, self.manifest
        prune.preloaded = lambda: set()

    def tearDown(self):
        prune.LISP, prune.MANIFEST, prune.preloaded = self._saved
        shutil.rmtree(self.tmp)

    def manifest_is(self, *lines):
        write(self.manifest, "\n".join(lines) + "\n")

    def plan(self):
        files, pruned, rescued, by_base, soft = prune.plan()
        return pruned, rescued, soft


class ManifestParsing(FakeTree):
    def test_comments_and_blank_lines_are_ignored(self):
        self.manifest_is("# a comment", "", "apps/  # trailing comment", "  ", "x/y.el")
        self.assertEqual(prune.read_manifest(), ["apps/", "x/y.el"])

    def test_directory_pattern_matches_everything_below(self):
        self.assertTrue(prune.matches("apps/a/b", ["apps/"]))
        self.assertFalse(prune.matches("other/a", ["apps/"]))

    def test_glob_pattern_matches_files(self):
        self.assertTrue(prune.matches("mail/rmailsum", ["mail/rmail*.el"]))
        self.assertFalse(prune.matches("mail/sendmail", ["mail/rmail*.el"]))


class DependencyRescue(FakeTree):
    def test_unrequired_files_are_pruned(self):
        write(f"{self.lisp}/keep.el", "(provide 'keep)\n")
        write(f"{self.lisp}/apps/gone.el", "(provide 'gone)\n")
        self.manifest_is("apps/")
        pruned, rescued, _ = self.plan()
        self.assertEqual(pruned, {"apps/gone"})
        self.assertEqual(rescued, {})

    def test_a_top_level_require_rescues_the_file(self):
        write(f"{self.lisp}/keep.el", "(require 'gone)\n")
        write(f"{self.lisp}/apps/gone.el", "")
        self.manifest_is("apps/")
        pruned, rescued, _ = self.plan()
        self.assertEqual(pruned, set())
        self.assertEqual(rescued, {"apps/gone": "keep"})

    def test_rescue_follows_the_chain(self):
        write(f"{self.lisp}/keep.el", "(require 'a)\n")
        write(f"{self.lisp}/apps/a.el", "(require 'b)\n")
        write(f"{self.lisp}/apps/b.el", "")
        write(f"{self.lisp}/apps/c.el", "")
        self.manifest_is("apps/")
        pruned, _, _ = self.plan()
        self.assertEqual(pruned, {"apps/c"})

    def test_an_indented_require_is_lazy_and_does_not_rescue(self):
        write(f"{self.lisp}/keep.el", "(defun f ()\n  (require 'gone))\n")
        write(f"{self.lisp}/apps/gone.el", "")
        self.manifest_is("apps/")
        pruned, rescued, soft = self.plan()
        self.assertEqual(pruned, {"apps/gone"})
        self.assertIn("gone", soft["keep"])

    def test_require_inside_eval_and_compile_is_hard(self):
        write(f"{self.lisp}/keep.el", "(eval-and-compile\n  (require 'gone))\n")
        write(f"{self.lisp}/apps/gone.el", "")
        self.manifest_is("apps/")
        self.assertEqual(self.plan()[0], set())

    def test_compile_time_only_requires_are_ignored(self):
        write(f"{self.lisp}/keep.el", "(eval-when-compile (require 'gone))\n")
        write(f"{self.lisp}/apps/gone.el", "")
        self.manifest_is("apps/")
        self.assertEqual(self.plan()[0], {"apps/gone"})

    def test_autoload_registries_do_not_keep_files_alive(self):
        write(f"{self.lisp}/loaddefs.el", "(require 'gone)\n")
        write(f"{self.lisp}/foo-loaddefs.el", "(require 'gone)\n")
        write(f"{self.lisp}/apps/gone.el", "")
        self.manifest_is("apps/")
        self.assertEqual(self.plan()[0], {"apps/gone"})

    def test_obsolete_directory_does_not_keep_files_alive(self):
        write(f"{self.lisp}/obsolete/old.el", "(require 'gone)\n")
        write(f"{self.lisp}/apps/gone.el", "")
        self.manifest_is("apps/")
        self.assertEqual(self.plan()[0], {"apps/gone"})

    def test_bang_exception_is_never_pruned(self):
        write(f"{self.lisp}/apps/gone.el", "")
        write(f"{self.lisp}/apps/kept.el", "")
        self.manifest_is("apps/", "!apps/kept.el")
        self.assertEqual(self.plan()[0], {"apps/gone"})

    def test_preloaded_files_are_never_pruned(self):
        write(f"{self.lisp}/apps/baked.el", "")
        self.manifest_is("apps/")
        prune.preloaded = lambda: {"apps/baked"}
        pruned, rescued, _ = self.plan()
        self.assertEqual(pruned, set())
        self.assertIn("apps/baked", rescued)

    def test_plan_is_deterministic(self):
        for n in "abc":
            write(f"{self.lisp}/apps/{n}.el", "")
        write(f"{self.lisp}/keep.el", "(require 'b)\n")
        self.manifest_is("apps/")
        self.assertEqual(self.plan()[0], self.plan()[0])


class ApplyToInstalledTree(FakeTree):
    def install(self):
        inst = os.path.join(self.tmp, "install")
        self.lisp_out = f"{inst}/share/emacs/32.0/lisp"
        self.eln_out = f"{inst}/lib/emacs/32.0/native-lisp/abc"
        for rel in ("apps/gone", "keep"):
            for ext in (".el.gz", ".elc"):
                write(f"{self.lisp_out}/{rel}{ext}")
        write(f"{self.eln_out}/gone-1234abcd-5678ef01.eln")
        write(f"{self.eln_out}/keep-1234abcd-5678ef01.eln")
        return inst

    def test_apply_removes_source_bytecode_and_native_code(self):
        write(f"{self.lisp}/keep.el", "")
        write(f"{self.lisp}/apps/gone.el", "")
        self.manifest_is("apps/")
        inst = self.install()
        with contextlib.redirect_stdout(io.StringIO()):
            prune.cmd_apply(inst)
        self.assertFalse(glob.glob(f"{self.lisp_out}/apps/gone*"))
        self.assertFalse(os.path.exists(f"{self.lisp_out}/apps"), "empty dir removed")
        self.assertFalse(glob.glob(f"{self.eln_out}/gone-*"))
        self.assertTrue(os.path.exists(f"{self.lisp_out}/keep.elc"))
        self.assertTrue(glob.glob(f"{self.eln_out}/keep-*.eln"))

    def test_native_code_is_kept_when_a_kept_file_shares_the_name(self):
        write(f"{self.lisp}/other/dup.el", "")
        write(f"{self.lisp}/apps/dup.el", "")
        self.manifest_is("apps/")
        inst = os.path.join(self.tmp, "install")
        lisp_out = f"{inst}/share/emacs/32.0/lisp"
        eln = f"{inst}/lib/emacs/32.0/native-lisp/abc/dup-1234abcd-5678ef01.eln"
        write(f"{lisp_out}/apps/dup.elc"); write(f"{lisp_out}/other/dup.elc"); write(eln)
        with contextlib.redirect_stdout(io.StringIO()):
            prune.cmd_apply(inst)
        self.assertFalse(os.path.exists(f"{lisp_out}/apps/dup.elc"))
        self.assertTrue(os.path.exists(eln), "flat .eln name is shared, so it must stay")

    def test_apply_is_idempotent(self):
        write(f"{self.lisp}/keep.el", "")
        write(f"{self.lisp}/apps/gone.el", "")
        self.manifest_is("apps/")
        inst = self.install()
        with contextlib.redirect_stdout(io.StringIO()):
            prune.cmd_apply(inst)
            prune.cmd_apply(inst)
        self.assertTrue(os.path.exists(f"{self.lisp_out}/keep.elc"))

    def test_apply_refuses_a_directory_that_is_not_an_install(self):
        write(f"{self.lisp}/apps/gone.el", "")
        self.manifest_is("apps/")
        with self.assertRaises(SystemExit):
            prune.cmd_apply(os.path.join(self.tmp, "nothing-here"))


class RealManifest(unittest.TestCase):
    """Checks against the real prune.list and the real Emacs source."""

    def test_every_pattern_matches_at_least_one_file(self):
        if not os.path.isdir(prune.LISP):
            self.skipTest("emacs-src not present")
        files = prune.all_files()
        for pat in prune.read_manifest():
            bare = pat.lstrip("!")
            with self.subTest(pattern=pat):
                self.assertTrue(any(prune.matches(f, [bare]) for f in files),
                                f"{pat} matches nothing (typo?)")

    def test_exception_mm_archive_survives(self):
        if not os.path.isdir(prune.LISP):
            self.skipTest("emacs-src not present")
        self.assertFalse("gnus/mm-archive" in prune.plan()[1],
                         "the !gnus/mm-archive.el exception is missing from prune.list")

    def test_pruned_set_excludes_preloaded_files(self):
        if not os.path.isdir(prune.LISP) or not os.path.exists(prune.EMACS):
            self.skipTest("needs emacs-src and a built emacs")
        self.assertFalse(prune.plan()[1] & prune.preloaded())

    def test_installed_tree_matches_the_plan(self):
        inst = os.path.join(ROOT, "install")
        dirs = glob.glob(f"{inst}/share/emacs/*/lisp")
        if not dirs:
            self.skipTest("no install/ tree")
        pruned = prune.plan()[1]
        leftovers = [r for r in pruned if os.path.exists(f"{dirs[0]}/{r}.elc")]
        self.assertEqual(leftovers, [], "pruned files still installed; run ./build.sh prune")
        self.assertTrue(os.path.exists(f"{dirs[0]}/gnus/mm-archive.elc"))


if __name__ == "__main__":
    unittest.main()
