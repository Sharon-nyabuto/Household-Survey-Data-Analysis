create schema Household_Survey;
set search_path = Household_Survey;
-----------------------------------------------------CREATING TABLE & IMPORTING DATA ----------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------
CREATE TABLE raw_household_survey_data (
    household_id text,
    respondent_id text,
    county text,
    age text,
    gender text,
    education_level text,
    income_monthly_kes text,
    household_size text,
    water_source text,
    sanitation_type text,
    interview_date text,
    residence_type text,
    employment_status text,
    livelihood_source text,
    health_insurance text,
    mobile_money_access text,
    food_security_status  text,
    distance_to_health_facility_km  text,
    dependency_ratio_category text,
    receives_remittances text,
    dwelling_type text,
    land_ownership text
);
create table hhs_data_cleaning as select * from raw_household_survey_data rhsd;
select * from hhs_data_cleaning;


--Creating a table where i will log in all my changes
create table cleaning_log (
    log_id serial primary key,
    log_timestamp timestamp default current_timestamp,
    column_name text,
    issue_type text,
    action_taken text,
	records_affected integer,
    analyst_note text
);

-----------------------------------------------------CLEANING DATA AND LOGGING CHANGES---------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------
---1. Age 
select distinct age_cleaned from hhs_data_cleaning;
--negative ages, ages way above 100, ages considered underage legally
select respondent_id, age, 
case 
	when age::numeric < 0 then null --converting negative to null, it's impossible to have below 0 age
	when age::numeric >100 then null ----it is highly unlikely(implausible)
	when age::numeric in (16,17) then age::numeric  -----emancipated minors, retained but flagged
	when age::numeric <16 then null  -----under 16 age will not be used in this analysis
	else age::numeric
end,
age_flag =
case
	when age::numeric < 0 then 'Invalid age- Negative Value'
	when age::numeric > 100 then 'Implausible, above 100'
	when age::numeric in (16,17) then 'emancipated_minor_unconfirmed'
	when age::numeric < 16 then 'Below minimum age'
	else null          ----->in the flag column this would mean there is no issue with the entry.
end as flag_column
from hhs_data_cleaning hdc 
where age is not null and age <> '';

--Add the flag column to your cleaned table
alter table hhs_data_cleaning add column age_flag Text;
 --Adding a new age column, the original one remains untouched
alter table hhs_data_cleaning add column age_cleaned numeric; 

-- Populate both columns
--Update
update hhs_data_cleaning hdc
set age_cleaned =
case
	when age::numeric < 0 then null --converting negative to null, it's impossible to have below 0 age
	when age::numeric >100 then null ----it is highly unlikely (implausible)
	when age::numeric in (16,17) then age::numeric  -----emancipated minors, retained but flagged(In Kenyan context they could be legitimate respondents)
	when age::numeric <18 then null  -----under 18 age will not be used in this analysis
	else age::numeric
end,
age_flag =
case
	when age::numeric < 0 then 'Invalid age- Negative Value'
	when age::numeric > 100 then 'Implausible, above 100'
	when age::numeric in (16,17) then 'emancipated_minor_unconfirmed'
	when age::numeric < 18 then 'Below minimum age'
	else null ----->in the flag column this would mean there is no issue with the entry.
end
where age is not null and age <> '';

--deleting age column
alter table hhs_data_cleaning 
drop column age;

-- Age cleaning log entries
insert into cleaning_log (column_name, issue_type, action_taken, records_affected, analyst_note)
values
('age', 'Missing values', 'Converted empty to null',123,'Empty strings converted to NULL for consistency across all numeric columns (NULL represents values unknown to analyst, distinct from no income or 0 income'),
('age', 'Negative values', 'All converted to null', 12,'No valid age can be negative. Flagged as Invalid age - Negative Value in age_flag'),
('age', 'Values above 100 (124 & 150)', 'All converted to null',259, 'Highly implausible for a primary household head. Flagged as Implausible above 100 in age_flag'),
('age', 'Ages under 18(16 and 17)', 'Retained and flagged as emancipated minors',209,'Emancipated minors heading their own households are legitimate respondents in the Kenyan context. Flagged as emancipated_minor_unconfirmed in age_flag');


--2. Gender 
--select
select distinct gender from hhs_data_cleaning;

select distinct initcap(trim(gender)),
case when initcap(trim(gender)) = 'F' then 'Female'
	when  initcap(trim(gender)) = 'M' then 'Male'
	when  gender = '' then 'Unknown'
	else initcap(trim(gender)) 
	end as distinct_gender
	from hhs_data_cleaning hdc;

--update
update hhs_data_cleaning hdc
set gender = 
case when initcap(trim(gender)) = 'F' then 'Female'
	when  initcap(trim(gender)) = 'M' then 'Male'
	when  gender = '' then 'Unknown'
	else initcap(trim(gender)) 
end;
---Logging the changes
INSERT INTO cleaning_log 
    (column_name, issue_type, action_taken, records_affected, analyst_note)
VALUES ('gender', 'Inconsistent coding - 6 variants found for 2 valid categories (Male, male, M, Female, female, F)', 'Standardised all variants to Male and Female using UPPER/LOWER case; Blanks converted to Unknown', 5494, 'Unknown introduced as a category to preserve blank records - For consistency across all text columns');

--3. Education Level
select * from hhs_data_cleaning hdc;
--select
select distinct education_level from hhs_data_cleaning hdc;
select distinct case
	when initcap(trim(education_level)) = 'Primary School' then 'Primary'
	when initcap(trim(education_level)) = 'Prim' then 'Primary'
	when initcap(trim(education_level)) = 'Sec' then 'Secondary'
	when initcap(trim(education_level)) = 'Uni' then 'University'
	when initcap(trim(education_level)) = 'College' then 'College/Tvet'
	when education_level = '' then 'Unknown'
	else initcap(trim(education_level))
end as cleaned_education
from hhs_data_cleaning hdc;
select count(respondent_id)  from raw_household_survey_data rhsd where education_level in ('Primary School','primary','secondary','Prim','Sec','Uni','College', '');
--update
update hhs_data_cleaning hdc 
set education_level =
case
	when initcap(trim(education_level)) = 'Primary School' then 'Primary'
	when initcap(trim(education_level)) = 'Prim' then 'Primary'
	when initcap(trim(education_level)) = 'Sec' then 'Secondary'
	when initcap(trim(education_level)) = 'Uni' then 'University'
	when initcap(trim(education_level)) = 'College' then 'College/Tvet'
	when education_level = '' then 'Unknown'
	else initcap(trim(education_level))
end;
select distinct education_level from hhs_data_cleaning hdc;
--logging
insert into cleaning_log 
    (column_name, issue_type, action_taken, records_affected, analyst_note)
values ('education_level', 'Inconsistent coding; 7 variants found for 4 valid categories', 'Standardised all variants to Primary, Secondary, University and College/Tvet. Blanks converted to Unknown',2966, 'Blanks converted to Unknown consistent approach for categorical variables across all text columns');

---3. Income Monthly (KES) - consolidated cleaning + flag
select distinct income_monthly_kes from hhs_data_cleaning;
--income with over 5 decimal places, negative income, missing values, outliers income at 9999999

---a. create income flag column
alter table hhs_data_cleaning add column income_flag varchar(100);
---b. verify first - run select query
select income_monthly_kes,
       round(income_monthly_kes::numeric, 2) as income_cleaned,
       case
           when income_monthly_kes is null then 'Missing value'
           when income_monthly_kes::numeric < 0 then 'Invalid - Negative value'
           when income_monthly_kes::numeric = 9999999.00 then 'Implausible - Extreme outlier'
           else null
       end as income_flag
from hhs_data_cleaning hdc
where income_monthly_kes is not null;
---c. update - rounding, blanks to null, negatives to null, outliers to null + flag
update hhs_data_cleaning hdc
set income_monthly_kes =
        case
            when income_monthly_kes = '' then null-----blank to null
            when income_monthly_kes::numeric < 0 then null -----negative to null
            when income_monthly_kes::numeric = 9999999.00 then null -----extreme outlier to null
            else round(income_monthly_kes::numeric, 2)  -----round valid values
        end,
    income_flag =
        case
            when income_monthly_kes::numeric < 0  then 'Invalid - Negative value'
            when income_monthly_kes::numeric = 9999999.00 then 'Implausible - Extreme outlier'
            else null
        end
where income_monthly_kes is not null;

-- Income cleaning log entries
insert into cleaning_log (column_name, issue_type, action_taken, records_affected, analyst_note)
values
('income_monthly_kes', 'Missing values', 'Converted to NULL',1266,'NULL retained to distinguish known missing from zero income'),
('income_monthly_kes', 'Decimal precision', 'Rounded all valid values to 2 decimal places',9346, 'No substantive data change'),
('income_monthly_kes', 'Negative values(-100)', 'All converted to null',47,'Logically impossible for reported household income. Flagged as Invalid -Negative value'),
('income_monthly_kes', 'Extreme outlier(9999999)', 'All converted to null',27,'Almost certainly a system sentinel or data entry error. Flagged as Implausible - Extreme outlier in income_flag');

--4. Household size
--removing 0 and blanks
--select
select * from hhs_data_cleaning hdc;
select distinct household_size from hhs_data_cleaning hdc;
select distinct household_size, nullif(nullif(household_size, ''),'0.0')
from hhs_data_cleaning hdc 
where hdc.household_size in ('','0.0');
--update
update hhs_data_cleaning hdc 
set household_size =  nullif(nullif(household_size, ''),'0.0')
where household_size in ('','0.0');
--now making it a whole number
update hhs_data_cleaning hdc 
set household_size = round(household_size::numeric, 0);


-- household size cleaning log entries
INSERT INTO cleaning_log 
    (column_name, issue_type, action_taken, records_affected, analyst_note)
values ('household_size',  'Missing values','Converted to NULL', 833,'NULL represents unknown household size, consistent with missing values in numeric columns'),
('household_size',  'Zero values','Converted to NULL',957, 'A household of zero members is logically impossible — the respondent alone constitutes at least one member. Zero values treated as data entry errors rather than valid responses, distinct from zero income which was retained as a valid value');

--5. Water Source
select * from hhs_data_cleaning hdc;
select distinct water_source from hhs_data_cleaning hdc;
--select
select distinct 
case
	when initcap(trim(water_source)) = 'Rainwater' then 'Rain Water'
	when initcap(trim(water_source)) = 'Piped' then 'Piped Water'
	when initcap(trim(water_source)) = 'Vendor' then 'Water Vendor'
	when initcap(trim(water_source)) = 'Bore Hole' then 'Borehole'
	when initcap(trim(water_source)) = 'River Water' then 'River'
	when water_source = '' then 'Unknown'
	else initcap(trim(water_source))
 end as cleaned_watersource
 from hhs_data_cleaning hdc;
--update
update hhs_data_cleaning hdc 
set water_source =
case
	when initcap(trim(water_source)) = 'Rainwater' then 'Rain Water'
	when initcap(trim(water_source)) = 'Piped' then 'Piped Water'
	when initcap(trim(water_source)) = 'Vendor' then 'Water Vendor'
	when initcap(trim(water_source)) = 'Bore Hole' then 'Borehole'
	when initcap(trim(water_source)) = 'River Water' then 'River'
	when water_source = '' then 'Unknown'
	else initcap(trim(water_source))
