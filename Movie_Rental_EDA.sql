create database MovieRental;
use MovieRental;
select * from actor;
select * from address;
select * from category;
select * from city;
select * from country;
select * from customer;
select * from film;
select * from film_actor;
select * from film_category;
select * from film_text;
select * from inventory;
select * from language;
select * from payment;
select * from rental;
select * from staff;
select * from store;

-- 1. What are the purchasing patterns of new customers versus repeat customers?
SELECT cust_type, name, SUM(pay.amount) AS revenue, COUNT(*) AS rentals
FROM (
  SELECT c.customer_id,
         CASE WHEN COUNT(r.rental_id) = 1 THEN 'new' WHEN COUNT(r.rental_id)>1 THEN 'repeat' ELSE 'no_rentals' END cust_type
  FROM customer c
  LEFT JOIN rental r ON c.customer_id = r.customer_id
  GROUP BY c.customer_id
) cc
JOIN rental r ON cc.customer_id = r.customer_id
JOIN inventory i ON r.inventory_id = i.inventory_id
JOIN film_category fc ON i.film_id = fc.film_id
JOIN category cat ON fc.category_id = cat.category_id
LEFT JOIN payment pay ON r.rental_id = pay.rental_id
GROUP BY cust_type, name
ORDER BY cust_type, rentals DESC;

-- 2. Which films have the highest rental rates and are most in demand?
SELECT f.film_id, f.title,
       COUNT(r.rental_id) AS total_rentals,
       COUNT(DISTINCT i.inventory_id) AS copies,
       ROUND(COUNT(r.rental_id) / NULLIF(COUNT(DISTINCT i.inventory_id),0),2) AS rentals_per_copy,
       round(Sum(f.rental_rate),2) AS Rental_Rate
FROM film f
JOIN inventory i ON f.film_id = i.film_id
LEFT JOIN rental r ON i.inventory_id = r.inventory_id
GROUP BY f.film_id, f.title
ORDER BY rentals_per_copy DESC
LIMIT 50;

-- 3. Are there correlations between staff performance and customer satisfaction?
SELECT s.staff_id, s.first_name, s.last_name, COUNT(r.rental_id) AS rentals_handled,
       SUM(p.amount) AS total_revenue
FROM staff s
JOIN rental r ON s.staff_id = r.staff_id
JOIN payment p ON r.rental_id = p.rental_id
GROUP BY s.staff_id, s.first_name, s.last_name
ORDER BY rentals_handled DESC;

-- Customer Satisfaction
SELECT s.staff_id, s.first_name, s.last_name,
       AVG(cust_rental.total_rentals) AS avg_rentals_per_customer
FROM staff s
JOIN rental r ON s.staff_id = r.staff_id
JOIN (
    SELECT customer_id, COUNT(rental_id) AS total_rentals
    FROM rental
    GROUP BY customer_id
) cust_rental ON cust_rental.customer_id = r.customer_id
GROUP BY s.staff_id, s.first_name, s.last_name;

-- 4. Are there seasonal trends in customer behavior across different locations?
SELECT
    st.store_id,
    MONTH(r.rental_date) AS month_num,
    MONTHNAME(r.rental_date) AS month_name,
    COUNT(r.rental_id) AS rentals,
    ROUND(SUM(p.amount), 2) AS revenue
FROM rental r
JOIN inventory i ON r.inventory_id = i.inventory_id
JOIN store st ON i.store_id = st.store_id
LEFT JOIN payment p ON p.rental_id = r.rental_id
GROUP BY st.store_id, month_num, month_name
ORDER BY st.store_id, month_num;

-- 5. Are certain language films more popular among specific customer segments?
SELECT 
    lg.language_id, 
    lg.name AS film_language,
    a.city_id, 
    ci.city,
    COUNT(r.rental_id) AS rentals,
    ROUND(SUM(p.amount),2) AS revenue
FROM rental r
JOIN inventory i ON r.inventory_id = i.inventory_id
JOIN film f ON i.film_id = f.film_id
JOIN language lg ON f.language_id = lg.language_id
JOIN customer c ON r.customer_id = c.customer_id
JOIN address a ON c.address_id = a.address_id
JOIN city ci ON a.city_id = ci.city_id
LEFT JOIN payment p ON p.rental_id = r.rental_id
GROUP BY lg.language_id, lg.name, a.city_id, ci.city
ORDER BY lg.language_id, rentals DESC
limit 200;

