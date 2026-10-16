-- CREDIT RISK
-- Q1. Which business unit has the biggest share of overdue receivables?
SELECT b.bu_name,
       ROUND(SUM(i.open_balance_inr) / 10000000, 1) AS open_cr,
       ROUND(SUM(CASE WHEN i.days_overdue > 0 THEN i.open_balance_inr ELSE 0 END) / 10000000, 1) AS overdue_cr,
       ROUND(100 * SUM(CASE WHEN i.days_overdue > 0 THEN i.open_balance_inr ELSE 0 END) / SUM(i.open_balance_inr), 1) AS overdue_pct
FROM invoices i
JOIN business_units b ON i.bu_id = b.bu_id
GROUP BY b.bu_name
ORDER BY overdue_pct DESC;

-- Findings: Industrial Resins has 55% of its open balance overdue (₹37.6 of ₹68.2 crore), against 18% to 32% in the other units. It holds 24% of the open balance but 41% of all overdue money.

-- Q2. Do weaker-rated customers hold most of the overdue amount?
SELECT c.credit_rating,
       COUNT(DISTINCT c.customer_id) AS customers,
       ROUND(SUM(i.open_balance_inr) / 10000000, 1) AS open_cr,
       ROUND(SUM(CASE WHEN i.days_overdue > 0 THEN i.open_balance_inr ELSE 0 END) / 10000000, 1) AS overdue_cr,
       ROUND(100 * SUM(CASE WHEN i.days_overdue > 0 THEN i.open_balance_inr ELSE 0 END) / SUM(i.open_balance_inr), 1) AS overdue_pct
FROM invoices i
JOIN customers c ON i.customer_id = c.customer_id
GROUP BY c.credit_rating
ORDER BY overdue_cr DESC;

-- Findings: Yes. Customers rated B, BB and CCC hold ₹57.5 of the ₹92.6 crore overdue (62%), yet they are 63 of the 236 customers with invoices (27%). Rating B is the worst, with 66% of its balance overdue. Unrated is the label for customers with a blank rating.

-- Q3. Which 10 customers have the largest overdue balance?
SELECT c.customer_name,
       c.credit_rating,
       COUNT(*) AS overdue_invoices,
       ROUND(SUM(i.open_balance_inr) / 10000000, 2) AS overdue_cr
FROM invoices i
JOIN customers c ON i.customer_id = c.customer_id
WHERE i.days_overdue > 0
GROUP BY c.customer_id, c.customer_name, c.credit_rating
ORDER BY overdue_cr DESC
LIMIT 10;

-- Findings: The ten largest overdue customers owe ₹42.9 crore, 46% of all overdue money, and every one is rated BB or worse or is unrated. Bharat Agri Products S.p.A. alone owes ₹10.6 crore across 11 overdue invoices.

-- Q4. Which customers owe more than their approved credit limit?
SELECT c.customer_name,
       c.credit_rating,
       ROUND(c.credit_limit_inr / 10000000, 2) AS credit_limit_cr,
       ROUND(SUM(i.open_balance_inr) / 10000000, 2) AS open_cr,
       ROUND((SUM(i.open_balance_inr) - c.credit_limit_inr) / 10000000, 2) AS excess_cr
FROM invoices i
JOIN customers c ON i.customer_id = c.customer_id
WHERE c.credit_limit_inr > 0
GROUP BY c.customer_id, c.customer_name, c.credit_rating, c.credit_limit_inr
HAVING SUM(i.open_balance_inr) > c.credit_limit_inr
ORDER BY excess_cr DESC;

-- Findings: 17 customers owe more than their limit, by ₹50.7 crore in total, and all 17 are rated BB or worse or are unrated which is a gap in credit controls.

-- Q5. How old are the unpaid invoices?
-- Solved in excel using PivotTable

-- LIQUIDITY RISK
-- Q6. Which units came closest to a cash squeeze?
SELECT b.bu_name,
       ROUND(MIN((t.closing_cash + t.undrawn_credit_line) / t.short_term_debt_due_30d), 2) AS lowest_coverage,
       ROUND(AVG((t.closing_cash + t.undrawn_credit_line) / t.short_term_debt_due_30d), 2) AS avg_coverage,
       SUM(CASE WHEN (t.closing_cash + t.undrawn_credit_line) / t.short_term_debt_due_30d < 1
                THEN 1 ELSE 0 END) AS months_below_1
