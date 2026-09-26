"""The portable bundles: the build scripts, and (when a bundle has been built) what is inside it.

Building a bundle takes minutes and needs the network, so tests that open one skip unless
dist/custom-emacs-windows-x64.zip exists (./build.sh dist windows).  A bundle that is older
than the settings in the repo is reported as stale: rebuild it before handing it out.
"""
import glob
import os
import subprocess
import unittest
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ZIP = os.path.join(ROOT, "dist", "custom-emacs-windows-x64.zip")
TOP = "custom-emacs-windows-x64/"
CONFIG_FILES = ["early-init.el", "init.el", "fastfind.el", "startpage.el"]


class Scripts(unittest.TestCase):
    def test_build_scripts_have_valid_syntax_and_are_executable(self):
        for s in ["tools/dist-windows.sh", "tools/test-windows.sh"]:
            with self.subTest(script=s):
                p = os.path.join(ROOT, s)
                self.assertTrue(os.access(p, os.X_OK))
                r = subprocess.run(["bash", "-n", p], capture_output=True, text=True)
                self.assertEqual(r.returncode, 0, r.stderr)

    def test_build_sh_knows_the_dist_command(self):
        r = subprocess.run([os.path.join(ROOT, "build.sh"), "dist"], capture_output=True, text=True)
        self.assertEqual(r.returncode, 2)
        self.assertIn("dist windows", r.stderr)

    def test_the_bundle_is_never_committed(self):
        with open(os.path.join(ROOT, ".gitignore")) as fh:
            self.assertIn("/dist/", fh.read())

    def test_the_launcher_source_passes_the_arguments_on_and_sets_the_settings_folder(self):
        with open(os.path.join(ROOT, "tools", "windows-launcher.c")) as fh:
            src = fh.read()
        for needle in ["--init-directory=", "runemacs.exe", "GetCommandLineW", "CUSTOM_EMACS_PORTABLE",
                       "tools\\\\git\\\\cmd", "tools\\\\rg"]:
            with self.subTest(needle=needle):
                self.assertIn(needle, src)

    def test_the_launcher_compiles_to_a_windows_gui_program(self):
        zig = os.path.join(ROOT, "dist", ".venv", "bin", "python")
        if not os.path.exists(zig):
            self.skipTest("no dist/.venv (./build.sh dist windows creates it)")
        out = os.path.join(ROOT, "dist", "cache", "launcher-test.exe")
        os.makedirs(os.path.dirname(out), exist_ok=True)
        r = subprocess.run([zig, "-m", "ziglang", "cc", "-target", "x86_64-windows-gnu", "-municode", "-O2", "-s",
                            "-Wl,--subsystem,windows", os.path.join(ROOT, "tools", "windows-launcher.c"), "-o", out],
                           capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stderr)
        with open(out, "rb") as fh:
            data = fh.read(2)
        self.assertEqual(data, b"MZ")                    # a Windows program
        os.remove(out)


@unittest.skipUnless(os.path.exists(ZIP), "no Windows bundle built (./build.sh dist windows)")
class WindowsBundle(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.z = zipfile.ZipFile(ZIP)
        cls.names = set(cls.z.namelist())

    @classmethod
    def tearDownClass(cls):
        cls.z.close()

    def test_everything_needed_to_run_is_inside(self):
        for f in ["Emacs.exe", "README.txt", "emacs/bin/emacs.exe", "emacs/bin/runemacs.exe",
                  "emacs/bin/emacsclient.exe", "emacs/bin/libtree-sitter-0.26.dll",
                  "tools/git/cmd/git.exe", "tools/git/usr/bin/sh.exe", "tools/rg/rg.exe",
                  "config/tree-sitter/libtree-sitter-java.dll", "config/tree-sitter/libtree-sitter-rust.dll"]:
            with self.subTest(file=f):
                self.assertIn(TOP + f, self.names)

    def test_settings_are_exactly_the_repo_settings(self):
        for f in CONFIG_FILES:
            with self.subTest(file=f):
                with open(os.path.join(ROOT, "config", f), "rb") as fh:
                    self.assertEqual(self.z.read(TOP + "config/" + f), fh.read(),
                                     f"{f} in the bundle differs from config/{f}: rebuild the bundle")

    def test_evil_and_magit_are_there_and_compiled(self):
        for pkg in ["evil", "magit", "magit-section", "with-editor", "llama"]:
            with self.subTest(package=pkg):
                self.assertTrue(any(n.startswith(f"{TOP}config/elpa/{pkg}-") and n.endswith(".elc")
                                    for n in self.names), f"{pkg} has no compiled files")

    def test_no_personal_state_is_shipped(self):
        for n in self.names:
            base = n[len(TOP):] if n.startswith(TOP) else n
            with self.subTest(file=base):
                self.assertFalse(base.startswith("config/") and os.path.basename(base) in
                                 {"recentf.eld", "recents.eld", "history", "custom.el", "places", "session"},
                                 "personal history must not be in a bundle")
                self.assertFalse(base.startswith("config/backups/") or base.startswith("config/fastfind/"))

    def test_packages_are_compiled_for_the_bundled_emacs_not_the_build_here(self):
        # .elc files carry the version of the Emacs that made them; ours is 32, the bundle runs 31
        for n in self.names:
            if n.startswith(TOP + "config/elpa/magit-4") and n.endswith("magit-mode.elc"):
                head = self.z.read(n)[:200]
                self.assertIn(b"Compiled", head)
                self.assertNotIn(b"Emacs 32", head)
                return
        self.fail("magit-mode.elc not found")

    def test_the_zip_has_a_sane_size_and_no_junk(self):
        size = os.path.getsize(ZIP)
        self.assertGreater(size, 60 * 1024 * 1024)
        self.assertLess(size, 400 * 1024 * 1024)
        self.assertFalse([n for n in self.names if "__pycache__" in n or n.endswith(".part")])

    def test_licenses_travel_with_the_programs(self):
        self.assertIn(TOP + "tools/git/LICENSE.txt", self.names)
        self.assertTrue(any(n.startswith(TOP + "emacs/share/emacs/31.1/etc/COPYING") for n in self.names))


if __name__ == "__main__":
    unittest.main()
