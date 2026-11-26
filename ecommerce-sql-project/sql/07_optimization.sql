/* =====================================================================
   SECTION 5 : QUERY OPTIMIZATION BASICS
   ===================================================================== */

-- 5.1 Indexes on JOIN / FILTER / GROUP columns
CREATE INDEX idx_orders_customer     ON orders(customer_id);
CREATE INDEX idx_orders_date_status  ON orders(order_date, status);
CREATE INDEX idx_items_order         ON order_items(order_id);
CREATE INDEX idx_items_product       ON order_items(product_id);
CREATE INDEX idx_products_category   ON products(category);

-- 5.2 Read the execution plan (SQLite: EXPLAIN QUERY PLAN | MySQL/PostgreSQL: EXPLAIN / EXPLAIN ANALYZE)
--     Look for SEARCH ... USING INDEX (good) vs SCAN TABLE (full scan, bad on big tables).
EXPLAIN QUERY PLAN
SELECT c.customer_name, SUM(oi.quantity)
FROM   orders o
JOIN   customers   c  ON c.customer_id = o.customer_id
JOIN   order_items oi ON oi.order_id   = o.order_id
WHERE  o.order_date >= '2025-10-01'
GROUP  BY c.customer_name;

/* 5.3 OPTIMIZATION CHEAT-SHEET  (bad  ->  good)
   a) SELECT *                          -> select only the columns you need
   b) WHERE strftime('%Y',order_date)='2025'   (function on column kills the index)
      -> WHERE order_date >= '2025-01-01' AND order_date < '2026-01-01'   (sargable)
   c) WHERE col IN (big subquery)       -> WHERE EXISTS (...) or a JOIN
   d) NOT IN (subquery with NULLs)      -> NOT EXISTS   (NOT IN returns nothing if a NULL appears)
   e) Correlated subquery per row       -> JOIN with pre-aggregated CTE or a window function
   f) DISTINCT to hide duplicate joins  -> fix the join condition / aggregate first
   g) Filter early (WHERE) before JOIN / GROUP BY; use HAVING only for aggregates
   h) UNION                             -> UNION ALL when duplicates don't matter (skips the sort)
   i) LIMIT without ORDER BY            -> always pair them, or results are random
   j) Leading wildcard LIKE '%abc'      -> can't use index; prefer 'abc%'
*/

-- 5.4 REWRITE EXAMPLE : correlated subquery  ->  window function (one pass over data)
-- BEFORE (re-computes the average for every row)
SELECT v.order_id, v.net_revenue
FROM   v_sales v
WHERE  v.net_revenue > (SELECT AVG(v2.net_revenue) FROM v_sales v2 WHERE v2.category = v.category)
LIMIT 10;

-- AFTER (single scan)
SELECT order_id, net_revenue
FROM ( SELECT order_id, net_revenue,
              AVG(net_revenue) OVER (PARTITION BY category) AS cat_avg
       FROM   v_sales ) t
WHERE  net_revenue > cat_avg
LIMIT 10;

-- 5.5 Sargable date filter (uses idx_orders_date_status)
SELECT COUNT(*) AS q4_orders
FROM   orders
WHERE  order_date >= '2025-10-01' AND order_date < '2026-01-01'
  AND  status = 'Delivered';
