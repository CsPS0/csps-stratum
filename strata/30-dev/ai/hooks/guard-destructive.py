#!/usr/bin/env python3
"""PreToolUse hook for Claude Code on Linux (matcher: Bash).

Blocks git force pushes, and recursive deletes whose target is not inside an
allowed root. Commands are tokenized with shlex, so quoted text (commit
messages, echo arguments, here-documents) is never read as a command.
Command substitutions, $(...) and backticks, are checked as commands of their own.

Variables matter only for rm targets. Before a target is judged, $HOME, $TMPDIR,
$REPOS (also written ${NAME}) and a leading ~ are filled in from this hook's
environment. A target that still holds a variable, $(...) or backticks after that
is blocked.

Allowed roots: $HOME/REPOS, the Claude scratch directory (${TMPDIR:-/tmp}/claude,
or ${TMPDIR:-/tmp}/claude-<uid> as Claude Code names it on Linux), and any extra
roots in GUARD_ALLOW_ROOTS (colon-separated).

Exit 2 blocks the call (stderr goes back to Claude). Exit 0 means no decision.
The hook fails closed: malformed input or any internal error also exits 2.
"""
import json
import os
import posixpath
import re
import shlex
import sys

WRAPPERS = {"sudo", "env", "command", "exec", "nohup", "time", "builtin", "doas"}
KEYWORDS = {"do", "then", "else", "elif", "if", "while", "until", "!", "{", "}"}
EXPANDABLE = ("HOME", "TMPDIR", "REPOS")
GIT_OPTS_WITH_VALUE = {"-C", "-c", "--git-dir", "--work-tree", "--namespace", "--super-prefix", "--config-env"}
PUSH_OPTS_WITH_VALUE = {"-o", "--push-option", "--repo", "--receive-pack", "--exec"}
XARGS_OPTS_WITH_VALUE = {"-n", "-I", "-P", "-d", "-L", "-s", "-E", "-a", "--max-args", "--max-procs",
                         "--delimiter", "--max-lines", "--max-chars", "--eof", "--arg-file", "--replace"}
REDIRECTS = {">", ">>", "<", "<<", "<<<", ">&", "<&", "&>", "&>>", ">|", "<>"}
SEPARATORS = set(";&|()")
VAR_RE = re.compile(r"\$(?:\{(" + "|".join(EXPANDABLE) + r")\}|(" + "|".join(EXPANDABLE) + r")(?![A-Za-z0-9_]))")


class Blocked(Exception):
    pass


def allow_roots():
    home = os.environ.get("HOME", "")
    tmp = os.environ.get("TMPDIR") or "/tmp"
    roots = [posixpath.join(home, "REPOS"), posixpath.join(tmp, "claude")]
    if hasattr(os, "getuid"):  # not on Windows Python, where the suite may also run
        roots.append(posixpath.join(tmp, f"claude-{os.getuid()}"))
    roots += [r for r in os.environ.get("GUARD_ALLOW_ROOTS", "").split(":") if r]
    return [posixpath.normpath(r) for r in roots if r.startswith("/")]


# ---------- text preparation ----------

HEREDOC = re.compile(r"<<-?\s*(['\"]?)([A-Za-z_][A-Za-z0-9_]*)\1")


def strip_heredocs(text):
    """Drop here-document bodies so their lines are not read as commands."""
    out, lines, i = [], text.split("\n"), 0
    while i < len(lines):
        line = lines[i]
        out.append(line)
        delims = [m.group(2) for m in HEREDOC.finditer(line)]
        i += 1
        for d in delims:
            while i < len(lines) and lines[i].strip() != d:
                i += 1
            i += 1  # skip the delimiter line itself
    return "\n".join(out)


def matching_paren(text, start):
    """Index of the ')' that closes the '(' at text[start], honouring quotes."""
    depth, q, i = 0, "", start
    while i < len(text):
        c = text[i]
        if q == "'":
            q = "" if c == "'" else q
        elif c == "\\":
            i += 1
        elif q == '"':
            if c == '"':
                q = ""
        elif c in "'\"":
            q = c
        elif c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return -1


