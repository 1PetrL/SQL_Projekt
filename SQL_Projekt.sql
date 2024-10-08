-- Discord: petrluka --

-- Vytvoření tabulky t_petr_luka_project_SQL_primary_final --

-- VIEW Spojení tabulek payroll

CREATE OR REPLACE VIEW joining_payroll_tables AS 
SELECT payroll_year
       ,cpc.name							  AS calculation		
       ,ROUND(AVG(value), 1)				  AS value
       ,cpu.name							  AS unit
       ,CASE 
       		WHEN cpib.name IS NULL
       		THEN 'Průměrná hodnota'
       		ELSE cpib.name
        END 								  AS industry_branch
FROM czechia_payroll cp 
JOIN czechia_payroll_unit cpu
	ON cp.unit_code = cpu.code
JOIN czechia_payroll_calculation cpc 
	ON cp.calculation_code = cpc.code 
LEFT JOIN czechia_payroll_industry_branch cpib
	ON cp.industry_branch_code = cpib.code
WHERE cpu.name = 'Kč' 
	AND cpc.name = 'přepočtený'
GROUP BY payroll_year
		 ,industry_branch
ORDER BY payroll_year
;

-- VIEW Spojení tabulek price -- 

CREATE OR REPLACE VIEW joining_price_tables AS
SELECT TO_CHAR (date_from, 'YYYY')  		AS price_year
	   ,cpc.name 							AS price_name
 	   ,ROUND(AVG(value), 1)  	    		AS price_value   
	   ,price_value 						AS price_value_unit
	   ,price_unit
FROM czechia_price cp 
JOIN czechia_price_category cpc
	ON category_code = cpc.code
WHERE region_code IS NULL
GROUP BY price_year
		 ,price_name
ORDER BY price_name
		 ,price_year
;

-- Výsledná tabulka ve spojení VIEWs: spojeni tabulek payroll a price --

CREATE OR REPLACE TABLE t_petr_luka_project_SQL_primary_final AS
WITH price_group 											  AS (
SELECT price_year
	   ,price_name
	   ,price_value
	   ,price_value_unit
	   ,price_unit
	   ,CASE 
	    	WHEN price_year = 2006 OR price_value IS NULL
	   		THEN 0
	   		ELSE (price_value)-(LAG(price_value, 1) OVER (
	   			ORDER BY price_name 
	   					 ,price_year))
	   END													 AS price_value_diff
FROM joining_price_tables
) ,payroll_group 											 AS (
SELECT payroll_year
	   ,value 			                        			 AS payroll_value
	   ,unit							        			 AS payroll_unit
	   ,industry_branch
	   ,(value - (LAG(value, 1) OVER (
			ORDER BY industry_branch
		   		  	 ,payroll_year )))						 AS payroll_value_diff
FROM joining_payroll_tables
GROUP BY industry_branch
		 ,payroll_year
)
SELECT payroll_year 					  	    			 AS common_year
	   ,industry_branch 				        			 AS payroll_industry_branch
	   ,price_name
	   ,ROUND(AVG(price_value), 1)							 AS price_value
	   ,price_value_unit
	   ,price_unit
	   ,ROUND(AVG(payroll_value), 1)						 AS payroll_value
	   ,payroll_unit
	   ,payroll_value_diff
	   ,CASE 
			WHEN payroll_value_diff <> 0
		    THEN ROUND(((payroll_value_diff / payroll_value) * 100), 1)
		    ELSE 0
		END 												 AS payroll_value_percent
	   ,price_value_diff
	   ,CASE 
		    WHEN price_unit IS NULL
		    THEN 0
		    ELSE ROUND(((price_value_diff / price_value) * 100), 1)
		END 												 AS price_value_percent
FROM payroll_group
JOIN price_group
	ON payroll_year = price_year
GROUP BY payroll_year
         ,industry_branch
         ,price_name
;

-- Vytvoření tabulky secondary_final --

CREATE OR REPLACE TABLE t_petr_luka_project_SQL_secondary_final
SELECT `year` AS e_year
	   ,e.country
	   ,e.population
	   ,GDP
	   ,gini
FROM countries c
LEFT JOIN economies e 
	ON e.country = c.country
WHERE continent = 'Europe'
	AND `year` 
		BETWEEN 2006
		AND 2018
ORDER BY e_year, country
;

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