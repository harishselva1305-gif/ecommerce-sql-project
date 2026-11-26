/* =====================================================================
   SECTION 3 : CTEs (Common Table Expressions)
   ===================================================================== */

-- 3.1 Chained CTEs : monthly revenue, profit and margin
WITH monthly AS (
    SELECT order_month,
           COUNT(DISTINCT order_id) AS orders,
           SUM(net_revenue)         AS revenue,
           SUM(profit)              AS profit
    FROM   v_sales
    GROUP  BY order_month
)
SELECT  order_month, orders,
        ROUND(revenue, 0)                      AS revenue,
        ROUND(profit, 0)                       AS profit,
        ROUND(100.0 * profit / revenue, 1)     AS margin_pct,
        ROUND(revenue / orders, 0)             AS avg_order_value
FROM    monthly
ORDER BY order_month;

-- 3.2 Customer Lifetime Value + value tier (3 chained CTEs)
WITH customer_orders AS (
    SELECT customer_id, order_id, SUM(net_revenue) AS order_value
    FROM   v_sales
    GROUP  BY customer_id, order_id
),
customer_ltv AS (
    SELECT customer_id,
           COUNT(*)               AS orders,
           SUM(order_value)       AS lifetime_value,
           AVG(order_value)       AS avg_order_value
    FROM   customer_orders
    GROUP  BY customer_id
),
tiered AS (
    SELECT *,
           CASE WHEN lifetime_value >= 40000 THEN 'Platinum'
                WHEN lifetime_value >= 20000 THEN 'Gold'
                WHEN lifetime_value >= 8000  THEN 'Silver'
                ELSE 'Bronze' END AS tier
    FROM   customer_ltv
)
SELECT  t.tier, COUNT(*) AS customers,
        ROUND(SUM(t.lifetime_value), 0)  AS revenue,
        ROUND(AVG(t.orders), 1)          AS avg_orders
FROM    tiered t
GROUP BY t.tier
ORDER BY revenue DESC;

-- 3.3 Recursive CTE : generate all 12 months, then find months with NO sales
--     (recursion is how you fill gaps in a time series)
WITH RECURSIVE months(m) AS (
    SELECT DATE('2025-01-01')
    UNION ALL
    SELECT DATE(m, '+1 month') FROM months WHERE m < DATE('2025-12-01')
)
SELECT  strftime('%Y-%m', m) AS month,
        COALESCE(ROUND(SUM(v.net_revenue), 0), 0) AS revenue
FROM    months
LEFT JOIN v_sales v ON v.order_month = strftime('%Y-%m', m)
GROUP BY month
ORDER BY month;

-- 3.4 Cohort retention : customers grouped by FIRST purchase month,
--     and how many came back in later months
WITH first_purchase AS (
    SELECT customer_id, MIN(order_month) AS cohort_month
    FROM   v_sales
    GROUP  BY customer_id
),
activity AS (
    SELECT DISTINCT customer_id, order_month FROM v_sales
)
SELECT  f.cohort_month,
        COUNT(DISTINCT f.customer_id)                                           AS cohort_size,
        COUNT(DISTINCT CASE WHEN a.order_month > f.cohort_month
                            THEN a.customer_id END)                             AS returned_later,
        ROUND(100.0 * COUNT(DISTINCT CASE WHEN a.order_month > f.cohort_month
                                          THEN a.customer_id END)
              / COUNT(DISTINCT f.customer_id), 1)                               AS retention_pct
FROM    first_purchase f
JOIN    activity a ON a.customer_id = f.customer_id
GROUP BY f.cohort_month
ORDER BY f.cohort_month;
