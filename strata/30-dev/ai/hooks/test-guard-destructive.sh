#!/usr/bin/env bash
# Tests for guard-destructive.py. Runs on Linux or under Git Bash on Windows.
# Uses a fake home (/home/tester) and REPOS (/home/tester/REPOS) so the results
# do not depend on the machine.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
hook="$here/guard-destructive.py"
py="${PYTHON:-python3}"
command -v "$py" >/dev/null 2>&1 || { echo "python3 not found" >&2; exit 1; }

# Under Git Bash, stop MSYS from rewriting /home/... arguments into Windows paths,
# and hand Windows Python the hook's path in Windows form.
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*)
    hook="$(cygpath -w "$hook")"
    export MSYS_NO_PATHCONV=1 ;;
esac
[ -f "$hook" ] || { echo "hook not found: $hook" >&2; exit 1; }

H=/home/tester
REPO=$H/REPOS/pala
pass=0 fail=0 n=0

# Runs the hook on stdin with a fake environment. The environment is set inside
# Python because Git Bash rewrites /home/... in the env vars it passes on.
# mode=raise replaces the command parser with one that throws, to test fail-closed.
run_hook() {  # run_hook <mode normal|raise>
  "$py" -c 'import importlib.util, os, sys
os.environ.update(HOME=sys.argv[1], TMPDIR="/tmp", REPOS=sys.argv[1] + "/REPOS", GUARD_ALLOW_ROOTS="")
spec = importlib.util.spec_from_file_location("guard", sys.argv[2])
guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guard)
if sys.argv[3] == "raise":
    def boom(*a, **k):
        raise RuntimeError("simulated internal error")
    guard.split_commands = boom
sys.exit(guard.main())' "$H" "$hook" "$1"
}

record() {  # record <expect> <label> <shown command> <exit code> <stderr>
  local expect="$1" label="$2" shown="$3" code="$4" err="$5" got mark
  n=$((n + 1))
  # Exit 2 alone is not enough: Python also exits 2 when it cannot open the script.
  case "$code" in
    0) got=allow ;;
    2) case "$err" in
         "Blocked by guard-destructive hook:"*) got=BLOCK ;;
         "guard-destructive: internal error"*) got=INTERNAL ;;
         *) got=ERR2 ;;
       esac ;;
    *) got="ERR$code" ;;
  esac
  if [ "$got" = "$expect" ]; then pass=$((pass + 1)); mark=ok; else fail=$((fail + 1)); mark=FAIL; fi
  printf '%-4s %-8s %-46s [%s]\n' "$mark" "$got" "$label" "$(printf '%s' "$shown" | tr '\n' ' ' | cut -c1-70)"
  if [ "$mark" = FAIL ] && [ -n "$err" ]; then printf '       stderr: %s\n' "$err"; fi
}

t() {  # t <expect allow|BLOCK|INTERNAL> <label> <cwd> <command> [tool] [mode]
  local expect="$1" label="$2" cwd="$3" cmd="$4" tool="${5:-Bash}" mode="${6:-normal}" json code err
  json=$(TOOL="$tool" CMD="$cmd" CWD="$cwd" "$py" -c 'import json,os; print(json.dumps({"tool_name": os.environ["TOOL"], "tool_input": {"command": os.environ["CMD"]}, "cwd": os.environ["CWD"]}))')
  set +e
  err=$(printf '%s' "$json" | run_hook "$mode" 2>&1 >/dev/null)
  code=$?
  set -e
  record "$expect" "$label" "$cmd" "$code" "$err"
}

t_raw() {  # t_raw <expect> <label> <raw stdin>
  local code err
  set +e
  err=$(printf '%s' "$3" | run_hook normal 2>&1 >/dev/null)
  code=$?
  set -e
  record "$1" "$2" "$3" "$code" "$err"
}

echo "== original 41 cases =="
# --- quoted paths with spaces ---
t allow "quoted path with spaces, inside REPOS"   "$REPO" "rm -rf \"$REPO/build output\""
t BLOCK "quoted path with spaces, outside"        "$REPO" "rm -rf \"$H/My Documents\""
t allow "single-quoted relative path, inside"     "$REPO" "rm -rf 'my out dir'"
t BLOCK "single-quoted absolute path, outside"    "$REPO" "rm -rf '/opt/Some App'"
# --- commit messages and text that mention push -f ---
t allow "commit message with push -f"             "$REPO" 'git commit -m "docs: never push -f to main"'
t allow "single-quoted message with --force"      "$REPO" "git commit -m 'git push --force is banned'"
t allow "echo text with git push --force"         "$REPO" 'echo "run git push --force later" && git status'
t allow "heredoc commit message"                  "$REPO" $'git commit -F - <<\'EOF\'\ngit push -f is banned here\nrm -rf / is also banned\nEOF'
t allow "subshell inside a quoted message"        "$REPO" "git commit -m \"\$(printf 'push -f\\nrm -rf /')\""
# --- real force pushes ---
t BLOCK "git push --force"                        "$REPO" 'git push --force'
t BLOCK "git -C ... push --force"                 "$REPO" "git -C $REPO push origin main --force"
t BLOCK "git push -uf"                            "$REPO" 'git push -uf origin main'
t BLOCK "git push +refspec"                       "$REPO" 'git push origin +main'
t BLOCK "chained git push -f"                     "$REPO" 'git status && git push -f'
t BLOCK "second line git push --force"            "$REPO" $'git status\ngit push --force'
t BLOCK "env wrapper git push -f"                 "$REPO" 'env FOO=1 git push -f'
t BLOCK "bash -c wrapper"                         "$REPO" 'bash -c "git push --force"'
t BLOCK "command after a heredoc"                 "$REPO" $'cat <<EOF > notes.txt\nhello\nEOF\ngit push --force'
t allow "force-with-lease (left to the ask rule)" "$REPO" 'git push --force-with-lease'
t allow "push option value is not a flag"         "$REPO" 'git push -o ci.skip origin main'
# --- recursive deletes: scratch dir and outside ---
t allow "rm -rf under the Claude scratch dir"     "$H"    'rm -rf /tmp/claude/abc/scratchpad/old'
uid=$("$py" -c 'import os; print(os.getuid() if hasattr(os, "getuid") else "")')
if [ -n "$uid" ]; then
  t allow "rm -rf under the per-user scratch dir"  "$H"    "rm -rf /tmp/claude-$uid/abc/scratchpad/old"
  t BLOCK "rm -rf under another user's scratch"    "$H"    "rm -rf /tmp/claude-$((uid + 1))/abc"
