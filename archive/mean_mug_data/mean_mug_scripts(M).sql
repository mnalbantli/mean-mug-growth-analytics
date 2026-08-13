## 2. Behavioral patterns: Loyal vs At Risk

## 2a. Frequency + basket size

SELECT
    c.SegmentID,
    s.SegmentName,
    COUNT(DISTINCT c.CustomerID)                         AS NumCustomers,
    COUNT(DISTINCT o.OrderID)                            AS TotalOrders,
    COUNT(DISTINCT o.OrderID) 
        / NULLIF(COUNT(DISTINCT c.CustomerID), 0)        AS AvgOrdersPerCustomer,
    AVG(o.TotalAmount)                                   AS AvgOrderValue
FROM customer c
JOIN customersegment s ON c.SegmentID = s.SegmentID
LEFT JOIN `order` o      ON c.CustomerID = o.CustomerID
WHERE c.SegmentID IN (3, 4)   -- Loyal, At Risk
GROUP BY c.SegmentID, s.SegmentName;

## 2b. Category mix by segment

SELECT
    c.SegmentID,
    s.SegmentName,
    mi.Category,
    SUM(oi.LineTotal)                                   AS CategoryRevenue,
    SUM(oi.LineTotal) 
      / NULLIF(SUM(SUM(oi.LineTotal)) OVER (PARTITION BY c.SegmentID), 0)
                                                        AS CategoryShareWithinSegment
FROM customer c
JOIN customersegment s ON c.SegmentID = s.SegmentID
JOIN `order` o         ON c.CustomerID = o.CustomerID
JOIN orderitem oi      ON o.OrderID     = oi.OrderID
JOIN menuitem mi       ON oi.MenuItemID = mi.MenuItemID
WHERE c.SegmentID IN (3, 4)
GROUP BY c.SegmentID, s.SegmentName, mi.Category
ORDER BY c.SegmentID, CategoryRevenue DESC;

## 2c. Time-of-day / weekday pattern by segment

SELECT
    c.SegmentID,
    s.SegmentName,
    DAYNAME(o.OrderDate)        AS DayOfWeek,
    HOUR(o.OrderTime)           AS HourOfDay,
    COUNT(*)                    AS OrderCount
FROM customer c
JOIN customersegment s ON c.SegmentID = s.SegmentID
JOIN `order` o         ON c.CustomerID = o.CustomerID
WHERE c.SegmentID IN (3, 4)
GROUP BY c.SegmentID, s.SegmentName, DayOfWeek, HourOfDay
ORDER BY c.SegmentID, DayOfWeek, HourOfDay;

## 3. First-order items that predict retention

WITH ordered_orders AS (
    SELECT
        o.CustomerID,
        o.OrderID,
        o.OrderDate,
        ROW_NUMBER() OVER (
            PARTITION BY o.CustomerID
            ORDER BY o.OrderDate
        ) AS rn
    FROM `order` o
),
first_order AS (
    SELECT
        CustomerID,
        OrderID AS FirstOrderID,
        OrderDate AS FirstOrderDate
    FROM ordered_orders
    WHERE rn = 1
),
future_orders AS (
    SELECT
        o.CustomerID,
        COUNT(*) AS FutureOrderCount
    FROM `order` o
    JOIN first_order f
      ON o.CustomerID = f.CustomerID
     AND o.OrderDate > f.FirstOrderDate
    GROUP BY o.CustomerID
)
SELECT
    mi.MenuItemID,
    mi.ItemName,
    mi.Category,
    COUNT(DISTINCT f.CustomerID)            AS CustomersWhoStartedWithItem,
    AVG(fo.FutureOrderCount)                AS AvgFutureOrdersAfterItem
FROM first_order f
JOIN orderitem oi  ON f.FirstOrderID = oi.OrderID
JOIN menuitem mi   ON oi.MenuItemID  = mi.MenuItemID
LEFT JOIN future_orders fo
       ON f.CustomerID = fo.CustomerID
GROUP BY mi.MenuItemID, mi.ItemName, mi.Category
HAVING COUNT(DISTINCT f.CustomerID) >= 5    -- avoid tiny groups
ORDER BY AvgFutureOrdersAfterItem DESC;

