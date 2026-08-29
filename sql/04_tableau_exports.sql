-- Varta Market: Tableau-ready datasets
-- Run each query separately and export its result as CSV.


-- ============================================================
-- 1. KPI SUMMARY
-- Export as: kpi_summary.csv
-- ============================================================

WITH yearly_metrics AS (
  SELECT
    order_year,

    COUNT(*) AS created_orders,

    COUNTIF(is_fulfilled_and_captured = 1)
      AS successful_orders,

    SAFE_DIVIDE(
      COUNTIF(is_fulfilled_and_captured = 1),
      COUNT(*)
    ) AS success_rate_percent,

    SUM(
      IF(is_fulfilled_and_captured = 1, net_revenue_uah, 0)
    ) AS net_revenue_uah,

    SUM(
      IF(is_fulfilled_and_captured = 1, gross_profit_uah, 0)
    ) AS gross_profit_uah,

    SAFE_DIVIDE(
      SUM(IF(is_fulfilled_and_captured = 1, gross_profit_uah, 0)),
      SUM(IF(is_fulfilled_and_captured = 1, net_revenue_uah, 0))
    ) AS gross_margin_percent,

    COUNT(
      DISTINCT IF(
        is_fulfilled_and_captured = 1,
        customer_id,
        NULL
      )
    ) AS active_customers

  FROM `project-3-506513.1.order_level_mart`

  WHERE order_year IN (2024, 2025)
    AND EXTRACT(MONTH FROM order_date) IN (10, 11)

  GROUP BY order_year
)

SELECT
  *,

  SAFE_DIVIDE(
    successful_orders
      - LAG(successful_orders) OVER (ORDER BY order_year),
    LAG(successful_orders) OVER (ORDER BY order_year)
  ) AS orders_yoy_percent,

  SAFE_DIVIDE(
    net_revenue_uah
      - LAG(net_revenue_uah) OVER (ORDER BY order_year),
    LAG(net_revenue_uah) OVER (ORDER BY order_year)
  ) AS revenue_yoy_percent,

  SAFE_DIVIDE(
    gross_profit_uah
      - LAG(gross_profit_uah) OVER (ORDER BY order_year),
    LAG(gross_profit_uah) OVER (ORDER BY order_year)
  ) AS gross_profit_yoy_percent,

  gross_margin_percent
    - LAG(gross_margin_percent) OVER (ORDER BY order_year)
    AS gross_margin_change_pp,

  success_rate_percent
    - LAG(success_rate_percent) OVER (ORDER BY order_year)
    AS success_rate_change_pp,

  SAFE_DIVIDE(
    active_customers
      - LAG(active_customers) OVER (ORDER BY order_year),
    LAG(active_customers) OVER (ORDER BY order_year)
  ) AS active_customers_yoy_percent

FROM yearly_metrics
ORDER BY order_year;


-- ============================================================
-- 2. MONTHLY KPIs
-- Export as: monthly_kpis.csv
-- ============================================================

WITH monthly_metrics AS (
  SELECT
    order_month,
    order_year,

    COUNT(*) AS created_orders,

    COUNTIF(is_fulfilled_and_captured = 1)
      AS successful_orders,

    SAFE_DIVIDE(
      COUNTIF(is_fulfilled_and_captured = 1),
      COUNT(*)
    ) AS success_rate_percent,

    SUM(
      IF(is_fulfilled_and_captured = 1, net_revenue_uah, 0)
    ) AS net_revenue_uah,

    SUM(
      IF(is_fulfilled_and_captured = 1, gross_profit_uah, 0)
    ) AS gross_profit_uah,

    SAFE_DIVIDE(
      SUM(IF(is_fulfilled_and_captured = 1, gross_profit_uah, 0)),
      SUM(IF(is_fulfilled_and_captured = 1, net_revenue_uah, 0))
    ) AS gross_margin_percent,

    SAFE_DIVIDE(
      SUM(IF(is_fulfilled_and_captured = 1, item_discount_uah, 0)),
      SUM(
        IF(
          is_fulfilled_and_captured = 1,
          item_sales_before_returns_uah + item_discount_uah,
          0
        )
      )
    ) AS discount_rate_percent

  FROM `project-3-506513.1.order_level_mart`

  WHERE order_year IN (2024, 2025)

  GROUP BY order_month, order_year
)

