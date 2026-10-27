USE ecommerce_analytics;

-- 1. KPI overview
SELECT ROUND(SUM(CASE WHEN is_cancelled = 0 THEN total_price END), 2)               AS gross_revenue,
       ROUND(-SUM(CASE WHEN is_cancelled = 1 THEN total_price END), 2)              AS cancelled_value,
       ROUND(SUM(total_price), 2)                                                   AS net_revenue,
       COUNT(DISTINCT CASE WHEN is_cancelled = 0 THEN invoice_no END)               AS orders,
       COUNT(DISTINCT customer_id)                                                  AS customers,
       ROUND(SUM(CASE WHEN is_cancelled = 0 THEN total_price END)
             / COUNT(DISTINCT CASE WHEN is_cancelled = 0 THEN invoice_no END), 2)   AS avg_order_value
FROM online_retail;

-- 2. Monthly revenue, orders, AOV and month-over-month growth (2011-12 is a partial month: data ends 2011-12-09)
WITH monthly AS (
    SELECT invoice_year_month AS month,
           ROUND(SUM(total_price), 2)       AS revenue,
           COUNT(DISTINCT invoice_no)       AS orders,
           COUNT(DISTINCT customer_id)      AS customers
    FROM online_retail
    WHERE is_cancelled = 0
    GROUP BY invoice_year_month
)
SELECT month, revenue, orders, customers,
       ROUND(revenue / orders, 2) AS avg_order_value,
       ROUND((revenue - LAG(revenue) OVER (ORDER BY month)) / LAG(revenue) OVER (ORDER BY month) * 100, 1) AS mom_growth_pct
FROM monthly
ORDER BY month;

-- 3. Revenue by day of week
SELECT day_of_week,
       ROUND(SUM(total_price), 2)  AS revenue,
       COUNT(DISTINCT invoice_no)  AS orders