## 4.Behaviors that predict churn
WITH last_order AS (
    SELECT
        CustomerID,
        MAX(OrderDate) AS LastOrderDate,
        COUNT(*)       AS TotalOrders,
        SUM(TotalAmount) AS TotalSpend
    FROM `order`
    GROUP BY CustomerID
),
reference AS (
    SELECT MAX(OrderDate) AS MaxOrderDate FROM `order`
)
SELECT
    c.CustomerID,
    c.SegmentID,
    s.SegmentName,
    lo.TotalOrders,
    lo.TotalSpend,
    DATEDIFF(r.MaxOrderDate, lo.LastOrderDate) AS DaysSinceLastOrder
FROM customer c
JOIN last_order lo ON c.CustomerID = lo.CustomerID
CROSS JOIN reference r
JOIN customersegment s ON c.SegmentID = s.SegmentID
ORDER BY DaysSinceLastOrder DESC, lo.TotalOrders ASC;

## 5. Visit frequency in first 30 days after joining
WITH orders_with_join AS (
    SELECT
        c.CustomerID,
        c.JoinDate,
        o.OrderID,
        o.OrderDate,
        DATEDIFF(o.OrderDate, c.JoinDate) AS DaysFromJoin
    FROM customer c
    JOIN `order` o ON c.CustomerID = o.CustomerID
    WHERE o.OrderDate >= c.JoinDate
      AND DATEDIFF(o.OrderDate, c.JoinDate) <= 30
),
buckets AS (
    SELECT
        CustomerID,
        CASE 
            WHEN DaysFromJoin BETWEEN 0 AND 7  THEN '0–7 days'
            WHEN DaysFromJoin BETWEEN 8 AND 14 THEN '8–14 days'
            WHEN DaysFromJoin BETWEEN 15 AND 30 THEN '15–30 days'
        END AS Bucket,
        OrderID
    FROM orders_with_join
)
SELECT
    Bucket,
    COUNT(DISTINCT CustomerID)              AS CustomersInBucket,
    COUNT(DISTINCT OrderID)                 AS OrdersInBucket,
    COUNT(DISTINCT OrderID)
      / NULLIF(COUNT(DISTINCT CustomerID),0) AS AvgOrdersPerCustomer
FROM buckets
GROUP BY Bucket
ORDER BY 
    CASE Bucket
        WHEN '0–7 days' THEN 1
        WHEN '8–14 days' THEN 2
        WHEN '15–30 days' THEN 3
    END;
    
## ️6. Did Campaign 101 improve repeat-visit rate (Loyal only)?
WITH first_exposure AS (
    SELECT
        ea.CustomerID,
        MIN(ea.AssignedAt) AS FirstAssignedAt,
        ea.CampaignID,
        ea.Variant
    FROM experimentassignment ea
    WHERE ea.CampaignID = 101
    GROUP BY ea.CustomerID, ea.CampaignID, ea.Variant
),
orders_after AS (
    SELECT
        fe.CustomerID,
        fe.CampaignID,
        fe.Variant,
        COUNT(o.OrderID) AS OrdersAfterExposure
    FROM first_exposure fe
    JOIN `order` o
      ON o.CustomerID = fe.CustomerID
     AND o.OrderDate >= DATE(fe.FirstAssignedAt)
    GROUP BY fe.CustomerID, fe.CampaignID, fe.Variant
)
SELECT
    ea.Variant,
    COUNT(DISTINCT ea.CustomerID)                 AS LoyalCustomersInVariant,
    AVG(IFNULL(oa.OrdersAfterExposure, 0))        AS AvgOrdersAfterExposure
FROM experimentassignment ea
JOIN customer c ON ea.CustomerID = c.CustomerID
LEFT JOIN orders_after oa
       ON ea.CustomerID = oa.CustomerID
      AND ea.CampaignID = oa.CampaignID
      AND ea.Variant    = oa.Variant
WHERE ea.CampaignID = 101
  AND c.SegmentID  = 3     -- Loyal
GROUP BY ea.Variant;

