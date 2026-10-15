#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
LEGIONFORGE 7.3.5 - normalize launch scripts (run on any OS: python tools/normalize_scripts.py).

Why the .bat files used to "flash and close":
  1. LF line endings instead of CRLF: cmd.exe mis-finds labels (goto / call :label).
  2. UTF-8 + chcp 65001: cmd reads batch files byte by byte, multibyte Cyrillic breaks label offsets.
  3. Unescaped ")" inside echo within ( ... ) blocks, e.g. "(code 5)": the block ends early,
     cmd dies with a syntax error and the window closes at once.

What this tool does:
  *.bat -> CP866 (OEM codepage of Russian Windows), CRLF, "chcp 866", escapes ")" in echo inside blocks,
           protects %PATH% variables in echo inside blocks (paths like "C:\\Program Files (x86)\\" break blocks too).
  *.ps1 -> UTF-8 with BOM (Windows PowerShell 5.1 reads BOM-less files as ANSI), CRLF.
Idempotent: safe to run repeatedly.
"""
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
SKIP_DIRS = {'.git', 'core', 'build', 'node_modules'}

PATH_VARS = ['ROOT', 'SERVER_DIR', 'TMP_DIR', 'SQL_DIR', 'LOG_FILE', 'MYSQL', 'MYSQL_CNF',
             'CLIENT_EXE', 'CLIENT_DIR', 'CLIENT_INPUT', 'TOOLS_DIR', 'BUILD_DIR']

CHAR_MAP = {
    '\u2014': '-', '\u2013': '-', '\u2212': '-', '\u00ab': '"', '\u00bb': '"', '\u201c': '"', '\u201d': '"',
    '\u2018': "'", '\u2019': "'", '\u2026': '...', '\u2192': '->', '\u2713': 'OK', '\u2714': 'OK',
    '\u00b7': '-', '\u2022': '*', '\u00a0': ' ', '\ufeff': '',
}

warnings = []


def escape_unquoted(text, chars):
    """Put ^ before given chars outside double quotes (already escaped ones are kept)."""
    out, quoted, i = [], False, 0
    while i < len(text):
        ch = text[i]
        if ch == '"':
            quoted = not quoted
            out.append(ch)
        elif ch == '^' and not quoted and i + 1 < len(text):
            out.append(ch)
            out.append(text[i + 1])
            i += 1
        elif ch in chars and not quoted:
            out.append('^' + ch)
        else:
            out.append(ch)
        i += 1
    return ''.join(out)


def fix_bat(name, text):
    text = text.replace('\r\n', '\n').replace('\r', '\n')
    delayed = False
    m0 = re.search(r'^\s*setlocal\b(.*)$', text, re.I | re.M)
    if m0:
        delayed = bool(re.search(r'(?<!Disable)EnableDelayedExpansion', m0.group(1), re.I))
    out, depth = [], 0
    for no, line in enumerate(text.split('\n'), 1):
        s = line.strip()
        low = s.lower()
        line = re.sub(r'^(\s*)chcp\s+65001', r'\1chcp 866', line, flags=re.I)
        line = line.replace('кодовая страница 65001', 'кодовая страница 866').replace(
            'UTF-8 без BOM', 'OEM CP866, окончания CRLF')
        if s.startswith(')'):
            depth = max(0, depth - 1)
        is_comment = low.startswith('::') or low.startswith('rem ') or low == 'rem'
        m = re.match(r'^(\s*)(@?echo)(\s+.*)$', line, re.I)
        if depth > 0 and m and not is_comment:
            head, body = m.group(1) + m.group(2), m.group(3)
            # Protect path variables with placeholders so the escaping below does not touch them.
            body = re.sub(r'%(\w+):\^?\)=\^\)%', lambda mm: '\x00' + mm.group(1) + '\x00', body)
            for var in PATH_VARS:
                body = body.replace('%' + var + '%', '\x00' + var + '\x00')
            body = escape_unquoted(body, ')')
            body = re.sub(r'\x00(\w+)\x00',
                          lambda mm: ('!%s!' if delayed else '%%%s:)=^)%%') % mm.group(1), body)
            line = head + body
        if m and not is_comment:
            bare = re.sub(r'"[^"]*"', '', m.group(3))
            bare = re.sub(r'\^.', '', bare)
            if re.search(r'[<>|&]', bare):
                warnings.append('%s:%d: echo contains unescaped < > | & : %s' % (name, no, s[:100]))
        if not is_comment and s.endswith('('):
            depth += 1
        out.append(line)
    text = '\n'.join(out)
    for k, v in CHAR_MAP.items():
        text = text.replace(k, v)
    try:
        data = text.encode('cp866')
    except UnicodeEncodeError as e:
        warnings.append('%s: char %r is not in CP866, replaced with "?"' % (name, text[e.start:e.end]))
        data = text.encode('cp866', errors='replace')
    return data.replace(b'\n', b'\r\n')


def read_any(path):
    raw = open(path, 'rb').read()
    for enc in ('utf-8-sig', 'cp866'):
        try:
            return raw.decode(enc)
        except UnicodeDecodeError:
            continue
    return raw.decode('cp1251', errors='replace')


def main():
    changed = 0
    for base, dirs, files in os.walk(ROOT):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS and not d.startswith('.')]
        for f in files:
            path = os.path.join(base, f)
            rel = os.path.relpath(path, ROOT).replace('\\', '/')
            low = f.lower()
            if low.endswith(('.bat', '.cmd')):
                new = fix_bat(rel, read_any(path))
            elif low.endswith('.ps1'):
                text = read_any(path).replace('\r\n', '\n').replace('\r', '\n').replace('\ufeff', '')
                new = b'\xef\xbb\xbf' + text.replace('\n', '\r\n').encode('utf-8')
            else:
                continue
            if new != open(path, 'rb').read():
                open(path, 'wb').write(new)
                changed += 1
                print('normalized:', rel)
    print('files changed:', changed)
    for w in warnings:
        print('WARNING', w)
    return 0


if __name__ == '__main__':
    sys.exit(main())