def preprocess(text):
    """Fill in known variables outside single quotes, and collect the bodies of
    $(...) and `...` (outside single quotes, so also inside double quotes)."""
    out, subs, q, i = [], [], "", 0
    while i < len(text):
        c = text[i]
        if q == "'":
            out.append(c)
            q = "" if c == "'" else q
            i += 1
            continue
        if c == "\\" and i + 1 < len(text):
            out.append(text[i:i + 2])
            i += 2
            continue
        if c == "$" and text.startswith("$(", i):
            j = matching_paren(text, i + 1)
            if j < 0:
                raise ValueError("unclosed $(")
            subs.append(text[i + 2:j])
            out.append(text[i:j + 1])
            i = j + 1
            continue
        if c == "`":
            j = text.find("`", i + 1)
            while j > 0 and text[j - 1] == "\\":
                j = text.find("`", j + 1)
            if j < 0:
                raise ValueError("unclosed backtick")
            subs.append(text[i + 1:j])
            out.append(text[i:j + 1])
            i = j + 1
            continue
        if c == "$":
            m = VAR_RE.match(text, i)
            if m:
                name = m.group(1) or m.group(2)
                value = os.environ.get(name)
                if value:
                    out.append(value)
                    i = m.end()
                    continue
        if c == '"':
            q = "" if q == '"' else '"'
        elif c == "'" and q == "":
            q = "'"
        out.append(c)
        i += 1
    return "".join(out), subs


def unquoted_newlines_to_semicolons(text):
    """shlex treats newlines as spaces; turn the unquoted ones into ';'."""
    out, q, i = [], "", 0
    while i < len(text):
        c = text[i]
        if q == "'":
            q = "" if c == "'" else q
        elif q == '"':
            if c == "\\" and i + 1 < len(text):
                out.append(c)
                i += 1
                c = text[i]
            elif c == '"':
                q = ""
        else:
            if c == "\\" and i + 1 < len(text) and text[i + 1] == "\n":
                i += 2
                continue
            if c in "'\"":
                q = c
            elif c == "\n":
                c = ";"
        out.append(c)
        i += 1
    return "".join(out)


def dynamic_words(text):
    """Words that still carry $ or ` outside single quotes after preprocessing."""
    found = set()
    for m in re.finditer(r"(?:[^\s'\"]|'[^']*'|\"(?:\\.|[^\"\\])*\")+", text):
        chunk = m.group(0)
        unquoted = re.sub(r"'[^']*'", "", chunk)
        if "$" in unquoted or "`" in unquoted:
            try:
                found.update(shlex.split(chunk, posix=True))
            except ValueError:
                found.add(chunk)
    return found


def split_commands(text, depth=0):
    """Return simple commands as lists of (word, unresolved) pairs, including the
    commands inside $(...) and backticks."""
    if depth > 6:
        raise ValueError("command substitutions nested too deeply")
    text, subs = preprocess(strip_heredocs(text))
    text = unquoted_newlines_to_semicolons(text)
    lex = shlex.shlex(text, posix=True, punctuation_chars=True)
    lex.whitespace_split = True
    lex.commenters = "#"
    raw = list(lex)
    unresolved = dynamic_words(text)

    cmds, cur, skip_next = [], [], False
    for tok in raw:
        if tok in REDIRECTS or (tok and set(tok) <= set("<>&|") and ("<" in tok or ">" in tok)):
            if cur and cur[-1][0].isdigit():
                cur.pop()  # file descriptor number, as in 2>/dev/null
            skip_next = True
            continue
        if tok and set(tok) <= SEPARATORS:
            if cur:
                cmds.append(cur)
            cur, skip_next = [], False
            continue
        if skip_next:
            skip_next = False
            continue
        cur.append((tok, tok in unresolved or "`" in tok))
    if cur:
        cmds.append(cur)
    for inner in subs:
        cmds.extend(split_commands(inner, depth + 1))
    return cmds


# ---------- path checks ----------

def assert_target(word, cwd, ctx):
    value, unresolved = word
    if unresolved or "$" in value or "`" in value:
        raise Blocked(f"recursive delete of a target that is still unresolved ({value}): {ctx}")
    if not value:
        raise Blocked(f"recursive delete with an empty target: {ctx}")
    if value == "~" or value.startswith("~/"):
        home = os.environ.get("HOME")
        if not home:
            raise Blocked(f"recursive delete of ~ with HOME unset: {ctx}")
        value = home + value[1:]
    elif value.startswith("~"):
        raise Blocked(f"recursive delete in another user's home ({value}): {ctx}")
    segs = value.split("/")
    wild = next((i for i, s in enumerate(segs) if re.search(r"[*?\[]", s)), -1)
    if wild == 0:
        value = "."
    elif wild > 0:
        value = "/".join(segs[:wild]) or "/"
    full = value if value.startswith("/") else posixpath.join(cwd, value)
    full = posixpath.normpath(full)
    if sys.platform != "win32":
        full = os.path.realpath(full)
    for root in allow_roots():
        if full.startswith(root.rstrip("/") + "/"):
            return
    raise Blocked(f"recursive delete outside {', '.join(allow_roots())}: {full} ({ctx})")