SELECT
  current_year.order_month,
  current_year.order_year,

  current_year.created_orders,
  current_year.successful_orders,
  current_year.success_rate_percent,
  current_year.net_revenue_uah,
  current_year.gross_profit_uah,
  current_year.gross_margin_percent,
  current_year.discount_rate_percent,

  SAFE_DIVIDE(
    current_year.successful_orders
      - previous_year.successful_orders,
    previous_year.successful_orders
  ) AS orders_yoy_percent,

  SAFE_DIVIDE(
    current_year.gross_profit_uah
      - previous_year.gross_profit_uah,
    previous_year.gross_profit_uah
  ) AS gross_profit_yoy_percent

FROM monthly_metrics AS current_year

LEFT JOIN monthly_metrics AS previous_year
  ON previous_year.order_month
    = DATE_SUB(current_year.order_month, INTERVAL 1 YEAR)

WHERE current_year.order_year = 2025
ORDER BY current_year.order_month;


-- ============================================================
-- 3. CUSTOMER MIX
-- Export as: customer_mix.csv
-- ============================================================

WITH successful_customer_orders AS (
  SELECT
    order_id,
    customer_id,
    order_date,
    order_year

  FROM `project-3-506513.1.order_level_mart`

  WHERE is_fulfilled_and_captured = 1
    AND customer_id IS NOT NULL
),

first_successful_order AS (
  SELECT
    customer_id,
    MIN(order_date) AS first_successful_order_date

  FROM successful_customer_orders
  GROUP BY customer_id
),

period_customers AS (
  SELECT DISTINCT
    o.order_year,
    o.customer_id,

    CASE
      WHEN f.first_successful_order_date
        >= DATE(o.order_year, 10, 1)
      THEN 'New'
      ELSE 'Returning'
    END AS customer_type

  FROM successful_customer_orders AS o

  JOIN first_successful_order AS f
    ON o.customer_id = f.customer_id

  WHERE o.order_year IN (2024, 2025)
    AND EXTRACT(MONTH FROM o.order_date) IN (10, 11)
),

customer_counts AS (
  SELECT
    order_year,
    customer_type,
    COUNT(*) AS customers

  FROM period_customers
  GROUP BY order_year, customer_type
)

SELECT
  order_year,
  customer_type,
  customers,

  SAFE_DIVIDE(
    customers,
    SUM(customers) OVER (PARTITION BY order_year)
  ) AS customer_share_percent

FROM customer_counts
ORDER BY order_year, customer_type;


-- ============================================================
-- 4. REGION SUMMARY
-- Export as: region_summary.csv
-- ============================================================

WITH region_actuals AS (
  SELECT
    normalized_shipping_region AS region,

    COUNT(*) AS orders_actual,

    COUNTIF(is_fulfilled_and_captured = 1)
      AS successful_orders,

    SUM(gross_profit_uah)
      AS gross_profit_actual_uah

  FROM `project-3-506513.1.order_level_mart`

  WHERE order_year = 2025
    AND EXTRACT(MONTH FROM order_date) IN (10, 11)

  GROUP BY normalized_shipping_region
),

region_targets AS (
  SELECT
    region,

    SUM(orders_target)
      AS orders_target,

    SUM(gross_profit_target_uah)
      AS gross_profit_target_uah

  FROM `project-3-506513.1.monthly_targets`

  WHERE PARSE_DATE('%Y-%m', month)
    BETWEEN DATE '2025-10-01' AND DATE '2025-11-01'

  GROUP BY region
)

SELECT
  t.region,

  COALESCE(a.orders_actual, 0)
    AS orders_actual,

  COALESCE(a.successful_orders, 0)
    AS successful_orders,

  t.orders_target,

  SAFE_DIVIDE(
    COALESCE(a.orders_actual, 0),
    t.orders_target
  ) AS orders_target_attainment_percent,

  COALESCE(a.gross_profit_actual_uah, 0)
    AS gross_profit_actual_uah,

  t.gross_profit_target_uah,

  SAFE_DIVIDE(
    COALESCE(a.gross_profit_actual_uah, 0),
    t.gross_profit_target_uah
  ) AS gross_profit_target_attainment_percent,

  CASE
    WHEN
      COALESCE(a.orders_actual, 0) >= t.orders_target
      AND COALESCE(a.gross_profit_actual_uah, 0)
        >= t.gross_profit_target_uah
    THEN 'Both met'

    WHEN
      COALESCE(a.orders_actual, 0) >= t.orders_target
      AND COALESCE(a.gross_profit_actual_uah, 0)
        < t.gross_profit_target_uah
    THEN 'Orders met, profit missed'

    WHEN
      COALESCE(a.orders_actual, 0) < t.orders_target
      AND COALESCE(a.gross_profit_actual_uah, 0)
        >= t.gross_profit_target_uah
    THEN 'Profit met, orders missed'

    ELSE 'Both missed'
  END AS target_status

