"""End-to-end tests of Emacs running in a real terminal (`emacs -nw`), driven with tmux.

Real keystrokes go through a real pseudo-terminal, so this covers what --batch cannot:
terminal key handling (Ctrl and Meta sequences), the screen that is actually drawn,
popups, and colors.  Runs only with RUN_TUI_TESTS=1 (tests/run-all.sh --gui) and tmux.
"""
import os
import re
import shutil
import subprocess
import tempfile
import time
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_install = os.path.join(ROOT, "install", "bin", "emacs")
EMACS = os.environ.get("EMACS_BIN") or (_install if os.path.exists(_install)
                                        else os.path.join(ROOT, "build", "src", "emacs"))
SOCK = f"emacs-tui-{os.getpid()}"


def tmux(*args, **kw):
    return subprocess.run(["tmux", "-L", SOCK, *args], capture_output=True, text=True, **kw)


@unittest.skipUnless(os.environ.get("RUN_TUI_TESTS") and shutil.which("tmux"),
                     "terminal tests: set RUN_TUI_TESTS=1 (tests/run-all.sh --gui) and install tmux")
class TerminalEmacs(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp(prefix="tui-")
        self.cfg = os.path.join(self.tmp, "cfg")
        os.makedirs(self.cfg)
        for f in ("early-init.el", "init.el", "fastfind.el"):
            shutil.copy(os.path.join(ROOT, "config", f), self.cfg)
        for d in ("elpa", "tree-sitter"):
            src = os.path.join(ROOT, "config", d)
            if os.path.isdir(src):
                os.symlink(src, os.path.join(self.cfg, d))

    def tearDown(self):
        tmux("kill-server")
        shutil.rmtree(self.tmp, ignore_errors=True)

    # -- helpers ------------------------------------------------------------
    def make_file(self, name, content):
        path = os.path.join(self.tmp, name)
        with open(path, "w") as fh:
            fh.write(content)
        return path

    def read(self, path):
        with open(path) as fh:
            return fh.read()

    def start(self, *files):
        cmd = f"TERM=xterm-256color {EMACS} -nw --init-directory={self.cfg} " + " ".join(files)
        r = tmux("new-session", "-d", "-s", "t", "-x", "110", "-y", "32", cmd)
        self.assertEqual(r.returncode, 0, r.stderr)

    def screen(self, ansi=False):
        args = ["capture-pane", "-t", "t", "-p"] + (["-e"] if ansi else [])
        return tmux(*args).stdout

    def keys(self, *k):
        tmux("send-keys", "-t", "t", *k)

    def text(self, s):
        tmux("send-keys", "-t", "t", "-l", s)

    def wait_for(self, needle, timeout=8.0, ansi=False):
        """Wait until NEEDLE (str or regex) appears on screen; return the screen."""
        end = time.time() + timeout
        pat = re.compile(needle if isinstance(needle, str) else needle.pattern, re.M)
        scr = ""
        while time.time() < end:
            scr = self.screen(ansi)
            if pat.search(scr):
                return scr
            time.sleep(0.1)
        self.fail(f"never saw {needle!r} on screen; last screen:\n{scr}")

    # -- tests --------------------------------------------------------------
    def test_a_file_opens_read_only_with_line_numbers_and_a_mode_line(self):
        f = self.make_file("a.txt", "hello world\n")
        self.start(f)
        scr = self.wait_for(r"^\s*1 hello world")
        self.assertIn("%%", scr, "mode line should show the read-only flag")
        self.assertIn("a.txt", scr)

    def test_typing_is_blocked_and_the_screen_says_so(self):
        f = self.make_file("a.txt", "hello\n")
        self.start(f)
        self.wait_for("hello")
        self.text("xyz")
        scr = self.wait_for("read-only")
        self.assertNotIn("xyzhello", scr)
        self.assertEqual(self.read(f), "hello\n")

    def test_the_edit_chord_allows_typing_saving_and_locking(self):
        f = self.make_file("a.txt", "hello\n")
        self.start(f)
        self.wait_for("hello")
        self.keys("C-c", "e", "e")
        self.wait_for("Editing ON")
        self.text("HI ")
        scr = self.wait_for("HI hello")
        self.assertIn("**", scr, "mode line should show the modified flag")
        self.assertEqual(self.read(f), "hello\n", "nothing on disk before saving")
        self.keys("C-x", "C-s")
        self.wait_for("Wrote")
        self.assertEqual(self.read(f), "HI hello\n")
        self.keys("C-c", "e", "l")
        self.wait_for("Editing OFF")
        self.text("zz")
        scr = self.wait_for("read-only")
        self.assertNotIn("zzHI", scr)
        self.assertEqual(self.read(f), "HI hello\n")

    def test_c_x_c_q_only_shows_a_reminder(self):
        f = self.make_file("a.txt", "hello\n")
        self.start(f)
        self.wait_for("hello")
        self.keys("C-x", "C-q")
        self.wait_for("C-c e e")
        self.text("q")
        self.wait_for("read-only")

    def test_which_key_lists_the_chords_after_c_c_e(self):
        f = self.make_file("a.txt", "hello\n")
        self.start(f)
        self.wait_for("hello")
        self.keys("C-c", "e")
        scr = self.wait_for("allow-editing", timeout=8)
        self.assertIn("stop-editing", scr)

    def test_m_x_shows_a_vertical_list_of_candidates(self):
        f = self.make_file("a.txt", "hello\n")
        self.start(f)
        self.wait_for("hello")
        self.keys("M-x")
        self.text("eglo")
        scr = self.wait_for("eglot-manual")
        self.assertRegex(scr, r"(?m)^eglot\b")

    def make_project(self):
        proj = os.path.join(self.tmp, "proj")
        os.makedirs(os.path.join(proj, "src", "demo"))
        for n in ("Geometry", "Shape", "Circle"):
            with open(os.path.join(proj, "src", "demo", n + ".java"), "w") as fh:
                fh.write("class X {}\n")
        subprocess.run(["git", "init", "-q"], cwd=proj, check=True)
        subprocess.run(["git", "add", "-A"], cwd=proj, check=True)
        return proj

    def test_file_finder_lists_a_fuzzy_match_and_enter_opens_it(self):
        proj = self.make_project()
        first = os.path.join(proj, "src", "demo", "Shape.java")
        self.start(first)
        self.wait_for("class X")
        self.keys("C-c", "f", "f")
        self.wait_for("Find file \\(proj\\)")
        self.text("gmtry")
        scr = self.wait_for("src/demo/Geometry.java")
        self.assertNotIn("No matches", scr)
        self.keys("Enter")
        scr = self.wait_for("Geometry.java\\s+All")
        self.assertIn("Geometry.java", scr)

    def test_evil_toggle_and_it_still_cannot_edit_a_read_only_file(self):
        f = self.make_file("a.txt", "hello\n")
        self.start(f)
        self.wait_for("hello")
        self.keys("C-c", "v")
        self.wait_for("Evil mode enabled")
        self.wait_for("<N>")                       # normal state
        self.keys("i")
        self.wait_for("<I>")                       # insert state
        self.text("xx")
        self.keys("Escape")
        # A terminal reads ESC followed by another key as Meta, so wait for the
        # state indicator (as a person's typing pause would) before the next key.
        self.wait_for("<N>")
        self.assertEqual(self.read(f), "hello\n")
        self.keys("C-c", "v")
        self.wait_for("Evil mode disabled")

    def test_dired_lists_files_and_is_read_only(self):
        self.make_file("alpha.txt", "a\n")
        self.make_file("beta.txt", "b\n")
        self.start(self.tmp)                       # opening a directory starts Dired
        scr = self.wait_for("alpha.txt")
        self.assertIn("beta.txt", scr)
        self.assertIn("Dired", scr)
        self.assertIn("%%", scr)

    def test_source_code_is_drawn_in_color(self):
        f = self.make_file("A.java", "public class A { int x; }\n")
        self.start(f)
        raw = self.wait_for("class", ansi=True)
        line = next(l for l in raw.splitlines() if "class" in l)
        self.assertRegex(line, "\x1b\\[[0-9;]*m", "highlighted code should carry color escapes")

    def test_quitting_exits_cleanly(self):
        f = self.make_file("a.txt", "hello\n")
        self.start(f)
        self.wait_for("hello")
        self.keys("C-x", "C-c")
        end = time.time() + 6
        while time.time() < end and tmux("has-session", "-t", "t").returncode == 0:
            time.sleep(0.1)
        self.assertNotEqual(tmux("has-session", "-t", "t").returncode, 0, "Emacs should have exited")
        self.assertEqual(self.read(f), "hello\n")


if __name__ == "__main__":
    unittest.main()
