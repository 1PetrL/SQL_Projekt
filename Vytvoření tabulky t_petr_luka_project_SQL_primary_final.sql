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