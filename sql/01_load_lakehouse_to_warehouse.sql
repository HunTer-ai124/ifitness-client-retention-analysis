/* =========================================================
   Step 1: Copy the raw lakehouse tables into the warehouse
   Run this in: ifitness_warehouse (New SQL query)
   The lakehouse (ifitness_lakehouse) must be in the same workspace.
   CREATE TABLE ... AS SELECT copies the data and makes the table in one go.
   ========================================================= */

-- Clients: one row per client
CREATE TABLE dbo.dim_clients AS
SELECT
    member_id,
    client_name,
    CAST(date_joined AS date)      AS date_joined,
    source,                                            -- Assigned by gym, Referral, Gym floor engagement
    referred_by_code,
    referred_by_id,                                    -- member_id of the person who referred them
    goal,
    gender,
    still_active,
    CAST(date_left AS date)        AS date_left,
    reason_left,
    reason_group,
    CAST(first_paid_month AS date) AS first_paid_month,
    CAST(last_paid_month AS date)  AS last_paid_month,
    CAST(months_paid AS int)       AS months_paid,
    CAST(times_came_back AS int)   AS times_came_back,
    rate_went_up,
    challenge,
    result,
    outcome,
    started_nervous
FROM ifitness_lakehouse.dbo.clients;

-- PT payments: one row per client per month they paid
CREATE TABLE dbo.fact_pt_payments AS
SELECT
    member_id,
    CAST(month AS date)                      AS month,
    CAST(pt_fee AS decimal(12,2))            AS pt_fee,
    membership_type,                                   -- New, Renewal, Came back
    CAST(est_gym_sub_value AS decimal(12,2)) AS est_gym_sub_value
FROM ifitness_lakehouse.dbo.pt_payments;

-- Supplement and accessory sales: one row per sale
CREATE TABLE dbo.fact_sales AS
SELECT
    CAST(sale_date AS date)           AS sale_date,
    CAST(month AS date)               AS month,
    member_id,                                         -- empty for the 8 estimated months
    product,
    category,
    CAST(quantity AS int)             AS quantity,
    CAST(unit_price AS decimal(12,2)) AS unit_price,
    CAST(total AS decimal(12,2))      AS total,
    is_estimate
FROM ifitness_lakehouse.dbo.sales;

-- What I paid out each month: service charge to the gym and tax to LIRS
CREATE TABLE dbo.fact_monthly_costs AS
SELECT
    CAST(month AS date)                   AS month,
    CAST(service_charge AS decimal(12,2)) AS service_charge,
    CAST(tax AS decimal(12,2))            AS tax
FROM ifitness_lakehouse.dbo.monthly_costs;

-- Client results: weight lost, stamina and so on
CREATE TABLE dbo.fact_client_progress AS
SELECT
    member_id,
    measure,
    unit,
    CAST(start_value AS decimal(9,2))  AS start_value,
    CAST(latest_value AS decimal(9,2)) AS latest_value,
    CAST(change AS decimal(9,2))       AS change,
    result_in_words
FROM ifitness_lakehouse.dbo.client_progress;

-- Calendar: one row per day, Aug 2023 to Jun 2026
CREATE TABLE dbo.dim_date AS
SELECT
    CAST(date AS date)         AS date,
    CAST(year AS int)          AS year,
    CAST(month_of_year AS int) AS month_of_year,
    month_short,
    month_name,
    CAST(month_number AS int)  AS month_number,
    work_year
FROM ifitness_lakehouse.dbo.dim_date;
