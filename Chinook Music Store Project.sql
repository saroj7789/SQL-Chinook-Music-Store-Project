/* =====================================================================
   CHINOOK MUSIC STORE — STUDENT ANSWER TEMPLATE
   ===================================================================== */

USE chinook;


/* =====================================================================
   OBJECTIVE QUESTIONS
   ===================================================================== */

-- O1
-- Does any table have missing values or duplicates? If yes how would you
-- handle it ?

-- checking for null values 
 SELECT * FROM album; -- No Null Values
 SELECT * FROM artist; -- No Null Values
 SELECT * FROM customer; -- company, state, postal_code, phone, fax columns contain null values
 SELECT * FROM employee; -- No Null Values
 SELECT * FROM genre; -- No Null Values
 SELECT * FROM invoice; -- No Null Values
 SELECT * FROM invoice_line; -- No Null Values
 SELECT * FROM media_type; -- No Null Values
 SELECT * FROM playlist; -- No Null Values
 SELECT * FROM playlist_track; -- No Null Values
 SELECT * FROM track; -- composer column contains Null values

-- Replacing null values
SET SQL_SAFE_UPDATES = 0;
UPDATE customer SET postal_code = NULL WHERE postal_code = 'None';
UPDATE customer SET company = 'Unknown' WHERE company IS NULL;
UPDATE customer SET state = 'Unknown' WHERE state IS NULL;
UPDATE customer SET postal_code = 'Unknown' WHERE postal_code IS NULL;
UPDATE customer SET phone = '+0 000 000-0000' WHERE phone IS NULL;
UPDATE customer SET fax = '+0 000 000-0000' WHERE fax IS NULL;
UPDATE customer SET company = "Unknown";
SET SQL_SAFE_UPDATES = 1;

-- O2
-- Find the top-selling tracks and top artist in the USA and identify their
-- most famous genres.

SELECT 
    t.name AS track_name, 
    ar.name AS artist_name, 
    g.name AS genre_name, 
    ROUND(SUM(il.unit_price * il.quantity), 2) AS total_revenue, 
    SUM(il.quantity) AS total_purchases 
FROM invoice i 
JOIN invoice_line il ON i.invoice_id = il.invoice_id 
JOIN track t         ON t.track_id = il.track_id 
JOIN album al        ON al.album_id = t.album_id 
JOIN artist ar       ON ar.artist_id = al.artist_id 
JOIN genre g         ON g.genre_id = t.genre_id 
WHERE i.billing_country = 'USA' 
GROUP BY t.track_id, t.name, ar.name, g.name 
ORDER BY total_purchases DESC, total_revenue DESC 
LIMIT 10;

-- O3
-- What is the customer demographic breakdown (age, gender, location) of
-- Chinook's customer base?

SELECT 
    country,
    COUNT(*) AS total_customers,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM customer), 2) AS pct_of_total
FROM customer
GROUP BY country
ORDER BY total_customers DESC, country ASC;

-- O4
-- Calculate the total revenue and number of invoices for each country, state,
-- and city:

SELECT billing_country, 
billing_state, 
billing_city, 
sum(total) AS total_revenue,
count(invoice_id) total_invoices 
FROM invoice 
GROUP BY billing_country, billing_state, billing_city
ORDER BY billing_country, billing_state, billing_city ;

-- O5
-- Find the top 5 customers by total revenue in each country

WITH customer_revenue AS (
    SELECT 
        c.country,
        c.customer_id,
        CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
        ROUND(SUM(i.total), 2) AS total_revenue,
        DENSE_RANK() OVER (
            PARTITION BY c.country 
            ORDER BY SUM(i.total) DESC
        ) AS rank_in_country
    FROM customer c
    JOIN invoice i ON c.customer_id = i.customer_id
    GROUP BY c.country, c.customer_id, c.first_name, c.last_name
)
SELECT 
    country,
    rank_in_country,
    customer_id,
    customer_name,
    total_revenue
FROM customer_revenue
WHERE rank_in_country <= 5
ORDER BY country ASC, rank_in_country ASC;

-- O6
-- Identify the top-selling track for each customer