end;
-- water_source cleaning log entries
insert into cleaning_log 
    (column_name, issue_type, action_taken, records_affected, analyst_note)
values ('water_source', 'Inconsistent coding; 10 variants found for 5 valid categories; Piped/piped water, River water/river, Rainwater/rain water, Borehole/bore hole, Water vendor/vendor', 'Standardised all variants to Rain Water, Borehole, Piped Water, Water Vendor and and River. Blanks converted to Unknown',5428, 'Blanks converted to Unknown consistent approach for categorical variables across all text columns');

--6. Sanitation_type
select * from hhs_data_cleaning hdc;
select distinct sanitation_type from hhs_data_cleaning hdc;
--select
select distinct case
	when initcap(trim(sanitation_type)) = 'Open' then 'Open Defecation'
	when initcap(trim(sanitation_type)) = 'Pit' then 'Pit Latrine'
	when initcap(trim(sanitation_type)) = 'Vip Latrine' then 'VIP Latrine'
	when initcap(trim(sanitation_type)) = 'Flush' then 'Flush Toilet'
	when sanitation_type = '' then 'Unknown'
	else initcap(trim(sanitation_type))
end as cleaned_sanitation
from hhs_data_cleaning hdc;
--update
update hhs_data_cleaning hdc 
set sanitation_type =
case
	when initcap(trim(sanitation_type)) = 'Open' then 'Open Defecation'
	when initcap(trim(sanitation_type)) = 'Pit' then 'Pit Latrine'
	when initcap(trim(sanitation_type)) = 'Vip Latrine' then 'VIP Latrine'
	when initcap(trim(sanitation_type)) = 'Flush' then 'Flush Toilet'
	when sanitation_type = '' then 'Unknown'
	else initcap(trim(sanitation_type))
end;
--sanitation_type cleaning log entry
insert into cleaning_log 
    (column_name, issue_type, action_taken, records_affected, analyst_note)
values('sanitation_type','Inconsistent coding; 8 variants for 4 categories','Standardized all variants to ;Open Defecation,Pit Latrine,VIP Latrine,Flush Toilet. Blanks converted to Unknown ',4047, 'Blanks converted to Unknown consistent approach for categorical variables across all text columns');

--7. Interview Date
select * from hhs_data_cleaning hdc;

select interview_date, count(*)  ----> This query helps us see the date variants that exist, and which are the most common enabling you to know where to start
from hhs_data_cleaning hdc
group by interview_date 
order by count(*) desc;
--select
select
    interview_date,
    case
        --when interview_date ~ '^\d{4}-\d{2}-\d{2}$' then interview_date::date -- If date already in ISO format,i.e. yyyy-mm-dd just cast it to date 
					/* ^\d{4} → starts with 4 digits (year)
					-\d{2} → dash + 2-digit month
					-\d{2}$ → dash + 2-digit day at end*/
       -- slash format mm/dd/yyyy or dd/mm/yyyy (assuming mm/dd/yyyy)
         when interview_date ~ '^\d{2}/\d{2}/\d{4}$' then  ---> \d means digits; $ means ends with, so in completion, this means if the date starts with 2 digits, then followed by 2digits then ends with 4 digits
         case when cast(split_part(interview_date, '/', 1) as int) > 12 then to_date(interview_date, 'dd/mm/yyyy') else to_date(interview_date, 'mm/dd/yyyy') end --“If I’m not sure whether it's day/month or month/day, I use logic: if the first number is too big to be a month, it must be the day.”
        -- dash numeric format mm-dd-yyyy
        when interview_date ~ '^\d{2}-\d{2}-\d{4}$' then to_date(interview_date, 'mm-dd-yyyy')
        -- full month name format
       -- when interview_date ~ '^[a-za-z]+ \d{1,2} \d{4}$' then to_date(trim(interview_date), 'fmmonth dd yyyy')  ----->When the date stars with letters, followed by 1 or 2 characters in the day and 4 characters fir the year, then conversion using month-name format. the trim removes any leading spaces and fm ignores spacing inconsistencies   
 		when interview_date ~ '^[A-Za-z]+ [0-9]{1,2} [0-9]{4}$' then to_date(interview_date, 'FMMonth DD YYYY')        
        else interview_date::date --else convert whatever else is left to a date
    end as clean_date
from hhs_data_cleaning;

--update
update hhs_data_cleaning hdc 
set interview_date =
case
	when interview_date ~ '^\d{4}-\d{2}-\d{2}$' then interview_date::date
	when interview_date ~ '^\d{2}/\d{2}/\d{4}$' then case when cast(split_part(interview_date, '/', 1) as int) > 12 
	then to_date(interview_date, 'dd/mm/yyyy') else to_date(interview_date, 'mm/dd/yyyy') end 
	when interview_date ~ '^\d{2}-\d{2}-\d{4}$' then case when cast(split_part(interview_date, '-', 1) as int) > 12 
	then to_date(interview_date, 'dd-mm-yyyy') else to_date(interview_date, 'mm-dd-yyyy') end
	when interview_date ~ '^\d{2}-\d{2}-\d{4}$' then to_date(interview_date, 'mm-dd-yyyy')
	when interview_date ~ '^[a-za-z]+ [0-9]{1,2} [0-9]{4}$' then to_date(interview_date, 'FMMonth DD YYYY')   
	else interview_date::date 
end;
--date cleaning log entry
insert into cleaning_log 
    (column_name, issue_type, action_taken, records_affected, analyst_note)
values ('interview_date', 'Inconsistent date formats; 4 distinct formats found: ISO (YYYY-MM-DD), Day-first (DD-MM-YYYY), Month/Day/Year numeric (MM/DD/YYYY), Month/Day/Year text (Month DD YYYY)','Normalised all dates to ISO 8601 standard (YYYY-MM-DD) using CASE-WHEN with regex pattern matching for each format variant',7087,'Ambiguous numeric dates interpreted as DD/MM/YYYY based on Kenyan date conventions and dataset origin.');

--8. Residence type
select distinct residence_type from hhs_data_cleaning hdc;
--select
select distinct initcap(trim(residence_type)), 
case
	when initcap(trim(residence_type)) = 'Peri Urban' then 'Peri-Urban'
	when residence_type = '' then 'Unknown'
	else initcap(trim(residence_type))
end as cleaned_residence
from hhs_data_cleaning;

--update
update hhs_data_cleaning hdc 
set residence_type =
case
	when initcap(trim(residence_type)) = 'Peri Urban' then 'Peri-Urban'
	when residence_type = '' then 'Unknown'
	else initcap(trim(residence_type))
end;
--residence_type cleaning log entry
insert into cleaning_log 
    (column_name, issue_type, action_taken, records_affected, analyst_note)
values('residence_type','Inconsistent coding; 8 variants for 3 categories;rural/Rural/RURAL, Peri-urban/peri urban, URBAN/Urban/urban','Standardized all variants to; Urban,Rural and Peri-Urban. Blanks converted to Unknown ',2116, 'Blanks converted to Unknown consistent approach for categorical variables across all text columns');
--9. Employment Status
select distinct employment_status from hhs_data_cleaning hdc;
--select
select distinct employment_status, 
case
	when initcap(trim(employment_status)) = 'Casual' then 'Casual Labour'
	when initcap(trim(employment_status)) in ('Not Working','Subsistence Farmer','Smallholder Farmer','Pastoralist','Student') then 'Unemployed'
	when initcap(trim(employment_status)) = 'Self-Employed' then 'Self Employed'
	when initcap(trim(employment_status)) in ('Employed (Formal)','Employed (Informal)') then 'Employed'
	when initcap(trim(employment_status)) = '' then 'Unknown'
	else initcap(trim(employment_status))
end as employment_cleaned 
from hhs_data_cleaning;
--update
update hhs_data_cleaning hdc 
	when initcap(trim(employment_status)) = 'Casual' then 'Casual Labour'
	when initcap(trim(employment_status)) in ('Not Working','Subsistence Farmer','Smallholder Farmer','Pastoralist','Student') then 'Unemployed'
	when initcap(trim(employment_status)) = 'Self-Employed' then 'Self Employed'
	when initcap(trim(employment_status)) in ('Employed (Formal)','Employed (Informal)') then 'Employed'
	when initcap(trim(employment_status)) = '' then 'Unknown'
	else initcap(trim(employment_status))
end;
--employment_status cleaning log entry
INSERT INTO cleaning_log 
    (column_name, issue_type, action_taken, records_affected, analyst_note)
values('employment_status', 'Inconsistent coding — 16 variants found for 4 valid categories. Variants included case differences (EMPLOYED, Employed, employed), descriptive entries (Formally employed, Employed (Formal), Employed (Informal)), and agriculture-specific entries (Farmer, Smallholder Farmer, Subsistence Farmer, Pastoralist)', 'Standardised all variants to 4 categories: Employed, Unemployed, Self Employed, Casual Labour. Blanks converted to Unknown',8766,'Agriculture-related entries (Farmer, Smallholder Farmer, Subsistence Farmer, Pastoralist) mapped to Unemployed - subsistence farming and pastoralism represent livelihood activities rather than formal or informal employment in the Kenyan context. GranularDetails of these activities are preserved in the livelihood_source column. Student and Not Working also mapped to Unemployed as neither represents active employment');

--10. Livelihood Source
select distinct livelihood_source from raw_household_survey_data rhsd;

case 
	when initcap(trim(livelihood_source)) in ('Petty Trade','Hawking','Business','Charcoal/Firewood') then 'Business/Trade'
	when initcap(trim(livelihood_source)) in ('Formal Wage','Salaries') then 'Employment'
	when initcap(trim(livelihood_source)) in ('Crop Farming','Tea Farming','Maize Farming') then 'Farming'
	when initcap(trim(livelihood_source)) = 'Bodaboda' then 'Transport Services'
	when initcap(trim(livelihood_source)) = '' then 'Unknown'
	else initcap(trim(livelihood_source)) 
end as livelihood
from hhs_data_cleaning hdc;
--update 
update hhs_data_cleaning hdc 
set livelihood_source =
case 
	when initcap(trim(livelihood_source)) in ('Petty Trade','Hawking','Business','Charcoal/Firewood') then 'Business/Trade'
	when initcap(trim(livelihood_source)) in ('Formal Wage','Salaries') then 'Employment'
	when initcap(trim(livelihood_source)) in ('Crop Farming','Tea Farming','Maize Farming') then 'Farming'
	when initcap(trim(livelihood_source)) = 'Bodaboda' then 'Transport Services'
	when initcap(trim(livelihood_source)) = '' then 'Unknown'
	else initcap(trim(livelihood_source)) 
end;
select * from cleaning_log; 
--livelihood_source cleaning log entry
insert into cleaning_log 
    (column_name, issue_type, action_taken, records_affected, analyst_note)