FROM online_retail
WHERE is_cancelled = 0
GROUP BY day_of_week
ORDER BY FIELD(day_of_week, 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday');

-- 4. Revenue by hour of day
SELECT invoice_hour,
       ROUND(SUM(total_price), 2)  AS revenue,
       COUNT(DISTINCT invoice_no)  AS orders
FROM online_retail
WHERE is_cancelled = 0
GROUP BY invoice_hour
ORDER BY invoice_hour;

-- 5. Top 10 products by net revenue
SELECT stock_code, description,
       SUM(quantity)              AS net_units,
       ROUND(SUM(total_price), 2) AS net_revenue,
       ROUND(SUM(total_price) / SUM(SUM(total_price)) OVER () * 100, 2) AS revenue_share_pct
FROM online_retail
GROUP BY stock_code, description
ORDER BY net_revenue DESC
LIMIT 10;

-- 6. Top 10 products by net units sold
SELECT stock_code, description,
       SUM(quantity)              AS net_units,
       ROUND(SUM(total_price), 2) AS net_revenue
FROM online_retail
GROUP BY stock_code, description
ORDER BY net_units DESC
LIMIT 10;

-- 7. Revenue by country
SELECT COALESCE(country, 'Unknown') AS country,
       ROUND(SUM(total_price), 2)                                       AS revenue,
       COUNT(DISTINCT invoice_no)                                       AS orders,
       COUNT(DISTINCT customer_id)                                      AS customers,
       ROUND(SUM(total_price) / SUM(SUM(total_price)) OVER () * 100, 2) AS revenue_share_pct
FROM online_retail
WHERE is_cancelled = 0
GROUP BY country
ORDER BY revenue DESC;

-- 8. Top 10 customers by net revenue
SELECT customer_id,
       COUNT(DISTINCT CASE WHEN is_cancelled = 0 THEN invoice_no END) AS orders,
       ROUND(SUM(total_price), 2)                                     AS net_revenue,
       MIN(invoice_date)                                              AS first_activity,
       MAX(invoice_date)                                              AS last_activity
FROM online_retail
WHERE customer_id IS NOT NULL
GROUP BY customer_id
ORDER BY net_revenue DESC
LIMIT 10;

-- 9. RFM segmentation (snapshot = day after the last invoice, monetary = net revenue)
WITH snapshot AS (
    SELECT DATE_ADD(MAX(invoice_date), INTERVAL 1 DAY) AS snapshot_date FROM online_retail
),
rfm AS (
    SELECT o.customer_id,
           DATEDIFF(s.snapshot_date, MAX(CASE WHEN o.is_cancelled = 0 THEN o.invoice_date END)) AS recency,
           COUNT(DISTINCT CASE WHEN o.is_cancelled = 0 THEN o.invoice_no END)                   AS frequency,
           SUM(o.total_price)                                                                   AS monetary
    FROM online_retail o
    CROSS JOIN snapshot s
    WHERE o.customer_id IS NOT NULL
    GROUP BY o.customer_id, s.snapshot_date
    HAVING frequency > 0 AND monetary > 0
),
scored AS (
    SELECT *,
           NTILE(5) OVER (ORDER BY recency DESC)   AS r_score,
           NTILE(5) OVER (ORDER BY frequency ASC)  AS f_score,
           NTILE(5) OVER (ORDER BY monetary ASC)   AS m_score
    FROM rfm
),
segmented AS (
    SELECT *,
           CASE WHEN r_score >= 4 AND f_score >= 4 THEN 'Champions'
                WHEN r_score >= 3 AND f_score >= 3 THEN 'Loyal'
                WHEN r_score >= 4 AND f_score <= 2 THEN 'New / Promising'
                WHEN r_score <= 2 AND f_score >= 4 THEN 'At Risk (was loyal)'
                WHEN r_score <= 2 AND f_score <= 2 THEN 'Lost'
                ELSE 'Needs Attention' END AS segment
    FROM scored
)
SELECT segment,
       COUNT(*)                                                    AS customers,
       ROUND(AVG(recency), 0)                                      AS avg_recency_days,
       ROUND(AVG(frequency), 1)                                    AS avg_orders,
       ROUND(SUM(monetary), 2)                                     AS revenue,
       ROUND(SUM(monetary) / SUM(SUM(monetary)) OVER () * 100, 1)  AS revenue_share_pct
FROM segmented
GROUP BY segment
ORDER BY revenue DESC;

-- 10. Repeat customers
WITH per_customer AS (
    SELECT customer_id, COUNT(DISTINCT invoice_no) AS orders
    FROM online_retail
    WHERE is_cancelled = 0 AND customer_id IS NOT NULL
    GROUP BY customer_id
)
SELECT COUNT(*)                                         AS customers,
       SUM(orders > 1)                                  AS repeat_customers,
       ROUND(SUM(orders > 1) / COUNT(*) * 100, 1)       AS repeat_rate_pct
FROM per_customer;

-- 11. Cohort retention by first purchase month (% of cohort active N months later)
WITH first_purchase AS (
    SELECT customer_id, MIN(DATE_FORMAT(invoice_date, '%Y-%m-01')) AS cohort_month
    FROM online_retail
    WHERE is_cancelled = 0 AND customer_id IS NOT NULL
    GROUP BY customer_id
),
activity AS (
    SELECT DISTINCT o.customer_id, f.cohort_month,
           TIMESTAMPDIFF(MONTH, f.cohort_month, o.invoice_date) AS month_index
    FROM online_retail o
    JOIN first_purchase f ON f.customer_id = o.customer_id
    WHERE o.is_cancelled = 0
),
cohort_sizes AS (
    SELECT cohort_month, COUNT(*) AS cohort_size FROM first_purchase GROUP BY cohort_month
)
SELECT DATE_FORMAT(a.cohort_month, '%Y-%m') AS cohort,
       c.cohort_size,
       a.month_index,
       COUNT(*)                                    AS active_customers,
       ROUND(COUNT(*) / c.cohort_size * 100, 1)    AS retention_pct
FROM activity a
JOIN cohort_sizes c ON c.cohort_month = a.cohort_month
GROUP BY a.cohort_month, c.cohort_size, a.month_index
ORDER BY a.cohort_month, a.month_index;

-- 12. Cancellation rate by month
SELECT invoice_year_month AS month,
       COUNT(DISTINCT CASE WHEN is_cancelled = 1 THEN invoice_no END)               AS cancelled_invoices,
       COUNT(DISTINCT invoice_no)                                                   AS total_invoices,
       ROUND(COUNT(DISTINCT CASE WHEN is_cancelled = 1 THEN invoice_no END)
             / COUNT(DISTINCT invoice_no) * 100, 1)                                 AS cancel_rate_pct,
       ROUND(-SUM(CASE WHEN is_cancelled = 1 THEN total_price END), 2)              AS cancelled_value
FROM online_retail
GROUP BY invoice_year_month
ORDER BY month;

-- 13. Top 10 most cancelled products
SELECT stock_code, description,
       -SUM(quantity)              AS units_cancelled,
       ROUND(-SUM(total_price), 2) AS cancelled_value
FROM online_retail
WHERE is_cancelled = 1
GROUP BY stock_code, description
ORDER BY cancelled_value DESC
LIMIT 10;

-- 14. Pareto: net revenue by customer quintile (quintile 1 = top 20% of customers)
WITH cust AS (
    SELECT customer_id, SUM(total_price) AS revenue
    FROM online_retail
    WHERE customer_id IS NOT NULL
    GROUP BY customer_id
    HAVING revenue > 0
),
ranked AS (
    SELECT revenue, NTILE(5) OVER (ORDER BY revenue DESC) AS quintile FROM cust
)
SELECT quintile,
       COUNT(*)                                                    AS customers,
       ROUND(SUM(revenue), 2)                                      AS revenue,
       ROUND(SUM(revenue) / SUM(SUM(revenue)) OVER () * 100, 1)    AS revenue_share_pct
FROM ranked
GROUP BY quintile
ORDER BY quintile;