## 7 Which segments respond best to new-product campaigns? (e.g., campaign linked to MenuItemID)
-- Let’s assume the “new product” campaign has CampaignID = 102 and is tied to a specific MenuItemID in offercampaign.
WITH campaign_item AS (
    SELECT CampaignID, MenuItemID
    FROM offercampaign
    WHERE CampaignID = 102
),
exposure AS (
    SELECT DISTINCT
        e.CustomerID,
        e.CampaignID
    FROM offerexposurelog e
    WHERE e.CampaignID = 102
),
trial_orders AS (
    SELECT
        o.CustomerID,
        o.OrderDate,
        ci.CampaignID
    FROM `order` o
    JOIN orderitem oi      ON o.OrderID    = oi.OrderID
    JOIN campaign_item ci  ON oi.MenuItemID = ci.MenuItemID
)
SELECT
    c.SegmentID,
    s.SegmentName,
    COUNT(DISTINCT ex.CustomerID)                                 AS ExposedCustomers,
    COUNT(DISTINCT t.CustomerID)                                  AS TrialCustomers,
    COUNT(DISTINCT t.CustomerID) / 
      NULLIF(COUNT(DISTINCT ex.CustomerID), 0)                    AS TrialRate
FROM exposure ex
JOIN customer c        ON ex.CustomerID = c.CustomerID
LEFT JOIN trial_orders t
       ON ex.CustomerID = t.CustomerID
LEFT JOIN customersegment s
       ON c.SegmentID   = s.SegmentID
GROUP BY c.SegmentID, s.SegmentName
ORDER BY TrialRate DESC;

## 8 Incremental revenue lift from exposure to Campaign 102 (!!!!!!!!!)
WITH campaign_window AS (
    SELECT
        CampaignID,
        DATE(StartDate) AS StartDate,
        DATE(EndDate)   AS EndDate
    FROM offercampaign
    WHERE CampaignID = 102
),
exposed AS (
    SELECT DISTINCT
        e.CustomerID
    FROM offerexposurelog e
    WHERE e.CampaignID = 102
),
orders_in_window AS (
    SELECT
        o.CustomerID,
        o.TotalAmount,
        o.OrderDate
    FROM `order` o
    JOIN campaign_window cw
      ON o.OrderDate BETWEEN cw.StartDate AND cw.EndDate
)
SELECT
    CASE 
        WHEN e.CustomerID IS NOT NULL THEN 'Exposed'
        ELSE 'Not Exposed'
    END AS ExposureGroup,
    COUNT(DISTINCT oi.CustomerID)     AS NumCustomers,
    SUM(oi.TotalAmount)               AS TotalRevenue,
    AVG(oi.TotalAmount)               AS AvgRevenuePerOrder
FROM orders_in_window oi
LEFT JOIN exposed e
       ON oi.CustomerID = e.CustomerID
GROUP BY ExposureGroup;

## 9 App vs Email: which channel converts better?

WITH first_exposure AS (
    SELECT
        e.CustomerID,
        e.CampaignID,
        e.Channel,
        MIN(e.ExposureAt) AS FirstExposureAt
    FROM offerexposurelog e
    GROUP BY e.CustomerID, e.CampaignID, e.Channel
),
orders_after AS (
    SELECT
        fe.CustomerID,
        fe.CampaignID,
        fe.Channel,
        COUNT(o.OrderID) AS OrdersAfterExposure,
        SUM(o.TotalAmount) AS RevenueAfterExposure
    FROM first_exposure fe
    LEFT JOIN `order` o
      ON o.CustomerID = fe.CustomerID
     AND o.OrderDate >= DATE(fe.FirstExposureAt)
    GROUP BY fe.CustomerID, fe.CampaignID, fe.Channel
)
SELECT
    Channel,
    COUNT(DISTINCT CustomerID)                      AS CustomersInChannel,
    AVG(OrdersAfterExposure)                        AS AvgOrdersAfter,
    AVG(RevenueAfterExposure)                       AS AvgRevenueAfter
FROM orders_after
GROUP BY Channel;

## 10 Menu items that increase likelihood of becoming Loyal (within 60 days)
WITH ordered_orders AS (
    SELECT
        o.CustomerID,
        o.OrderID,
        o.OrderDate,
        ROW_NUMBER() OVER (
            PARTITION BY o.CustomerID
            ORDER BY o.OrderDate
        ) AS rn
    FROM `order` o
),
first_order AS (
    SELECT
        CustomerID,
        OrderID AS FirstOrderID,
        OrderDate AS FirstOrderDate
    FROM ordered_orders
    WHERE rn = 1
),
loyal_within_60 AS (
    SELECT
        c.CustomerID
    FROM customer c
    JOIN first_order f
      ON c.CustomerID = f.CustomerID
    WHERE c.SegmentID = 3
      AND DATEDIFF(f.FirstOrderDate, c.JoinDate) <= 60
)
SELECT
    mi.MenuItemID,
    mi.ItemName,
    mi.Category,
    COUNT(DISTINCT f.CustomerID)                            AS TotalStarters,
    SUM(CASE WHEN lw.CustomerID IS NOT NULL THEN 1 ELSE 0 END)
        AS StartersWhoBecameLoyal,
    SUM(CASE WHEN lw.CustomerID IS NOT NULL THEN 1 ELSE 0 END)
        / NULLIF(COUNT(DISTINCT f.CustomerID), 0)           AS LoyalRateAmongStarters