-- 6. How does customer loyalty impact sales revenue over time?
WITH customer_loyalty AS (
  SELECT c.customer_id,
         CASE
           WHEN COUNT(r.rental_id) <= 2 THEN 'low'
           WHEN COUNT(r.rental_id) BETWEEN 3 AND 10 THEN 'medium'
           ELSE 'high'
         END AS loyalty_band
  FROM customer c
  LEFT JOIN rental r ON c.customer_id = r.customer_id
  GROUP BY c.customer_id
)
SELECT cl.loyalty_band,
       DATE_FORMAT(p.payment_date, '%Y-%m') AS yearmonth,
       COUNT(DISTINCT p.payment_id) AS payments,
       ROUND(SUM(p.amount),2) AS revenue
FROM payment p
JOIN customer_loyalty cl ON p.customer_id = cl.customer_id
GROUP BY cl.loyalty_band, yearmonth
ORDER BY cl.loyalty_band, yearmonth;

-- 7. Are certain film categories more popular in specific locations?
SELECT city, category_name, rentals FROM (
  SELECT ci.city,
         cat.name AS category_name,
         COUNT(r.rental_id) AS rentals,
         ROW_NUMBER() OVER (PARTITION BY ci.city ORDER BY COUNT(r.rental_id) DESC) rn
  FROM rental r
  JOIN inventory i ON r.inventory_id = i.inventory_id
  JOIN film_category fc ON i.film_id = fc.film_id
  JOIN category cat ON fc.category_id = cat.category_id
  JOIN customer c ON r.customer_id = c.customer_id
  JOIN address a ON c.address_id = a.address_id
  JOIN city ci ON a.city_id = ci.city_id
  GROUP BY ci.city, cat.name
) t
WHERE rn = 1;

-- 8. How does the availability and knowledge of staff affect customer ratings?
SELECT s.staff_id, s.first_name, s.last_name, COUNT(r.rental_id) AS rentals_handled,
       SUM(p.amount) AS revenue_generated
FROM staff s
JOIN rental r ON s.staff_id = r.staff_id
JOIN payment p ON r.rental_id = p.rental_id
GROUP BY s.staff_id, s.first_name, s.last_name;


-- 9. How does the proximity of stores to customers impact rental frequency?
SELECT c.customer_id, CONCAT(c.first_name,' ',c.last_name) AS customer_name,
       s.store_id, COUNT(r.rental_id) AS rentals_count
FROM customer c
JOIN rental r ON c.customer_id = r.customer_id
JOIN inventory i ON r.inventory_id = i.inventory_id
JOIN store s ON i.store_id = s.store_id
GROUP BY c.customer_id, c.first_name, c.last_name, s.store_id
ORDER BY rentals_count DESC
LIMIT 100;

-- 10. Do specific film categories attract different age groups of customers?
SELECT
   CASE 
     WHEN MOD(c.customer_id, 5) = 0 THEN 'under_18'
     WHEN MOD(c.customer_id, 5) = 1 THEN '18-25'
     WHEN MOD(c.customer_id, 5) = 2 THEN '26-40'
     WHEN MOD(c.customer_id, 5) = 3 THEN '41-60'
     ELSE '60_plus' 
   END AS age_band,
   cat.name AS category,
   COUNT(r.rental_id) AS rentals,
   ROUND(SUM(p.amount),2) AS revenue
FROM customer c
JOIN rental r ON c.customer_id = r.customer_id
JOIN inventory i ON r.inventory_id = i.inventory_id
JOIN film_category fc ON i.film_id = fc.film_id
JOIN category cat ON fc.category_id = cat.category_id
LEFT JOIN payment p ON p.rental_id = r.rental_id
GROUP BY age_band, cat.name
ORDER BY age_band, rentals DESC
LIMIT 1000;

-- 11. What are the demographics and preferences of the highest-spending customers?
-- Top spenders and their home city
WITH customer_spend AS (
   SELECT 
       c.customer_id,
       CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
       ROUND(SUM(p.amount), 2) AS total_spent
   FROM customer c
   LEFT JOIN payment p ON c.customer_id = p.customer_id
   GROUP BY c.customer_id, c.first_name, c.last_name
)
SELECT 
    cs.customer_id,
    cs.customer_name,
    cs.total_spent,
    ci.city,
    ci.city_id
