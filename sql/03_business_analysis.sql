-- Varta Market: core business analysis
-- Main comparison period: October-November 2025 vs 2024


-- ============================================================
-- 1. Executive KPI comparison
-- ============================================================

WITH period_metrics AS (
  SELECT
    order_year,

    COUNT(*) AS created_orders,

    COUNTIF(is_fulfilled_and_captured = 1)
      AS successful_orders,

    SUM(
      IF(is_fulfilled_and_captured = 1, net_revenue_uah, 0)
    ) AS net_revenue_uah,

    SUM(
      IF(is_fulfilled_and_captured = 1, gross_profit_uah, 0)
    ) AS gross_profit_uah,

    SUM(
      IF(is_fulfilled_and_captured = 1, item_discount_uah, 0)
    ) AS discount_uah,

    SUM(
      IF(
        is_fulfilled_and_captured = 1,
        item_sales_before_returns_uah + item_discount_uah,
        0
      )
    ) AS sales_before_discount_uah,

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
),

calculated_metrics AS (
  SELECT
    *,

    100 * SAFE_DIVIDE(successful_orders, created_orders)
      AS success_rate_percent,

    100 * SAFE_DIVIDE(gross_profit_uah, net_revenue_uah)
      AS gross_margin_percent,

    100 * SAFE_DIVIDE(discount_uah, sales_before_discount_uah)
      AS discount_rate_percent

  FROM period_metrics
)

SELECT
  *,

  ROUND(
    100 * SAFE_DIVIDE(
      successful_orders
        - LAG(successful_orders) OVER (ORDER BY order_year),
      LAG(successful_orders) OVER (ORDER BY order_year)
    ),
    2
  ) AS orders_yoy_percent,

  ROUND(
    100 * SAFE_DIVIDE(
      net_revenue_uah
        - LAG(net_revenue_uah) OVER (ORDER BY order_year),
      LAG(net_revenue_uah) OVER (ORDER BY order_year)
    ),
    2
  ) AS revenue_yoy_percent,

  ROUND(
    100 * SAFE_DIVIDE(
      gross_profit_uah
        - LAG(gross_profit_uah) OVER (ORDER BY order_year),
      LAG(gross_profit_uah) OVER (ORDER BY order_year)
    ),
    2
  ) AS gross_profit_yoy_percent,

  ROUND(
    gross_margin_percent
      - LAG(gross_margin_percent) OVER (ORDER BY order_year),
    2
  ) AS gross_margin_change_pp,

  ROUND(
    100 * SAFE_DIVIDE(
      active_customers
        - LAG(active_customers) OVER (ORDER BY order_year),
      LAG(active_customers) OVER (ORDER BY order_year)
    ),
    2
  ) AS active_customers_yoy_percent

FROM calculated_metrics
ORDER BY order_year;


-- ============================================================
-- 2. Monthly YoY growth: successful orders and gross profit
-- ============================================================

WITH monthly_metrics AS (
  SELECT
    order_month,
    order_year,

    COUNTIF(is_fulfilled_and_captured = 1)
      AS successful_orders,

    SUM(
      IF(is_fulfilled_and_captured = 1, gross_profit_uah, 0)
    ) AS gross_profit_uah

  FROM `project-3-506513.1.order_level_mart`

  WHERE order_year IN (2024, 2025)

  GROUP BY order_month, order_year
)

SELECT
  current_year.order_month,

  current_year.successful_orders
    AS successful_orders_2025,

  previous_year.successful_orders
    AS successful_orders_2024,

  ROUND(
    100 * SAFE_DIVIDE(
      current_year.successful_orders
        - previous_year.successful_orders,
      previous_year.successful_orders
    ),
    2
  ) AS orders_yoy_percent,

  current_year.gross_profit_uah
    AS gross_profit_2025_uah,

  previous_year.gross_profit_uah
    AS gross_profit_2024_uah,

  ROUND(
    100 * SAFE_DIVIDE(
      current_year.gross_profit_uah
        - previous_year.gross_profit_uah,
      previous_year.gross_profit_uah
    ),
    2
  ) AS gross_profit_yoy_percent

FROM monthly_metrics AS current_year

LEFT JOIN monthly_metrics AS previous_year
  ON previous_year.order_month
    = DATE_SUB(current_year.order_month, INTERVAL 1 YEAR)

WHERE current_year.order_year = 2025
ORDER BY current_year.order_month;


-- ============================================================
-- 3. Customer mix: new vs returning customers
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

  ROUND(
    100 * SAFE_DIVIDE(
      customers,
      SUM(customers) OVER (PARTITION BY order_year)
    ),
    2
  ) AS customer_share_percent

