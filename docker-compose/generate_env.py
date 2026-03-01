#!/usr/bin/env python3

"""Generate docker-compose/.env from env_template.env and an override.
Usage: generate_env.py [env_template] [override_env] [out_env]
If override is missing, uses docker-compose/override.env. Default output: docker-compose/.env
Supports substitutions ${VAR} and $VAR and resolves them recursively.
"""

import re
import sys
from pathlib import Path


def _split_unquoted_comment(line: str):
    """Return (code_part, comment_part).
    Finds first unquoted '#' and splits the line. If none, comment_part is None.
    """
    in_sq = False
    in_dq = False
    for i, ch in enumerate(line):
        if ch == "'" and not in_dq:
            in_sq = not in_sq
            continue
        if ch == '"' and not in_sq:
            in_dq = not in_dq
            continue
        if ch == '#' and not in_sq and not in_dq:
            return line[:i].rstrip(), line[i+1:].strip()
    return line.rstrip(), None


def parse_env(path: Path):
    """Parse an env file returning (data_dict, comments_dict).
    comments_dict maps variable name -> inline comment (without '#').
    Lines that begin with '#' are treated as standalone comments and not returned.
    """
    data = {}
    comments = {}
    if not path.exists():
        return data, comments
    for line in path.read_text().splitlines():
        raw = line.rstrip('\n')
        s = raw.strip()
        if not s:
            continue
        if s.startswith('#'):
            # standalone comment line -> skip from mapping
            continue
        code_part, comment_part = _split_unquoted_comment(raw)
        if '=' in code_part:
            k, v = code_part.split('=', 1)
            k = k.strip()
            v = v.strip()
            # remove surrounding quotes if present
            if (v.startswith('"') and v.endswith('"')) or (v.startswith("'") and v.endswith("'")):
                v = v[1:-1]
            data[k] = v
            if comment_part:
                comments[k] = comment_part
        else:
            # lines like "OPENSEARCH_PORT" without '=' -> treat as key with empty default
            m = re.match(r'^([A-Za-z_][A-Za-z0-9_]*)$', code_part.strip())
            if m:
                key = m.group(1)
                data[key] = ''
                if comment_part:
                    comments[key] = comment_part
    return data, comments


_var_pattern = re.compile(r'\$(?:\{([^}]+)\}|([A-Za-z_][A-Za-z0-9_]*))')


def substitute_once(value: str, mapping: dict) -> str:
    def repl(m):
        key = m.group(1) or m.group(2)
        return mapping.get(key, m.group(0))
    return _var_pattern.sub(repl, value)


def resolve_mapping(mapping: dict, max_iters=20) -> dict:
    resolved = dict(mapping)
    for _ in range(max_iters):
        changed = False
        for k, v in list(resolved.items()):
            new = substitute_once(v, resolved)
            if new != v:
                resolved[k] = new
                changed = True
        if not changed:
            break
    return resolved


def main():
    argv = sys.argv
    base_path = Path(argv[1]) if len(argv) > 1 else Path('docker-compose/env_template.env')
    override_path = Path(argv[2]) if len(argv) > 2 else Path('docker-compose/override.env')
    out_path = Path(argv[3]) if len(argv) > 3 else Path('docker-compose/.env')

    base, base_comments = parse_env(base_path)
    override, override_comments = parse_env(override_path)
    merged = base.copy()
    merged.update(override)
    resolved = resolve_mapping(merged)

    out_lines = []
    def _format_value(v: str) -> str:
        # If the value contains spaces, #, quotes, brackets or backslashes, quote it safely
        if v is None:
            return ''
        needs_quote = any(ch in v for ch in (' ', '#', '"', "'", '\\', '[', ']'))
        if not needs_quote:
            return v
        # escape backslashes and double quotes for a safe double-quoted string
        esc = v.replace('\\', '\\\\').replace('"', '\\"')
        return f'"{esc}"'
    # preserve comments and order from template when possible
    if base_path.exists():
        for line in base_path.read_text().splitlines():
            raw = line.rstrip('\n')
            s = raw.strip()
            if not s:
                out_lines.append(raw)
                continue
            if s.startswith('#'):
                out_lines.append(raw)
                continue
            code_part, comment_part = _split_unquoted_comment(raw)
            if '=' in code_part:
                key = code_part.split('=', 1)[0].strip()
                val = resolved.get(key, '')
                # prefer override comment then base comment
                comment = override_comments.get(key) if 'override_comments' in locals() and key in override_comments else base_comments.get(key)
                fv = _format_value(val)
                if comment:
                    out_lines.append(f'{key}={fv} # {comment}')
                else:
                    out_lines.append(f'{key}={fv}')
                continue
            m = re.match(r'^([A-Za-z_][A-Za-z0-9_]*)$', code_part.strip())
            if m:
                key = m.group(1)
                val = resolved.get(key, '')
                comment = override_comments.get(key) if 'override_comments' in locals() and key in override_comments else base_comments.get(key)
                fv = _format_value(val)
                if comment:
                    out_lines.append(f'{key}={fv} # {comment}')
                else:
                    out_lines.append(f'{key}={fv}')
                continue
            out_lines.append(raw)
    # append any extra keys from overrides
    for k, v in resolved.items():
        if not any((ln.split('=',1)[0].strip() == k) for ln in out_lines if '=' in ln):
            comment = override_comments.get(k) if 'override_comments' in locals() and k in override_comments else base_comments.get(k)
            fv = _format_value(v)
            if comment:
                out_lines.append(f'{k}={fv} # {comment}')
            else:
                out_lines.append(f'{k}={fv}')

    out_path.write_text('\n'.join(out_lines) + '\n')
    print(f'Write {out_path}')


if __name__ == '__main__':
    main()