WITH customer_tracks AS (
    SELECT 
        c.customer_id,
        CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
        t.track_id,
        t.name AS track_name,
        SUM(il.quantity) AS total_purchased,
        ROUND(SUM(il.unit_price * il.quantity), 2) AS total_spent_on_track,
        DENSE_RANK() OVER (
            PARTITION BY c.customer_id 
            ORDER BY SUM(il.quantity) DESC, SUM(il.unit_price * il.quantity) DESC
        ) AS rnk
    FROM customer c
    JOIN invoice i       ON c.customer_id = i.customer_id
    JOIN invoice_line il ON i.invoice_id = il.invoice_id
    JOIN track t         ON il.track_id = t.track_id
    GROUP BY 
        c.customer_id, 
        c.first_name, 
        c.last_name, 
        t.track_id, 
        t.name
)
SELECT 
    customer_id,
    customer_name,
    track_id,
    track_name,
    total_purchased,
    total_spent_on_track
FROM customer_tracks
WHERE rnk = 1
ORDER BY customer_id ASC;

-- O7
-- Are there any patterns or trends in customer purchasing behavior (e.g.,
-- frequency of purchases, preferred payment methods, average order value)?

SELECT 
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    c.country,
    COUNT(i.invoice_id) AS total_purchases,
    ROUND(SUM(i.total), 2) AS total_spend,
    ROUND(AVG(i.total), 2) AS average_order_value,
    MIN(DATE(i.invoice_date)) AS first_purchase_date,
    MAX(DATE(i.invoice_date)) AS last_purchase_date,
    DATEDIFF(MAX(i.invoice_date), MIN(i.invoice_date)) AS customer_active_days
FROM customer c
JOIN invoice i ON c.customer_id = i.customer_id
GROUP BY 
    c.customer_id,
    c.first_name,
    c.last_name,
    c.country
ORDER BY total_purchases DESC, total_spend DESC;

-- O8
-- What is the customer churn rate?

