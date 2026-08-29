# Varta Market — E-commerce Performance Analysis

An end-to-end e-commerce analysis built with BigQuery SQL and Tableau to determine whether rapid order growth in 2025 was profitable and sustainable.

[View the interactive Tableau dashboard](https://public.tableau.com/app/profile/nikita.sergeevich/viz/VartaMarket2025Performance/ExecutiveOverview)

## Business Problem

Varta Market experienced strong order growth in 2025. Management needed to understand:

* whether the growth represented completed and paid orders;
* whether revenue and gross profit grew at the same pace;
* what caused the decline in profitability;
* which regions and product categories required attention;
* whether growth was supported by returning customers.

The main comparison covers October–November 2025 versus the same period in 2024. December was excluded because some orders had not reached their final status by the analysis cutoff.

## Key Results

* Successful orders reached **17,155**, up **30.8% YoY**.
* Net revenue reached **UAH 43.70M**, up **30.1% YoY**.
* Gross profit reached **UAH 15.47M**, but grew by only **13.3% YoY**.
* Gross margin fell to **35.41%**, a decline of **5.24 percentage points**.
* The average discount rate increased from approximately **4.7% to 10.7%**.
* Applying the 2024 category-level discount rates to the observed 2025 sales mix produced a **UAH 3.05M scenario gap** in realized revenue.
* Returning customers increased their share from **57.5% to 71.8%**, providing a positive signal for customer retention.
* **Electronics** and **Kids** were the only categories with a negative YoY change in gross profit.
* Most regions that achieved their order targets still failed to achieve their gross-profit targets.

## Main Conclusion

Order growth was real, but it became significantly less profitable in October–November 2025.

The main visible driver was the sharp increase in discounts. Higher product costs and returns created additional pressure. At the same time, the growing share of returning customers suggests that the customer base became more stable.

The discount impact is a scenario estimate rather than proven lost profit: the available observational data cannot show how many customers would still have purchased without the higher discounts.

## Recommendations

1. Evaluate promotional campaigns using control groups or A/B tests before maintaining the higher discount level.
2. Track gross profit and gross margin alongside order targets to prevent unprofitable growth.
3. Investigate pricing, discounts, product costs, and returns in the Electronics and Kids categories.
4. Continue monitoring returning-customer share and repeat-purchase behavior.
5. Review regions that achieved order targets but missed gross-profit targets.

## KPI Definitions

* **Successful Order:** an order that was fulfilled and had a captured payment.
* **Net Revenue:** retained customer payments after completed refunds and chargebacks.
* **Gross Profit:** net revenue minus the cost of retained items.
* **Gross Margin:** gross profit divided by net revenue.
* **Discount Rate:** item discounts divided by merchandise value before discounts.
* **Returning Customer:** a customer whose first successful order occurred before the analyzed period.

## Data and Methodology

The analysis used seven e-commerce tables:

* orders;
* order items;
* customers;
* products;
* payments;
* returns;
* monthly regional targets.

The workflow included:

1. Data-quality and relationship checks.
2. Construction of an order-level analytical mart.
3. Monthly and YoY KPI analysis.
4. Profitability-driver analysis by category.
5. Customer and regional target analysis.
6. Tableau dashboard development.

A data-quality issue involving delivered orders with missing delivery timestamps was identified and documented during validation.

## Tools

* **BigQuery SQL** — data validation, transformations, KPI calculations, and analytical queries.
* **Tableau Public** — dashboard development and business visualization.
* **GitHub** — project documentation and reproducibility.

## Limitations

* The analysis is observational and does not prove that higher discounts caused additional orders.
* Guest purchases cannot be reliably connected across multiple orders.
* Gross profit does not include payroll, taxes, marketing expenses, or other operating costs.
* December was excluded from the final YoY comparison because of incomplete order outcomes at the cutoff date.