FROM first_order f
JOIN orderitem oi     ON f.FirstOrderID = oi.OrderID
JOIN menuitem mi      ON oi.MenuItemID = mi.MenuItemID
LEFT JOIN loyal_within_60 lw
       ON f.CustomerID = lw.CustomerID
GROUP BY mi.MenuItemID, mi.ItemName, mi.Category
HAVING COUNT(DISTINCT f.CustomerID) >= 5
ORDER BY LoyalRateAmongStarters DESC;

## 11 Category → basket size & future spend (!!!!!)

WITH basket AS (
    SELECT
        o.OrderID,
        o.CustomerID,
        SUM(oi.LineTotal) AS BasketValue
    FROM `order` o
    JOIN orderitem oi ON o.OrderID = oi.OrderID
    GROUP BY o.OrderID, o.CustomerID
),
category_first AS (
    SELECT
        c.CustomerID,
        mi.Category AS DominantCategory
    FROM customer c
    JOIN `order` o      ON c.CustomerID = o.CustomerID
    JOIN orderitem oi   ON o.OrderID    = oi.OrderID
    JOIN menuitem mi    ON oi.MenuItemID = mi.MenuItemID
    WHERE o.OrderID = (
        SELECT MIN(o2.OrderID)
        FROM `order` o2
        WHERE o2.CustomerID = c.CustomerID
    )
),
future_spend AS (
    SELECT
        o.CustomerID,
        SUM(o.TotalAmount) AS TotalFutureSpend,
        COUNT(*)           AS FutureOrders
    FROM `order` o
    GROUP BY o.CustomerID
)
SELECT
    cf.DominantCategory,
    AVG(b.BasketValue)           AS AvgBasketValue,
    AVG(fs.FutureOrders)         AS AvgFutureOrders,
    AVG(fs.TotalFutureSpend)     AS AvgFutureSpend
FROM category_first cf
JOIN basket b      ON cf.CustomerID = b.CustomerID
JOIN future_spend fs ON cf.CustomerID = fs.CustomerID
GROUP BY cf.DominantCategory
ORDER BY AvgFutureSpend DESC;

## 12 Seasonal items (e.g., Gingerbread Latte) → retention
WITH seasonal_buyers AS (
    SELECT DISTINCT
        o.CustomerID
    FROM `order` o
    JOIN orderitem oi ON o.OrderID = oi.OrderID
    JOIN menuitem mi  ON oi.MenuItemID = mi.MenuItemID
    WHERE mi.Category = 'Seasonal'
    -- OR mi.ItemName IN ('Gingerbread Latte', 'Peppermint Mocha')
),
orders_per_customer AS (
    SELECT
        CustomerID,
        COUNT(*) AS TotalOrders
    FROM `order`
    GROUP BY CustomerID
)
SELECT
    CASE 
        WHEN sb.CustomerID IS NOT NULL THEN 'SeasonalBuyer'
        ELSE 'NonSeasonal'
    END AS BuyerType,
    AVG(opc.TotalOrders) AS AvgOrdersPerCustomer,
    COUNT(*)             AS NumCustomers
FROM orders_per_customer opc
LEFT JOIN seasonal_buyers sb
       ON opc.CustomerID = sb.CustomerID
GROUP BY BuyerType;

## 13 Hour-of-day → conversion into Loyal
WITH first_order AS (
    SELECT
        o.CustomerID,
        MIN(o.OrderDate) AS FirstOrderDate,
        MIN(HOUR(o.OrderTime)) AS FirstOrderHour
    FROM `order` o
    GROUP BY o.CustomerID
)
SELECT
    fo.FirstOrderHour AS HourOfDay,
    COUNT(*)          AS TotalNewCustomers,
    SUM(CASE WHEN c.SegmentID = 3 THEN 1 ELSE 0 END)
                      AS CustomersWhoAreNowLoyal,
    SUM(CASE WHEN c.SegmentID = 3 THEN 1 ELSE 0 END)
      / NULLIF(COUNT(*), 0) AS LoyalRate
