-- Varta Market: data quality and relationship checks
-- BigQuery Standard SQL

-- =====================================================
-- 1. Row counts
-- =====================================================

SELECT 'orders' AS table_name, COUNT(*) AS row_count
FROM `project-3-506513.1.orders`

UNION ALL

SELECT 'order_items', COUNT(*)
FROM `project-3-506513.1.order_items`

UNION ALL

SELECT 'customers', COUNT(*)
FROM `project-3-506513.1.customers`

UNION ALL

SELECT 'products', COUNT(*)
FROM `project-3-506513.1.products`

UNION ALL

SELECT 'payments', COUNT(*)
FROM `project-3-506513.1.payments`

UNION ALL

SELECT 'returns', COUNT(*)
FROM `project-3-506513.1.returns`

UNION ALL

SELECT 'monthly_targets', COUNT(*)
FROM `project-3-506513.1.monthly_targets`;


-- =====================================================
-- 2. Primary-key duplicate checks
-- =====================================================

SELECT
  'orders.order_id' AS checked_key,
  COUNT(*) - COUNT(DISTINCT order_id) AS duplicate_rows
FROM `project-3-506513.1.orders`

UNION ALL

SELECT
  'order_items.order_item_id',
  COUNT(*) - COUNT(DISTINCT order_item_id)
FROM `project-3-506513.1.order_items`

UNION ALL

SELECT
  'customers.customer_id',
  COUNT(*) - COUNT(DISTINCT customer_id)
FROM `project-3-506513.1.customers`

UNION ALL

SELECT
  'products.product_id',
  COUNT(*) - COUNT(DISTINCT product_id)
FROM `project-3-506513.1.products`;


-- =====================================================
-- 3. Orphan-record checks
-- =====================================================

SELECT
  'orders -> customers' AS relationship,
  COUNT(*) AS orphan_rows
FROM `project-3-506513.1.orders` AS o

LEFT JOIN `project-3-506513.1.customers` AS c
  ON o.customer_id = c.customer_id

WHERE o.customer_id IS NOT NULL
  AND c.customer_id IS NULL

UNION ALL

SELECT
  'order_items -> orders',
  COUNT(*)
FROM `project-3-506513.1.order_items` AS oi

LEFT JOIN `project-3-506513.1.orders` AS o
  ON oi.order_id = o.order_id

WHERE o.order_id IS NULL

UNION ALL

SELECT
  'order_items -> products',
  COUNT(*)
FROM `project-3-506513.1.order_items` AS oi

LEFT JOIN `project-3-506513.1.products` AS p
  ON oi.product_id = p.product_id

WHERE p.product_id IS NULL

UNION ALL

SELECT
  'payments -> orders',
  COUNT(*)
FROM `project-3-506513.1.payments` AS pay

LEFT JOIN `project-3-506513.1.orders` AS o
  ON pay.order_id = o.order_id

WHERE o.order_id IS NULL

UNION ALL

SELECT
  'returns -> order_items',
  COUNT(*)
FROM `project-3-506513.1.returns` AS r

LEFT JOIN `project-3-506513.1.order_items` AS oi
  ON r.order_item_id = oi.order_item_id

WHERE oi.order_item_id IS NULL;


-- =====================================================
-- 4. Important NULL and status checks
-- =====================================================

SELECT
  COUNT(*) AS total_orders,

  COUNTIF(customer_id IS NULL)
    AS missing_customer_id,

  ROUND(
    100 * SAFE_DIVIDE(
      COUNTIF(customer_id IS NULL),
      COUNT(*)
    ),
    2
  ) AS missing_customer_percent,

  COUNTIF(delivered_ts IS NULL)
    AS missing_delivered_ts,

  COUNTIF(
    order_status = 'delivered'
    AND delivered_ts IS NULL
  ) AS delivered_without_timestamp

FROM `project-3-506513.1.orders`;


-- =====================================================
-- 5. Invalid item-value checks
-- =====================================================

SELECT
  COUNT(*) AS total_order_items,

  COUNTIF(quantity <= 0)
    AS invalid_quantity,

  COUNTIF(unit_price_uah < 0)
    AS negative_price,

  COUNTIF(unit_cost_uah < 0)
    AS negative_cost,

  COUNTIF(item_discount_uah < 0)
    AS negative_discount,

  COUNTIF(
    item_discount_uah
      > unit_price_uah * quantity
  ) AS discount_above_item_value

FROM `project-3-506513.1.order_items`;
