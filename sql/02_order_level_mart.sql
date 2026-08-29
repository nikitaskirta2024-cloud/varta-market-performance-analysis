-- Varta Market: order-level analytical mart
-- Grain: one row per order
-- Combines orders, customers, items, payments and completed returns.
-- The mart preserves all orders and provides flags for KPI filtering.

CREATE OR REPLACE TABLE `project-3-506513.1.order_level_mart` AS

WITH items_by_order AS (
  SELECT
    order_id,

    COUNT(*) AS order_lines_count,
    COUNT(DISTINCT product_id) AS distinct_products_count,
    SUM(quantity) AS sold_quantity,
    SUM(item_discount_uah) AS item_discount_uah,

    SUM(
      unit_price_uah * quantity
      - item_discount_uah
    ) AS item_sales_before_returns_uah,

    SUM(
      unit_cost_uah * quantity
    ) AS item_cost_before_returns_uah,

    SUM(
      unit_price_uah * quantity
      - item_discount_uah
      - unit_cost_uah * quantity
    ) AS item_gross_profit_before_returns_uah

  FROM `project-3-506513.1.order_items`
  GROUP BY order_id
),


payments_by_order AS (
  SELECT
    order_id,

    COUNT(*) AS payment_events_count,

    COUNTIF(payment_status = 'captured')
      AS captured_events,

    COUNTIF(payment_status = 'failed')
      AS failed_events,

    COUNTIF(payment_status = 'pending')
      AS pending_events,

    COUNTIF(payment_status = 'refunded')
      AS refunded_events,

    COUNTIF(payment_status = 'chargeback')
      AS chargeback_events,

    SUM(
      IF(
        payment_status = 'captured',
        payment_amount_uah,
        0
      )
    ) AS captured_amount_uah,

    SUM(
      IF(
        payment_status = 'refunded',
        payment_amount_uah,
        0
      )
    ) AS payment_refunded_uah,

    SUM(
      IF(
        payment_status = 'chargeback',
        payment_amount_uah,
        0
      )
    ) AS chargeback_uah,

    SUM(
      CASE
        WHEN payment_status = 'captured'
          THEN payment_amount_uah

        WHEN payment_status IN ('refunded', 'chargeback')
          THEN -payment_amount_uah

        ELSE 0
      END
    ) AS retained_payment_uah,

    ARRAY_AGG(
      payment_status
      ORDER BY payment_sequence DESC, payment_ts DESC
      LIMIT 1
    )[OFFSET(0)] AS latest_payment_status,

    MAX(payment_ts) AS last_payment_ts

  FROM `project-3-506513.1.payments`

  WHERE DATE(payment_ts) <= DATE '2025-12-31'

  GROUP BY order_id
),


returns_by_order AS (
  SELECT
    r.order_id,

    COUNT(*) AS return_requests_count,

    COUNTIF(r.return_status = 'requested')
      AS requested_returns,

    COUNTIF(r.return_status = 'approved')
      AS approved_returns,

    COUNTIF(r.return_status = 'completed')
      AS completed_returns,

    COUNTIF(r.return_status = 'rejected')
      AS rejected_returns,

    SUM(
      IF(
        r.return_status = 'completed',
        r.returned_quantity,
        0
      )
    ) AS returned_quantity,

    SUM(
      IF(
        r.return_status = 'completed',
        r.refund_amount_uah,
        0
      )
    ) AS completed_refund_uah,

    SUM(
      IF(
        r.return_status = 'completed',
        oi.unit_cost_uah * r.returned_quantity,
        0
      )
    ) AS returned_item_cost_uah,

    MAX(r.return_request_ts) AS last_return_request_ts

  FROM `project-3-506513.1.returns` AS r

  LEFT JOIN `project-3-506513.1.order_items` AS oi
    ON r.order_item_id = oi.order_item_id

  WHERE DATE(r.return_request_ts) <= DATE '2025-12-31'

  GROUP BY r.order_id
),


