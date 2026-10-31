/* =========================================================
   Step 2: Views that answer the business questions
   Run this in: ifitness_warehouse, after Step 1.
   A view is a saved query. It doesn't copy data, it just runs when you use it.
   Run each CREATE VIEW on its own (highlight it, then Run).
   ========================================================= */

-- 1. One row per month: clients, retention, money in and money out
CREATE VIEW dbo.vw_monthly_kpis AS
WITH active AS (
    -- how many clients paid each month, and how much
    SELECT
        month,
        COUNT(DISTINCT member_id)                                AS active_clients,
        SUM(pt_fee)                                              AS pt_fees,
        SUM(CASE WHEN membership_type = 'New' THEN 1 ELSE 0 END)       AS new_clients,
        SUM(CASE WHEN membership_type = 'Came back' THEN 1 ELSE 0 END) AS came_back
    FROM dbo.fact_pt_payments
    GROUP BY month
),
kept AS (
    -- clients who paid this month AND last month
    SELECT
        cur.month,
        COUNT(*) AS kept_from_last_month
    FROM dbo.fact_pt_payments AS cur
    JOIN dbo.fact_pt_payments AS prev
        ON  prev.member_id = cur.member_id
        AND prev.month     = DATEADD(month, -1, cur.month)
    GROUP BY cur.month
),
sales AS (
    SELECT month, SUM(total) AS supplement_sales
    FROM dbo.fact_sales
    GROUP BY month
)
SELECT
    c.month,
    a.active_clients,
    LAG(a.active_clients) OVER (ORDER BY c.month)          AS active_last_month,
    COALESCE(k.kept_from_last_month, 0)                     AS kept_from_last_month,
    CAST(k.kept_from_last_month AS decimal(9,4))
        / NULLIF(LAG(a.active_clients) OVER (ORDER BY c.month), 0) AS retention_pct,
    a.new_clients,
    a.came_back,
    a.pt_fees,
    COALESCE(s.supplement_sales, 0)                         AS supplement_sales,
    c.service_charge,
    c.tax,
    a.pt_fees - c.service_charge - c.tax                    AS my_earnings
FROM dbo.fact_monthly_costs AS c
LEFT JOIN active AS a ON a.month = c.month
LEFT JOIN kept   AS k ON k.month = c.month
LEFT JOIN sales  AS s ON s.month = c.month;

-- 2. One row per client: how long they stayed and what they spent
CREATE VIEW dbo.vw_client_summary AS
SELECT
    cl.member_id,
    cl.client_name,
    cl.source,
    cl.goal,
    cl.first_paid_month,
    cl.last_paid_month,
    cl.months_paid,
    cl.times_came_back,
    cl.still_active,
    cl.reason_group,
    cl.outcome,
    (SELECT SUM(p.pt_fee) FROM dbo.fact_pt_payments AS p WHERE p.member_id = cl.member_id) AS total_pt_fees,
    COALESCE((SELECT SUM(s.total) FROM dbo.fact_sales AS s WHERE s.member_id = cl.member_id), 0) AS supplement_spend
FROM dbo.dim_clients AS cl;

-- 3. Where clients came from, and how valuable each source was
CREATE VIEW dbo.vw_source_summary AS
SELECT
    source,
    COUNT(*)                                                    AS clients,
    CAST(COUNT(*) AS decimal(9,4)) / (SELECT COUNT(*) FROM dbo.dim_clients) AS share_of_clients,
    SUM(total_pt_fees)                                          AS total_pt_fees,
    AVG(CAST(months_paid AS decimal(9,2)))                      AS avg_months_stayed
FROM dbo.vw_client_summary
GROUP BY source;

-- 4. The headline numbers in one row (the KPI cards)
CREATE VIEW dbo.vw_headline_kpis AS
SELECT
    (SELECT COUNT(*) FROM dbo.dim_clients)                       AS total_clients,
    (SELECT MAX(active_clients) FROM dbo.vw_monthly_kpis)        AS peak_active_clients,
    (SELECT CAST(SUM(kept_from_last_month) AS decimal(9,4)) / SUM(active_last_month)
       FROM dbo.vw_monthly_kpis)                                 AS retention_pct,
    (SELECT AVG(CAST(months_paid AS decimal(9,2))) FROM dbo.dim_clients) AS avg_months_per_client,
    (SELECT CAST(SUM(CASE WHEN source IN ('Referral', 'Gym floor engagement') THEN 1 ELSE 0 END) AS decimal(9,4))
            / COUNT(*) FROM dbo.dim_clients)                     AS brought_in_myself_pct,
    (SELECT SUM(pt_fee) FROM dbo.fact_pt_payments)               AS total_pt_fees,
    (SELECT SUM(total) FROM dbo.fact_sales)                      AS supplement_sales,
    (SELECT SUM(service_charge) FROM dbo.fact_monthly_costs)     AS service_charge_paid,
    (SELECT -SUM(change) FROM dbo.fact_client_progress
      WHERE measure = 'Body weight' AND change < 0)              AS kg_lost_by_clients;
