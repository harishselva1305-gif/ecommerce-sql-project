/* =====================================================================
   SECTION 1 : JOINS
   ===================================================================== */

-- 1.1 INNER JOIN : full order detail (only rows that match in all tables)
SELECT  o.order_id, o.order_date, c.customer_name, c.city,
        p.product_name, oi.quantity, oi.discount_pct
FROM    orders o
INNER JOIN customers   c  ON c.customer_id = o.customer_id
INNER JOIN order_items oi ON oi.order_id   = o.order_id
INNER JOIN products    p  ON p.product_id  = oi.product_id
ORDER BY o.order_date, o.order_id
LIMIT 20;

-- 1.2 LEFT JOIN : customers who signed up but NEVER ordered (win-back list)
SELECT  c.customer_id, c.customer_name, c.city, c.signup_date
FROM    customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
WHERE   o.order_id IS NULL;

-- 1.3 RIGHT JOIN : products that never appeared in any order (dead stock)
--     (RIGHT JOIN needs SQLite 3.39+/MySQL/PostgreSQL. Same result with
--      LEFT JOIN by swapping table order: FROM products LEFT JOIN order_items)
SELECT  p.product_id, p.product_name, p.category, p.unit_price
FROM    order_items oi
RIGHT JOIN products p ON p.product_id = oi.product_id
WHERE   oi.order_item_id IS NULL;

-- 1.4 FULL OUTER JOIN : actual revenue vs target per category.
--     Shows categories with sales but no target (Sports) AND
--     categories with a target but no sales (Toys).
WITH actual AS (
    SELECT category, ROUND(SUM(net_revenue), 0) AS actual_revenue
    FROM   v_sales
    GROUP  BY category
)
SELECT  COALESCE(a.category, t.category)              AS category,
        a.actual_revenue,
        t.target_revenue,
        ROUND(100.0 * a.actual_revenue / t.target_revenue, 1) AS achievement_pct,
        CASE WHEN t.category IS NULL        THEN 'No target set'
             WHEN a.category IS NULL        THEN 'No sales'
             WHEN a.actual_revenue >= t.target_revenue THEN 'Target met'
             ELSE 'Below target' END                   AS status
FROM    actual a
FULL OUTER JOIN sales_targets t ON t.category = a.category;
-- MySQL has no FULL JOIN: use LEFT JOIN ... UNION ... RIGHT JOIN.

-- 1.5 SELF JOIN : pairs of customers living in the same city and segment
SELECT  a.customer_name AS customer_1, b.customer_name AS customer_2, a.city, a.segment
FROM    customers a
JOIN    customers b ON a.city = b.city
                   AND a.segment = b.segment
                   AND a.customer_id < b.customer_id     -- avoids duplicates & self pairs
ORDER BY a.city
LIMIT 15;
