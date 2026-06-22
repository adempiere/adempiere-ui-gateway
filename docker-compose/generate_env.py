#!/usr/bin/env python3

"""Generate docker-compose/.env from env_template.env and an optional override file.

Parameter combinations
----------------------
(no args)                   all defaults: template=docker-compose/env_template.env,
                            override=docker-compose/override.env (skipped if absent),
                            output=docker-compose/.env
TEMPLATE                    custom template path; override and output use defaults
TEMPLATE OVERRIDE           custom template and override; output uses default
TEMPLATE OVERRIDE OUTPUT    all custom paths

Flags
-----
--dry-run   Print the resolved .env to stdout instead of writing the output file.
            Informational messages are redirected to stderr, so stdout is clean
            and can be piped or redirected:
                ./generate_env.py --dry-run > preview.env
-h/--help   Show this help and exit.

Variable substitution
---------------------
Supports ${VAR} and $VAR references; resolved recursively up to 20 passes.
Variables still set to '__CHANGE_ME__' after merging cause an abort — these
are required values that must be set explicitly in override.env (e.g. timezone).
"""

import argparse
import re
import sys
import textwrap
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
            continue
        code_part, comment_part = _split_unquoted_comment(raw)
        if '=' in code_part:
            k, v = code_part.split('=', 1)
            k = k.strip()
            v = v.strip()
            if (v.startswith('"') and v.endswith('"')) or (v.startswith("'") and v.endswith("'")):
                v = v[1:-1]
            data[k] = v
            if comment_part:
                comments[k] = comment_part
        else:
            m = re.match(r'^([A-Za-z_][A-Za-z0-9_]*)$', code_part.strip())
            if m:
                key = m.group(1)
                data[key] = ''
                if comment_part:
                    comments[key] = comment_part
    return data, comments


_var_pattern = re.compile(r'\$(?:\{([^}]+)\}|([A-Za-z_][A-Za-z0-9_]*))')

REQUIRED_SENTINEL = '__CHANGE_ME__'


def check_required(resolved: dict) -> None:
    """Abort if any value is still the required-but-unset sentinel.

    Some values (e.g. container timezone) must never silently fall back to a
    default — a wrong timezone produces wrong record timestamps that nobody
    notices until it's an audit/compliance problem. Failing loudly here beats
    failing silently at runtime.
    """
    unset = sorted(k for k, v in resolved.items() if v == REQUIRED_SENTINEL)
    if unset:
        print('ERROR: the following required values must be set in override.env '
              'before generating .env:', file=sys.stderr)
        for k in unset:
            print(f'  {k}', file=sys.stderr)
        sys.exit(1)


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


def _report_overrides(base: dict, override: dict, override_path: Path, file=sys.stdout) -> None:
    if not override_path.exists():
        print('No override.env found — using env_template.env as-is', file=file)
        return
    if not override:
        print('override.env is empty — no changes from template', file=file)
        return
    changed = {k: (base.get(k, '<not in template>'), v)
               for k, v in override.items()
               if base.get(k) != v}
    if not changed:
        print('override.env present but all values match template — no effective changes', file=file)
        return
    print('Changes from override.env:', file=file)
    max_len = max(len(k) for k in changed)
    for k, (old_val, new_val) in changed.items():
        print(f'  {k:{max_len}}  "{old_val}"  →  "{new_val}"', file=file)


def main():
    parser = argparse.ArgumentParser(
        prog='generate_env.py',
        description='Generate docker-compose/.env from env_template.env and an optional override file.',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=textwrap.dedent("""\
            examples:
              ./generate_env.py                                  # all defaults
              ./generate_env.py env_template.env                 # custom template, rest default
              ./generate_env.py env_template.env override.env    # custom template + override
              ./generate_env.py env_template.env override.env .env  # all custom
              ./generate_env.py --dry-run                        # preview without writing
              ./generate_env.py --dry-run > preview.env          # save preview to file
        """),
    )
    parser.add_argument(
        'template', nargs='?', default='docker-compose/env_template.env', metavar='TEMPLATE',
        help='path to env_template.env (default: docker-compose/env_template.env)',
    )
    parser.add_argument(
        'override', nargs='?', default='docker-compose/override.env', metavar='OVERRIDE',
        help='path to override.env (default: docker-compose/override.env; silently skipped if absent)',
    )
    parser.add_argument(
        'output', nargs='?', default='docker-compose/.env', metavar='OUTPUT',
        help='output path for .env (default: docker-compose/.env)',
    )
    parser.add_argument(
        '--dry-run', action='store_true',
        help='print resolved .env to stdout instead of writing the output file',
    )
    args = parser.parse_args()

    base_path = Path(args.template)
    override_path = Path(args.override)
    out_path = Path(args.output)

    report_out = sys.stderr if args.dry_run else sys.stdout

    base, base_comments = parse_env(base_path)
    override, override_comments = parse_env(override_path)
    _report_overrides(base, override, override_path, file=report_out)
    merged = base.copy()
    merged.update(override)
    resolved = resolve_mapping(merged)
    check_required(resolved)

    out_lines = []

    def _format_value(v: str) -> str:
        if v is None:
            return ''
        needs_quote = any(ch in v for ch in (' ', '#', '"', "'", '\\', '[', ']'))
        if not needs_quote:
            return v
        esc = v.replace('\\', '\\\\').replace('"', '\\"')
        return f'"{esc}"'

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
                comment = override_comments.get(key) or base_comments.get(key)
                fv = _format_value(val)
                out_lines.append(f'{key}={fv} # {comment}' if comment else f'{key}={fv}')
                continue
            m = re.match(r'^([A-Za-z_][A-Za-z0-9_]*)$', code_part.strip())
            if m:
                key = m.group(1)
                val = resolved.get(key, '')
                comment = override_comments.get(key) or base_comments.get(key)
                fv = _format_value(val)
                out_lines.append(f'{key}={fv} # {comment}' if comment else f'{key}={fv}')
                continue
            out_lines.append(raw)

    for k, v in resolved.items():
        if not any((ln.split('=', 1)[0].strip() == k) for ln in out_lines if '=' in ln):
            comment = override_comments.get(k) or base_comments.get(k)
            fv = _format_value(v)
            out_lines.append(f'{k}={fv} # {comment}' if comment else f'{k}={fv}')

    if args.dry_run:
        print('\n'.join(out_lines))
        print(f'[dry-run] would write {len(out_lines)} lines to {out_path}', file=sys.stderr)
    else:
        out_path.write_text('\n'.join(out_lines) + '\n')
        print(f'Written: {out_path}')


if __name__ == '__main__':
    main()
