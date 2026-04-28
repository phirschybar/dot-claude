#!/usr/bin/env python3
"""Checkvist API client for Ben's todo list. Stdlib only.

Reads credentials from ~/.claude/skills/checkvist/.credentials.
Default list is 619960 ("topics").
"""
from __future__ import annotations

import argparse
import json
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

DEFAULT_LIST_ID = 619960
SKILL_DIR = Path.home() / ".claude" / "skills" / "checkvist"
CREDS_PATH = SKILL_DIR / ".credentials"
TOKEN_CACHE = Path.home() / ".claude" / ".cache" / "checkvist_token.json"
API_BASE = "https://checkvist.com"


def die(msg: str, code: int = 1) -> None:
    print(msg, file=sys.stderr)
    sys.exit(code)


def load_credentials() -> tuple[str, str]:
    if not CREDS_PATH.exists():
        die(
            f"missing {CREDS_PATH}\n"
            f"  cp {CREDS_PATH}.example {CREDS_PATH}\n"
            f"  chmod 600 {CREDS_PATH}\n"
            f"  # then edit and replace REPLACE_ME values"
        )
    env: dict[str, str] = {}
    for line in CREDS_PATH.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        env[k.strip()] = v.strip().strip('"').strip("'")
    user = env.get("CHECKVIST_USERNAME")
    key = env.get("CHECKVIST_OPENAPI_KEY")
    if not user or not key or "REPLACE_ME" in (user, key):
        die(f"CHECKVIST_USERNAME and CHECKVIST_OPENAPI_KEY must be set in {CREDS_PATH}")
    return user, key


def get_token(username: str, openapi_key: str, force_refresh: bool = False) -> str:
    if not force_refresh and TOKEN_CACHE.exists():
        try:
            return json.loads(TOKEN_CACHE.read_text())["token"]
        except Exception:
            pass
    body = urllib.parse.urlencode(
        {"username": username, "remote_key": openapi_key}
    ).encode()
    req = urllib.request.Request(
        f"{API_BASE}/auth/login.json", data=body, method="POST"
    )
    try:
        with urllib.request.urlopen(req) as r:
            data = json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        body_text = e.read().decode(errors="replace")
        die(f"login failed: {e.code} {e.reason} — {body_text}")
    # Checkvist's /auth/login.json returns either a bare JSON string (the token)
    # or a dict with a "token" key, depending on API revision.
    if isinstance(data, str):
        token = data
    elif isinstance(data, dict):
        token = data.get("token")
    else:
        token = None
    if not token:
        die(f"no token in login response: {data!r}")
    TOKEN_CACHE.parent.mkdir(parents=True, exist_ok=True)
    TOKEN_CACHE.write_text(json.dumps({"token": token}))
    TOKEN_CACHE.chmod(0o600)
    return token


def api(
    method: str,
    path: str,
    token: str,
    params: dict | None = None,
    _retried: bool = False,
):
    url = f"{API_BASE}{path}"
    data = None
    if params:
        if method == "GET":
            url += "?" + urllib.parse.urlencode(params)
        else:
            data = urllib.parse.urlencode(params).encode()
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("X-Client-Token", token)
    try:
        with urllib.request.urlopen(req) as r:
            raw = r.read().decode()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        if e.code == 401 and not _retried:
            if TOKEN_CACHE.exists():
                TOKEN_CACHE.unlink()
            user, key = load_credentials()
            new_token = get_token(user, key, force_refresh=True)
            return api(method, path, new_token, params, _retried=True)
        body_text = e.read().decode(errors="replace")
        die(f"API {method} {path} failed: {e.code} — {body_text}")


def cmd_add(args, token):
    params = {"task[content]": args.content}
    if args.parent:
        params["task[parent_id]"] = str(args.parent)
    if args.priority:
        params["task[priority]"] = str(args.priority)
    res = api("POST", f"/checklists/{args.list}/tasks.json", token, params)
    print(f"added {res.get('id')}: {res.get('content')}")


def cmd_list(args, token):
    res = api("GET", f"/checklists/{args.list}/tasks.json", token)
    if not isinstance(res, list):
        die(f"unexpected list response: {res}")
    for t in res:
        marker = "x" if t.get("status") == 1 else " "
        parent = f" (parent {t.get('parent_id')})" if t.get("parent_id") else ""
        print(f"  [{marker}] {t['id']}: {t.get('content', '')}{parent}")


def cmd_find(args, token):
    res = api("GET", f"/checklists/{args.list}/tasks.json", token)
    needle = args.query.lower()
    for t in res:
        if needle in (t.get("content") or "").lower():
            marker = "x" if t.get("status") == 1 else " "
            print(f"  [{marker}] {t['id']}: {t['content']}")


def cmd_complete(args, token):
    api(
        "POST",
        f"/checklists/{args.list}/tasks/{args.task_id}/close.json",
        token,
    )
    print(f"closed {args.task_id}")


def cmd_lists(args, token):
    res = api("GET", "/checklists.json", token)
    for l in res:
        print(f"  {l['id']}: {l.get('name', '?')}")


def main():
    ap = argparse.ArgumentParser(
        description="Checkvist CLI for Ben's todo list (default: 'topics' list 619960)"
    )
    sub = ap.add_subparsers(dest="cmd", required=True)

    p_add = sub.add_parser("add", help="add a task")
    p_add.add_argument("content")
    p_add.add_argument("--list", type=int, default=DEFAULT_LIST_ID)
    p_add.add_argument("--parent", type=int, help="parent task id (creates subtask)")
    p_add.add_argument("--priority", type=int, choices=[1, 2, 3])

    p_list = sub.add_parser("list", help="list all tasks in a list")
    p_list.add_argument("--list", type=int, default=DEFAULT_LIST_ID)

    p_find = sub.add_parser("find", help="find tasks containing query string")
    p_find.add_argument("query")
    p_find.add_argument("--list", type=int, default=DEFAULT_LIST_ID)

    p_complete = sub.add_parser("complete", help="mark task complete")
    p_complete.add_argument("task_id", type=int)
    p_complete.add_argument("--list", type=int, default=DEFAULT_LIST_ID)

    sub.add_parser("lists", help="show all your lists")

    args = ap.parse_args()
    user, key = load_credentials()
    token = get_token(user, key)
    {
        "add": cmd_add,
        "list": cmd_list,
        "find": cmd_find,
        "complete": cmd_complete,
        "lists": cmd_lists,
    }[args.cmd](args, token)


if __name__ == "__main__":
    main()
