ALTER TABLE customers ADD CONSTRAINT PK_customers PRIMARY KEY (customer_id);
ALTER TABLE products  ADD CONSTRAINT PK_products  PRIMARY KEY (product_id);
ALTER TABLE orders    ADD CONSTRAINT FK_orders_customers
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id);
ALTER TABLE orders    ADD CONSTRAINT FK_orders_products
    FOREIGN KEY (product_id)  REFERENCES products(product_id);


-- ─────────────────────────────────────────
-- 1. Revenue by category and sub-category
-- ─────────────────────────────────────────
SELECT
    p.category,
    p.sub_category,
    SUM(o.quantity * o.unit_price * (1 - COALESCE(o.discount_pct, 0))) AS total_revenue,
    COUNT(DISTINCT o.order_id) AS order_count
FROM orders o
JOIN products p ON o.product_id = p.product_id
GROUP BY p.category, p.sub_category
ORDER BY total_revenue DESC;


-- ─────────────────────────────────────────
-- 2. Revenue and order count by governorate
-- ─────────────────────────────────────────
SELECT
    c.governorate,
    COUNT(DISTINCT o.order_id) AS order_count,
    SUM(o.quantity * o.unit_price * (1 - COALESCE(o.discount_pct, 0))) AS total_revenue
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
GROUP BY c.governorate
ORDER BY total_revenue DESC;


-- ─────────────────────────────────────────
-- 3. Monthly revenue trend (2023–2025)
-- ─────────────────────────────────────────
SELECT
    YEAR(order_date)  AS order_year,
    MONTH(order_date) AS order_month,
    SUM(quantity * unit_price * (1 - COALESCE(discount_pct, 0))) AS total_revenue,
    COUNT(DISTINCT order_id) AS order_count
FROM orders
GROUP BY YEAR(order_date), MONTH(order_date)
ORDER BY order_year, order_month;


-- ─────────────────────────────────────────
-- 4. Top 15 customers by lifetime spend
-- ─────────────────────────────────────────
SELECT TOP 15
    c.customer_id,
    c.customer_name,
    c.governorate,
    COUNT(DISTINCT o.order_id) AS total_orders,
    SUM(o.quantity * o.unit_price * (1 - COALESCE(o.discount_pct, 0))) AS lifetime_spend
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
GROUP BY c.customer_id, c.customer_name, c.governorate
ORDER BY lifetime_spend DESC;


-- ─────────────────────────────────────────
-- 5. RFM segmentation (Recency, Frequency, Monetary)
-- ─────────────────────────────────────────

WITH customer_metrics AS (
    SELECT
        c.customer_id,
        c.customer_name,
        DATEDIFF(DAY, MAX(o.order_date), (SELECT MAX(order_date) FROM orders)) AS recency_days,
        COUNT(DISTINCT o.order_id) AS frequency,
        SUM(o.quantity * o.unit_price * (1 - COALESCE(o.discount_pct, 0))) AS monetary
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    GROUP BY c.customer_id, c.customer_name
),
rfm_scores AS (
    SELECT
        *,
        NTILE(4) OVER (ORDER BY recency_days DESC) AS R_Score,
        NTILE(4) OVER (ORDER BY frequency ASC)     AS F_Score,
        NTILE(4) OVER (ORDER BY monetary ASC)      AS M_Score
    FROM customer_metrics
)
SELECT
    *,
    CASE
        WHEN R_Score >= 3 AND F_Score >= 3 AND M_Score >= 3 THEN 'Champions'
        WHEN F_Score >= 3 AND M_Score >= 3                  THEN 'Loyal Customers'
        WHEN R_Score <= 2 AND (F_Score >= 3 OR M_Score >= 3) THEN 'At Risk'
        ELSE 'Lost'
    END AS rfm_segment
FROM rfm_scores
ORDER BY monetary DESC;
