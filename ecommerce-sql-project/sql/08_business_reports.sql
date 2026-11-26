/* =====================================================================
   SECTION 6 : FINAL BUSINESS REPORTS (put it all together)
   ===================================================================== */

-- 6.1 EXECUTIVE KPI SUMMARY
SELECT  ROUND(SUM(net_revenue), 0)                          AS total_revenue,
        ROUND(SUM(profit), 0)                               AS total_profit,
        ROUND(100.0 * SUM(profit) / SUM(net_revenue), 1)    AS profit_margin_pct,
        COUNT(DISTINCT order_id)                            AS delivered_orders,
        COUNT(DISTINCT customer_id)                         AS buying_customers,
        ROUND(SUM(net_revenue) / COUNT(DISTINCT order_id), 0) AS avg_order_value
FROM    v_sales;

-- 6.2 Order status leakage : how much demand is lost to cancellations / returns?
SELECT  o.status,
        COUNT(DISTINCT o.order_id)                               AS orders,
        ROUND(100.0 * COUNT(DISTINCT o.order_id)
              / SUM(COUNT(DISTINCT o.order_id)) OVER (), 1)      AS pct_of_orders
FROM    orders o
GROUP BY o.status
ORDER BY orders DESC;

-- 6.3 State-wise performance with rank
SELECT  c.state,
        ROUND(SUM(v.net_revenue), 0)                           AS revenue,
        COUNT(DISTINCT v.customer_id)                          AS customers,
        RANK() OVER (ORDER BY SUM(v.net_revenue) DESC)         AS state_rank
FROM    v_sales v
JOIN    customers c ON c.customer_id = v.customer_id
GROUP BY c.state
ORDER BY state_rank;

-- 6.4 Category profitability (revenue rank vs profit-margin rank)
SELECT  category,
        ROUND(SUM(net_revenue), 0)                         AS revenue,
        ROUND(100.0 * SUM(profit) / SUM(net_revenue), 1)   AS margin_pct,
        RANK() OVER (ORDER BY SUM(net_revenue) DESC)       AS revenue_rank,
        RANK() OVER (ORDER BY SUM(profit) / SUM(net_revenue) DESC) AS margin_rank
FROM    v_sales
GROUP BY category;

-- 6.5 Does discounting actually help?  (volume vs margin by discount band)
SELECT  oi.discount_pct,
        COUNT(*)                                                           AS line_items,
        SUM(oi.quantity)                                                   AS units,
        ROUND(AVG(100.0 * (p.unit_price * (1 - oi.discount_pct / 100.0) - p.cost_price)
                  / (p.unit_price * (1 - oi.discount_pct / 100.0))), 1)    AS avg_margin_pct
FROM    order_items oi
JOIN    orders   o ON o.order_id   = oi.order_id AND o.status = 'Delivered'
JOIN    products p ON p.product_id = oi.product_id
GROUP BY oi.discount_pct
ORDER BY oi.discount_pct;

-- 6.6 Repeat-purchase rate
WITH c AS (
    SELECT customer_id, COUNT(DISTINCT order_id) AS orders FROM v_sales GROUP BY customer_id
)
SELECT  COUNT(*)                                              AS buying_customers,
        SUM(CASE WHEN orders > 1 THEN 1 ELSE 0 END)           AS repeat_customers,
        ROUND(100.0 * SUM(CASE WHEN orders > 1 THEN 1 ELSE 0 END) / COUNT(*), 1) AS repeat_rate_pct
FROM    c;

-- 6.7 Frequently bought together : product pairs in the same order (self join)
SELECT  p1.product_name AS product_a, p2.product_name AS product_b, COUNT(*) AS times_together
FROM    order_items a
JOIN    order_items b  ON a.order_id = b.order_id AND a.product_id < b.product_id
JOIN    products p1    ON p1.product_id = a.product_id
JOIN    products p2    ON p2.product_id = b.product_id
GROUP BY p1.product_name, p2.product_name
ORDER BY times_together DESC
LIMIT 10;

-- 6.8 Best-selling day of week and payment mix
SELECT  CASE strftime('%w', order_date) WHEN '0' THEN 'Sun' WHEN '1' THEN 'Mon' WHEN '2' THEN 'Tue'
             WHEN '3' THEN 'Wed' WHEN '4' THEN 'Thu' WHEN '5' THEN 'Fri' ELSE 'Sat' END AS weekday,
        COUNT(DISTINCT order_id)    AS orders,
        ROUND(SUM(net_revenue), 0)  AS revenue
FROM    v_sales
GROUP BY strftime('%w', order_date)
ORDER BY strftime('%w', order_date);

/* ================================ END ================================ */