fi
t BLOCK "rm -rf in home, outside REPOS"           "$REPO" "rm -rf $H/guard-test"
t BLOCK "rm -rf under /etc"                       "$REPO" 'rm -rf /etc/guard-test'
t BLOCK "rm -rf /"                                "$REPO" 'rm -rf /'
t BLOCK "sudo rm -rf"                             "$REPO" 'sudo rm -rf /var/lib/x'
t BLOCK "VAR=value prefix rm -rf"                 "$REPO" 'FOO=bar rm -rf /opt/x'
t BLOCK "sh -c wrapper rm -rf"                    "$REPO" "sh -c 'rm -rf /opt/x'"
t BLOCK "rm -rf after --"                         "$REPO" 'rm -rf -- /opt/x'
t BLOCK "rm --recursive"                          "$REPO" 'rm --recursive /var/tmp/x'
# --- recursive deletes: inside, and edge cases ---
t allow "rm -r -f relative, inside"               "$REPO" 'rm -r -f ./out'
t allow "rm -rf -- relative, inside"              "$REPO" 'rm -rf -- ./dist'
t allow "redirect target not taken as a path"     "$REPO" 'rm -rf build 2>/dev/null'
t allow "wildcard inside a repo"                  "$REPO" "rm -rf $REPO/build/*"
t BLOCK "wildcard at the repo root"               "$REPO" "rm -rf $H/REPOS/*"
t BLOCK "relative path climbing out"              "$REPO" 'rm -rf ../../..'
t BLOCK "relative path from cwd outside"          "$H"    'rm -rf build'
t BLOCK "\$HOME target outside REPOS"             "$REPO" 'rm -rf "$HOME/x"'
t BLOCK "home path with ~"                        "$REPO" 'rm -rf ~/x'
t BLOCK "command substitution"                    "$REPO" "echo \$(rm -rf $H/x)"
t allow "non-recursive delete anywhere"           "$H"    "rm -f $H/a.txt"
t allow "other tool is ignored"                   "/"     'ignored' Read

echo "== requested cases =="
t allow "echo \$PATH"                             "$REPO" 'echo $PATH'
t allow "cd into a \$HOME path"                   "$REPO" 'cd "$HOME/REPOS/x"'
t allow "for loop over *"                         "$REPO" 'for f in *; do echo "$f"; done'
t allow "rm -rf \$HOME/REPOS target"              "$REPO" 'rm -rf "$HOME/REPOS/x/build"'
t allow "rm -rf \$REPOS target"                   "$REPO" 'rm -rf "$REPOS/x/build"'
t BLOCK "true; git push -f"                       "$REPO" 'true; git push -f'
t BLOCK "cd x && rm -rf /"                        "$REPO" 'cd x && rm -rf /'
t BLOCK "(rm -rf ~) subshell"                     "$REPO" '(rm -rf ~)'
t BLOCK "rm -rf / in backticks"                   "$REPO" 'echo `rm -rf /`'
t BLOCK "pipeline into xargs rm -rf"              "$REPO" 'find . -name node_modules | xargs rm -rf'
t_raw INTERNAL "malformed JSON input"                     '{"tool_name": "Bash", "tool_input": {"command": "ls"'
t INTERNAL "simulated internal exception"         "$REPO" 'ls' Bash raise

echo "== extra cases =="
t allow "\${HOME} brace form, inside REPOS"       "$REPO" 'rm -rf "${HOME}/REPOS/x/build"'
t BLOCK "variable set earlier in the command"     "$REPO" 'D=/opt/x; rm -rf "$D"'
t BLOCK "rm -rf / inside a for loop"              "$REPO" 'for f in x; do rm -rf /; done'
t BLOCK "\$(rm ...) inside double quotes"         "$REPO" 'echo "$(rm -rf /opt/x)"'
t allow "commit message via \$(cat <<'EOF')"      "$REPO" $'git commit -m "$(cat <<\'EOF\'\nfix: never git push -f\n\nrm -rf / stays banned\nEOF\n)"'
t BLOCK "xargs -0 rm -rf"                         "$REPO" 'printf "%s\0" a b | xargs -0 rm -rf'
t_raw INTERNAL "empty input"                              ''
t_raw INTERNAL "JSON that is not an object"               '["Bash"]'

echo "passed: $pass  failed: $fail  of $n"
[ "$fail" -eq 0 ]