FROM first_order fo
JOIN customer c ON fo.CustomerID = c.CustomerID
GROUP BY fo.FirstOrderHour
ORDER BY HourOfDay;

## 14 Do Loyal customers shift time preference with weather/events?
SELECT
    c.SegmentID,
    s.SegmentName,
    ef.Weather,
    HOUR(o.OrderTime)       AS HourOfDay,
    COUNT(*)                AS OrderCount
FROM `order` o
JOIN customer c        ON o.CustomerID = c.CustomerID
JOIN customersegment s ON c.SegmentID = s.SegmentID
JOIN externalfactor ef 
     ON ef.FactDate   = o.OrderDate
    AND ef.LocationID = o.LocationID
WHERE c.SegmentID = 3   -- Loyal
GROUP BY c.SegmentID, s.SegmentName, ef.Weather, HourOfDay
ORDER BY ef.Weather, HourOfDay;

## 15. Bad weather → hot drink share
WITH order_with_weather AS (
    SELECT
        o.OrderID,
        o.LocationID,
        o.OrderDate,
        ef.Weather
    FROM `order` o
    JOIN externalfactor ef
      ON ef.FactDate   = o.OrderDate
     AND ef.LocationID = o.LocationID
),
category_sales AS (
    SELECT
        ow.Weather,
        mi.Category,
        SUM(oi.LineTotal) AS Revenue
    FROM order_with_weather ow
    JOIN orderitem oi ON ow.OrderID = oi.OrderID
    JOIN menuitem mi  ON oi.MenuItemID = mi.MenuItemID
    GROUP BY ow.Weather, mi.Category
)
SELECT
    Weather,
    Category,
    Revenue,
    Revenue / NULLIF(SUM(Revenue) OVER (PARTITION BY Weather), 0)
        AS CategoryShareByWeather
FROM category_sales
ORDER BY Weather, CategoryShareByWeather DESC;

## 16 Basket co-occurrence by segment
WITH base AS (
    SELECT
        o.OrderID,
        c.CustomerID,
        c.SegmentID,
        oi.MenuItemID
    FROM `order` o
    JOIN customer c   ON o.CustomerID = c.CustomerID
    JOIN orderitem oi ON o.OrderID    = oi.OrderID
),
pairs AS (
    SELECT
        b1.SegmentID,
        b1.MenuItemID AS ItemA,
        b2.MenuItemID AS ItemB,
        COUNT(DISTINCT b1.OrderID) AS CooccurringOrders
    FROM base b1
    JOIN base b2
      ON b1.OrderID = b2.OrderID
     AND b1.MenuItemID < b2.MenuItemID
    GROUP BY b1.SegmentID, ItemA, ItemB
)
SELECT
    p.SegmentID,
    s.SegmentName,
    mi1.ItemName AS ItemA,
    mi2.ItemName AS ItemB,
    p.CooccurringOrders
FROM pairs p
JOIN customersegment s ON p.SegmentID = s.SegmentID
JOIN menuitem mi1 ON p.ItemA = mi1.MenuItemID
JOIN menuitem mi2 ON p.ItemB = mi2.MenuItemID
ORDER BY p.SegmentID, p.CooccurringOrders DESC;

## 17. Do discounted purchases lead to larger baskets or lower future spend?
WITH basket AS (
    SELECT
        o.OrderID,
        o.CustomerID,
        o.PromoID,
        SUM(oi.LineTotal) AS BasketValue
    FROM `order` o
    JOIN orderitem oi ON o.OrderID = oi.OrderID
    GROUP BY o.OrderID, o.CustomerID, o.PromoID
),
future_spend AS (
    SELECT
        o.CustomerID,
        SUM(o.TotalAmount) AS TotalSpend,
        COUNT(*)           AS OrderCount
    FROM `order` o
    GROUP BY o.CustomerID
)
SELECT
    CASE 
        WHEN b.PromoID IS NULL THEN 'NoPromo'
        ELSE 'Promo'
    END AS PromoGroup,
    AVG(b.BasketValue)                 AS AvgBasketValue,
    AVG(fs.TotalSpend)                 AS AvgTotalSpendPerCustomer,
    AVG(fs.OrderCount)                 AS AvgOrdersPerCustomer
FROM basket b
JOIN future_spend fs ON b.CustomerID = fs.CustomerID
GROUP BY PromoGroup;