FROM region_targets AS t

LEFT JOIN region_actuals AS a
  ON t.region = a.region

ORDER BY orders_target_attainment_percent DESC;


-- ============================================================
-- 5. CATEGORY SUMMARY
-- Export as: category_summary.csv
-- ============================================================

WITH completed_returns_by_item AS (
  SELECT
    order_item_id,
    SUM(returned_quantity) AS returned_quantity,
    SUM(refund_amount_uah) AS completed_refund_uah

  FROM `project-3-506513.1.returns`

  WHERE return_status = 'completed'
    AND DATE(return_request_ts) <= DATE '2025-12-31'

  GROUP BY order_item_id
),

category_year AS (
  SELECT
    m.order_year,
    p.category,

    SUM(oi.unit_price_uah * oi.quantity)
      AS sales_before_discount_uah,

    SUM(oi.item_discount_uah)
      AS discount_uah,

    SUM(
      oi.unit_price_uah * oi.quantity
      - oi.item_discount_uah
      - COALESCE(r.completed_refund_uah, 0)
    ) AS net_sales_uah,

    SUM(
      oi.unit_cost_uah * oi.quantity
      - oi.unit_cost_uah
        * COALESCE(r.returned_quantity, 0)
    ) AS net_cost_uah

  FROM `project-3-506513.1.order_level_mart` AS m

  JOIN `project-3-506513.1.order_items` AS oi
    ON m.order_id = oi.order_id

  JOIN `project-3-506513.1.products` AS p
    ON oi.product_id = p.product_id

  LEFT JOIN completed_returns_by_item AS r
    ON oi.order_item_id = r.order_item_id

  WHERE m.order_year IN (2024, 2025)
    AND EXTRACT(MONTH FROM m.order_date) IN (10, 11)
    AND m.is_fulfilled_and_captured = 1

  GROUP BY m.order_year, p.category
),

category_metrics AS (
  SELECT
    order_year,
    category,
    sales_before_discount_uah,
    discount_uah,
    net_sales_uah,
    net_cost_uah,

    net_sales_uah - net_cost_uah
      AS gross_profit_uah,

    SAFE_DIVIDE(
      discount_uah,
      sales_before_discount_uah
    ) AS discount_rate_percent,

    SAFE_DIVIDE(
      net_sales_uah - net_cost_uah,
      net_sales_uah
    ) AS gross_margin_percent

  FROM category_year
),

category_comparison AS (
  SELECT
    category,

    MAX(IF(order_year = 2024, gross_profit_uah, NULL))
      AS gross_profit_2024_uah,

    MAX(IF(order_year = 2025, gross_profit_uah, NULL))
      AS gross_profit_2025_uah,

    MAX(IF(order_year = 2024, discount_rate_percent, NULL))
      AS discount_rate_2024_percent,

    MAX(IF(order_year = 2025, discount_rate_percent, NULL))
      AS discount_rate_2025_percent,

    MAX(IF(order_year = 2025, gross_margin_percent, NULL))
      AS gross_margin_2025_percent

  FROM category_metrics
  GROUP BY category
)

SELECT
  category,
  gross_profit_2024_uah,
  gross_profit_2025_uah,

  gross_profit_2025_uah - gross_profit_2024_uah
    AS gross_profit_change_uah,

  discount_rate_2024_percent,
  discount_rate_2025_percent,
  gross_margin_2025_percent,

  CASE
    WHEN gross_profit_2025_uah >= gross_profit_2024_uah
      THEN 'Growth'
    ELSE 'Decline'
  END AS category_result

FROM category_comparison
ORDER BY gross_profit_change_uah DESC;
