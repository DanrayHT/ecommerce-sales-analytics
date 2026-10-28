USE ecommerce_analytics;

CREATE OR REPLACE VIEW vw_customer_rfm AS
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
           CASE WHEN recency <= 30 THEN 5 WHEN recency <= 90 THEN 4 WHEN recency <= 180 THEN 3
                WHEN recency <= 270 THEN 2 ELSE 1 END AS r_score,
           CASE WHEN frequency >= 10 THEN 5 WHEN frequency >= 5 THEN 4 WHEN frequency >= 3 THEN 3
                WHEN frequency = 2 THEN 2 ELSE 1 END  AS f_score,
           NTILE(5) OVER (ORDER BY monetary ASC, customer_id) AS m_score
    FROM rfm
)
SELECT customer_id, recency, frequency, ROUND(monetary, 2) AS monetary, r_score, f_score, m_score,
       CASE WHEN r_score >= 4 AND f_score >= 4 THEN 'Champions'
                WHEN (r_score <= 3 AND f_score >= 4) OR (r_score <= 2 AND f_score >= 3) THEN 'At Risk (was loyal)'
                WHEN r_score >= 3 AND f_score >= 3 THEN 'Loyal'
                WHEN r_score >= 4 AND f_score <= 2 THEN 'New / Promising'
                WHEN r_score <= 2 AND f_score <= 2 THEN 'Lost'
                ELSE 'Needs Attention' END AS segment
FROM scored;

CREATE OR REPLACE VIEW vw_cohort_retention AS
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
       COUNT(*)                                 AS active_customers,
       ROUND(COUNT(*) / c.cohort_size * 100, 1) AS retention_pct
FROM activity a
JOIN cohort_sizes c ON c.cohort_month = a.cohort_month
GROUP BY a.cohort_month, c.cohort_size, a.month_index;