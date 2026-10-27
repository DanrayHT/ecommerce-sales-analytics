CREATE DATABASE IF NOT EXISTS ecommerce_analytics
    DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE ecommerce_analytics;

CREATE TABLE IF NOT EXISTS online_retail (
    id                 INT UNSIGNED   NOT NULL AUTO_INCREMENT PRIMARY KEY,
    invoice_no         VARCHAR(20)    NOT NULL,
    stock_code         VARCHAR(20)    NOT NULL,
    description        VARCHAR(255)   NOT NULL,
    quantity           INT            NOT NULL,
    invoice_date       DATETIME       NOT NULL,
    unit_price         DECIMAL(10,2)  NOT NULL,
    customer_id        INT            NULL,
    country            VARCHAR(60)    NULL,
    is_cancelled       TINYINT(1)     NOT NULL DEFAULT 0,
    total_price        DECIMAL(12,2)  NOT NULL,
    invoice_year       SMALLINT       NOT NULL,
    invoice_month      TINYINT        NOT NULL,
    invoice_year_month CHAR(7)        NOT NULL,
    day_of_week        VARCHAR(10)    NOT NULL,
    invoice_hour       TINYINT        NOT NULL,
    INDEX idx_invoice_no   (invoice_no),
    INDEX idx_stock_code   (stock_code),
    INDEX idx_customer_id  (customer_id),
    INDEX idx_invoice_date (invoice_date),
    INDEX idx_country      (country),
    INDEX idx_year_month   (invoice_year_month)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;