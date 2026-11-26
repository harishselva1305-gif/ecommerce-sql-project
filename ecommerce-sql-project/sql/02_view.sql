-- ---------------------------------------------------------------------
-- BASE VIEW : one row per delivered order line with revenue & profit
-- (single source of truth, so every report uses the same revenue logic)
-- ---------------------------------------------------------------------
CREATE VIEW v_sales AS
SELECT  o.order_id,
        o.customer_id,
        o.order_date,
        strftime('%Y-%m', o.order_date)                                  AS order_month,  -- PostgreSQL: TO_CHAR(order_date,'YYYY-MM')
        p.product_id,
        p.product_name,
        p.category,
        oi.quantity,
        ROUND(oi.quantity * p.unit_price * (1 - oi.discount_pct / 100.0), 2)                   AS net_revenue,
        ROUND(oi.quantity * (p.unit_price * (1 - oi.discount_pct / 100.0) - p.cost_price), 2)  AS profit
FROM    orders o
JOIN    order_items oi ON oi.order_id   = o.order_id
JOIN    products    p  ON p.product_id  = oi.product_id
WHERE   o.status = 'Delivered';