# ---------- rules ----------

def base(name):
    return posixpath.basename(name).lower()


def is_assignment(word):
    return re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", word[0]) is not None


def check_words(words, cwd, ctx, depth=0):
    if depth > 6:
        raise ValueError("wrappers nested too deeply")
    while words and (is_assignment(words[0]) or base(words[0][0]) in KEYWORDS
                     or (len(words) > 1 and base(words[0][0]) in WRAPPERS)):
        words = words[1:]
    if not words:
        return
    name, args = base(words[0][0]), words[1:]

    if name == "git":
        i = 0
        while i < len(args) and args[i][0].startswith("-"):
            if args[i][0] in GIT_OPTS_WITH_VALUE:
                i += 1
            i += 1
        if i < len(args) and args[i][0] == "push":
            rest, k = args[i + 1:], 0
            while k < len(rest):
                a = rest[k][0]
                if a in PUSH_OPTS_WITH_VALUE:
                    k += 2
                    continue
                if a in ("--force", "--force=true"):
                    raise Blocked(f"git force push: {ctx}")
                if re.fullmatch(r"-[a-zA-Z]+", a) and "f" in a:
                    raise Blocked(f"git force push (short flag {a}): {ctx}")
                if re.match(r"^\+\S", a):
                    raise Blocked(f"git force push (+refspec {a}): {ctx}")
                k += 1

    elif name == "rm":
        recursive, targets, opts = rm_args(args)
        if recursive:
            if not targets:
                raise Blocked(f"recursive rm with no target: {ctx}")
            for t in targets:
                assert_target(t, cwd, ctx)

    elif name == "xargs":
        # xargs appends targets read from stdin, which the hook cannot see
        k = 0
        while k < len(args) and args[k][0].startswith("-"):
            if args[k][0] in XARGS_OPTS_WITH_VALUE:
                k += 1
            k += 1
        inner = args[k:]
        if inner and base(inner[0][0]) == "rm" and rm_args(inner[1:])[0]:
            raise Blocked(f"recursive rm on targets piped through xargs: {ctx}")
        if inner:
            check_words(inner, cwd, ctx, depth + 1)

    elif name in ("bash", "sh", "zsh", "dash"):
        for j, w in enumerate(args):
            if re.fullmatch(r"-[a-z]*c", w[0]) and j + 1 < len(args):
                inner = args[j + 1][0]
                for c in split_commands(inner):
                    check_words(c, cwd, f"{name} -c: {inner}", depth + 1)
                break


def rm_args(args):
    recursive, targets, opts = False, [], True
    for w in args:
        a = w[0]
        if opts and a == "--":
            opts = False
            continue
        if opts and a == "--recursive":
            recursive = True
            continue
        if opts and re.fullmatch(r"-[a-zA-Z]+", a):
            recursive = recursive or bool(re.search(r"[rR]", a))
            continue
        if opts and a.startswith("--"):
            continue
        targets.append(w)
    return recursive, targets, opts


def check(data):
    if not isinstance(data, dict):
        raise ValueError("hook input is not a JSON object")
    if data.get("tool_name") != "Bash":
        return
    cmd = (data.get("tool_input") or {}).get("command") or ""
    if not cmd:
        return
    cwd = data.get("cwd") or os.getcwd()
    for c in split_commands(cmd):
        check_words(c, cwd, cmd)


def main():
    try:
        try:
            data = json.loads(sys.stdin.read())
        except Exception as e:
            sys.stderr.write(f"guard-destructive: internal error: unreadable or malformed hook input ({e})\n")
            return 2
        check(data)
        return 0
    except Blocked as e:
        sys.stderr.write(f"Blocked by guard-destructive hook: {e}\n")
        return 2
    except Exception as e:
        sys.stderr.write(f"guard-destructive: internal error: {type(e).__name__}: {e}\n")
        return 2


if __name__ == "__main__":
    sys.exit(main())