FROM treasury_monthly t
JOIN business_units b ON t.bu_id = b.bu_id
GROUP BY b.bu_name
ORDER BY lowest_coverage;

-- Findings: Industrial Resins fell below 1.0 in four months (July, September, October and November 2023), reaching 0.55 in November 2023. Engineering Compounds dipped once, to 0.91 in February 2024. The other three units never fell below 2.6.

-- Q7. How strong is working capital in each unit?
SELECT b.bu_name,
       ROUND(AVG(t.current_assets / t.current_liabilities), 2) AS avg_current_ratio,
       ROUND(AVG((t.current_assets - t.inventory) / t.current_liabilities), 2) AS avg_quick_ratio
FROM treasury_monthly t
JOIN business_units b ON t.bu_id = b.bu_id
GROUP BY b.bu_name
ORDER BY avg_quick_ratio;

-- Findings: Industrial Resins has the weakest quick ratio (1.50) and Packaging Films the strongest (2.45). The ranking matches the 30-day coverage ranking, and dividing average assets by average liabilities instead gives the same order.

-- Q8. Working capital cycle: how many days does cash stay tied up?
-- Solved in Excel using formulas to find DIO, DSO, DPO and CCC

-- MARKET RISK
-- Q9. How volatile are USD/INR, EUR/INR and crude oil, and what is the worst likely one-day move? 
-- Solved in Excel using formulas to find Daily Volatality and VaR

-- Q10. How much crude-linked buying is unhedged, and did hedging help or cost money?
SELECT b.bu_name,
       ROUND(SUM(p.total_amount) / 1000000, 1) AS crude_spend_usd_m,
       ROUND(SUM(CASE WHEN p.hedged_flag = 'N' THEN p.total_amount ELSE 0 END) / 1000000, 1) AS unhedged_usd_m,
       ROUND(100 * SUM(CASE WHEN p.hedged_flag = 'N' THEN p.total_amount ELSE 0 END)
                 / SUM(p.total_amount), 0) AS unhedged_pct,
       ROUND(SUM(CASE WHEN p.hedged_flag = 'Y'
                      THEN p.quantity * (p.unit_price - p.hedge_price) ELSE 0 END) / 1000000, 2) AS hedge_result_usd_m
FROM purchases p
JOIN business_units b ON p.bu_id = b.bu_id
WHERE p.material = 'Crude-linked feedstock'
GROUP BY b.bu_id, b.bu_name
ORDER BY unhedged_pct DESC;

-- Findings: Industrial Resins leaves 78% of its crude buying unhedged ($20.5m of $26.4m), the highest share and the largest unhedged amount. Across the company $57.4m of $106.2m is unhedged. Every unit's hedges lost money, $1.38m in total, because oil drifted lower after the prices were locked in. Packaging Films, the heaviest hedger, lost the most ($0.65m). This is the cost of insurance and not evidence that hedging was a mistake. Ten hedged purchases have no recorded hedge price and are skipped in the result column.

-- Q11. How much of the foreign-currency money still to be collected is unhedged?
SELECT b.bu_name,
       i.currency,
       COUNT(*) AS open_invoices,
       ROUND(SUM(i.invoice_amount - i.amount_paid) / 1000000, 2) AS open_unhedged_m,
       ROUND(SUM(i.open_balance_inr) / 10000000, 1) AS open_unhedged_cr
FROM invoices i
JOIN business_units b ON i.bu_id = b.bu_id
WHERE i.currency <> 'INR'
  AND i.hedged_flag = 'N'
  AND i.status IN ('OPEN', 'PARTIALLY PAID')
GROUP BY b.bu_id, b.bu_name, i.currency
ORDER BY open_unhedged_cr DESC;

-- Findings: ₹59.7 crore of foreign-currency receivables is unhedged, 46% of the ₹129.0 crore still to be collected in foreign currency: 3.34 million USD (₹28.7 crore) and 3.42 million EUR (₹31.0 crore). Industrial Resins holds ₹27.5 crore of it, also about 46%, and only 18% of its foreign balance is hedged, against 82% at Packaging Films. The euro balance is slightly larger than the dollar balance and EUR/INR is more than twice as volatile, so euro receivables are the riskier exposure. Applying the one-day 95% worst-fall VaR from Q8 gives roughly ₹0.19 crore for the euro balance and ₹0.07 crore for the dollar balance.