FROM customer_spend cs
JOIN customer c ON cs.customer_id = c.customer_id
JOIN address a ON c.address_id = a.address_id
JOIN city ci ON a.city_id = ci.city_id
ORDER BY cs.total_spent DESC
LIMIT 50;

-- 12. How does the availability of inventory impact customer satisfaction and repeat business?
-- Average copies per film at a store + store repeat rate
WITH store_inventory AS (
  SELECT st.store_id, COUNT(i.inventory_id) AS total_copies, COUNT(DISTINCT i.film_id) AS distinct_films,
         ROUND(COUNT(i.inventory_id) / NULLIF(COUNT(DISTINCT i.film_id),0),2) AS avg_copies_per_film
  FROM inventory i
  JOIN store st ON i.store_id = st.store_id
  GROUP BY st.store_id
),
store_repeat AS (
  SELECT st.store_id,
         (SUM(CASE WHEN cr.rentals > 1 THEN 1 ELSE 0 END) / NULLIF(COUNT(DISTINCT r.customer_id),0)) AS repeat_rate
  FROM rental r
  JOIN inventory i ON r.inventory_id = i.inventory_id
  JOIN store st ON i.store_id = st.store_id
  LEFT JOIN (SELECT customer_id, COUNT(*) AS rentals FROM rental GROUP BY customer_id) cr ON cr.customer_id = r.customer_id
  GROUP BY st.store_id
)
SELECT si.store_id, si.avg_copies_per_film, sr.repeat_rate
FROM store_inventory si
JOIN store_repeat sr ON si.store_id = sr.store_id;

-- 13. What are the busiest hours or days for each store location, and how does it impact staffing requirements?
WITH store_hours AS (
  SELECT st.store_id, HOUR(r.rental_date) AS hour_of_day, COUNT(*) AS cnt
  FROM rental r
  JOIN inventory i ON r.inventory_id = i.inventory_id
  JOIN store st ON i.store_id = st.store_id
  GROUP BY st.store_id, hour_of_day
)
SELECT store_id, hour_of_day, cnt
FROM (
  SELECT store_id, hour_of_day, cnt,
         ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY cnt DESC) rn
  FROM store_hours
) t
WHERE rn <= 3
ORDER BY store_id, cnt DESC;

-- 14.What are the cultural or demographic factors that influence customer preferences in different locations? 
SELECT co.country, ci.city, cat.name AS category,
       COUNT(r.rental_id) AS rentals, ROUND(SUM(p.amount),2) AS revenue
FROM rental r
JOIN inventory i ON r.inventory_id = i.inventory_id
JOIN film_category fc ON i.film_id = fc.film_id
JOIN category cat ON fc.category_id = cat.category_id
JOIN customer c ON r.customer_id = c.customer_id
JOIN address a ON c.address_id = a.address_id
JOIN city ci ON a.city_id = ci.city_id
JOIN country co ON ci.country_id = co.country_id
LEFT JOIN payment p ON p.rental_id = r.rental_id
GROUP BY co.country, ci.city, cat.name
ORDER BY co.country, rentals DESC;

-- 15.How does the availability of films in different languages impact customer satisfaction and rental frequency?
SELECT lg.name AS language,
       COUNT(r.rental_id) AS rentals,
       ROUND(SUM(p.amount),2) AS revenue,
       ROUND(SUM(CASE WHEN cr.rentals>1 THEN 1 ELSE 0 END) / NULLIF(COUNT(DISTINCT r.customer_id),0),3) AS repeat_rate
FROM rental r
JOIN inventory i ON r.inventory_id = i.inventory_id
JOIN film f ON i.film_id = f.film_id
JOIN language lg ON f.language_id = lg.language_id
LEFT JOIN payment p ON p.rental_id = r.rental_id
LEFT JOIN (SELECT customer_id, COUNT(*) AS rentals FROM rental GROUP BY customer_id) cr ON cr.customer_id = r.customer_id
GROUP BY lg.name
ORDER BY rentals DESC;