WITH latest_purchase AS (
    SELECT 
        c.customer_id,
        MAX(i.invoice_date) AS last_purchase_date
    FROM customer c
    LEFT JOIN invoice i ON c.customer_id = i.customer_id
    GROUP BY c.customer_id
),
customer_status AS (
    SELECT 
        lp.customer_id,
        DATEDIFF((SELECT MAX(invoice_date) FROM invoice), lp.last_purchase_date) AS days_inactive
    FROM latest_purchase lp
)
SELECT 
    COUNT(*) AS total_customers,
    SUM(CASE WHEN days_inactive > 90 OR days_inactive IS NULL THEN 1 ELSE 0 END) AS churned_customers,
    SUM(CASE WHEN days_inactive <= 90 THEN 1 ELSE 0 END) AS active_customers,
    ROUND(
        SUM(CASE WHEN days_inactive > 90 OR days_inactive IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 
        2
    ) AS churn_rate_percentage
FROM customer_status;

-- O9
-- Calculate the percentage of total sales contributed by each genre in the
-- USA and identify the best-selling genres and artists.
WITH usa_genre_sales AS (
    SELECT 
        g.genre_id,
        g.name AS genre_name,
        SUM(il.unit_price * il.quantity) AS genre_sales
    FROM invoice i
    JOIN invoice_line il ON i.invoice_id = il.invoice_id
    JOIN track t         ON il.track_id = t.track_id
    JOIN genre g         ON t.genre_id = g.genre_id
    WHERE i.billing_country = 'USA'
    GROUP BY g.genre_id, g.name
)
SELECT 
    genre_name,
    ROUND(genre_sales, 2) AS genre_sales,
    ROUND(
        (genre_sales * 100.0) / SUM(genre_sales) OVER(), 
        2
    ) AS sales_percentage
FROM usa_genre_sales
ORDER BY sales_percentage DESC;


-- O10
-- Find customers who have purchased tracks from at least 3 different genres

SELECT 
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    COUNT(DISTINCT t.genre_id) AS distinct_genres_purchased
FROM customer c
JOIN invoice i       ON c.customer_id = i.customer_id
JOIN invoice_line il ON i.invoice_id = il.invoice_id
JOIN track t         ON il.track_id = t.track_id
GROUP BY 
    c.customer_id, 
    c.first_name, 
    c.last_name
HAVING COUNT(DISTINCT t.genre_id) >= 3
ORDER BY distinct_genres_purchased DESC, customer_name ASC;

-- O11
-- Rank genres based on their sales performance in the USA

SELECT 
    DENSE_RANK() OVER (
        ORDER BY SUM(il.unit_price * il.quantity) DESC
    ) AS genre_rank,
    g.name AS genre_name,
    SUM(il.quantity) AS total_tracks_sold,
    ROUND(SUM(il.unit_price * il.quantity), 2) AS total_revenue,
    ROUND(
        SUM(il.unit_price * il.quantity) * 100.0 / SUM(SUM(il.unit_price * il.quantity)) OVER(), 
        2
    ) AS percentage_of_usa_sales
FROM invoice i
JOIN invoice_line il ON i.invoice_id = il.invoice_id
JOIN track t         ON il.track_id = t.track_id
JOIN genre g         ON t.genre_id = g.genre_id
WHERE i.billing_country = 'USA'
GROUP BY g.genre_id, g.name
ORDER BY genre_rank ASC;

-- O12
-- Identify customers who have not made a purchase in the last 3 months

WITH store_latest_date AS (
    SELECT MAX(invoice_date) AS max_date FROM invoice
),
customer_last_purchase AS (
    SELECT 
        c.customer_id,
        CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
        c.email,
        c.country,
        MAX(i.invoice_date) AS last_purchase_date
    FROM customer c
    LEFT JOIN invoice i ON c.customer_id = i.customer_id
    GROUP BY c.customer_id, c.first_name, c.last_name, c.email, c.country
)
SELECT 
    clp.customer_id,
    clp.customer_name,
    clp.email,
    clp.country,
    clp.last_purchase_date,
    DATEDIFF(sld.max_date, clp.last_purchase_date) AS days_since_last_purchase
FROM customer_last_purchase clp
CROSS JOIN store_latest_date sld
WHERE clp.last_purchase_date IS NULL 
   OR clp.last_purchase_date < DATE_SUB(sld.max_date, INTERVAL 3 MONTH)
ORDER BY days_since_last_purchase DESC;


/* =====================================================================
   SUBJECTIVE QUESTIONS
   ===================================================================== */

-- S1
-- Recommend the three albums from the new record label that should be
-- prioritised for advertising and promotion in the USA based on genre
-- sales analysis.

SELECT 
    g.name AS genre_name,
    SUM(il.quantity) AS tracks_sold,
    ROUND(SUM(il.unit_price * il.quantity), 2) AS total_sales,
    ROUND(
        SUM(il.quantity) * 100.0 / SUM(SUM(il.quantity)) OVER(), 
        2
    ) AS usa_market_share_pct
FROM invoice i
JOIN invoice_line il ON i.invoice_id = il.invoice_id
JOIN track t         ON il.track_id = t.track_id
JOIN genre g         ON t.genre_id = g.genre_id
WHERE i.billing_country = 'USA'
GROUP BY g.genre_id, g.name
ORDER BY tracks_sold DESC;

-- S2
-- Determine the top-selling genres in countries other than the USA and
-- identify any commonalities or differences.

WITH country_genre_sales AS (
    SELECT 
        i.billing_country,
        g.name AS genre_name,
        SUM(il.quantity) AS tracks_sold,
        ROUND(SUM(il.unit_price * il.quantity), 2) AS revenue,
        DENSE_RANK() OVER (
            PARTITION BY i.billing_country 
            ORDER BY SUM(il.quantity) DESC, SUM(il.unit_price * il.quantity) DESC
        ) AS genre_rank
    FROM invoice i
    JOIN invoice_line il ON i.invoice_id = il.invoice_id
    JOIN track t         ON il.track_id = t.track_id
    JOIN genre g         ON t.genre_id = g.genre_id
    WHERE i.billing_country != 'USA'
    GROUP BY i.billing_country, g.genre_id, g.name
)
SELECT 
    billing_country,
    genre_rank,
    genre_name,
    tracks_sold,
    revenue
FROM country_genre_sales
WHERE genre_rank <= 3
ORDER BY billing_country ASC, genre_rank ASC;

-- S3
-- Customer Purchasing Behavior Analysis: How do the purchasing habits
-- (frequency, basket size, spending amount) of long-term customers differ
-- from those of new customers? What insights can these patterns provide
-- about customer loyalty and retention strategies?

WITH customer_orders AS (
    SELECT 
        c.customer_id,
        MIN(i.invoice_date) AS first_order_date,
        MAX(i.invoice_date) AS last_order_date,
        COUNT(DISTINCT i.invoice_id) AS total_orders,
        SUM(il.quantity) AS total_tracks_purchased,
        ROUND(SUM(il.unit_price * il.quantity), 2) AS total_spent
    FROM customer c
    JOIN invoice i       ON c.customer_id = i.customer_id
    JOIN invoice_line il ON i.invoice_id = il.invoice_id
    GROUP BY c.customer_id
),
customer_segments AS (
    SELECT 
        co.*,
        DATEDIFF((SELECT MAX(invoice_date) FROM invoice), co.first_order_date) AS tenure_days,
        -- Segment: Long-term (acquired > 2 years ago) vs. New/Recent customers
        CASE 
            WHEN DATEDIFF((SELECT MAX(invoice_date) FROM invoice), co.first_order_date) >= 730 THEN 'Long-Term Customers'
            ELSE 'New / Recent Customers'
        END AS cohort_group
    FROM customer_orders co
)
SELECT 
    cohort_group,
    COUNT(customer_id) AS customer_count,
    ROUND(AVG(total_orders), 1) AS avg_orders_per_customer,
    ROUND(AVG(total_spent), 2) AS avg_lifetime_spend,
    ROUND(AVG(total_spent / total_orders), 2) AS avg_order_value_aov,
    ROUND(AVG(total_tracks_purchased / total_orders), 1) AS avg_basket_size_tracks
FROM customer_segments
GROUP BY cohort_group;

-- S4
-- Product Affinity Analysis: Which music genres, artists, or albums are
-- frequently purchased together by customers? How can this information
-- guide product recommendations and cross-selling initiatives?

WITH invoice_genres AS (
    -- Step 1: Get unique genres present in each invoice
    SELECT DISTINCT 
        il.invoice_id,
        g.genre_id,
        g.name AS genre_name
    FROM invoice_line il
    JOIN track t ON il.track_id = t.track_id
    JOIN genre g ON t.genre_id = g.genre_id
)
-- Step 2: Self-join on invoice_id with strict ordering on genre to prevent duplicates
SELECT 
    ig1.genre_name AS genre_1,
    ig2.genre_name AS genre_2,
    COUNT(*) AS times_purchased_together
FROM invoice_genres ig1
JOIN invoice_genres ig2 
    ON ig1.invoice_id = ig2.invoice_id
   AND ig1.genre_name < ig2.genre_name
GROUP BY 
    ig1.genre_name, 
    ig2.genre_name
ORDER BY times_purchased_together DESC;

-- S5
-- Regional Market Analysis: Do customer purchasing behaviors and churn rates
-- vary across different geographic regions or store locations? How might
-- these correlate with local demographic or economic factors?

WITH max_date AS (
    SELECT MAX(invoice_date) AS store_max_date FROM invoice
),
customer_summary AS (
    SELECT 
        c.customer_id,
        c.country,
        COUNT(i.invoice_id) AS total_orders,
        SUM(i.total) AS customer_revenue,
        AVG(i.total) AS customer_aov,
        MAX(i.invoice_date) AS last_order_date,
        CASE 
            WHEN DATEDIFF((SELECT store_max_date FROM max_date), MAX(i.invoice_date)) > 180 THEN 1 
            ELSE 0 
        END AS is_churned
    FROM customer c
    JOIN invoice i ON c.customer_id = i.customer_id
    GROUP BY c.customer_id, c.country
)
SELECT 
    country,
    COUNT(customer_id) AS total_customers,
    SUM(total_orders) AS total_orders,
    ROUND(SUM(customer_revenue), 2) AS total_revenue,
    ROUND(AVG(customer_revenue), 2) AS avg_spend_per_customer,
    ROUND(AVG(customer_aov), 2) AS avg_order_value,
    SUM(is_churned) AS churned_customers,
    ROUND(SUM(is_churned) * 100.0 / COUNT(customer_id), 1) AS churn_rate_pct
FROM customer_summary
GROUP BY country
ORDER BY total_revenue DESC;

-- S6
-- Customer Risk Profiling: Based on customer profiles (age, gender, location,
-- purchase history), which customer segments are more likely to churn or
-- pose a higher risk of reduced spending? What factors contribute to this
-- risk?

WITH store_date AS (
    SELECT MAX(invoice_date) AS max_date FROM invoice
),
cus_data AS (
    SELECT
        customer_id,
        COUNT(*) AS total_latest_orders
    FROM invoice 
    WHERE invoice_date >= (SELECT DATE_SUB(max_date, INTERVAL 1 YEAR) FROM store_date)
    GROUP BY customer_id
),
summary AS (
    SELECT
        c.customer_id,
        CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
        c.country,
        ROUND(SUM(i.total), 2) AS total_spent,
        COUNT(i.invoice_id) AS total_orders,
        ROUND(AVG(i.total), 2) AS avg_order_amount
    FROM customer c
    JOIN invoice i ON c.customer_id = i.customer_id
    GROUP BY c.customer_id, c.first_name, c.last_name, c.country
)
SELECT
    s.customer_id,
    s.customer_name,
    s.country,
    s.total_orders,
    COALESCE(c.total_latest_orders, 0) AS total_latest_orders,
    s.total_spent,
    s.avg_order_amount,
    CASE
        WHEN COALESCE(c.total_latest_orders, 0) < 2 
          OR s.total_orders < 5 
          OR s.total_spent < 20 
        THEN 'High Risk'
        ELSE 'Low Risk'
    END AS customer_status
FROM summary s
LEFT JOIN cus_data c ON s.customer_id = c.customer_id
ORDER BY customer_status DESC, s.total_spent ASC;

-- S7
-- Customer Lifetime Value Modeling: How can you leverage customer data
-- (tenure, purchase history, engagement) to predict the lifetime value of
-- different customer segments? This could inform targeted marketing and
-- loyalty program strategies. Can you observe any common characteristics
-- or purchase patterns among customers who have stopped purchasing?

WITH customer_ltv AS (
    SELECT 
        c.customer_id,
        CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
        c.country,
        c.city,
        MIN(i.invoice_date) AS first_purchase_date,
        MAX(i.invoice_date) AS last_purchase_date,
        COUNT(DISTINCT i.invoice_id) AS total_orders,
        ROUND(SUM(i.total), 2) AS total_revenue,
        ROUND(AVG(i.total), 2) AS avg_order_value,
        DATEDIFF(MAX(i.invoice_date), MIN(i.invoice_date)) AS customer_tenure_days
    FROM customer c
    JOIN invoice i ON c.customer_id = i.customer_id
    GROUP BY 
        c.customer_id,
        c.first_name,
        c.last_name,
        c.country,
        c.city
),
latest_invoice_date AS (
    SELECT MAX(invoice_date) AS latest_date FROM invoice
),
customer_segments AS (
    SELECT 
        cl.*,
        DATEDIFF(lid.latest_date, cl.last_purchase_date) AS inactive_days,
        -- Annualized Revenue Run-Rate (normalized per year)
        ROUND(
            cl.total_revenue / GREATEST(cl.customer_tenure_days / 365.0, 1.0),
            2
        ) AS annualized_value,
        CASE
            WHEN cl.total_revenue >= 40 AND cl.total_orders >= 5 THEN 'High Value'
            WHEN cl.total_revenue >= 20 THEN 'Medium Value'
            ELSE 'Low Value'
        END AS customer_segment,
        CASE
            WHEN DATEDIFF(lid.latest_date, cl.last_purchase_date) > 90 THEN 'Churned'
            ELSE 'Active'
        END AS customer_status
    FROM customer_ltv cl
    CROSS JOIN latest_invoice_date lid
)
SELECT 
    customer_segment,
    customer_status,
    COUNT(customer_id) AS total_customers,
    ROUND(AVG(total_orders), 2) AS avg_purchase_frequency,
    ROUND(AVG(avg_order_value), 2) AS avg_order_value,
    ROUND(AVG(total_revenue), 2) AS avg_total_revenue,
    ROUND(AVG(customer_tenure_days), 2) AS avg_customer_tenure_days,
    ROUND(AVG(annualized_value), 2) AS avg_annualized_run_rate,
    ROUND(AVG(inactive_days), 2) AS avg_inactive_days
FROM customer_segments
GROUP BY 
    customer_segment,
    customer_status
ORDER BY avg_total_revenue DESC;

-- S8
-- If data on promotional campaigns (discounts, events, email marketing) is
-- available, how could you measure their impact on customer acquisition,
-- retention, and overall sales?

WITH campaign_period AS (
    SELECT 
        '2024-01-01' AS campaign_start,
        '2024-03-31' AS campaign_end
),
sales_before_campaign AS (
    SELECT 
        COUNT(DISTINCT invoice_id) AS total_orders_before,
        ROUND(SUM(total), 2) AS total_sales_before,
        ROUND(AVG(total), 2) AS avg_order_value_before,
        COUNT(DISTINCT customer_id) AS customers_before
    FROM invoice i
    CROSS JOIN campaign_period cp
    WHERE i.invoice_date < cp.campaign_start
),
sales_after_campaign AS (
    SELECT 
        COUNT(DISTINCT invoice_id) AS total_orders_after,
        ROUND(SUM(total), 2) AS total_sales_after,
        ROUND(AVG(total), 2) AS avg_order_value_after,
        COUNT(DISTINCT customer_id) AS customers_after
    FROM invoice i
    CROSS JOIN campaign_period cp
    WHERE i.invoice_date BETWEEN cp.campaign_start 
                              AND cp.campaign_end
)
SELECT 
    sbc.total_orders_before,
    sac.total_orders_after,
    sbc.total_sales_before,
    sac.total_sales_after,
    sbc.avg_order_value_before,
    sac.avg_order_value_after,
    sbc.customers_before,
    sac.customers_after,
    ROUND(
        ((sac.total_sales_after - sbc.total_sales_before)
         / sbc.total_sales_before) * 100,
        2
    ) AS sales_growth_percentage
FROM sales_before_campaign sbc
CROSS JOIN sales_after_campaign sac; 

-- S9
-- How would you approach this problem, if the objective and subjective
-- questions weren't given?

Follow an Audit-to-Action framework:

Audit Data: Check schema, keys, and date ranges.

Track KPIs: Measure revenue, order volume, and AOV.

Analyze Products: Identify top genres, artists, and Pareto (80/20) sellers.

Segment Users: Use RFM, cohort retention, and churn analysis.

Decide: Localize catalogs, bundle affinities, and automate retention triggers.

-- S10
-- How can you alter the "Albums" table to add a new column named
-- "ReleaseYear" of type INTEGER to store the release year of each album?

ALTER TABLE album
ADD COLUMN release_year INT;

-- S11
-- Chinook is interested in understanding the purchasing behavior of customers
-- based on their geographical location. They want to know the average
-- total amount spent by customers from each country, along with the number
-- of customers and the average number of tracks purchased per customer.
-- Write an SQL query to provide this information.

WITH customer_spending AS (
    SELECT 
        c.customer_id,
        c.country,
        SUM(i.total) AS customer_total_spend,
        SUM(il.quantity) AS customer_total_tracks
    FROM customer c
    JOIN invoice i       ON c.customer_id = i.customer_id
    JOIN invoice_line il ON i.invoice_id = il.invoice_id
    GROUP BY c.customer_id, c.country
)
SELECT 
    country,
    COUNT(customer_id) AS total_customers,
    ROUND(AVG(customer_total_spend), 2) AS avg_total_spend_per_customer,
    ROUND(AVG(customer_total_tracks), 2) AS avg_tracks_purchased_per_customer
FROM customer_spending
GROUP BY country
ORDER BY avg_total_spend_per_customer DESC;

/* ===================================== END OF FILE ===================================== */