/* =====================================================================
   SECTION 4 : WINDOW FUNCTIONS
   ===================================================================== */

-- 4.1 ROW_NUMBER : each customer's most recent order (dedupe pattern)
WITH ranked AS (
    SELECT  o.customer_id, o.order_id, o.order_date, o.status,
            ROW_NUMBER() OVER (PARTITION BY o.customer_id
                               ORDER BY o.order_date DESC, o.order_id DESC) AS rn
    FROM    orders o
)
SELECT  c.customer_name, r.order_id, r.order_date, r.status
FROM    ranked r
JOIN    customers c ON c.customer_id = r.customer_id
WHERE   r.rn = 1
ORDER BY r.order_date DESC
LIMIT 15;

-- 4.2 ROW_NUMBER vs RANK vs DENSE_RANK : product revenue ranking per category
--     ROW_NUMBER = always unique | RANK = gaps after ties | DENSE_RANK = no gaps
WITH product_rev AS (
    SELECT category, product_name, ROUND(SUM(net_revenue), 0) AS revenue
    FROM   v_sales
    GROUP  BY category, product_name
)
SELECT  category, product_name, revenue,
        ROW_NUMBER() OVER (PARTITION BY category ORDER BY revenue DESC) AS row_num,
        RANK()       OVER (PARTITION BY category ORDER BY revenue DESC) AS rnk,
        DENSE_RANK() OVER (PARTITION BY category ORDER BY revenue DESC) AS dense_rnk
FROM    product_rev
ORDER BY category, revenue DESC;

-- 4.3 Top-N per group : best 2 products in every category
WITH product_rev AS (
    SELECT category, product_name, SUM(net_revenue) AS revenue
    FROM   v_sales GROUP BY category, product_name
),
ranked AS (
    SELECT *, DENSE_RANK() OVER (PARTITION BY category ORDER BY revenue DESC) AS rk
    FROM   product_rev
)
SELECT category, product_name, ROUND(revenue, 0) AS revenue, rk
FROM   ranked
WHERE  rk <= 2
ORDER BY category, rk;

-- 4.4 LAG : month-over-month revenue growth
WITH monthly AS (
    SELECT order_month, SUM(net_revenue) AS revenue
    FROM   v_sales GROUP BY order_month
)
SELECT  order_month,
        ROUND(revenue, 0)                                          AS revenue,
        ROUND(LAG(revenue) OVER (ORDER BY order_month), 0)         AS prev_month,
        ROUND(100.0 * (revenue - LAG(revenue) OVER (ORDER BY order_month))
              / LAG(revenue) OVER (ORDER BY order_month), 1)       AS mom_growth_pct
FROM    monthly
ORDER BY order_month;

-- 4.5 LAG + LEAD : days between consecutive orders per customer
--     (repeat-purchase behaviour / churn signal)
WITH o AS (
    SELECT DISTINCT customer_id, order_id, order_date FROM v_sales
)
SELECT  customer_id, order_id, order_date,
        LAG(order_date)  OVER w AS previous_order,
        LEAD(order_date) OVER w AS next_order,
        CAST(julianday(order_date) - julianday(LAG(order_date) OVER w) AS INTEGER) AS days_since_prev  -- PostgreSQL: order_date - LAG(order_date) OVER w
FROM    o
WINDOW  w AS (PARTITION BY customer_id ORDER BY order_date, order_id)
ORDER BY customer_id, order_date
LIMIT 20;

