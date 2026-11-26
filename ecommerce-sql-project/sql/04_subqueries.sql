/* =====================================================================
   SECTION 2 : SUBQUERIES & CORRELATED SUBQUERIES
   ===================================================================== */

-- 2.1 Scalar subquery : products priced above the overall average price
SELECT  product_name, category, unit_price,
        ROUND((SELECT AVG(unit_price) FROM products), 0) AS avg_price
FROM    products
WHERE   unit_price > (SELECT AVG(unit_price) FROM products)
ORDER BY unit_price DESC;

-- 2.2 IN subquery : customers who bought at least one Electronics item
SELECT  customer_id, customer_name, city
FROM    customers
WHERE   customer_id IN (SELECT customer_id FROM v_sales WHERE category = 'Electronics');

-- 2.3 NOT EXISTS : active-before but "lapsed" customers
--     (ordered in 2025 but nothing in the last 90 days of the data)
SELECT  c.customer_id, c.customer_name,
        (SELECT MAX(order_date) FROM orders o WHERE o.customer_id = c.customer_id) AS last_order
FROM    customers c
WHERE   EXISTS     (SELECT 1 FROM orders o WHERE o.customer_id = c.customer_id)
  AND   NOT EXISTS (SELECT 1 FROM orders o
                    WHERE  o.customer_id = c.customer_id
                      AND  o.order_date >= DATE((SELECT MAX(order_date) FROM orders), '-90 day'))  -- PostgreSQL: MAX(order_date) - 90
ORDER BY last_order;

-- 2.4 Derived table (subquery in FROM) : average order value by segment
SELECT  segment, ROUND(AVG(order_value), 2) AS avg_order_value, COUNT(*) AS orders
FROM  ( SELECT o.order_id, c.segment, SUM(v.net_revenue) AS order_value
        FROM   orders o
        JOIN   customers c ON c.customer_id = o.customer_id
        JOIN   v_sales   v ON v.order_id    = o.order_id
        GROUP  BY o.order_id, c.segment ) t
GROUP BY segment
ORDER BY avg_order_value DESC;

-- 2.5 CORRELATED subquery : orders worth MORE than that customer's own average
--     (the inner query re-runs for every outer row, depends on outer customer_id)
WITH order_totals AS (
    SELECT order_id, customer_id, SUM(net_revenue) AS order_value
    FROM   v_sales
    GROUP  BY order_id, customer_id
)
SELECT  ot.customer_id, ot.order_id, ROUND(ot.order_value, 0) AS order_value
FROM    order_totals ot
WHERE   ot.order_value > (SELECT AVG(i.order_value)
                          FROM   order_totals i
                          WHERE  i.customer_id = ot.customer_id)
ORDER BY ot.order_value DESC
LIMIT 15;

-- 2.6 CORRELATED subquery : products priced above their OWN category average
SELECT  p.product_name, p.category, p.unit_price
FROM    products p
WHERE   p.unit_price > (SELECT AVG(p2.unit_price) FROM products p2 WHERE p2.category = p.category)
ORDER BY p.category, p.unit_price DESC;

-- 2.7 Correlated subquery in SELECT : each customer's latest order status
SELECT  c.customer_name,
        (SELECT o.status FROM orders o
         WHERE  o.customer_id = c.customer_id
         ORDER BY o.order_date DESC, o.order_id DESC LIMIT 1) AS latest_order_status
FROM    customers c
LIMIT 15;
