
-- structure of the each columns
DESC customers;
desc order_items;
desc orders;
desc products;

 -- checking the missing values
 SELECT
    SUM(customer_id IS NULL) AS customer_id_null,
    SUM(customer_name IS NULL) AS customer_name_null,
    SUM(city IS NULL) AS city_null,
    SUM(gender IS NULL) AS gender_null,
    SUM(signup_date IS NULL) AS signup_date_null
FROM customers;

-- --------------------- Sales & Revenue Analysis ```````````````````````````

-- 01 What is our total revenue?
SELECT  SUM(quantity * unit_price) 
	AS total_revenue
FROM order_items;

-- 02 How has our revenue trended month by month?
SELECT  DATE_FORMAT(o.order_date, '%Y-%m') AS month,
SUM(oi.quantity * oi.unit_price) AS total_revenue
FROM orders o
JOIN order_items oi 
    ON o.order_id = oi.order_id
GROUP BY DATE_FORMAT(o.order_date, '%Y-%m')
ORDER BY month;

-- 03 Which month had the highest revenue?
SELECT DATE_FORMAT(o.order_date, '%Y-%m') AS month,
    ROUND(SUM(oi.quantity * oi.unit_price), 2) AS revenue
FROM orders o
JOIN order_items oi
    ON o.order_id = oi.order_id
GROUP BY DATE_FORMAT(o.order_date, '%Y-%m')
ORDER BY revenue DESC
LIMIT 3;

-- 04 Which category generates the most revenue?
SELECT p.category, SUM(oi.quantity * oi.unit_price) 
AS total_revenue
	FROM order_items oi
JOIN products p 
    ON oi.product_id = p.product_id
GROUP BY p.category
ORDER BY total_revenue DESC
LIMIT 1;

-- 05 What percentage does each category contribute to total revenue?
SELECT 
p.category,
    ROUND(SUM(oi.quantity * oi.unit_price), 2) AS revenue,
    ROUND(
        100 * SUM(oi.quantity * oi.unit_price)
        / SUM(SUM(oi.quantity * oi.unit_price)) OVER (),2) 
AS revenue_percentage
FROM products p
JOIN order_items oi
    ON p.product_id = oi.product_id
GROUP BY p.category
ORDER BY revenue_percentage DESC;

-- ----------------------------Product Analysis ``````````````````````````````````````

-- 01 What are the top 5 best-selling products?
SELECT p.product_id,p.product_name,SUM(oi.quantity) 
	AS total_quantity_sold
FROM order_items oi
JOIN products p 
    ON oi.product_id = p.product_id
GROUP BY p.product_id, p.product_name
ORDER BY total_quantity_sold DESC
LIMIT 5;

-- 02 Which product generates the highest revenue?
SELECT p.product_id,p.product_name,
    SUM(oi.quantity * oi.unit_price) AS total_revenue
FROM products p
JOIN order_items oi 
    ON p.product_id = oi.product_id
GROUP BY p.product_id, p.product_name
ORDER BY total_revenue DESC
LIMIT 1;

-- 03 Which is the best-selling product category?
SELECT p.category,SUM(oi.quantity) AS total_quantity_sold
FROM products p
JOIN order_items oi 
    ON p.product_id = oi.product_id
GROUP BY p.category
ORDER BY total_quantity_sold DESC
LIMIT 1;

-- 04 Which product generates the lowest revenue?
SELECT p.product_id,p.product_name,SUM(oi.quantity * oi.unit_price) AS total_revenue
FROM products p
JOIN order_items oi 
    ON p.product_id = oi.product_id
GROUP BY p.product_id, p.product_name
ORDER BY total_revenue ASC
LIMIT 1;

-- 05 Which two products are most frequently purchased together?
SELECT 
    p1.product_name AS product_1,
    p2.product_name AS product_2,
    COUNT(*) AS times_purchased_together
FROM order_items oi1
JOIN order_items oi2
    ON oi1.order_id = oi2.order_id
    AND oi1.product_id < oi2.product_id
JOIN products p1
    ON oi1.product_id = p1.product_id
JOIN products p2
    ON oi2.product_id = p2.product_id
GROUP BY p1.product_name, p2.product_name
ORDER BY times_purchased_together DESC
LIMIT 1;

-- -----------Customer Analysis````````````````````````

-- 01 Who are our top 5 most valuable customers?
SELECT c.customer_id,c.customer_name,
    SUM(oi.quantity * oi.unit_price) AS total_spent
FROM customers c
JOIN orders o 
    ON c.customer_id = o.customer_id
JOIN order_items oi 
    ON o.order_id = oi.order_id
GROUP BY c.customer_id, c.customer_name
ORDER BY total_spent DESC
LIMIT 5;

-- 02 Which customers purchase repeatedly?
SELECT c.customer_id,c.customer_name,
    COUNT(o.order_id) AS total_orders
FROM customers c
JOIN orders o 
    ON c.customer_id = o.customer_id
GROUP BY c.customer_id, c.customer_name
HAVING COUNT(o.order_id) > 1
ORDER BY total_orders DESC;

-- 03 How many customers are new vs returning?
WITH first_order AS (SELECT customer_id,
        MIN(order_date) AS first_order_date,
        COUNT(*) AS total_orders
    FROM orders
    GROUP BY customer_id
)
SELECT CASE
        WHEN total_orders = 1 THEN 'New Customer'
        ELSE 'Returning Customer'
    END AS customer_type,
    COUNT(*) AS total_customers
FROM first_order
GROUP BY customer_type;

-- 04 How many new customers were acquired each month?
WITH first_order AS (SELECT customer_id,
        MIN(order_date) AS first_order_date
    FROM orders
    GROUP BY customer_id
)
SELECT
    DATE_FORMAT(first_order_date, '%Y-%m') AS month,
    COUNT(*) AS new_customers
FROM first_order
GROUP BY DATE_FORMAT(first_order_date, '%Y-%m')
ORDER BY month;

-- 05 Which customers purchase from more than one category?
SELECT o.customer_id,
    COUNT(DISTINCT p.category) AS total_categories
FROM orders o
JOIN order_items oi
    ON o.order_id = oi.order_id
JOIN products p
    ON oi.product_id = p.product_id
GROUP BY o.customer_id
HAVING COUNT(DISTINCT p.category) > 1;

-- ---------Customer Retention & Order Analysis-----------------
-- 01 Which customers are at risk of churn?
SELECT customer_id,
    MAX(order_date) AS last_order_date
FROM orders
GROUP BY customer_id
HAVING MAX(order_date) < DATE_SUB('2026-04-30', INTERVAL 90 DAY)
ORDER BY last_order_date;

-- 02 What is the customer churn rate?
WITH customer_last_order AS (
SELECT customer_id,MAX(order_date) AS last_order_date
    FROM orders
    GROUP BY customer_id
)
SELECT ROUND(100 * SUM(
            CASE
                WHEN last_order_date < '2026-04-30' THEN 1 ELSE 0 END
        ) / COUNT(*),2) AS churn_rate
FROM customer_last_order;

-- 03 What percentage of orders get cancelled?alter
SELECT ROUND(100 * SUM(
            CASE
                WHEN order_status = 'Cancelled' THEN 1
                ELSE 0
            END
        ) / COUNT(*),2) AS cancelled_order_percentage
FROM orders;

-- 04 How many orders were delivered vs cancelled?
SELECT
    order_status,
    COUNT(*) AS total_orders
FROM orders
WHERE order_status IN ('Delivered', 'Cancelled')
GROUP BY order_status;

-- 05 What is the daily sales trend?
SELECT 
    o.order_date,
    ROUND(SUM(oi.quantity * oi.unit_price), 2) AS daily_revenue
FROM orders o
JOIN order_items oi
    ON o.order_id = oi.order_id
GROUP BY o.order_date
ORDER BY o.order_date;

































