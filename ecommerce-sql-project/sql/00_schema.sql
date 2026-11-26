/* =====================================================================
   PROJECT : E-COMMERCE SALES ANALYSIS  (Advanced SQL & Business Querying)
   DIALECT : Standard SQL, tested on SQLite 3.45 (also runs on MySQL 8+ /
             PostgreSQL with the small date-function changes noted inline)
   PERIOD  : Jan 2025 - Dec 2025   |   CURRENCY: INR (Rs.)

   BUSINESS GOAL
   Help the management understand WHO buys, WHAT sells, WHEN sales peak,
   and WHERE revenue is leaking, using only SQL.

   CONCEPTS COVERED
   1. Joins ............... INNER, LEFT, RIGHT, FULL
   2. Subqueries .......... scalar, IN, EXISTS, derived table, correlated
   3. CTEs ................ chained CTEs, recursive CTE
   4. Window functions .... ROW_NUMBER, RANK, DENSE_RANK, LEAD, LAG, NTILE,
                            running totals, moving averages, % of total
   5. Optimization ........ indexes, sargable filters, EXPLAIN, rewrites
   6. Final business reports: RFM, Pareto (80/20), cohort retention, MoM growth

   TABLES
   customers(customer_id PK, customer_name, city, state, signup_date, segment)
   products(product_id PK, product_name, category, sub_category, unit_price, cost_price)
   orders(order_id PK, customer_id FK, order_date, status, payment_method)
   order_items(order_item_id PK, order_id FK, product_id FK, quantity, discount_pct)
   sales_targets(category PK, target_revenue)

   DATA QUIRKS (intentional, so joins have something to show)
   - A few customers never placed an order          -> LEFT JOIN demo
   - 2 products were never sold                   -> RIGHT JOIN demo
   - 'Toys' has a target but no products,
     'Sports' has products but no target          -> FULL JOIN demo
   - Orders can be Delivered / Shipped / Cancelled / Returned
     -> revenue is counted only for Delivered orders (see v_sales)
   ===================================================================== */

-- ---------------------------------------------------------------------
-- 0. SCHEMA
-- ---------------------------------------------------------------------
DROP VIEW  IF EXISTS v_sales;
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS sales_targets;

CREATE TABLE customers (
    customer_id   INTEGER PRIMARY KEY,
    customer_name TEXT NOT NULL,
    city          TEXT,
    state         TEXT,
    signup_date   TEXT,
    segment       TEXT
);

CREATE TABLE products (
    product_id   INTEGER PRIMARY KEY,
    product_name TEXT NOT NULL,
    category     TEXT,
    sub_category TEXT,
    unit_price   REAL NOT NULL,
    cost_price   REAL NOT NULL
);

CREATE TABLE sales_targets (
    category       TEXT PRIMARY KEY,
    target_revenue REAL
);

CREATE TABLE orders (
    order_id       INTEGER PRIMARY KEY,
    customer_id    INTEGER NOT NULL REFERENCES customers(customer_id),
    order_date     TEXT NOT NULL,          -- ISO format YYYY-MM-DD
    status         TEXT NOT NULL,
    payment_method TEXT
);

CREATE TABLE order_items (
    order_item_id INTEGER PRIMARY KEY,
    order_id      INTEGER NOT NULL REFERENCES orders(order_id),
    product_id    INTEGER NOT NULL REFERENCES products(product_id),
    quantity      INTEGER NOT NULL,
    discount_pct  INTEGER NOT NULL DEFAULT 0
);

-- ---------------------------------------------------------------------
-- SAMPLE DATA
-- ---------------------------------------------------------------------
