-- výzkumné otázky --

-- 1. Rostou v průběhu let mzdy ve všech odvětvích, nebo v některých klesají? --
-- Odpověď: Z dlouhodobého hlediska rostou mzdy ve všech odvětí, ale z krátkodobého hlediska v některých odvětvích v průběhu let mzdy klesají. Nejčastěji v oboru Těžba a dobývání --

SELECT payroll_industry_branch
	   ,COUNT(common_year) AS payroll_count
FROM(
	SELECT payroll_industry_branch
	   	   ,common_year
	   	   ,payroll_value_percent
	FROM t_petr_luka_project_sql_primary_final
GROUP BY payroll_industry_branch
		 ,common_year) 	   AS tab_select
WHERE payroll_value_percent < 0 
	AND payroll_industry_branch <> 'Průměrná hodnota'
GROUP BY payroll_industry_branch
ORDER BY payroll_count DESC
		 ,payroll_industry_branch ASC

-- 2. Kolik je možné si koupit litrů mléka a kilogramů chleba za první a poslední srovnatelné období v dostupných datech cen a mezd? --
-- Odpověď: viz tabulka níže, kde lze vidět, že v roce 2006 lze koupit 1 213,4 Kg Chleba nebo 1 356,7 litrů mléka za průměrnou mzdu v tomto roce. --
-- V roce 2018 lze zakoupit 1 324,1 Kg chleba nebo 1618,3 litrů mléka. --

SELECT common_year 
	   ,price_name 
	   ,ROUND((AVG(payroll_value)/price_value), 1) AS count_value
	   ,price_unit
FROM t_petr_luka_project_SQL_primary_final
WHERE price_name 
	IN ('Mléko polotučné pasterované', 'Chléb konzumní kmínový')
	AND common_year 
	IN (2006, 2018) 
	AND payroll_industry_branch = 'Průměrná hodnota'
GROUP BY common_year 
		 ,price_name
;
 
-- 3. Která kategorie potravin zdražuje nejpomaleji (je u ní nejnižší percentuální meziroční nárůst)? --
-- Odpověď: Nejpomaleji mezi rokem 2006 a 2018 zdražuje Cukr krystalový, který za tuto dobu zlevnil o 37,3 %.

WITH year_2018 					AS(
SELECT price_name 				AS name_2018
	   ,price_value 			AS price_2018
FROM t_petr_luka_project_SQL_primary_final
WHERE common_year = 2018
GROUP BY common_year
		 ,price_name
ORDER BY price_name
), year_2006 					AS (
SELECT price_name 				AS name_2006 
	   ,price_value 			AS price_2006
FROM t_petr_luka_project_SQL_primary_final
WHERE common_year = 2006
GROUP BY common_year
		 ,price_name
ORDER BY price_name
)
SELECT name_2018
	   ,ROUND((((price_2018 - price_2006) 
	   	/ price_2018) *100), 1) AS price_perc
FROM year_2018 
JOIN year_2006
	ON name_2018 = name_2006
ORDER BY price_perc
LIMIT 1
;

-- 4. Existuje rok, ve kterém byl meziroční nárůst cen potravin výrazně vyšší než růst mezd (větší než 10 %)? --
-- Odpověď: NE, nejvyšší meziroční nárust cen potravin oproti nárustu mezd byl v roce 2013 o 5,4 % --

SELECT common_year
	   ,ROUND(AVG(price_value_percent), 1) - ROUND(AVG(payroll_value_percent), 1) AS diff_value_percent
FROM t_petr_luka_project_SQL_primary_final
GROUP BY common_year
ORDER BY diff_value_percent DESC
LIMIT 1
;

-- 5. Má výška HDP vliv na změny ve mzdách a cenách potravin? Neboli, pokud HDP vzroste výrazněji v jednom roce, projeví se to na cenách potravin či mzdách ve stejném nebo násdujícím roce výraznějším růstem?--
-- Odpověď: Není tomu tak vždy. Chybí data z roku 2019 pro tabulku cen potravin. Kdybychom měli tato data a ukázalo by se, že mezi rokem 2018 - 2019 byl nárust ceny vyšší než 4 % tak dle vypočtených dat vychází:
--          Pokud HDP vzrostlo o více jak 4 %, tak nárust cen potravin i mezd narostl ve stejném a zároveň v následujícím roce o více jak 4 % přesně ve dvou ze tří případů.
--          S daty, které máme, můžeme říci, že pokud HDP vzrostlo o více jak 4 %, tak o více jak 4 % vzrostly mzdy i ceny potravin ve dvou ze tří případů. V následujícím roce mzdy ve dvou ze tří případů a ceny potravin v jednom ze tří případů.

WITH gdp_join 										 AS (
SELECT economies.`year` 
	   ,gdp
	   ,ROUND((((gdp - (LAG(gdp, 1)OVER (
			ORDER BY `year`)))/gdp)*100), 1) AS gdp_value_percent		
FROM economies
WHERE country = 'Czech Republic' 
)
,price_and_payroll 									 AS (
SELECT common_year
	   ,ROUND(AVG(payroll_value_percent), 1)         AS avg_payroll_perc
	   ,ROUND(AVG(price_value_percent), 1)           AS avg_price_perc
	   ,LEAD(ROUND(AVG(payroll_value_percent), 1)) OVER (
			ORDER BY common_year)					 AS lead_payroll
	   ,LEAD(ROUND(AVG(price_value_percent), 1)) OVER (
			ORDER BY common_year)					 AS lead_price
FROM t_petr_luka_project_SQL_primary_final
GROUP BY common_year
ORDER BY common_year
)
SELECT common_year
	   ,CASE 
		    WHEN (gdp_value_percent > 4 
		    	AND avg_payroll_perc > 4
		    	AND avg_price_perc > 4)
	   		THEN 'Payroll and Price are Higer'
	   		WHEN gdp_value_percent > 4 
	   			AND avg_payroll_perc > 4
	   		THEN 'Payroll is Higher'
	   		WHEN gdp_value_percent > 4 
	   			AND avg_price_perc > 4
	   		THEN 'Price is Higher'
	   		WHEN gdp_value_percent > 4
	   			AND (avg_price_perc
	   			OR avg_price_perc) < 4
	   		THEN 'Has NO effect'
	   		ELSE '-'
	   END                                           AS same_year_differences
	   ,CASE 
		    WHEN (gdp_value_percent > 4 
		    	AND lead_payroll > 4 
		    	AND lead_price > 4)
	   		THEN 'Payroll and Price are Higer'
	   		WHEN gdp_value_percent > 4 
	   			AND lead_payroll > 4
	   		THEN 'Payroll is Higher'
	   		WHEN gdp_value_percent > 4 
	   			AND lead_price > 4
	   		THEN 'Price is Higher'
	   		WHEN gdp_value_percent > 4
	   			AND (lead_price
	   			OR lead_payroll) < 4
	   		THEN 'Has NO effect'
	   		ELSE '-'
	   END                                           AS previous_year_differences
FROM price_and_payroll
JOIN gdp_join
	ON common_year = `year`
WHERE common_year 
	BETWEEN 2007 
		AND 2018
	AND gdp_value_percent > 4
GROUP BY common_year
ORDER BY common_year
;