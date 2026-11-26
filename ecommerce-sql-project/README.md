# E-commerce Sales Analysis - Advanced SQL & Business Querying

Concepts: Joins (INNER/LEFT/RIGHT/FULL), subqueries & correlated subqueries, CTEs (incl. recursive),
window functions (ROW_NUMBER, RANK, DENSE_RANK, LEAD, LAG, NTILE, running totals, moving averages),
query optimization basics.

Database: SQLite (data is dummy/sample, Jan-Dec 2025, amounts in INR).

## Folder structure
```
ecommerce-sql-project/
|-- ecommerce.db              <- ready-made database (open directly)
|-- run.py                    <- runs all queries, prints results
|-- sql/
|   |-- 00_schema.sql         tables
|   |-- 01_data.sql           sample data
|   |-- 02_view.sql           v_sales view (revenue logic)
|   |-- 03_joins.sql
|   |-- 04_subqueries.sql
|   |-- 05_ctes.sql
|   |-- 06_window_functions.sql
|   |-- 07_optimization.sql
|   `-- 08_business_reports.sql
`-- .vscode/                  extension suggestions + tasks
```

## Way 1 - Python runner (easiest, nothing to install except Python 3.11+)
1. VS Code -> File -> Open Folder -> select `ecommerce-sql-project`
2. Open terminal (Ctrl + `) and run:
   ```
   python run.py          # all sections
   python run.py 06       # only window functions
   ```
   (Mac/Linux: `python3 run.py`). Output also saved in `results.txt`.
3. Or press **Ctrl+Shift+B** to run the task.

## Way 2 - Run queries inside VS Code (SQLite extension)
1. Install the recommended extension **SQLite** (alexcvzz.vscode-sqlite). VS Code will suggest it automatically.
2. Ctrl+Shift+P -> `SQLite: Choose Database` -> pick `ecommerce.db`
3. Open any file in `sql/` (e.g. `06_window_functions.sql`), select ONE query, right-click -> **Run Selected Query**
   (or Ctrl+Shift+P -> `SQLite: Run Query`). Results open in a side panel.
4. Left sidebar -> **SQLITE EXPLORER** shows tables and the view.
Tip: Select only one query at a time, otherwise only the first result is shown.

If RIGHT / FULL JOIN throws a syntax error in the extension (older bundled SQLite), use Way 1,
or rewrite as LEFT JOIN (alternatives are given in the comments).

## Rebuild the database from scratch
`python run.py` deletes and recreates `ecommerce.db` from sql/00-02 each time.

## Suggested viva / report flow
Schema -> Joins -> Subqueries -> CTEs -> Window functions -> Optimization (EXPLAIN) -> Business reports (KPIs, RFM, Pareto).