## 18 Variant A vs B: retention after 14 days

WITH first_assignment AS (
    SELECT
        ea.CustomerID,
        ea.CampaignID,
        ea.Variant,
        MIN(ea.AssignedAt) AS FirstAssignedAt
    FROM experimentassignment ea
    GROUP BY ea.CustomerID, ea.CampaignID, ea.Variant
),
orders_after AS (
    SELECT
        fa.CustomerID,
        fa.Variant,
        COUNT(*) AS Orders14dPlus
    FROM first_assignment fa
    JOIN `order` o
      ON o.CustomerID = fa.CustomerID
     AND o.OrderDate >= DATE(fa.FirstAssignedAt) + INTERVAL 14 DAY
    GROUP BY fa.CustomerID, fa.Variant
)
SELECT
    fa.Variant,
    COUNT(DISTINCT fa.CustomerID)              AS CustomersInVariant,
    AVG(IFNULL(oa.Orders14dPlus, 0))          AS AvgOrdersAfter14d
FROM first_assignment fa
LEFT JOIN orders_after oa
       ON fa.CustomerID = oa.CustomerID
      AND fa.Variant    = oa.Variant
GROUP BY fa.Variant;

## 19 Does exposure frequency impact conversion?

WITH exposure_counts AS (
    SELECT
        CustomerID,
        CampaignID,
        COUNT(*) AS ExposureCount,
        MIN(ExposureAt) AS FirstExposureAt
    FROM offerexposurelog
    GROUP BY CustomerID, CampaignID
),
conversion AS (
    SELECT
        ec.CustomerID,
        ec.CampaignID,
        MIN(o.OrderDate) AS FirstOrderAfterExposure
    FROM exposure_counts ec
    JOIN `order` o
      ON o.CustomerID = ec.CustomerID
     AND o.OrderDate >= DATE(ec.FirstExposureAt)
    GROUP BY ec.CustomerID, ec.CampaignID
)
SELECT
    ec.ExposureCount,
    COUNT(DISTINCT ec.CustomerID)                  AS CustomersInBucket,
    COUNT(DISTINCT conv.CustomerID)                AS Converters,
    COUNT(DISTINCT conv.CustomerID) 
      / NULLIF(COUNT(DISTINCT ec.CustomerID), 0)   AS ConversionRate
FROM exposure_counts ec
LEFT JOIN conversion conv
       ON ec.CustomerID = conv.CustomerID
      AND ec.CampaignID = conv.CampaignID
GROUP BY ec.ExposureCount
ORDER BY ec.ExposureCount;


## 20 Spillover effect: non-promoted items (!!!!!)
WITH promoted AS (
    SELECT CampaignID, MenuItemID
    FROM offercampaign
    WHERE CampaignID = 102
),
exposed_customers AS (
    SELECT DISTINCT CustomerID
    FROM offerexposurelog
    WHERE CampaignID = 102
),
orders_after AS (
    SELECT
        o.OrderID,
        o.CustomerID,
        o.OrderDate
    FROM `order` o
    JOIN offerexposurelog e
      ON o.CustomerID = e.CustomerID
     AND o.OrderDate >= DATE(e.ExposureAt)
    WHERE e.CampaignID = 102
),
non_promoted_sales AS (
    SELECT
        oa.CustomerID,
        SUM(oi.LineTotal) AS NonPromotedRevenue
    FROM orders_after oa
    JOIN orderitem oi ON oa.OrderID = oi.OrderID
    LEFT JOIN promoted p
           ON oi.MenuItemID = p.MenuItemID
    WHERE p.MenuItemID IS NULL   -- exclude promoted item itself
    GROUP BY oa.CustomerID
),
baseline_sales AS (
    SELECT
        o.CustomerID,
        SUM(o.TotalAmount) AS TotalRevenue
    FROM `order` o
    GROUP BY o.CustomerID
)
SELECT
    CASE 
        WHEN ec.CustomerID IS NOT NULL THEN 'Exposed'
        ELSE 'NotExposed'
    END AS ExposureGroup,
    AVG(IFNULL(nps.NonPromotedRevenue, 0)) AS AvgNonPromotedRevenue
FROM baseline_sales bs
LEFT JOIN exposed_customers ec
       ON bs.CustomerID = ec.CustomerID
LEFT JOIN non_promoted_sales nps
       ON bs.CustomerID = nps.CustomerID
GROUP BY ExposureGroup;