order_base AS (
  SELECT
    o.order_id,
    o.customer_id,

    o.order_ts,
    DATE(o.order_ts) AS order_date,
    DATE_TRUNC(DATE(o.order_ts), MONTH) AS order_month,
    EXTRACT(YEAR FROM o.order_ts) AS order_year,

    o.order_status,
    o.order_channel,
    o.device_type,

    o.shipping_region,
    CASE LOWER(
  TRIM(
    REGEXP_REPLACE(o.shipping_region, r'[-\s]+', ' ')
  )
)
  WHEN 'dnipropetrovsk'  THEN 'Dnipropetrovsk'
  WHEN 'dnipropetrovska' THEN 'Dnipropetrovsk'
  WHEN 'ivano frankivsk' THEN 'Ivano-Frankivsk'
  WHEN 'kharkiv'         THEN 'Kharkiv'
  WHEN 'kyiv'            THEN 'Kyiv'
  WHEN 'kyiv city'       THEN 'Kyiv City'
  WHEN 'lviv'            THEN 'Lviv'
  WHEN 'odesa'           THEN 'Odesa'
  WHEN 'odessa'          THEN 'Odesa'
  WHEN 'poltava'         THEN 'Poltava'
  WHEN 'vinnytsia'       THEN 'Vinnytsia'
  WHEN 'zaporizhia'      THEN 'Zaporizhzhia'
  WHEN 'zaporizhzhia'    THEN 'Zaporizhzhia'
  ELSE o.shipping_region
END AS normalized_shipping_region,
    o.shipping_city,
    o.shipping_fee_uah,

    o.promised_delivery_ts,
    o.delivered_ts,

    CASE
      WHEN o.customer_id IS NULL THEN 1
      ELSE 0
    END AS is_guest_checkout,

    CASE
      WHEN o.customer_id IS NULL
        THEN 'Guest checkout'

      WHEN c.acquisition_channel IS NULL
        THEN 'Unknown acquisition channel'

      ELSE c.acquisition_channel
    END AS acquisition_channel,

    c.loyalty_tier,
    c.home_region AS customer_home_region,
    c.home_city AS customer_home_city,
    c.birth_year,
    c.signup_ts,

    CASE
      WHEN
        o.order_status = 'delivered'
        AND o.delivered_ts IS NOT NULL
        AND DATE(o.delivered_ts) <= DATE '2025-12-31'
      THEN 1
      ELSE 0
    END AS is_delivered_by_cutoff,

    CASE
      WHEN i.order_id IS NOT NULL THEN 1
      ELSE 0
    END AS has_order_items,

    COALESCE(i.order_lines_count, 0)
      AS order_lines_count,

    COALESCE(i.distinct_products_count, 0)
      AS distinct_products_count,

    COALESCE(i.sold_quantity, 0)
      AS sold_quantity,

    COALESCE(i.item_discount_uah, 0)
      AS item_discount_uah,

    COALESCE(i.item_sales_before_returns_uah, 0)
      AS item_sales_before_returns_uah,

    COALESCE(i.item_cost_before_returns_uah, 0)
      AS item_cost_before_returns_uah,

    COALESCE(i.item_gross_profit_before_returns_uah, 0)
      AS item_gross_profit_before_returns_uah,

    COALESCE(p.payment_events_count, 0)
      AS payment_events_count,

    COALESCE(p.captured_events, 0)
      AS captured_events,

    COALESCE(p.failed_events, 0)
      AS failed_events,

    COALESCE(p.pending_events, 0)
      AS pending_events,

    COALESCE(p.refunded_events, 0)
      AS refunded_events,

    COALESCE(p.chargeback_events, 0)
      AS chargeback_events,

    COALESCE(p.captured_amount_uah, 0)
      AS captured_amount_uah,

    COALESCE(p.payment_refunded_uah, 0)
      AS payment_refunded_uah,

    COALESCE(p.chargeback_uah, 0)
      AS chargeback_uah,

    COALESCE(p.retained_payment_uah, 0)
      AS retained_payment_uah,

    p.latest_payment_status,
    p.last_payment_ts,

    COALESCE(r.return_requests_count, 0)
      AS return_requests_count,

    COALESCE(r.requested_returns, 0)
      AS requested_returns,

    COALESCE(r.approved_returns, 0)
      AS approved_returns,

    COALESCE(r.completed_returns, 0)
      AS completed_returns,

    COALESCE(r.rejected_returns, 0)
      AS rejected_returns,

    COALESCE(r.returned_quantity, 0)
      AS returned_quantity,

    COALESCE(r.completed_refund_uah, 0)
      AS completed_refund_uah,

    COALESCE(r.returned_item_cost_uah, 0)
      AS returned_item_cost_uah,

    r.last_return_request_ts

  FROM `project-3-506513.1.orders` AS o

  LEFT JOIN `project-3-506513.1.customers` AS c
    ON o.customer_id = c.customer_id

  LEFT JOIN items_by_order AS i
    ON o.order_id = i.order_id

  LEFT JOIN payments_by_order AS p
    ON o.order_id = p.order_id

  LEFT JOIN returns_by_order AS r
    ON o.order_id = r.order_id

  WHERE DATE(o.order_ts)
    BETWEEN DATE '2024-01-01' AND DATE '2025-12-31'
),


order_financials AS (
  SELECT
    *,

    CASE
      WHEN is_delivered_by_cutoff = 1
      THEN retained_payment_uah - completed_refund_uah
      ELSE 0
    END AS net_revenue_uah,

    CASE
      WHEN is_delivered_by_cutoff = 1
      THEN item_cost_before_returns_uah - returned_item_cost_uah
      ELSE 0
    END AS net_item_cost_uah,

    CASE
      WHEN is_delivered_by_cutoff = 1
      THEN sold_quantity - returned_quantity
      ELSE 0
    END AS net_sold_quantity

  FROM order_base
),


order_metrics AS (
  SELECT
    *,

    net_revenue_uah - net_item_cost_uah
      AS gross_profit_uah,

    CASE
      WHEN
        is_delivered_by_cutoff = 1
        AND captured_events > 0
      THEN 1
      ELSE 0
    END AS is_fulfilled_and_captured,

    CASE
      WHEN
        is_delivered_by_cutoff = 1
        AND net_revenue_uah > 0
      THEN 1
      ELSE 0
    END AS is_retained_sale,

    CASE
      WHEN
        is_delivered_by_cutoff = 1
        AND captured_events > 0
        AND net_revenue_uah <= 0
      THEN 1
      ELSE 0
    END AS is_fully_reversed_sale

  FROM order_financials
)


SELECT
  *,
  CASE
    WHEN net_revenue_uah > 0
    THEN ROUND(
      100 * SAFE_DIVIDE(
        gross_profit_uah,
        net_revenue_uah
      ),
      2
    )
    ELSE NULL
  END AS gross_margin_percent

FROM order_metrics
ORDER BY order_ts, order_id; 
