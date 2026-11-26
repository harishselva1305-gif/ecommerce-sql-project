"""Runs every query in /sql and prints the results in the terminal.

Usage:
    python run.py            -> rebuild ecommerce.db and run ALL queries
    python run.py 06         -> run only files starting with 06 (window functions)
    python run.py 03 05      -> run several sections
Results are also saved to results.txt
"""
import sqlite3, sys, re, glob, os

HERE = os.path.dirname(os.path.abspath(__file__))
DB = os.path.join(HERE, "ecommerce.db")
SETUP = ("00", "01", "02")          # schema, data, view

def table(cur, rows, limit=25):
    cols = [d[0] for d in cur.description]
    shown = rows[:limit]
    w = [max(len(str(c)), *(len(str(r[i])) for r in shown)) if shown else len(str(c)) for i, c in enumerate(cols)]
    line = " | ".join(str(c).ljust(w[i]) for i, c in enumerate(cols))
    out = [line, "-+-".join("-" * x for x in w)]
    for r in shown:
        out.append(" | ".join(("" if v is None else str(v)).ljust(w[i]) for i, v in enumerate(r)))
    if len(rows) > limit:
        out.append(f"... ({len(rows) - limit} more rows)")
    return "\n".join(out)

def statements(text):
    buf = ""
    for line in text.splitlines(True):
        buf += line
        if sqlite3.complete_statement(buf):
            yield buf
            buf = ""

def title_of(stmt):
    for line in stmt.splitlines():
        s = line.strip()
        if s.startswith("--") and len(s) > 3 and not set(s) <= set("-= "):
            return s.lstrip("- ").strip()
    return ""

def main():
    if sqlite3.sqlite_version_info < (3, 39):
        print(f"SQLite {sqlite3.sqlite_version} is too old: RIGHT/FULL JOIN need 3.39+. Please upgrade Python (3.11+).")
    wanted = sys.argv[1:]
    if os.path.exists(DB): os.remove(DB)
    con = sqlite3.connect(DB)
    out = []
    for f in sorted(glob.glob(os.path.join(HERE, "sql", "*.sql"))):
        prefix = os.path.basename(f)[:2]
        text = open(f, encoding="utf-8").read()
        setup = prefix in SETUP
        if not setup and wanted and prefix not in wanted:
            continue
        if not setup:
            out.append("\n" + "#" * 70 + "\n# " + os.path.basename(f) + "\n" + "#" * 70)
        for st in statements(text):
            body = re.sub(r"/\*.*?\*/|--[^\n]*", "", st, flags=re.S).strip()
            if not body:
                continue
            cur = con.execute(st)
            if setup or not cur.description:
                continue
            rows = cur.fetchall()
            out.append("\n>> " + (title_of(st) or body.split("\n")[0][:60]) + f"   [{len(rows)} rows]")
            out.append(table(cur, rows))
    con.commit()
    text = "\n".join(out)
    print(text)
    open(os.path.join(HERE, "results.txt"), "w", encoding="utf-8").write(text)

if __name__ == "__main__":
    main()
