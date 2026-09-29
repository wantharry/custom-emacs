"""The portable bundles: the build scripts, and (when a bundle has been built) what is inside it.

Building a bundle takes minutes and needs the network, so tests that open one skip unless
dist/custom-emacs-windows-x64.zip exists (./build.sh dist windows).  A bundle that is older
than the settings in the repo is reported as stale: rebuild it before handing it out.
"""
import glob
import os
import re
import subprocess
import unittest
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ZIP = os.path.join(ROOT, "dist", "custom-emacs-windows-x64.zip")
TOP = ""  # the zip has no wrapping top-level folder (fixed 2026-09-27: it doubled on Windows' own
          # "Extract All", which proposes a same-named destination folder)
CONFIG_FILES = ["early-init.el", "init.el", "fastfind.el", "startpage.el", "docsbuffer.el", "gitfolders.el", "llm.el", "llm-council.el", "shortcuts.el", "dictate.el"]

LINUX_ZIP = os.path.join(ROOT, "dist", "custom-emacs-linux-x86_64.zip")
LINUX_TARBALL = os.path.join(ROOT, "dist", "custom-emacs-linux-x86_64.tar.gz")
LINUX_NAME = "custom-emacs-linux-x86_64"


class Scripts(unittest.TestCase):
    def test_build_scripts_have_valid_syntax_and_are_executable(self):
        for s in ["tools/dist-windows.sh", "tools/test-windows.sh", "tools/dist-linux.sh"]:
            with self.subTest(script=s):
                p = os.path.join(ROOT, s)
                self.assertTrue(os.access(p, os.X_OK))
                r = subprocess.run(["bash", "-n", p], capture_output=True, text=True)
                self.assertEqual(r.returncode, 0, r.stderr)

    def test_build_sh_knows_the_dist_command(self):
        r = subprocess.run([os.path.join(ROOT, "build.sh"), "dist"], capture_output=True, text=True)
        self.assertEqual(r.returncode, 2)
        self.assertIn("dist windows", r.stderr)
        self.assertIn("linux", r.stderr)

    def test_the_bundle_is_never_committed(self):
        with open(os.path.join(ROOT, ".gitignore")) as fh:
            self.assertIn("/dist/", fh.read())

    def test_the_launcher_source_passes_the_arguments_on_and_sets_the_settings_folder(self):
        with open(os.path.join(ROOT, "tools", "windows-launcher.c")) as fh:
            src = fh.read()
        for needle in ["--init-directory=", "runemacs.exe", "GetCommandLineW", "CUSTOM_EMACS_PORTABLE", "CUSTOM_EMACS_HOME", "JAVA_HOME",
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
        for f in ["Emacs.exe", "README.txt", "README.md", "emacs/bin/emacs.exe", "emacs/bin/runemacs.exe",
                  "emacs/bin/emacsclient.exe", "emacs/bin/libtree-sitter-0.26.dll",
                  "tools/git/cmd/git.exe", "tools/git/usr/bin/sh.exe", "tools/rg/rg.exe", "tools/fd/fd.exe",
                  "tools/jdtls/config_win/config.ini", "docs/SEARCHING.md", "docs/EGLOT.md",
                  "config/tree-sitter/libtree-sitter-java.dll", "config/tree-sitter/libtree-sitter-rust.dll",
                  "config/tree-sitter/libtree-sitter-html.dll", "config/tree-sitter/libtree-sitter-css.dll",
                  "config/tree-sitter/libtree-sitter-javascript.dll", "config/tree-sitter/libtree-sitter-jsdoc.dll",
                  "config/tree-sitter/libtree-sitter-typescript.dll", "config/tree-sitter/libtree-sitter-tsx.dll",
                  "config/tree-sitter/libtree-sitter-json.dll"]:
            with self.subTest(file=f):
                self.assertIn(TOP + f, self.names)

    def test_settings_are_exactly_the_repo_settings(self):
        for f in CONFIG_FILES:
            with self.subTest(file=f):
                with open(os.path.join(ROOT, "config", f), "rb") as fh:
                    self.assertEqual(self.z.read(TOP + "config/" + f), fh.read(),
                                     f"{f} in the bundle differs from config/{f}: rebuild the bundle")

    def test_every_doc_guide_is_included_for_the_in_emacs_docs_buffer(self):
        real = {f"docs/{n}" for n in os.listdir(os.path.join(ROOT, "docs")) if n.endswith(".md")}
        self.assertTrue(real, "no docs/*.md found in the repository itself")
        for f in real:
            with self.subTest(file=f):
                self.assertIn(TOP + f, self.names)

    def test_the_java_language_server_and_its_launcher_jar_are_there(self):
        self.assertTrue(any(n.startswith(TOP + "tools/jdtls/plugins/org.eclipse.equinox.launcher_") and n.endswith(".jar")
                            for n in self.names), "no jdtls launcher jar")
        self.assertTrue(any(n.startswith(TOP + "tools/jdtls/plugins/org.eclipse.jdt.ls.core_") for n in self.names))

    def test_no_jdk_is_bundled(self):
        # Java needs its own JDK installed, the same as Rust needs rust-analyzer installed;
        # see my/bundled-jdtls-command in config/init.el.
        self.assertFalse([n for n in self.names if n.startswith(TOP + "tools/jdk/")], "no tools/jdk/ should be shipped")

    def test_evil_and_magit_are_there_and_compiled(self):
        for pkg in ["evil", "magit", "magit-section", "with-editor", "llama", "treemacs", "dash", "hydra", "pfuture", "consult"]:
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


@unittest.skipUnless(os.path.exists(LINUX_ZIP), "no Linux bundle built (./build.sh dist linux)")
class LinuxBundle(unittest.TestCase):
    """The Linux bundle is the same Emacs 32 this repo itself builds, just relocated (patched
    RPATH) with its shared libraries copied alongside it --- unlike the Windows bundle, which
    uses a different, official prebuilt Emacs and so must recompile every package for it. That
    means the repo's own config/elpa is already binary-compatible and is copied verbatim (see
    tools/dist-linux.sh); there is no separate "compiled for the right Emacs" concern to test
    here the way WindowsBundle has one."""

    @classmethod
    def setUpClass(cls):
        cls.z = zipfile.ZipFile(LINUX_ZIP)
        cls.names = set(cls.z.namelist())

    @classmethod
    def tearDownClass(cls):
        cls.z.close()

    def test_the_zip_has_no_wrapping_top_level_folder(self):
        # Extracting it (a file manager's "Extract Here", which proposes a same-named
        # destination folder) must not double-nest --- the same bug already fixed for the
        # Windows zip; see the comment above `TOP` and tools/dist-linux.sh's own "== archives".
        self.assertFalse([n for n in self.names if n.startswith(LINUX_NAME + "/")],
                         "the zip must not wrap everything in one more custom-emacs-linux-x86_64/ folder")

    def test_everything_needed_to_run_is_inside(self):
        for f in ["Emacs", "README.txt", "README.md", "DISTRIBUTION.md", "install-desktop-entry.sh",
                  "app/bin/emacs", "app/bin/emacsclient", "tools/rg",
                  "config/tree-sitter/libtree-sitter-java.so", "config/tree-sitter/libtree-sitter-rust.so",
                  "config/tree-sitter/libtree-sitter-html.so", "config/tree-sitter/libtree-sitter-css.so",
                  "config/tree-sitter/libtree-sitter-javascript.so", "config/tree-sitter/libtree-sitter-json.so",
                  "share/glib-2.0/schemas/gschemas.compiled", "share/fonts/DejaVuSansMono.ttf"]:
            with self.subTest(file=f):
                self.assertIn(f, self.names)

    def test_settings_are_exactly_the_repo_settings(self):
        for f in CONFIG_FILES:
            with self.subTest(file=f):
                with open(os.path.join(ROOT, "config", f), "rb") as fh:
                    self.assertEqual(self.z.read("config/" + f), fh.read(),
                                     f"{f} in the Linux bundle differs from config/{f}: rebuild it (./build.sh dist linux)")

    def test_every_doc_guide_is_included_for_the_in_emacs_docs_buffer(self):
        real = {f"docs/{n}" for n in os.listdir(os.path.join(ROOT, "docs")) if n.endswith(".md")}
        self.assertTrue(real, "no docs/*.md found in the repository itself")
        for f in real:
            with self.subTest(file=f):
                self.assertIn(f, self.names)

    def test_evil_and_magit_are_there_and_compiled(self):
        for pkg in ["evil", "magit", "magit-section", "with-editor", "llama", "treemacs", "dash", "hydra", "pfuture", "consult"]:
            with self.subTest(package=pkg):
                self.assertTrue(any(n.startswith(f"config/elpa/{pkg}-") and n.endswith(".elc")
                                    for n in self.names), f"{pkg} has no compiled files")

    def test_no_personal_state_is_shipped(self):
        for n in self.names:
            with self.subTest(file=n):
                self.assertFalse(n.startswith("config/") and os.path.basename(n) in
                                 {"recentf.eld", "recents.eld", "history", "custom.el", "places", "session"},
                                 "personal history must not be in a bundle")
                self.assertFalse(n.startswith("config/backups/") or n.startswith("config/fastfind/"))

    def test_the_zip_has_a_sane_size_and_no_junk(self):
        size = os.path.getsize(LINUX_ZIP)
        self.assertGreater(size, 60 * 1024 * 1024)
        self.assertLess(size, 400 * 1024 * 1024)
        self.assertFalse([n for n in self.names if "__pycache__" in n or n.endswith(".part")])

    def test_no_glibc_or_gpu_driver_libraries_are_bundled(self):
        # These must come from the machine itself (see the `skip` regexp in tools/dist-
        # linux.sh): bundling glibc risks a mismatch with the kernel/loader on the machine
        # that runs it, and GPU drivers are inherently machine-specific.
        bad = re.compile(r'^lib/(ld-linux.*|libc|libm|libdl|libpthread|libGL|libEGL|libvulkan.*)\.so')
        self.assertFalse([n for n in self.names if bad.match(n)], "glibc/driver libraries must not be bundled")


@unittest.skipUnless(os.path.exists(LINUX_TARBALL), "no Linux bundle built (./build.sh dist linux)")
class LinuxTarball(unittest.TestCase):
    def test_the_tarball_wraps_everything_in_one_top_level_folder(self):
        # Unlike the zip (see LinuxBundle.test_the_zip_has_no_wrapping_top_level_folder), a
        # .tar.gz is conventionally extracted with `tar -xzf`, which never creates its own
        # destination folder --- so wrapping it in one top-level folder here is the normal,
        # expected, safe convention, not the same double-nesting risk a zip has.
        names = subprocess.run(["tar", "-tzf", LINUX_TARBALL], capture_output=True, text=True, check=True).stdout.splitlines()
        self.assertTrue(names, "empty tarball")
        self.assertTrue(all(n.startswith(LINUX_NAME + "/") or n == LINUX_NAME + "/" for n in names),
                        "every entry should be inside one custom-emacs-linux-x86_64/ folder")


if __name__ == "__main__":
    unittest.main()
