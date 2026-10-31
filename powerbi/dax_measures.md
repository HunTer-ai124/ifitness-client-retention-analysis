# DAX used in the Power BI report

All measures sit in the model next to the Calendar table. Each one has a short note on what it does.

## Calendar table

```DAX
Calendar =
ADDCOLUMNS (
    CALENDAR ( DATE ( 2023, 8, 1 ), DATE ( 2026, 6, 30 ) ),    -- every day I worked there
    "Year", YEAR ( [Date] ),
    "Month Name", FORMAT ( [Date], "mmm yyyy" ),                -- Aug 2023
    "Month Number", YEAR ( [Date] ) * 100 + MONTH ( [Date] ),   -- 202308, for sorting
    "Work Year",                                                -- my 3 work years, Aug to Jul
        SWITCH (
            TRUE (),
            [Date] < DATE ( 2024, 8, 1 ), "Year 1",
            [Date] < DATE ( 2025, 8, 1 ), "Year 2",
            "Year 3"
        )
)
```

Extra columns for the attendance grid:

```DAX
Month Short = FORMAT ( 'Calendar'[Date], "mmm" )   -- Aug, Sep... (sorted by Month Of Year)
Month Of Year = MONTH ( 'Calendar'[Date] )
```

## Clients and retention

```DAX
Total Clients = COUNTROWS ( Clients )

Active Clients = DISTINCTCOUNT ( PT_Payments[MemberID] )          -- clients who paid in the period

Peak Active Clients =
MAXX ( VALUES ( 'Calendar'[Month Number] ), [Active Clients] )    -- busiest month

Active Last Month =
CALCULATE ( [Active Clients], DATEADD ( 'Calendar'[Date], -1, MONTH ) )

Kept From Last Month =                                            -- paid last month AND this month
VAR ThisMonth = VALUES ( PT_Payments[MemberID] )
VAR LastMonth =
    CALCULATETABLE ( VALUES ( PT_Payments[MemberID] ), DATEADD ( 'Calendar'[Date], -1, MONTH ) )
RETURN
    COUNTROWS ( INTERSECT ( ThisMonth, LastMonth ) )

Retention % =                                                     -- added up month by month
DIVIDE (
    SUMX ( VALUES ( 'Calendar'[Month Number] ), [Kept From Last Month] ),
    SUMX ( VALUES ( 'Calendar'[Month Number] ), [Active Last Month] )
)

Avg Months Per Client = AVERAGE ( Clients[MonthsPaid] )
Clients 12+ Months = CALCULATE ( [Total Clients], Clients[MonthsPaid] >= 12 )
Clients Who Came Back = CALCULATE ( [Total Clients], Clients[TimesCameBack] > 0 )
Total Comebacks = CALCULATE ( COUNTROWS ( PT_Payments ), PT_Payments[MembershipType] = "Came back" )
Stayed After Price Rise = CALCULATE ( [Total Clients], Clients[RateWentUp] = "Yes" )
Clients Left = CALCULATE ( [Total Clients], Clients[StillActive] = "No" )
```

## Growth and sales

```DAX
Total PT Fees = SUM ( PT_Payments[PTFee] )

PT Growth Y1 to Y2 =
VAR Y1 = CALCULATE ( [Total PT Fees], 'Calendar'[Work Year] = "Year 1" )
VAR Y2 = CALCULATE ( [Total PT Fees], 'Calendar'[Work Year] = "Year 2" )
RETURN
    DIVIDE ( Y2 - Y1, Y1 )

Clients Brought In % =                                            -- referrals + floor engagement
DIVIDE (
    CALCULATE ( [Total Clients], Clients[Source] IN { "Referral", "Gym floor engagement" } ),
    [Total Clients]
)

Referral Clients = CALCULATE ( [Total Clients], Clients[Source] = "Referral" )
Engagement Clients = CALCULATE ( [Total Clients], Clients[Source] = "Gym floor engagement" )
New Clients = CALCULATE ( COUNTROWS ( PT_Payments ), PT_Payments[MembershipType] = "New" )
Gym Membership Months = COUNTROWS ( PT_Payments )

Supplement Sales = SUM ( Sales[Total] )

Months With Sales =
COUNTROWS ( FILTER ( VALUES ( 'Calendar'[Month Number] ), [Supplement Sales] > 0 ) )
```

## Client results

```DAX
Weight Lost (kg) =
- CALCULATE (
    SUM ( Client_Progress[Change] ),
    Client_Progress[Measure] = "Body weight",
    Client_Progress[Change] < 0
)

Clients Who Lost Weight =
CALCULATE (
    DISTINCTCOUNT ( Client_Progress[MemberID] ),
    Client_Progress[Measure] = "Body weight",
    Client_Progress[Change] < 0
)

Goals Reached = CALCULATE ( [Total Clients], Clients[Outcome] = "Goal reached" )
Goal Reached % = DIVIDE ( [Goals Reached], [Total Clients] )
```
