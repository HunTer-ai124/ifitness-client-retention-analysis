/* =========================================================
   Step 3: Questions a gym owner would ask, answered with SQL
   Run any of these in ifitness_warehouse.
   ========================================================= */

-- Q1. What are the headline numbers?
SELECT * FROM dbo.vw_headline_kpis;

-- Q2. Did retention hold up each work year?
SELECT
    d.work_year,
    CAST(SUM(m.kept_from_last_month) AS decimal(9,4)) / SUM(m.active_last_month) AS retention_pct,
    SUM(m.pt_fees)                AS pt_fees,
    AVG(CAST(m.active_clients AS decimal(9,2))) AS avg_active_clients
FROM dbo.vw_monthly_kpis AS m
JOIN dbo.dim_date AS d ON d.date = m.month
GROUP BY d.work_year
ORDER BY d.work_year;

-- Q3. Why did clients leave?
SELECT reason_group, COUNT(*) AS clients
FROM dbo.dim_clients
WHERE still_active = 'No'
GROUP BY reason_group
ORDER BY clients DESC;

-- Q4. Which clients sent me the most referrals?
SELECT
    ref.client_name     AS referrer,
    COUNT(*)            AS people_referred
FROM dbo.dim_clients AS c
JOIN dbo.dim_clients AS ref ON ref.member_id = c.referred_by_id
WHERE c.source = 'Referral'
GROUP BY ref.client_name
ORDER BY people_referred DESC;

-- Q5. Which source brings the most valuable clients?
SELECT * FROM dbo.vw_source_summary ORDER BY total_pt_fees DESC;

-- Q6. What sells best?
SELECT category, SUM(total) AS sales, COUNT(*) AS sales_count
FROM dbo.fact_sales
GROUP BY category
ORDER BY sales DESC;
