/* Emacs.exe: the one-click launcher for the portable Windows bundle.
 *
 * Finds the folder it lives in, puts the bundled Git and ripgrep first on PATH, points
 * Emacs at the bundled settings (config\), and starts it without a console window.
 * Any files or options given to Emacs.exe are passed on to Emacs.
 *
 * Built by tools/dist-windows.sh with zig cc (a cross compiler): no Windows needed.
 */
#ifndef UNICODE
#define UNICODE
#endif
#ifndef _UNICODE
#define _UNICODE
#endif
#include <windows.h>
#include <wchar.h>

static wchar_t *skip_program_name(wchar_t *cmd) {
  if (*cmd == L'"') { cmd++; while (*cmd && *cmd != L'"') cmd++; if (*cmd) cmd++; }
  else while (*cmd && *cmd != L' ' && *cmd != L'\t') cmd++;
  while (*cmd == L' ' || *cmd == L'\t') cmd++;
  return cmd;
}

int WINAPI wWinMain(HINSTANCE inst, HINSTANCE prev, PWSTR cmdline, int show) {
  wchar_t self[MAX_PATH * 2], home[MAX_PATH * 2];
  DWORD n = GetModuleFileNameW(NULL, self, MAX_PATH * 2);
  if (n == 0 || n >= MAX_PATH * 2) return 1;
  wchar_t *slash = wcsrchr(self, L'\\');
  if (!slash) return 1;
  *slash = 0;                       /* self is now the folder holding Emacs.exe */
  wcscpy(home, self);

  /* PATH: bundled Git (for Magit) and ripgrep (fast search) come first. */
  wchar_t oldpath[32768];
  DWORD len = GetEnvironmentVariableW(L"PATH", oldpath, 32768);
  if (len == 0 || len >= 32768) oldpath[0] = 0;
  wchar_t newpath[32768 + 1024];
  swprintf(newpath, 32768 + 1024, L"%s\\tools\\git\\cmd;%s\\tools\\git\\usr\\bin;%s\\tools\\rg;%s\\emacs\\bin;%s",
           self, self, self, self, oldpath);
  SetEnvironmentVariableW(L"PATH", newpath);
  SetEnvironmentVariableW(L"CUSTOM_EMACS_PORTABLE", L"1");

  /* Make "~" mean the user's profile folder, like it does in a normal shell. */
  wchar_t tmp[MAX_PATH];
  if (GetEnvironmentVariableW(L"HOME", tmp, MAX_PATH) == 0) {
    wchar_t up[MAX_PATH * 2];
    if (GetEnvironmentVariableW(L"USERPROFILE", up, MAX_PATH * 2) > 0)
      SetEnvironmentVariableW(L"HOME", up);
  }

  wchar_t *args = skip_program_name(GetCommandLineW());
  wchar_t cmd[32768];
  swprintf(cmd, 32768, L"\"%s\\emacs\\bin\\runemacs.exe\" \"--init-directory=%s\\config\" %s", self, home, args);

  STARTUPINFOW si = { sizeof si };
  PROCESS_INFORMATION pi;
  if (!CreateProcessW(NULL, cmd, NULL, NULL, FALSE, 0, NULL, self, &si, &pi)) {
    MessageBoxW(NULL, L"Could not start emacs\\bin\\runemacs.exe.\n\nKeep Emacs.exe next to the folders emacs, config and tools; do not move it alone.",
                L"Custom Emacs", MB_OK | MB_ICONERROR);
    return 1;
  }
  CloseHandle(pi.hThread);
  CloseHandle(pi.hProcess);
  return 0;
}
