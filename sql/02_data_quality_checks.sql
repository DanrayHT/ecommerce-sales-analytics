USE ecommerce_analytics;

SELECT check_name, issue_count,
       CASE WHEN severity = 'INFO' THEN 'INFO'
            WHEN issue_count = 0 THEN 'OK' ELSE 'FAIL' END AS status
FROM (
    SELECT 'Null in required columns' AS check_name, 'ERROR' AS severity, COUNT(*) AS issue_count
    FROM online_retail
    WHERE invoice_no IS NULL OR stock_code IS NULL OR description IS NULL
       OR invoice_date IS NULL OR unit_price IS NULL OR quantity IS NULL

    UNION ALL
    SELECT 'Duplicate rows', 'ERROR', COALESCE(SUM(cnt - 1), 0)
    FROM (SELECT COUNT(*) AS cnt FROM online_retail
          GROUP BY invoice_no, stock_code, description, quantity, invoice_date, unit_price, customer_id, country
          HAVING COUNT(*) > 1) d

    UNION ALL
    SELECT 'Price <= 0', 'ERROR', COUNT(*) FROM online_retail WHERE unit_price <= 0

    UNION ALL
    SELECT 'Sale with quantity <= 0', 'ERROR', COUNT(*) FROM online_retail WHERE is_cancelled = 0 AND quantity <= 0

    UNION ALL
    SELECT 'Cancellation with quantity >= 0', 'ERROR', COUNT(*) FROM online_retail WHERE is_cancelled = 1 AND quantity >= 0

    UNION ALL
    SELECT 'Cancel flag does not match invoice prefix', 'ERROR', COUNT(*)
    FROM online_retail WHERE is_cancelled <> (invoice_no LIKE 'C%')

    UNION ALL
    SELECT 'total_price <> quantity * unit_price', 'ERROR', COUNT(*)
    FROM online_retail WHERE ABS(total_price - quantity * unit_price) > 0.01

    UNION ALL
    SELECT 'Stock code with more than one description', 'ERROR', COUNT(*)
    FROM (SELECT stock_code FROM online_retail GROUP BY stock_code HAVING COUNT(DISTINCT description) > 1) x

    UNION ALL
    SELECT 'Invoice spanning multiple customers', 'ERROR', COUNT(*)
    FROM (SELECT invoice_no FROM online_retail GROUP BY invoice_no HAVING COUNT(DISTINCT customer_id) > 1) x

    UNION ALL
    SELECT 'Invoice date outside 2010-12-01 .. 2011-12-09', 'ERROR', COUNT(*)
    FROM online_retail WHERE invoice_date < '2010-12-01' OR invoice_date >= '2011-12-10'

    UNION ALL
    SELECT 'Rows without customer_id', 'INFO', COUNT(*) FROM online_retail WHERE customer_id IS NULL

    UNION ALL
    SELECT 'Rows without country', 'INFO', COUNT(*) FROM online_retail WHERE country IS NULL

    UNION ALL
    SELECT 'Outlier rows (|quantity| > 10000 or price > 1000)', 'INFO', COUNT(*)
    FROM online_retail WHERE ABS(quantity) > 10000 OR unit_price > 1000
) checks;

SELECT COUNT(*)                                                    AS total_rows,
       COUNT(DISTINCT invoice_no)                                  AS invoices,
       COUNT(DISTINCT stock_code)                                  AS products,
       COUNT(DISTINCT customer_id)                                 AS customers,
       ROUND(SUM(CASE WHEN is_cancelled = 0 THEN total_price END), 2) AS gross_revenue
FROM online_retail;