values('livelihood_source', 'Inconsistent coding; 24 variants found across case differences, descriptive entries and overlapping categories. Variants included case differences (FARMING, Farming, farming), crop-specific entries (Crop farming, Maize farming, Tea farming), and business-related entries (Petty trade, Hawking, Business, Charcoal/firewood)', 'Standardised all variants. Consolidated into canonical categories: Business/Trade, Employment, Farming, Transport Services. Blanks converted to Unknown', 5438, 'Consolidation decisions made: 
(1) Petty Trade, Hawking, Business and Charcoal/Firewood grouped into Business/Trade (They represent informal or semi-formal trade activities). 
(2) Formal Wage and Salaries grouped into Employment (Both represent formal employment arrangement. 
(3) Crop Farming, Maize Farming and Tea Farming grouped into Farming (Crop-specific entries retained as farming to avoid fragmentation 
(4) Bodaboda mapped to Transport Services(It is a distinct and common livelihood in Kenya warranting its own category). 
Remaining entries (Fishing, Remittances, Mixed Farming, Livestock, Agri-business, Domestic Work, Rental Income, Casual Farm Work, Multiple Sources) retained as-is as they represent sufficiently distinct livelihood categories');

--11. Health insurance
select distinct health_insurance from hhs_data_cleaning hdc;
--select
select distinct health_insurance, 
case
	when trim(health_insurance) in ('no','none','No insurance') then 'None'
	when trim(health_insurance) in ('nhif - inactive','NHIF (lapsed)') then 'NHIF - Inactive'
	when trim(health_insurance) = 'nhif' then 'NHIF'
	when health_insurance = '' then 'Unknown'
	else trim(health_insurance)
end as insurance
from hhs_data_cleaning hdc;
--update
update hhs_data_cleaning hdc 
set health_insurance =
case
	when trim(health_insurance) in ('no','none','No insurance') then 'None'
	when trim(health_insurance) in ('nhif - inactive','NHIF (lapsed)') then 'NHIF - Inactive'
	when trim(health_insurance) = 'nhif' then 'NHIF'
	when health_insurance = '' then 'Unknown'
	else trim(health_insurance)
end;
--health_insurance cleaning log entry
insert into cleaning_log 
    (column_name, issue_type, action_taken, records_affected, analyst_note)
values('health_insurance', 'Inconsistent coding; 12 variants for 8 categories. Variants included case differences, (NHIF, nhif, NHIF lapsed, NHIF inactive, nhif-inactive, NHIF (lapsed)) and uninsured entries (No insurance, no, none)', 'Standardised to 8 categories: NHIF, NHIF - Inactive, SHA, Linda Mama, Employer-provided, Private insurance, Community-based, None. Blanks converted to Unknown', 4079, 'NHIF retained as a distinct category - data collection spanned the NHIF to SHA transition; converting NHIF records to SHA cannot be done with certainty for all respondents.
NHIF lapsed, NHIF inactive and all related variants consolidated into NHIF - Inactive, indicating households that did have insurance, but couldnt use it due to delayed payments, analytically distinct from None which represents households that have never been insured. No, none and No insurance all mapped to None');

--12. Mobile money Access
select distinct mobile_money_access from hhs_data_cleaning hdc;
--select
select distinct mobile_money_access,
case
	when initcap(trim(mobile_money_access)) in ('None','No Phone') then 'No'
	when initcap(trim(mobile_money_access)) = ('M-Pesa & Airtel') then 'M-Pesa & Airtel Money'
	when initcap(trim(mobile_money_access)) in 'Mpesa','M-Pesa (Shared)' then 'M-Pesa'
	when trim(mobile_money_access) = '' then 'Unknown'
	else initcap(trim(mobile_money_access))
end as mobile_money
from hhs_data_cleaning hdc;
--update
update hhs_data_cleaning hdc 
set mobile_money_access =
case
	when initcap(trim(mobile_money_access)) in ('None','No Phone') then 'No'
	when initcap(trim(mobile_money_access)) = ('M-Pesa & Airtel') then 'M-Pesa & Airtel Money'
	when initcap(trim(mobile_money_access)) in ('Mpesa','Mpesa (Shared)') then 'M-Pesa'
	when trim(mobile_money_access) = '' then 'Unknown'
	else initcap(trim(mobile_money_access))
end;
--mobile money access cleaning log entry
insert into cleaning_log
(column_name, issue_type, action_taken, records_affected, analyst_note)
values('mobile_money_access','Inconsistent coding; 11 variants for 5 categories. Variants included case differences (M-Pesa, Mpesa, MPESA, M-PESA) and platform name inconsistencies (AIRTEL, Airtel Money)','Standardised to 5 categories: M-Pesa, Airtel Money, T-Kash, M-Pesa & Airtel Money, No. Blanks converted to Unknown',7427, 'Platform names standardised to official branding. No represents households with no mobile money access');

--13. Food Security Status
select distinct food_security_status from hhs_data_cleaning hdc;
select distinct food_security_status,
case 
	when initcap(trim(food_security_status)) = 'Moderately Insecure' then 'Moderately Food Insecure'
	when initcap(trim(food_security_status)) = 'Severely Insecure' then 'Severely Food Insecure'
	when initcap(trim(food_security_status)) = 'Mildly Insecure' then 'Mildly Food Insecure'
	when initcap(trim(food_security_status)) = 'Secure' then 'Food Secure'
	when food_security_status = '' then 'Unknown'
	else initcap(trim(food_security_status)) 
end
from hhs_data_cleaning hdc;
--update
update hhs_data_cleaning hdc 
set food_security_status =
case 
	when initcap(trim(food_security_status)) = 'Moderately Food Insecure' then 'Moderately Insecure'
	when initcap(trim(food_security_status)) = 'Severely Food Insecure' then 'Severely Insecure'
	when initcap(trim(food_security_status)) = 'Mildly Food Insecure' then 'Mildly Insecure'
	when initcap(trim(food_security_status)) = 'Chronically Food Insecure' then 'Chronically Insecure'
	else initcap(trim(food_security_status)) 
end;
--food security status cleaning log entry
insert into cleaning_log 
    (column_name, issue_type, action_taken, records_affected, analyst_note)
values('food_security_status','Inconsistent coding; 12 variants for 6 categories. Variants included case differences (FOOD SECURE, Food Secure, secure) and descriptive inconsistencies (Moderately Food Insecure, moderately insecure, Severely Food Insecure, chronically food insecure)','Standardised to 6 categories: Food Secure, Mildly Insecure, Moderately Insecure, Severely Insecure, Chronically Insecure, Food Insecure. Blanks converted to Unknown', 8550,'Chronically food insecure retained as distinct from Severely Insecure (chronic insecurity implies persistent/ongoing food deprivation)');

--14. distance_to_health_facility_km
--select
select distinct distance_to_health_facility_km, nullif(distance_to_health_facility_km, '')
from hhs_data_cleaning hdc where distance_to_health_facility_km ~ '[^0-9.]'  
or hdc.distance_to_health_facility_km = ''; --if your numbers have decimals, the regex match will need to have a . at the end, to include the numbers with decimals. So instead of [^0-9] you write [^0-9.] 
--checking if we have outliers
select max(distance_to_health_facility_km::numeric) from hhs_data_cleaning hdc where hdc.distance_to_health_facility_km ~ '[0-9.]';
select min(distance_to_health_facility_km::numeric) from hhs_data_cleaning hdc where hdc.distance_to_health_facility_km ~ '[0-9.]';
--update
update hhs_data_cleaning hdc
set distance_to_health_facility_km = null
where hdc.distance_to_health_facility_km = '' or hdc.distance_to_health_facility_km ~ '[^0-9.]';
select distance_to_health_facility_km from hhs_data_cleaning;

--distance_to_health_facility_km cleaning log entry
insert into cleaning_log 
    (column_name, issue_type, action_taken, records_affected, analyst_note)
values('distance_to_health_facility_km', 'Mixed data types; text entries of Don''t Know and blank entries in a numeric column', 'Don''t Know entries and blanks replaced with NULL', 599, 'Don''t Know represents a genuine non-response and cannot be inferred or estimated. Blanks treated as missing for the same reason, explaining why they are all nulled');

--15. Dependency Ratio Category
select * from hhs_data_cleaning hdc;
select distinct hdc.dependency_ratio_category from hhs_data_cleaning hdc;
--select
select distinct dependency_ratio_category,
case
	when initcap(trim(dependency_ratio_category)) = 'Medium (0.5-1.0)' then 'Medium'
	when initcap(trim(dependency_ratio_category)) = 'High (>1.0)' then 'High'
	when initcap(trim(dependency_ratio_category)) = 'Low (0-0.5)' then 'Low'
	when dependency_ratio_category = '' then 'Unknown'
	else initcap(trim(dependency_ratio_category))
end as dependency_category from hhs_data_cleaning hdc;

update hhs_data_cleaning hdc 
set dependency_ratio_category =
case
	when initcap(trim(dependency_ratio_category)) = 'Medium (0.5-1.0)' then 'Medium'
	when initcap(trim(dependency_ratio_category)) = 'High (>1.0)' then 'High'
	when initcap(trim(dependency_ratio_category)) = 'Low (0-0.5)' then 'Low'
	when dependency_ratio_category = '' then 'Unknown'
	else initcap(trim(dependency_ratio_category))
end;
--adding deependency ratio coulumn
alter table hhs_data_cleaning 
add column dependency_ratio TEXT;

update hhs_data_cleaning 
set dependency_ratio =
case
	when dependency_ratio_category = 'Low' then '0-0.5'
	when dependency_ratio_category = 'Medium' then '0.5-1'
	when dependency_ratio_category = 'High' then '>1'
	else dependency_ratio_category
end;

---renaming category column
alter table hhs_data_cleaning 
rename column dependency_ratio_category to dependency_category;

-- Dependency Ratio Category log entry
insert into cleaning_log 
    (column_name, issue_type, action_taken, records_affected, analyst_note)
values('dependency_ratio_category','6 variants for 3 categories; mixed category and dependency ratio range','Standardized and retained 3 main categories(low, medium,high); Separated range and category; Blank entries converted to unknown. ',7057,'Ratio ranges extracted into a separate column named dependency ratio, to preserve the numeric detail without corrupting the categorical field. Column renamed to dependency category to reflect content');

--16. Receives remittances
select distinct receives_remittances from hhs_data_cleaning hdc;
--select
select distinct receives_remittances, initcap(trim(receives_remittances))as case_standardized ,nullif(receives_remittances,'')as no_blanks from hhs_data_cleaning hdc;
select distinct receives_remittances, nullif(initcap(trim(receives_remittances)),'') from hhs_data_cleaning hdc;
--update
update hhs_data_cleaning hdc 
set receives_remittances = nullif(initcap(trim(receives_remittances)),'');

--receives remittances log entry
insert into cleaning_log 
    (column_name, issue_type, action_taken, records_affected, analyst_note)
values('receives_remittances', 'Inconsistent coding; 8 variants for 3 categories. Variants were purely case differences (Yes/yes/YES, No/no/NO, Occasionally/occasionally)', 'Standardised to 3 categories: Yes, No, Occasionally. Blanks converted to Unknown', 7795,'Occasionally retained as a distinct category as it indicates partial  remittance receipt');

--17. Dwelling Type
select * from hhs_data_cleaning hdc;
--select
select distinct dwelling_type from hhs_data_cleaning hdc;
select distinct dwelling_type,
case
	when initcap(trim(dwelling_type)) in ('Single Room', 'Bedsitter', 'Rental Apartment') then 'Apartment/Rental Housing'
	when initcap(trim(dwelling_type)) in ('Mud House', 'Traditional Hut', 'Mud/Wattle') then 'Traditional House'
	when initcap(trim(dwelling_type)) = 'Mabati House' then 'Semi-Permanent'
	when dwelling_type = '' then 'Unknown'
	else initcap(trim(dwelling_type))
	end as classification from hhs_data_cleaning hdc;
--update
update hhs_data_cleaning hdc 
set dwelling_type =
case
	when initcap(trim(dwelling_type)) in ('Single Room', 'Bedsitter', 'Rental Apartment') then 'Apartment/Rental Housing'
	when initcap(trim(dwelling_type)) in ('Mud House', 'Traditional Hut', 'Mud/Wattle') then 'Traditional House'
	when initcap(trim(dwelling_type)) = 'Mabati House' then 'Semi-Permanent'
	when dwelling_type = '' then 'Unknown'
	else initcap(trim(dwelling_type))
	end;
--dwelling type log entry
insert into cleaning_log 
    (column_name, issue_type, action_taken, records_affected, analyst_note)
values('dwelling_type','Responses contained 12 variations in terminology, capitalization, and housing descriptions','Standardized into four categories: Permanent House, Apartment/Rental, Semi-permanent House, and Traditional House.',9500,'Similar housing types were grouped into standard categories. Mabati houses were classified as Semi-permanent due to regional construction norms; single rooms and bedsitters were considered rentals due to limited structural information in the data');

--18. Land Ownership
select distinct land_ownership from hhs_data_cleaning hdc;
select distinct land_ownership, nullif(initcap(trim(land_ownership)),'') from hhs_data_cleaning hdc;
--update
update hhs_data_cleaning hdc 
set land_ownership = nullif(initcap(trim(land_ownership)),'');

select * from cleaning_log;

--land ownership log entry
insert into cleaning_log 
    (column_name, issue_type, action_taken, records_affected, analyst_note)
values('land_ownership','11 variants for 5 categories','Consolidated to canonocal values, to have 5 distinct categories',9500,'Borrowed/caretaker retained as a category to capture informal arrangements such as caretaker or borrowed land access,and does not represent formal ownership or rental agreements');
select* from hhs_data_cleaning hdc;

--19. Duplicates in household ID + Respondent id pairs
--identifying what the duplicates are(Using matching household id and respondent id)
select household_id, respondent_id, count(*) 
from hhs_data_cleaning hdc 
group by household_id, respondent_id
having count(*) > 1; ---> For any match that appears more than once
---> Confirming the duplicates are throughout the dataset, using a subquery
select * from hhs_data_cleaning hdc 
where (hdc.household_id, respondent_id) 
in (select household_id, respondent_id
from hhs_data_cleaning hdc 
group by household_id, respondent_id
having count(*) > 1)
order by household_id, respondent_id;
--checking what duplicate pairs will be removed
select * from
(select *, row_number() over (partition by household_id, respondent_id order by interview_date desc)rownumber --order by date ensures the latest entry gets the first number
 from hhs_data_cleaning hdc) categrized
 where rownumber >1;
--deleting the duplicate pairs
delete from hhs_data_cleaning
where ctid in (
    select ctid
    from (select ctid,  row_number() over (partition by household_id, respondent_id order by interview_date desc)rownumber from hhs_data_cleaning hdc) t
    where rownumber > 1);
select * from hhs_data_cleaning hdc;

--deduplication in household_id + Respondent_id pairs
insert into cleaning_log 
    (column_name, issue_type, action_taken, records_affected, analyst_note)
values('household_id','Duplicate entries','Used row_number() partitioning by household_id and respondent_id pairs to retain unique entries per pair',50,'Duplicate records were identified based on repeated combinations of household_id and Respondent_id');

--20. Duplicates in Respondent_id
--checking for duplicates
select respondent_id, count(*) from hhs_data_cleaning hdc
group by hdc.respondent_id 
having count(*)>1;
--confirming duplicates across all columns
select * from hhs_data_cleaning where respondent_id in(
select (respondent_id) 
from hhs_data_cleaning hdc
group by hdc.respondent_id 
having count(*)>1) 
order by respondent_id;
--removing the duplicates
delete from hhs_data_cleaning
where ctid in (
    select ctid
    from (select ctid,  row_number() over (partition by respondent_id order by interview_date desc)rownumber from hhs_data_cleaning hdc)
    where rownumber > 1);
select * from hhs_data_cleaning hdc;
INSERT INTO cleaning_log 
    (column_name, issue_type, action_taken, records_affected, analyst_note)
VALUES('respondent_id','Duplicate respondent_ids associated with different household ids, but identical records across al other columns','Removed duplicate & retained single entry per record, after confirming all other fields matched',10,'Records were determined to be duplicate entries rather than distinct observations due to identical respondent information and interview dates'); 

select count (*) from hhs_data_cleaning hdc;
--22. Duplicates in household id
--identifying the duplicate
select household_id, count(*) from hhs_data_cleaning hdc
group by hdc.household_id 
having count(*) > 1;
---checking if it is across all columns
select * from hhs_data_cleaning where household_id in(
select (household_id) 
from hhs_data_cleaning hdc
group by hdc.household_id 
having count(*)>1) 
order by household_id;
--removing the duplicates
delete from hhs_data_cleaning
where ctid in (
    select ctid
    from (select ctid,  row_number() over (partition by household_id order by interview_date desc)rownumber from hhs_data_cleaning hdc)
    where rownumber > 1);
select * from hhs_data_cleaning hdc
where hdc.household_id = 'HH112539';
INSERT INTO cleaning_log 
    (column_name, issue_type, action_taken, records_affected, analyst_note)
VALUES('Household_id','Duplicate Household ids with identical records across all columns','Removed duplicate records and retained one observation per duplicated Household ID',20,'Upon inspection of other variables, records were determined to be duplicates, and were deleted to retain unique entries, maintaining household level uniqueness');

----------------------------------------------------STANDARDIZING DATA TYPES------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------
alter table hhs_data_cleaning 
add primary key (household_id),
alter column respondent_id type varchar(10),
alter column county type varchar(20),
alter column age_cleaned type int using age_cleaned::int,
alter column gender type varchar (20),
alter column education_level type varchar(100),
alter column income_monthly_kes type numeric using income_monthly_kes::numeric,
alter column household_size type int using household_size::int,
alter column water_source type varchar(100),
alter column sanitation_type type varchar(100),
alter column interview_date type date using interview_date::date,
alter column residence_type type varchar(100),
alter column employment_status type varchar(100),
alter column livelihood_source type varchar(100),
alter column health_insurance type varchar(100),
alter column mobile_money_access type varchar(100),
alter column food_security_status  type varchar(100),
alter column distance_to_health_facility_km  type numeric using distance_to_health_facility_km::numeric,
alter column dependency_category type varchar(100),
alter column receives_remittances type varchar(50),
alter column dwelling_type type varchar(100),
alter column land_ownership type varchar(100),
alter column dependency_ratio type varchar(100);

alter table hhs_data_cleaning 
add constraint respondent_id_unique unique (respondent_id),
alter column age_flag type varchar(100);

INSERT INTO cleaning_log 
    (column_name, issue_type, action_taken, records_affected, analyst_note)
VALUES('Entire dataset','non defined data types for value fields','converted fields to appropriate data types, and set primary keys',0,'Household id made primary key, while respondent id was made a unique key. Numeric and categorical columns defined appropriately based on their datatypes');
select * from hhs_data_cleaning hdc;

create table cleaned_household_survey as select * from hhs_data_cleaning hdc;

---------------------------------------------------ANALYSIS-----------------------------------------------------------------------

--A. ===========DEMOGRAPHIC PROFILE=======

-- How many respondents were surveyed per county, and what percentage does each county represent of the total sample?

select *, round((respondents_per_county/ total_respondents)* 100.0,1) as percentage_distribution from
(select county, count(respondent_id) as respondents_per_county,  sum(count(respondent_id)) over () as total_respondents
from cleaned_household_survey
group by county
order by count(respondent_id) desc) respondent_distribution;
-- to get the percentage, we do the county representation divide by total people, multiplied by 100

--2. What is the mean, median, minimum and maximum age of respondents disaggregated by residence type (Urban / Peri-urban / Rural)?
--In postgres, mean is otained by using average avg() while median is achieved using percentile
select * from cleaned_household_survey;
select residence_type, min(age) as minimum_age, max(age) as maximum_age, round(avg(age),2) as mean_age, percentile_cont(0.5) within group (order by age) as median_age
from cleaned_household_survey chs
group by residence_type;

--3. What is the age group distribution (15–24, 25–34, 35–49, 50–64, 65+) by county?
select county,
		sum(case when age between 16 and 17 then 1 else 0 end) as Emancipated_Minor,
		sum(case when age between 18 and 24 then 1 else 0 end) as Youth,
		sum(case when age between 25 and 34 then 1 else 0 end) as Young_adults,
        sum(case when age between 35 and 49 then 1 else 0 end) as Adults,
		sum(case when age between 50 and 64 then 1 else 0 end) as Older_Adults,
		sum(case when age >= 65 then 1 else 0 end) as Seniors,
		sum(case when age is null then 1 else 0 end) as Age_not_provided,
		count(*) as total_respondents
from cleaned_household_survey
group by county;

--4. What is the gender composition (% male vs % female) per county — flag any county exceeding 60% one gender as a potential sampling anomaly?
select * from cleaned_household_survey chs;

select *, 
round(Female_respondents * 100.0 / total_respondents, 1) as female_contribution,
round(male_respondents  * 100.0 / total_respondents,1) as male_contribution,
round(Gender_not_provided * 100.0/ total_respondents,1) as Contribution_Gender_not_provided
from
(select county, count(respondent_id) as total_respondents,
				sum(case when gender = 'Female' then 1 else 0 end) as Female_respondents,
				sum(case when gender = 'Male' then 1 else 0 end) as Male_respondents,
				sum(case when gender = 'Unknown' then 1 else 0 end) as Gender_not_provided
from cleaned_household_survey chs 
group by county
order by county) as gender_summary;

--5. What is the average household size by county, ranked from largest to smallest?
select * from cleaned_household_survey chs;

select county, round(avg(household_size),1) as average_household_size, dense_rank() over(order by avg(household_size) desc) as household_size_ranked
from cleaned_household_survey chs
where household_size is not null
group by county;

--6. What is the education level distribution by gender and residence type?
select * from cleaned_household_survey chs;

select 
    education_level,
 --female
    sum(case when gender = 'Female' and residence_type = 'Urban' then 1 else 0 end) as female_urban,
    sum(case when gender = 'Female' and residence_type = 'Rural' then 1 else 0 end) as female_rural,     
    sum(case when gender = 'Female' and residence_type = 'Peri-Urban'then 1 else 0 end) as female_peri_urban,
 --male            
     sum(case when gender = 'Male' and residence_type = 'Urban' then 1 else 0 end) as male_urban,
    sum(case when gender = 'Male' and residence_type = 'Rural' then 1 else 0 end) as male_rural,     
    sum(case when gender = 'Male' and residence_type = 'Peri-Urban'then 1 else 0 end) as male_peri_urban,
 --unknown gender 
 	sum(case when gender is null or gender not in ('Male','Female') then 1 else 0 end) as gender_unknown,  
 --unknown residence_type
 	sum(case when residence_type is null or residence_type not in ('Urban','Rural','Peri-Urban') then 1 else 0 end) as residence_type_unknown,
    count(*) as total_respondents
from cleaned_household_survey
group by education_level
order by education_level;

--7. Which counties have the highest share of respondents with no formal education or only primary schooling?
--number of respondents per county with primary education level
select county, count(respondent_id) as count_primary_education_only
from cleaned_household_survey chs 
where education_level = 'Primary'
group by county
order by count(respondent_id)desc;

--included subquery for the % share of respondents with primary education
select *, round((count_primary_education_only * 100)/total_respondents,2) as percentage_of_total
from
(select county, sum(case when education_level = 'Primary' then 1 else 0 end) as count_primary_education_only, count(respondent_id) as total_respondents
from cleaned_household_survey chs
group by county) as Primary_education_count
order by percentage_of_total desc;

--B. ===========ECONOMIC VULNERABILITY=======
--8. What is the mean and median monthly income (KES) by residence type — and what is the urban-rural income gap in absolute and percentage terms?
--mean = avg
--median = percentile cont
select * from cleaned_household_survey chs;
select residence_type, round(avg(monthly_income),2) as average_monthly_income, percentile_cont(0.5) within group (order by monthly_income) as median_monthly_income from cleaned_household_survey chs
group by residence_type;

--urban-rural income gap = difference in average income between people living in urban areas and rural areas.
--income gap
with income_residence_summary as 
(select
        round(avg(case when residence_type = 'Urban' then monthly_income end),2) as urban_avg,
        round(avg(case when residence_type = 'Rural' then monthly_income end),2) as rural_avg
from cleaned_household_survey chs)
select * , urban_avg - rural_avg as income_gap,
    		round(urban_avg / rural_avg,3) as income_ratio,
    		round((urban_avg - rural_avg) / rural_avg * 100,2) as percent_gap
from income_residence_summary;


--9. What share of households fall in the bottom two income quintiles (Q1 and Q2), disaggregated by county?
--Grouping by quintile

select county, total_households, round((sum(respondents) * 100) /total_households,2) as household_share 
from (
		select county, quintile, count(*) as respondents, total_households
		from (
			select county, monthly_income, ntile(5) over(order by monthly_income) as quintile, 
			count(household_id) over(partition by county) as total_households
			from cleaned_household_survey chs
			group by county, monthly_income, household_id) income_quintiles
		where quintile between 1 and 2  ---> Retaining just the bottom 2 quintiles
		group by county, quintile, total_households
		order by county, quintile) bottom_quintile_share
group by county, total_households; ----> The reason this is wrong is because the aggregation is done before ntile, s othe ntile does not group as it should, but still gets the correct answer
---> Correct way to do it, do the ntile on the incomes, before group by

select county, count(*) as total_households, round((sum(case when quintile in (1,2) then 1 else 0 end)*100.0)/count(*),2) as bottom_2_share
from(
    select county, ntile(5) over (order by monthly_income) as quintile
    from cleaned_household_survey) quintile_summary
group by county
order by county;

--10. What are the top 5 dominant livelihood sources in urban areas vs rural areas?
select * from cleaned_household_survey chs;
with ranked_livelihood as 
(select residence_type, livelihood_source, count(livelihood_source) as respondents, dense_rank() over ( partition by residence_type order by count(livelihood_source)desc) as ranking
from cleaned_household_survey chs
where livelihood_source != 'Unknown'
group by residence_type, livelihood_source)
select * from ranked_livelihood
where residence_type in ('Rural','Urban') and ranking between 1 and 5;

--11. What is the employment status breakdown (formal, informal, casual, farming, unemployed) by county?
select distinct chs.employment_status from cleaned_household_survey chs;
select county, sum(case when employment_status = 'Self Employed' then 1 else 0 end) as Informal_employment,
			   sum(case when employment_status = 'Employed' then 1 else 0 end) as formal_employment,
			   sum(case when employment_status = 'Casual Labour' then 1 else 0 end) as Casual,
			   sum(case when employment_status = 'Unemployed' then 1 else 0 end) as Unemployed
from cleaned_household_survey chs
group by county;

--12. What percentage of households receive remittances by county, and which 3 counties are most remittance-dependent?

select county, count(household_id) as households
from cleaned_household_survey chs
where chs.livelihood_source = 'Remittances'
group by county;

select * , round((households_with_remittances * 100)/households,2) as remittance_percentage 
from (
	select county, count(household_id) as households, sum(case when livelihood_source = 'Remittances' then 1 else 0 end) as households_with_remittances
	from cleaned_household_survey chs
	group by county) as remittance_summary
order by households_with_remittances desc
limit 3;

--13.  How does average income vary across education levels, disaggregated by residence type?
--group by education levels
--use case when to get avg income across edn levels
select distinct education_level from cleaned_household_survey;
select residence_type, 
					round(avg(case when education_level = 'University' then monthly_income end),2) as University_avg_income,
					round(avg(case when education_level = 'College/Tvet' then monthly_income end),2) as College_avg_income,
					round(avg(case when education_level =  'Secondary' then monthly_income end),2) as Secondary_avg_income,
					round(avg(case when education_level = 'Primary' then monthly_income end),2) as Primary_avg_income
from cleaned_household_survey chs 
where residence_type != 'Unknown'
group by chs.residence_type;

--14. What is the income distribution across dwelling types — do permanent structure residents earn significantly more?
select distinct dwelling_type from cleaned_household_survey chs;
select dwelling_type, round(avg(monthly_income),2) as average_monthly_income, percentile_cont(0.5) within group (order by monthly_income) as median_monthly_income
from cleaned_household_survey chs
where dwelling_type != 'Unknown'
group by dwelling_type;
				   
--15. Among households that receive remittances, what is their average income vs those that do not?
---not supposed to use the livelihood source
select distinct receives_remittances from cleaned_household_survey;
select 
    round(avg(case when receives_remittances in ('Yes', 'Occasionally') then monthly_income end), 2) as average_income_remittance,
    round(avg(case when receives_remittances = 'No' then  monthly_income end), 2) as average_income_no_remittance
from cleaned_household_survey chs
where receives_remittances is not null;----> To exclude the households where it was not known the livelihood source

--C. =======HEALTH ACCESS=======

--16. Q16	What is the health insurance coverage rate (any type) by residence type — and what % are completely uninsured?
select * from cleaned_household_survey chs;  
select distinct health_insurance from cleaned_household_survey chs;
select residence_type, count(household_id) as total_respondents,
		sum(case when health_insurance = 'Employer-provided' then 1 else 0 end) as Employee_Insured,
		sum(case when health_insurance = 'Linda Mama' then 1 else 0 end) as Linda_Mama,
		sum(case when health_insurance = 'SHA' then 1 else 0 end) as SHA,
		sum(case when health_insurance = 'NHIF' then 1 else 0 end) as NHIF,
		sum(case when health_insurance = 'Private insurance' then 1 else 0 end) as Privately_Insured,
		sum(case when health_insurance = 'Community-based' then 1 else 0 end) as Community_Insured,
		sum(case when health_insurance = 'NHIF - Inactive' then 1 else 0 end) as Inactive_Cover,
		sum(case when health_insurance = 'None' then 1 else 0 end) as Un_insured,
		sum(case when health_insurance = 'Unknown' then 1 else 0 end) as Respondent_didnt_Provideinfo
from cleaned_household_survey chs 
group by residence_type;

--alternative
select  health_insurance, round((Urban_distribution * 100)/total_respondents,2) as Urban_Percentage,
		   round((Peri_urban_distribution * 100)/total_respondents,2) as Peri_Urban_Percentage,
		   round((Rural_distribution * 100)/total_respondents,2) as Rural_Percentage
from(
		select health_insurance, count(household_id) as total_respondents,
		sum(case when residence_type = 'Urban' then 1 else 0 end) as Urban_distribution,
		sum(case when residence_type = 'Peri-Urban' then 1 else 0 end) as Peri_urban_distribution,
		sum(case when residence_type = 'Rural' then 1 else 0 end) as Rural_distribution
		from cleaned_household_survey 
		group by health_insurance) respondent_insurance_distribution
where health_insurance != 'Unknown';

--17. What is the breakdown of insurance type (NHIF, SHA, Linda Mama, private, none) by county?

select county, count(household_id) as total_respondents,
		sum(case when health_insurance = 'Employer-provided' then 1 else 0 end) as Employee_Insured,
		sum(case when health_insurance = 'Linda Mama' then 1 else 0 end) as Linda_Mama,
		sum(case when health_insurance = 'SHA' then 1 else 0 end) as SHA,
		sum(case when health_insurance = 'NHIF' then 1 else 0 end) as NHIF,
		sum(case when health_insurance = 'Private insurance' then 1 else 0 end) as Privately_Insured,
		sum(case when health_insurance = 'Community-based' then 1 else 0 end) as Community_Insured,
		sum(case when health_insurance = 'NHIF - Inactive' then 1 else 0 end) as Inactive_Cover,
		sum(case when health_insurance = 'None' then 1 else 0 end) as Uninsured,
		sum(case when health_insurance = 'Unknown' then 1 else 0 end) as Info_not_provided
from cleaned_household_survey chs 
group by county;

--18. What is the average and maximum distance to the nearest health facility by county, ranked worst-to-best?
select county, round(avg(distance_to_health_facility_km),2) as average_dthf, max(distance_to_health_facility_km) as maximum_dthf,
dense_rank() over (order by avg(distance_to_health_facility_km)) ranked_distance
from cleaned_household_survey chs
group by county;

--19. How many and what % of households live more than 10km from a health facility, disaggregated by residence type?
select * ,round((distance_over_10km * 100)/no_of_households,2) as distance_over_10km_percentage 
from( 
	select residence_type, count(household_id) as no_of_households, sum(case when distance_to_health_facility_km >10 then 1 else 0 	end) as distance_over_10km 
	from cleaned_household_survey chs
	where chs.residence_type != 'Unknown'
	group by residence_type) distance_over_10km_summary;

select count(distance_to_health_facility_km) from cleaned_household_survey chs
where chs.residence_type = 'Urban' and distance_to_health_facility_km >10; ----> confirms the numeric result above

--20. What % of households use unimproved water sources (river, unimproved vendor) by county?
--Assumptions I will make- The water vendor source is improved
--The rain water is collected with no proper storage/colletion method, therefore is unimproved
select * from cleaned_household_survey chs;
select distinct water_source from cleaned_household_survey chs;

select *, (Unimproved_watersources_households * 100)/households as Percentage_Unimproved
from(
select county, count(household_id) as households, sum(case when water_source in ('Rain Water','River') then 1 else 0 end) as Unimproved_watersources_households
from cleaned_household_survey group by county) Summary_unimproved_sources;


--21. What % of households practice open defecation by residence type and county?
select * , (Households_open_defecation * 100)/households as Open_defecation_percentage
from (
	select county, residence_type, count(household_id) as households, sum(case when sanitation_type = 'Open Defecation' then 1 	else 0 end) as Households_open_defecation
	from cleaned_household_survey chs
	where residence_type != 'Unknown'
	group by county, residence_type
	order by county, residence_type) Open_defecation_summary;

--22. What is the WASH vulnerability profile — cross-tabulate unimproved water source vs open defecation by residence type?

select *,  (Unimproved_water_and_open_defecation *100)/ households as vulnerability_percentage 
from(
	select residence_type, count(household_id) as households, sum(case when water_source in ('Rain Water','River') then 1 else 0 end) as Unimproved_water,
	sum(case when sanitation_type = 'Open Defecation' then 1 	else 0 end) as open_defecation,
	sum(case when sanitation_type = 'Open Defecation' and water_source in ('Rain Water','River') then 1 else 0 end) as Unimproved_water_and_open_defecation 
	from cleaned_household_survey 
	where residence_type != 'Unknown'
	group by residence_type) vulnerability_profile;

--23. Among uninsured households, what is their average distance to the nearest health facility vs insured households?
select count(household_id) as respondents, round(avg(case when health_insurance = 'None' then distance_to_health_facility_km end),2) uninsured_households,
										   round(avg(case when health_insurance != 'None' then distance_to_health_facility_km end),2) insured_households
from cleaned_household_survey chs; 


--D. =======FOOD SECURITY=======
--24. What is the food security status distribution (% Food Secure / Mildly / Moderately / Severely Insecure) by residence type?
select distinct food_security_status from cleaned_household_survey;
select food_security_status, Urban_pop, (Urban_pop*100)/ households as urban_Percent, Rural_pop, (Rural_pop*100)/ households as rural_percent, Peri_urban_pop, (Peri_urban_pop*100)/ households as Peri_urban_percent
from(
		select food_security_status, count(household_id) as households, sum(case when residence_type = 'Urban' then 1 else 0 end) as Urban_pop,
                                                                sum(case when residence_type = 'Rural' then 1 else 0 end) as Rural_pop,
                                                                sum(case when residence_type = 'Peri-Urban' then 1 else 0 end) as Peri_urban_pop
from cleaned_household_survey
where food_security_status != 'Unknown'
group by food_security_status) food_security_summary;

--25. Which 3 counties have the highest rate of severe food insecurity?
select *, (Severe_insecure * 100)/households as Food_insecurity_rate
from(
	select county, count(household_id)as households, sum(case when food_security_status in ('Severely Insecure','Chronically Insecure') then 1 else 0 end) as  	Severe_insecure
	from cleaned_household_survey
	group by county) Severely_food_insecure
order by food_insecurity_rate desc;

--26. How does food security status vary across income quintiles — does severity worsen linearly with lower income? There is no linear relationship
--distribution of numbers per quintile
select quintile, food_security_status, count(*) as households
from (
 		select household_id, food_security_status,ntile(5) over(order by monthly_income) as quintile
        from cleaned_household_survey
	    where food_security_status <> 'Unknown'	)quintile_summary 
group by quintile, food_security_status
order by quintile, food_security_status;

---having them as percentages
select
    quintile,
    round(sum(case when food_security_status = 'Food Secure' then 1 else 0 end) * 100.0 / count(*), 2) as food_secure_pct,
    round(sum(case when food_security_status = 'Mildly Insecure' then 1 else 0 end) * 100.0 / count(*), 2) as mildly_insecure_pct,
    round(sum(case when food_security_status = 'Moderately Insecure' then 1 else 0 end) * 100.0 / count(*), 2) as moderately_insecure_pct,
    round(sum(case when food_security_status = 'Severely Insecure' then 1 else 0 end) * 100.0 / count(*), 2) as severely_insecure_pct,
     round(sum(case when food_security_status = 'Chronically Insecure' then 1 else 0 end) * 100.0 / count(*), 2) as chronically_insecure_pct,
    round(sum(case when food_security_status = 'Food Insecure' then 1 else 0 end) * 100.0 / count(*), 2) as food_insecure_pct,
    count(*) as total_households
from (
    select household_id, food_security_status, ntile(5) over (order by monthly_income) as quintile
    from cleaned_household_survey
    where food_security_status <> 'Unknown') as Quintile_summary
group by quintile
order by quintile;

--27. Which livelihood sources are most strongly associated with food insecurity (moderate or severe)?
--Food insecure = Moderately food insecure OR Severely food insecure OR self-reported chronically food insecure
select livelihood_source, count(respondent_id) as total_households, 
(sum(case when food_security_status in ('Food Insecure','Severely Insecure','Chronically Insecure','Moderately Insecure') then 1 else 0 end)*100/count(household_id)) as Food_insecure
from cleaned_household_survey chs
group by livelihood_source
order by food_insecure desc;

--28. Is larger household size associated with higher food insecurity? Compare mean household size by food security category.- I do not think so, but i am not sure
select food_security_status, avg(household_size) as mean_hh_size 
from cleaned_household_survey chs
where chs.food_security_status != 'Unknown'
group by chs.food_security_status
order by mean_hh_size desc;

--29. Among severely food insecure households, what % also use unimproved water sources — a double-deprivation count?
select (sum(case when food_security_status in ('Food Insecure','Severely Insecure','Chronically Insecure','Moderately Insecure') and water_source in ('River','Rain')then 1 else 0 end)*100/count(household_id)) as Double_deprivation_share 
from cleaned_household_survey chs;

--30. What is the food insecurity rate among households where the primary livelihood is casual labour vs formal employment?
select livelihood_source, 
(sum(case when food_security_status in ('Food Insecure','Severely Insecure','Chronically Insecure','Moderately Insecure') then 1 else 0 end) *100/ count(household_id)) as insecurity_rate 
from cleaned_household_survey chs
where livelihood_source in ('Casual Farm Work','Employment')
group by livelihood_source
order by Insecurity_rate desc;

--E. =======FINANCIAL INCLUSION=======
--31. What is the mobile money access rate by residence type — and which platform (M-Pesa, Airtel, T-Kash) dominates?
--access rate by residence type
select distinct mobile_money_access from cleaned_household_survey;
select residence_type, count(household_id) as households,
(sum(case when mobile_money_access in ('M-Pesa (Shared)', 'Airtel Money', 'T-Kash', 'M-Pesa', 'M-Pesa & Airtel Money') then 1 else 0 end) *100) / count (household_id) as access_rate,
(sum(case when mobile_money_access = 'No' then 1 else 0 end)*100)/count(household_id) as no_access_rate
from cleaned_household_survey chs 
where residence_type != 'Unknown'
group by residence_type;

---dominating platform
select residence_type, count(*) as total_households,
sum(case when mobile_money_access ='M-Pesa' then 1 else 0 end) as MPesa,
sum(case when mobile_money_access = 'Airtel Money' then 1 else 0 end) as Airtel_money,
sum(case when mobile_money_access = 'T-Kash' then 1 else 0 end) as T_Kash,
sum(case when mobile_money_access = 'M-Pesa & Airtel Money' then 1 else 0 end) as MPesa_and_Airtel
from cleaned_household_survey chs 
where residence_type != 'Unknown'
group by chs.residence_type;

--percentage
select residence_type, count(household_id) as total_households,
round((sum(case when mobile_money_access = 'M-Pesa' then 1 else 0 end)*100.0)/count(household_id),2) as MPesa_Pct,
round((sum(case when mobile_money_access = 'Airtel Money' then 1 else 0 end)*100.0)/count(household_id),2) as Airtel_money_Pct,
round((sum(case when mobile_money_access = 'T-Kash' then 1 else 0 end)*100.0)/count(household_id),2) as T_Kash_Pct,
round((sum(case when mobile_money_access = 'M-Pesa & Airtel Money' then 1 else 0 end)*100.0)/count(household_id),2) as MPesa_and_Airtel_Pct
from cleaned_household_survey chs 
where residence_type != 'Unknown'
group by chs.residence_type;

--32. How does mobile money penetration vary by age group — is there a generational exclusion gap? Yes, there seems to be one
select * from cleaned_household_survey chs;
--Numbers
select mobile_money_access,count(respondent_id) as total_respondents,
		sum(case when age between 16 and 17 then 1 else 0 end) as Emancipated_minor,
		sum(case when age between 18 and 24 then 1 else 0 end) as Youth,
		sum(case when age between 25 and 34 then 1 else 0 end) as Young_adults,
        sum(case when age between 35 and 49 then 1 else 0 end) as Adults,
		sum(case when age between 50 and 64 then 1 else 0 end) as Older_Adults,
		sum(case when age >= 65 then 1 else 0 end) as Seniors
from cleaned_household_survey chs
where chs.mobile_money_access <> 'Unknown'
group by  mobile_money_access;

--percentages
select mobile_money_access,count(respondent_id) as total_respondents,
		round((sum(case when age between 16 and 17 then 1 else 0 end)*100.0)/count(respondent_id),2) as Emancipated_minor,
		round((sum(case when age between 18 and 24 then 1 else 0 end)*100.0)/count(respondent_id),2) as Youth,
		round((sum(case when age between 25 and 34 then 1 else 0 end)*100.0)/count(respondent_id),2) as Young_adults,
        round((sum(case when age between 35 and 49 then 1 else 0 end)*100.0)/count(respondent_id),2) as Adults,
		round((sum(case when age between 50 and 64 then 1 else 0 end)*100.0)/count(respondent_id),2) as Older_Adults,
		round((sum(case when age >= 65 then 1 else 0 end) *100.0)/count(respondent_id),2)  as Seniors
from cleaned_household_survey chs
where chs.mobile_money_access <> 'Unknown'
group by  mobile_money_access;

--33. Is there a gender gap in mobile money access? Compare penetration rates for male vs female respondents.---no gap
select mobile_money_access, count(respondent_id) as total_respondents,
		sum(case when gender = 'Male' then 1 else 0 end) as Male_pct,
		sum(case when gender = 'Female' then 1 else 0 end) as Female_pct
from cleaned_household_survey chs
where chs.mobile_money_access <> 'Unknown'
group by chs.mobile_money_access;
--Percent Distribution
select mobile_money_access, count(respondent_id) as total_respondents,
		round((sum(case when gender = 'Male' then 1 else 0 end)*100.0)/count(respondent_id),2) as Male_pct,
		round((sum(case when gender = 'Female' then 1 else 0 end)*100.0)/count(respondent_id),2) as Female_pct
from cleaned_household_survey chs
where chs.mobile_money_access <> 'Unknown'
group by chs.mobile_money_access;

--How does mobile money access vary by employment status — are casual workers and farmers less financially included? -Overall employed seem to be more included, least included are students, then pastoralists, Casuals and unemployed seem to be doing pretty well compared to farmers
select distinct employment_status from cleaned_household_survey chs;
--numbers
select mobile_money_access, 
		sum(case when employment_status = 'Employed' then 1 else 0 end) as employed,
		sum(case when employment_status = 'Self Employed' then 1 else 0 end) as self_employed,
		sum(case when employment_status = 'Casual Labour' then 1 else 0 end) as casual_labour,
		sum(case when employment_status = 'Farmer' then 1 else 0 end) as farmer,		
		sum(case when employment_status = 'Pastoralist' then 1 else 0 end) as pastoralist,			
		sum(case when employment_status = 'Student' then 1 else 0 end) as student,		
		sum(case when employment_status = 'Unemployed' then 1 else 0 end) as unemployed
from cleaned_household_survey chs
where chs.mobile_money_access <> 'Unknown'
group by chs.mobile_money_access;

--percentage
select mobile_money_access, 
		round((sum(case when employment_status = 'Employed' then 1 else 0 end)*100.0)/count(*),2) as employed,
		round((sum(case when employment_status = 'Self Employed' then 1 else 0 end)*100.0)/count(*),2)  as self_employed,
		round((sum(case when employment_status = 'Casual Labour' then 1 else 0 end)*100.0)/count(*),2)  as casual_labour,
		round((sum(case when employment_status = 'Farmer' then 1 else 0 end)*100.0)/count(*),2)  as farmer,		
		round((sum(case when employment_status = 'Pastoralist' then 1 else 0 end)*100.0)/count(*),2)  as pastoralist,			
		round((sum(case when employment_status = 'Student' then 1 else 0 end)*100.0)/count(*),2)  as student,		
		round((sum(case when employment_status = 'Unemployed' then 1 else 0 end)*100.0)/count(*),2)  as unemployed
from cleaned_household_survey chs
where chs.mobile_money_access <> 'Unknown'
group by chs.mobile_money_access;

--34. Which county has the lowest mobile money penetration rate, and what is its residence type composition? ---residence type composition done in a separate query, not sure how to do it in one.
--Mobile money access by county and residence type?
select county, 
sum(case when mobile_money_access ='M-Pesa' then 1 else 0 end) as MPesa,
sum(case when mobile_money_access = 'Airtel Money' then 1 else 0 end) as Airtel_money,
sum(case when mobile_money_access = 'T-Kash' then 1 else 0 end) as T_Kash,
sum(case when mobile_money_access = 'M-Pesa & Airtel Money' then 1 else 0 end) as MPesa_and_Airtel,
sum(case when mobile_money_access = 'No' then 1 else 0 end)as no_access
from cleaned_household_survey chs 
group by chs.county;

--percentage
select county, count(*) as total_respondents,
round((sum(case when mobile_money_access ='M-Pesa' then 1 else 0 end) *100.0)/count(*),2) as MPesa,
round((sum(case when mobile_money_access = 'Airtel Money' then 1 else 0 end) *100.0)/count(*),2) as Airtel_money,
round((sum(case when mobile_money_access = 'T-Kash' then 1 else 0 end) *100.0)/count(*),2) as T_Kash,
round((sum(case when mobile_money_access = 'M-Pesa & Airtel Money' then 1 else 0 end)*100.0)/count(*),2) as MPesa_and_Airtel,
--round((sum(case when mobile_money_access = 'No' then 1 else 0 end) *100.0)/count(*),2) as no_access,
round( 100.0 * sum(case when mobile_money_access is not null and mobile_money_access <> 'No' then 1 else 0 end)/count(*),2) as any_mobile_money_access
from cleaned_household_survey chs 
group by chs.county
order by any_mobile_money_access;
---residence composition
select  county,  residence_type, count(*) as Residence_comp,round(100.0 * count(*) / sum(count(*)) over (partition by county), 2) as pct_within_county
from cleaned_household_survey
where residence_type <> 'Unknown'
group by county, residence_type;  

--36, What % of households in the bottom income quintile (Q1) have no mobile money access AND no health insurance — the financially excluded core?

  select * from cleaned_household_survey chs;
select quintiles, count(*)as total_households, 
round((sum(case when mobile_money_access = 'No' and health_insurance = 'None' then 1 else 0 end)*100.0)/count(*),2) as financially_excluded_pct
from(
	select chs.mobile_money_access, chs.health_insurance, ntile(5) over(order by monthly_income) as quintiles
	from cleaned_household_survey chs) as quintile_summary
group by quintiles
order by quintiles;

--F. =======MULTIDIMENSIONAL VULNERABILITY INDEX======= 
--37. Construct a vulnerability score (0–5) per household: 1 point each for — bottom income quintile, food insecure (moderate/severe), no health insurance, no mobile money, unimproved water source. What is the score distribution?
---vulnerability score per county
	select county, count(*) as total_households,  
	case when income_quintile = 1 then 1 else 0 end + 
	case when food_security_status in ('Food Insecure','Moderately Insecure','Chronically Insecure','Severely Insecure') then 1 else 0 end+
	case when health_insurance = 'None' then 1 else 0 end +
	case when mobile_money_access = 'No' then 1 else 0 end +
	case when water_source in ('River','Rain Water') then 1 else 0 end as vulnerability_score
	from(
		select household_id, county, food_security_status, health_insurance, mobile_money_access,water_source, ntile(5) over(order by monthly_income) as 	income_quintile
		from cleaned_household_survey) vulnerability_table
	group by county, vulnerability_score
	order by county, vulnerability_score;
	
--vulnerability score throughout the dataset

select count(*) as total_households,  
case when income_quintile = 1 then 1 else 0 end + 
case when food_security_status in ('Food Insecure','Moderately Insecure','Chronically Insecure','Severely Insecure') then 1 else 0 end+
case when health_insurance = 'None' then 1 else 0 end +
case when mobile_money_access = 'No' then 1 else 0 end +
case when water_source in ('River','Rain Water') then 1 else 0 end as vulnerability_score
from(
	select household_id, food_security_status, health_insurance, mobile_money_access,water_source, ntile(5) over(order by monthly_income) as income_quintile
	from cleaned_household_survey) vulnerability_table
group by vulnerability_score
order by vulnerability_score;

--38. Which county has the highest average vulnerability score and highest share of households scoring 4 or 5?

select county,
round((sum(case when vulnerability_score in (4,5) then 1 else 0 end)*100.0)/count(*),2) as Score_4_5,
round(avg(vulnerability_score),2) as average_score
from(
	select county, 
	case when income_quintile = 1 then 1 else 0 end + 
	case when food_security_status in ('Food Insecure','Moderately Insecure','Chronically Insecure','Severely Insecure') then 1 else 0 end+
	case when health_insurance = 'None' then 1 else 0 end +
	case when mobile_money_access = 'No' then 1 else 0 end +
	case when water_source in ('River','Rain Water') then 1 else 0 end as vulnerability_score
	from(
		select household_id, county, food_security_status, health_insurance, mobile_money_access,water_source, ntile(5) over(order by monthly_income) as 		income_quintile
		from cleaned_household_survey) summary
	)vulnerability_classification
group by county
order by average_score desc;

----Count of households in each vulnerability score per county 
select county,
sum(case when vulnerability_score = 0 then total_households end) as Score_0,
sum(case when vulnerability_score = 1 then total_households end) as Score_1,
sum(case when vulnerability_score = 2 then total_households end) as Score_2,
sum(case when vulnerability_score = 3 then total_households end) as Score_3,
sum(case when vulnerability_score = 4 then total_households end) as Score_4,
sum(case when vulnerability_score = 5 then total_households end) as Score_5,
avg(vulnerability_score) as average_score
from(
	select county, count(*) as total_households,  
	case when income_quintile = 1 then 1 else 0 end + 
	case when food_security_status in ('Food Insecure','Moderately Insecure','Chronically Insecure','Severely Insecure') then 1 else 0 end+
	case when health_insurance = 'None' then 1 else 0 end +
	case when mobile_money_access = 'No' then 1 else 0 end +
	case when water_source in ('River','Rain Water') then 1 else 0 end as vulnerability_score
	from(
		select household_id, county, food_security_status, health_insurance, mobile_money_access,water_source, ntile(5) over(order by monthly_income) as 		income_quintile
		from cleaned_household_survey) summary
	group by county, vulnerability_score
	order by county, vulnerability_score)vulnerability_classification
group by county;

--39. What is the vulnerability score distribution by residence type — do rural households disproportionately score 4–5?
select residence_type, count(*),
round((sum(case when vulnerability_score in (4,5) then 1 else 0 end)*100.0)/count(*),2) as Pct_of_Score_4_5,
round(avg(vulnerability_score),2) as average_score
from(
	select residence_type, 
	case when income_quintile = 1 then 1 else 0 end + 
	case when food_security_status in ('Food Insecure','Moderately Insecure','Chronically Insecure','Severely Insecure') then 1 else 0 end+
	case when health_insurance = 'None' then 1 else 0 end +
	case when mobile_money_access = 'No' then 1 else 0 end +
	case when water_source in ('River','Rain Water') then 1 else 0 end as vulnerability_score
	from(
		select household_id, residence_type, food_security_status, health_insurance, mobile_money_access,water_source, ntile(5) over(order by monthly_income) 		as income_quintile
		from cleaned_household_survey) summary
	)vulnerability_classification
where residence_type <> 'Unknown'
group by residence_type;

--40. Profile the highest-vulnerability households (score = 5): what livelihood source, education level, county, and dwelling type are most common among them?
--find some time to understand the cross join lateral, where it is used and how it works
select  dimension, category, count(*) as households, vulnerability_score
from ( 
	select county, livelihood_source,education_level,dwelling_type,
	case when income_quintile = 1 then 1 else 0 end + 
	case when food_security_status in ('Food Insecure','Moderately Insecure','Chronically Insecure','Severely Insecure') then 1 else 0 end+
	case when health_insurance = 'None' then 1 else 0 end +
	case when mobile_money_access = 'No' then 1 else 0 end +
	case when water_source in ('River','Rain Water') then 1 else 0 end as vulnerability_score   
    from (
		select household_id, county, livelihood_source, education_level, dwelling_type, food_security_status, health_insurance, mobile_money_access, 		water_source, ntile(5) over(order by monthly_income) as income_quintile
        from cleaned_household_survey)summary)
cross join lateral (
    values
        ('livelihood_source', livelihood_source),
        ('education_level', education_level),
        ('county', county),
        ('dwelling_type', dwelling_type)) as x(dimension, category)
where vulnerability_score = 5
group by dimension, category, vulnerability_score
order by dimension, households desc;


--======================================================================VIEWS==================================================================================
--Module 1:  Demographic profile
-- VIEW 1: v_demographic_profile

create or replace view v_demographic_profile as
with total as (
    select count(respondent_id) as total_respondents
    from cleaned_household_survey
)
select
    county,
    -- q01: respondent count and % of total sample
    total.total_respondents, count(respondent_id) respondents_per_county,
    round(count(respondent_id) * 100.0 / total.total_respondents, 1) as percentage_distribution,
    -- q02: age statistics (by county; residence_type breakdown kept in standalone q02)
    round(avg(age), 2) mean_age,
    percentile_cont(0.5) within group (order by age) median_age,
    max(age) maximum_age,
    -- q04: gender composition
    round(sum(case when gender = 'Female'  then 1 else 0 end) * 100.0 / count(respondent_id), 1) as female_contribution,
    round(sum(case when gender = 'Male'    then 1 else 0 end) * 100.0 / count(respondent_id), 1) as male_contribution,
    round(avg(household_size), 2) avg_household_size,
    -- q06: education by gender and residence type
    sum(case when gender = 'Female' and residence_type = 'Urban'      then 1 else 0 end) as female_urban,
    sum(case when gender = 'Female' and residence_type = 'Rural'      then 1 else 0 end) as female_rural,
    sum(case when gender = 'Female' and residence_type = 'Peri-Urban' then 1 else 0 end) as female_peri_urban,
    sum(case when gender = 'Male'   and residence_type = 'Urban'      then 1 else 0 end) as male_urban,
    sum(case when gender = 'Male'   and residence_type = 'Rural'      then 1 else 0 end) as male_rural,
    sum(case when gender = 'Male'   and residence_type = 'Peri-Urban' then 1 else 0 end) as male_peri_urban,
    -- q07: Education share
    round(sum(case when education_level = 'Primary' then 1 else 0 end) * 100.0/count(respondent_id), 2) as pct_primary_education,
    round(sum(case when education_level = 'Secondary' then 1 else 0 end) * 100.0/count(respondent_id), 2) as pct_secondary_education,
    round(sum(case when education_level in ('College/Tvet','University') then 1 else 0 end) * 100.0/count(respondent_id), 2) as pct_tertiary_education,
       -- q02b: age distribution by bucket (counts + % of county total)
    sum(case when age <= 17 then 1 else 0 end) as emancipated_minor,
    sum(case when age between 18 and 35 then 1 else 0 end) as youth,
    sum(case when age between 36 and 49 then 1 else 0 end) as adults,
    sum(case when age between 50 and 64 then 1 else 0 end) as older_adults,
    sum(case when age >= 65 then 1 else 0 end) as seniors
from cleaned_household_survey
cross join total
group by county, total.total_respondents
order by respondents_per_county desc;

--============================================================
--Module 2: Economic Vulnerability
--View 2: Economic Vulnerability - County Level
--create or replace view v_county_economic as
with quintile_base as (
    select county, residence_type,  livelihood_source,  ntile(5) over (order by monthly_income) as quintile
    from cleaned_household_survey)       
    select county, residence_type,livelihood_source,     
-- Q09: Total households and bottom two quintiles share
       count(*) total_households,
       sum(case when quintile in (1,2) then 1 else 0 end) bottom_2_quintile_count,
       round(sum(case when quintile in (1,2) then 1 else 0 end)*100.0/count(*),2) bottom_2_quintile_pct,
       -- Q10: Livelihood source ranking within residence type
       dense_rank() over(partition by residence_type order by count(case when livelihood_source != 'Unknown' then 1 end) desc) livelihood_rank                         
from quintile_base
where livelihood_source  <> 'Unknown' and residence_type <> 'Unknown'
group by county, residence_type, livelihood_source
order by county, residence_type,livelihood_rank;

--View 3: Economic Vulnerability_ Residence type level

create or replace view v_income_by_residence as
with income_summary as (
  select residence_type, round(avg(monthly_income),2) mean_income, percentile_cont(0.5) within group (order by monthly_income) median_income,
  -- Q13: Average income by education level
  round(avg(case when education_level in ('College/Tvet','University')  then monthly_income end),2) tertiary_avg_income,
  round(avg(case when education_level = 'Secondary' then monthly_income end),2) secondary_avg_income,
  round(avg(case when education_level = 'Primary' then monthly_income end),2) primary_avg_income
 from cleaned_household_survey
where residence_type not in ('Unknown')
group by residence_type)
select residence_type, mean_income, median_income,
       -- Q13: Education income columns
tertiary_avg_income, secondary_avg_income, primary_avg_income
from income_summary
order by mean_income desc; 

--View 4: Rural-Urban Income Gap
create or replace view v_urban_rural_income_gap as
select
       round(avg(monthly_income),2) mean_income,
       round(avg(case when residence_type = 'Urban' then monthly_income end),2) urban_avg,
       round(avg(case when residence_type = 'Rural' then monthly_income end),2) rural_avg,
       round(avg(case when residence_type = 'Urban' then monthly_income end) -
             avg(case when residence_type = 'Rural' then monthly_income end),2) income_gap_kes,
       round((avg(case when residence_type = 'Urban' then monthly_income end) -
              avg(case when residence_type = 'Rural' then monthly_income end)) /
              nullif(avg(case when residence_type = 'Rural' then monthly_income end),0) * 100,2) income_gap_pct,
       round(avg(case when residence_type = 'Urban' then monthly_income end) /
             nullif(avg(case when residence_type = 'Rural' then monthly_income end),0),3) income_ratio, county
from cleaned_household_survey
where residence_type in ('Urban','Rural')
group by county
order by county;
-- ============================================================
-- Module 3 — Health Access
--View 5
create or replace view v_health_access as
select county,  residence_type, count(household_id) total_respondents,
 -- Q16: Insurance coverage Percentage
   round(sum(case when health_insurance = 'None' then 1 else 0 end)*100.0/count(household_id),2) pct_uninsured,
   round(sum(case when health_insurance != 'None' and health_insurance != 'Unknown' then 1 else 0 end)*100.0/count(household_id),2) pct_insured,
       -- Q18: Distance to health facility with rank
   round(avg(distance_to_health_facility_km),2) avg_distance_to_facility,max(distance_to_health_facility_km) max_distance_to_facility,
   -- Q19: Households over 10km from facility
   sum(case when distance_to_health_facility_km > 10 then 1 else 0 end) households_over_10km,
   round(sum(case when distance_to_health_facility_km > 10 then 1 else 0 end)*100.0/count(household_id),2) pct_over_10km,
   -- Q20: Unimproved water sources
   round(sum(case when water_source in ('Rain Water','River') then 1 else 0 end)*100.0/count(household_id),2) pct_unimproved_water,
   -- Q21: Open defecation
   round(sum(case when sanitation_type = 'Open Defecation' then 1 else 0 end)*100.0/count(household_id),2) open_defecation_pct,
   -- Q22: WASH double vulnerability
   sum(case when sanitation_type = 'Open Defecation' and water_source in ('Rain Water','River') then 1 else 0 end) unimproved_water_and_open_defecation,       
   round(sum(case when sanitation_type = 'Open Defecation'and water_source in ('Rain Water','River') then 1 else 0 end)*100.0/count(household_id),2) wash_vulnerability_pct,           
       -- Q23: Average distance by insurance status
       round(avg(case when health_insurance = 'None' then distance_to_health_facility_km end),2) avg_distance_uninsured,
       round(avg(case when health_insurance != 'None' then distance_to_health_facility_km end),2) avg_distance_insured
from cleaned_household_survey
where residence_type != 'Unknown'
group by county, residence_type
order by county, residence_type;


-- ============================================================
-- Module 4: Food Security
--View 6
create or replace view v_food_security as
with quintile_base as (
    select household_id, county,  water_source,food_security_status, ntile(5) over(order by monthly_income) as quintile
    from cleaned_household_survey)      
  		select quintile, count(*) total_households,  
     -- Q26: Food security distribution by income quintile
   round(sum(case when food_security_status = 'Food Secure' then 1 else 0 end)*100.0/count(*),2) food_secure_pct,
   round(sum(case when food_security_status = 'Mildly Insecure' then 1 else 0 end)*100.0/count(*),2) mildly_insecure_pct,
   round(sum(case when food_security_status = 'Moderately Insecure' then 1 else 0 end)*100.0/count(*),2) moderately_insecure_pct,
   round(sum(case when food_security_status = 'Severely Insecure' then 1 else 0 end)*100.0/count(*),2) severely_insecure_pct,
   round(sum(case when food_security_status = 'Chronically Insecure' then 1 else 0 end)*100.0/count(*),2) chronically_insecure_pct,
   round(sum(case when food_security_status = 'Food Insecure' then 1 else 0 end)*100.0/count(*),2) food_insecure_pct,
   -- Q29: Double deprivation — food insecure AND unimproved water source
   sum(case when food_security_status in ('Food Insecure','Severely Insecure','Chronically Insecure','Moderately Insecure')
           and water_source in ('River','Rain') then 1 else 0 end) double_deprivation_count,
   round(sum(case when food_security_status in ('Food Insecure','Severely Insecure','Chronically Insecure','Moderately Insecure')
           and water_source in ('River','Rain') then 1 else 0 end)*100.0/count(*),2) double_deprivation_pct         
from quintile_base
   where food_security_status <> 'Unknown'
group by quintile
order by quintile;

-- ============================================================
-- Module 5: Financial Inclusion
--View 7  v_financial_inclusion
create or replace view v_financial_inclusion as
with quintile_base as (
    select mobile_money_access, health_insurance, county, residence_type,ntile(5) over(order by monthly_income) as quintile
    from cleaned_household_survey
    where mobile_money_access != 'Unknown')      
select county, residence_type,count(*) total_households,         
 -- Q34: Mobile money penetration by county
 round((sum(case when mobile_money_access != 'No' then 1 else 0 end)*100.0)/count(*),2) any_mobile_money_access_pct,
 round((sum(case when mobile_money_access = 'No' then 1 else 0 end)*100.0)/count(*),2) no_access_pct,
   -- Q34: Residence type composition within county using window function
 round(100.0*count(*)/sum(count(*)) over(partition by county),2) pct_within_county,
   -- Q36: Financially excluded core per quintile
 round(sum(case when quintile = 1 and mobile_money_access = 'No'and health_insurance = 'None' then 1 else 0 end)*100.0/count(*),2) financially_excluded_q1_pct          
from quintile_base
where residence_type != 'Unknown'
group by county, residence_type
order by no_access_pct desc;  


-- ============================================================
-- Module 6 : Multidimensional Vulnerability Index
-- VIEW 8: v_vulnerability_index

create or replace view v_vulnerability_profile as
with quintile_base as (select household_id, county, livelihood_source, education_level, dwelling_type, dependency_category, food_security_status, health_insurance, mobile_money_access, water_source, 
ntile(5) over(order by monthly_income) as income_quintile from cleaned_household_survey
where county <> 'Unknown'
      and livelihood_source <> 'Unknown'
      and education_level <> 'Unknown'
      and dwelling_type <> 'Unknown'
      and dependency_category <> 'Unknown'
      and food_security_status <> 'Unknown'
      and health_insurance <> 'Unknown'
      and mobile_money_access <> 'Unknown'
      and water_source <> 'Unknown'),
vulnerability_scored as (select county, 
case when income_quintile = 1 then 1 else 0 end + 
case when food_security_status in ('Food Insecure','Moderately Insecure','Chronically Insecure','Severely Insecure') then 1 else 0 end + 
case when health_insurance = 'None' then 1 else 0 end + case when mobile_money_access = 'No' then 1 else 0 end + 
case when water_source in ('River','Rain Water') then 1 else 0 
end as vulnerability_score, livelihood_source, education_level, dwelling_type, dependency_category from quintile_base)
select county, count(*) total_households,
sum(case when vulnerability_score = 0 then 1 else 0 end) score_0,
sum(case when vulnerability_score = 1 then 1 else 0 end) score_1,
sum(case when vulnerability_score = 2 then 1 else 0 end) score_2,
sum(case when vulnerability_score = 3 then 1 else 0 end) score_3,
sum(case when vulnerability_score = 4 then 1 else 0 end) score_4,
sum(case when vulnerability_score = 5 then 1 else 0 end) score_5,
round(avg(vulnerability_score),2) average_vulnerability_score,
round(sum(case when vulnerability_score in (4,5) then 1 else 0 end)*100.0/count(*),2) pct_score_4_5,
mode() within group(order by case when vulnerability_score in (4,5) then livelihood_source end) dominant_livelihood,
mode() within group(order by case when vulnerability_score in (4,5) then education_level end) dominant_education,
mode() within group(order by case when vulnerability_score in (4,5) then dwelling_type end) dominant_dwelling,
mode() within group(order by case when vulnerability_score in (4,5) then dependency_category end) dominant_dependency
from vulnerability_scored
group by county
order by county;

-- Adding quintile column for the views
alter table final_cleaned_household_survey
add column income_quintile int;
with quintiles as (
    select
        household_id, ntile(5) over (order by monthly_income) as income_quintile
    from final_cleaned_household_survey)
update final_cleaned_household_survey fch
set income_quintile = q.income_quintile
from quintiles q
where fch.household_id = q.household_id;
--------------------------------------------------------INDEXES-----------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------

create index idx_county_residence on cleaned_household_survey (county, residence_type);
create index idx_monthly_income on cleaned_household_survey (monthly_income);

create table final_cleaned_household_survey as select * from cleaned_household_survey;