FROM customer_counts
ORDER BY order_year, customer_type;


-- ============================================================
-- 4. Discount-rate change and incremental discount scenario
-- ============================================================

WITH item_sales AS (
  SELECT
    m.order_year,

    SUM(oi.unit_price_uah * oi.quantity)
      AS sales_before_discount_uah,

    SUM(oi.item_discount_uah)
      AS discount_uah

  FROM `project-3-506513.1.order_level_mart` AS m

  JOIN `project-3-506513.1.order_items` AS oi
    ON m.order_id = oi.order_id

  WHERE m.order_year IN (2024, 2025)
    AND EXTRACT(MONTH FROM m.order_date) IN (10, 11)
    AND m.is_fulfilled_and_captured = 1

  GROUP BY m.order_year
),

discount_metrics AS (
  SELECT
    order_year,
    sales_before_discount_uah,
    discount_uah,

    SAFE_DIVIDE(
      discount_uah,
      sales_before_discount_uah
    ) AS discount_rate

  FROM item_sales
),

comparison AS (
  SELECT
    current_year.sales_before_discount_uah
      AS sales_2025_before_discount_uah,

    previous_year.discount_rate
      AS discount_rate_2024,

    current_year.discount_rate
      AS discount_rate_2025,

    current_year.discount_uah
      AS actual_discount_2025_uah

  FROM discount_metrics AS current_year

  CROSS JOIN discount_metrics AS previous_year

  WHERE current_year.order_year = 2025
    AND previous_year.order_year = 2024
)

SELECT
  ROUND(sales_2025_before_discount_uah, 2)
    AS sales_2025_before_discount_uah,

  ROUND(100 * discount_rate_2024, 2)
    AS discount_rate_2024_percent,

  ROUND(100 * discount_rate_2025, 2)
    AS discount_rate_2025_percent,

  ROUND(actual_discount_2025_uah, 2)
    AS actual_discount_2025_uah,

  ROUND(
    sales_2025_before_discount_uah * discount_rate_2024,
    2
  ) AS discount_at_2024_rate_uah,

  ROUND(
    actual_discount_2025_uah
      - sales_2025_before_discount_uah * discount_rate_2024,
    2
  ) AS incremental_discount_scenario_uah

FROM comparison;


-- ============================================================
-- 5. Gross-profit change by product category
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

    SUM(
      oi.unit_price_uah * oi.quantity
      - oi.item_discount_uah
      - COALESCE(r.completed_refund_uah, 0)
      - (
          oi.unit_cost_uah * oi.quantity
          - oi.unit_cost_uah
            * COALESCE(r.returned_quantity, 0)
        )
    ) AS gross_profit_uah

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

category_comparison AS (
  SELECT
    category,

    MAX(IF(order_year = 2024, gross_profit_uah, NULL))
      AS gross_profit_2024_uah,

    MAX(IF(order_year = 2025, gross_profit_uah, NULL))
      AS gross_profit_2025_uah

  FROM category_year
  GROUP BY category
)

SELECT
  category,
  ROUND(gross_profit_2024_uah, 2)
    AS gross_profit_2024_uah,

  ROUND(gross_profit_2025_uah, 2)
    AS gross_profit_2025_uah,

  ROUND(
    gross_profit_2025_uah - gross_profit_2024_uah,
    2
  ) AS gross_profit_change_uah,

  CASE
    WHEN gross_profit_2025_uah >= gross_profit_2024_uah
      THEN 'Growth'
    ELSE 'Decline'
  END AS profit_change_direction

FROM category_comparison
ORDER BY gross_profit_change_uah DESC;


-- ============================================================
-- 6. Regional target attainment
-- ============================================================

WITH region_actuals AS (
  SELECT
    normalized_shipping_region AS region,

    COUNT(*) AS orders_actual,

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

  a.orders_actual,
  t.orders_target,

  ROUND(
    100 * SAFE_DIVIDE(a.orders_actual, t.orders_target),
    2
  ) AS orders_target_attainment_percent,

  ROUND(a.gross_profit_actual_uah, 2)
    AS gross_profit_actual_uah,

  ROUND(t.gross_profit_target_uah, 2)
    AS gross_profit_target_uah,

  ROUND(
    100 * SAFE_DIVIDE(
      a.gross_profit_actual_uah,
      t.gross_profit_target_uah
    ),
    2
  ) AS gross_profit_target_attainment_percent

FROM region_targets AS t

LEFT JOIN region_actuals AS a
  ON t.region = a.region

ORDER BY orders_target_attainment_percent DESC;