-- 4.6 Running total (cumulative revenue) + share of annual revenue
WITH monthly AS (
    SELECT order_month, SUM(net_revenue) AS revenue
    FROM   v_sales GROUP BY order_month
)
SELECT  order_month,
        ROUND(revenue, 0)                                                   AS revenue,
        ROUND(SUM(revenue) OVER (ORDER BY order_month
              ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), 0)         AS running_total,
        ROUND(100.0 * SUM(revenue) OVER (ORDER BY order_month
              ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
              / SUM(revenue) OVER (), 1)                                    AS cumulative_pct,
        ROUND(100.0 * revenue / SUM(revenue) OVER (), 1)                    AS pct_of_year
FROM    monthly
ORDER BY order_month;

-- 4.7 Moving average : 3-month moving average smooths the festive spike
WITH monthly AS (
    SELECT order_month, SUM(net_revenue) AS revenue
    FROM   v_sales GROUP BY order_month
)
SELECT  order_month,
        ROUND(revenue, 0) AS revenue,
        ROUND(AVG(revenue) OVER (ORDER BY order_month
              ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 0) AS moving_avg_3m
FROM    monthly
ORDER BY order_month;

-- 4.8 Running total that RESETS per category (partitioned running total)
WITH cat_month AS (
    SELECT category, order_month, SUM(net_revenue) AS revenue
    FROM   v_sales GROUP BY category, order_month
)
SELECT  category, order_month, ROUND(revenue, 0) AS revenue,
        ROUND(SUM(revenue) OVER (PARTITION BY category ORDER BY order_month), 0) AS category_running_total
FROM    cat_month
ORDER BY category, order_month;

-- 4.9 NTILE : RFM segmentation (Recency, Frequency, Monetary) scored 1-4
WITH rfm_base AS (
    SELECT  customer_id,
            CAST(julianday((SELECT MAX(order_date) FROM v_sales)) - julianday(MAX(order_date)) AS INTEGER) AS recency_days,
            COUNT(DISTINCT order_id) AS frequency,
            SUM(net_revenue)         AS monetary
    FROM    v_sales
    GROUP   BY customer_id
),
rfm_score AS (
    SELECT *,
           NTILE(4) OVER (ORDER BY recency_days DESC) AS r,   -- recent buyers get higher score
           NTILE(4) OVER (ORDER BY frequency)         AS f,
           NTILE(4) OVER (ORDER BY monetary)          AS m
    FROM   rfm_base
)
SELECT  customer_id, recency_days, frequency, ROUND(monetary, 0) AS monetary, r, f, m,
        CASE WHEN r >= 3 AND f >= 3 AND m >= 3 THEN 'Champion'
             WHEN r >= 3 AND f >= 2             THEN 'Loyal'
             WHEN r = 4                         THEN 'New / Promising'
             WHEN r <= 2 AND f >= 3             THEN 'At Risk'
             WHEN r = 1                         THEN 'Lost'
             ELSE 'Needs Attention' END AS segment
FROM    rfm_score
ORDER BY monetary DESC
LIMIT 20;

-- 4.10 Pareto / 80-20 analysis : how many customers make 80% of revenue?
WITH cust AS (
    SELECT customer_id, SUM(net_revenue) AS revenue FROM v_sales GROUP BY customer_id
),
cum AS (
    SELECT customer_id, revenue,
           SUM(revenue) OVER (ORDER BY revenue DESC)           AS running_rev,
           SUM(revenue) OVER ()                                AS total_rev,
           ROW_NUMBER() OVER (ORDER BY revenue DESC)           AS cust_rank,
           COUNT(*) OVER ()                                    AS total_customers
    FROM   cust
)
SELECT  MAX(cust_rank)                                           AS customers_for_80pct,
        MAX(total_customers)                                     AS total_customers,
        ROUND(100.0 * MAX(cust_rank) / MAX(total_customers), 1)  AS pct_of_customers
FROM    cum
WHERE   running_rev - revenue < 0.8 * total_rev;

-- 4.11 FIRST_VALUE / LAST_VALUE : compare each order to the customer's first order
WITH o AS (
    SELECT customer_id, order_id, order_date, SUM(net_revenue) AS order_value
    FROM   v_sales GROUP BY customer_id, order_id, order_date
)
SELECT  customer_id, order_date, ROUND(order_value, 0) AS order_value,
        ROUND(FIRST_VALUE(order_value) OVER (PARTITION BY customer_id ORDER BY order_date, order_id), 0) AS first_order_value,
        ROUND(order_value - FIRST_VALUE(order_value) OVER (PARTITION BY customer_id ORDER BY order_date, order_id), 0) AS change_vs_first
FROM    o
ORDER BY customer_id, order_date
LIMIT 15;
