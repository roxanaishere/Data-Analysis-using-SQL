/* This project is part of work at DataCamp SQL for Business Analyst track. */
/* In this project, I will perform data analysis on key metrics that businesses use to measure performance. 
I'll write SQL queries to calculate these metrics and produce report-ready results for a fictional food delivery company. */
/* The datasets are from real companies. */

-- ---------------------------
-- Revenue, Cost, and Profit--
-- ---------------------------
/* Profit is one of the first things people use to assess a company's success. I calculated revenue and cost, and then combine the two calculations using Common Table Expressions to calculate profit. */
WITH revenue AS ( 
	SELECT
		DATE_TRUNC('month', order_date) :: DATE AS delivr_month,
		sum(meal_price * order_quantity) AS revenue
	FROM meals
	JOIN orders ON meals.meal_id = orders.meal_id
	GROUP BY delivr_month),
  cost AS (
 	SELECT
		DATE_TRUNC('month', stocking_date) :: DATE AS delivr_month,
		sum(meal_cost * stocked_quantity) AS cost
	FROM meals
    JOIN stock ON meals.meal_id = stock.meal_id
	GROUP BY delivr_month)

SELECT
	revenue.delivr_month,
	revenue - cost as profit
FROM revenue
JOIN cost ON revenue.delivr_month = cost.delivr_month
ORDER BY revenue.delivr_month ASC;


-- ------------------
-- User-Centric KPIs-
-- ------------------
/* Financial KPIs like profit are important, but they don't speak to user activity and engagement. I then calculated the registrations and active users KPIs, and use window functions to calculate the user growth and retention rates. */

-- Registrations
WITH reg_dates AS (
  SELECT
    user_id,
    MIN(order_date) AS reg_date -- A Delivr user's registration date is the date of that user's first order.
  FROM orders
  GROUP BY user_id)

SELECT
  date_trunc('month', reg_date):: DATE AS delivr_month,
  count(distinct user_id) AS regs
FROM reg_dates
GROUP BY delivr_month
ORDER BY delivr_month ASC; 


-- MAU Monitor: Month-on-Month (MoM) MAU Growth Rate
WITH mau AS (
  SELECT
    DATE_TRUNC('month', order_date) :: DATE AS delivr_month,
    COUNT(DISTINCT user_id) AS mau
  FROM orders
  GROUP BY delivr_month),

  mau_with_lag AS (
  SELECT
    delivr_month,
    mau,
    GREATEST(
      LAG(mau) OVER (ORDER BY delivr_month ASC),
    1) AS last_mau
  FROM mau)

SELECT
  delivr_month,
  ROUND(
    (mau - last_mau)::numeric / last_mau,
  2) AS growth
FROM mau_with_lag
ORDER BY delivr_month;

-- MoM Order Growth Rate
WITH orders AS (
  SELECT
    DATE_TRUNC('month', order_date) :: DATE AS delivr_month,
    count(distinct order_id) AS orders
  FROM orders
  GROUP BY delivr_month),

  orders_with_lag AS (
  SELECT
    delivr_month,
    orders,
    COALESCE(
      lag(orders) over (order by delivr_month),
    1) AS last_orders
  FROM orders)

SELECT
  delivr_month,
  ROUND(
    (orders - last_orders)::numeric / last_orders,
  2) AS growth
FROM orders_with_lag
ORDER BY delivr_month ASC;


-- Retention Rate
WITH user_monthly_activity AS (
  SELECT DISTINCT
    DATE_TRUNC('month', order_date) :: DATE AS delivr_month,
    user_id
  FROM orders)

SELECT
  previous.delivr_month,
  ROUND(
    count(distinct current.user_id)::numeric/
    greatest(count(distinct previous.user_id),1),
  2) AS retention_rate
FROM user_monthly_activity AS previous
LEFT JOIN user_monthly_activity AS current
ON previous.user_id = current.user_id
AND previous.delivr_month = (current.delivr_month - Interval '1 month')
GROUP BY previous.delivr_month
ORDER BY previous.delivr_month ASC;


-- ----------------------------------
-- ARPU, Histograms, and Percentiles-
-- ----------------------------------
/* Since a KPI is a single number, it can't describe how data is distributed. Thus I went on to dive into unit economics, histograms, bucketing, and percentiles, which can help spot the variance in user behaviors. */

-- ARPU: Average Revenue Per User (Per Week)
WITH kpi AS (
  SELECT
    date_trunc('week', order_date) :: date AS delivr_week,
    sum(meal_price * order_quantity) AS revenue,
    count(distinct user_id) AS users
  FROM meals AS m
  JOIN orders AS o ON m.meal_id = o.meal_id
  GROUP BY delivr_week)

SELECT
  delivr_week,
  ROUND(
    revenue :: numeric / greatest(users,1),
  2) AS arpu
FROM kpi
ORDER BY delivr_week ASC;

-- Histogram of Revenue: A frequency table of revenue by user
WITH user_revenues AS (
  SELECT
    user_id,
    sum(meal_price * order_quantity) AS revenue
  FROM meals AS m
  JOIN orders AS o ON m.meal_id = o.meal_id
  GROUP BY user_id)

SELECT
  round(revenue::numeric, -2) AS revenue_100,
  count(distinct user_id) AS users
FROM user_revenues
GROUP BY revenue_100
ORDER BY revenue_100 ASC;

-- Bucketing Users by Orders
with user_orders as(
  SELECT
    user_id,
    count(distinct order_id) AS orders
  FROM orders
  GROUP BY user_id)

SELECT
  CASE
    WHEN orders < 8 THEN 'Low-orders users'
    WHEN orders < 15 THEN 'Mid-orders users'
    ELSE 'High-orders users'
  END AS order_group,
  count(distinct user_id) AS users
FROM user_orders
GROUP BY order_group;

-- Revenue Interquartile Range (IQR): Count of users in IQR
WITH user_revenues AS (
  SELECT
    user_id,
    SUM(m.meal_price * o.order_quantity) AS revenue
  FROM meals AS m
  JOIN orders AS o ON m.meal_id = o.meal_id
  GROUP BY user_id),

  quartiles AS (
  SELECT
    ROUND(
      PERCENTILE_CONT(0.25) WITHIN GROUP
      (ORDER BY revenue ASC) :: NUMERIC,
    2) AS revenue_p25,
    ROUND(
      PERCENTILE_CONT(0.75) WITHIN GROUP
      (ORDER BY revenue ASC) :: NUMERIC,
    2) AS revenue_p75
  FROM user_revenues)

SELECT
  count(distinct user_id) AS users
FROM user_revenues
CROSS JOIN quartiles
WHERE revenue :: NUMERIC >= revenue_p25
  AND revenue :: NUMERIC <= revenue_p75;
  
  
