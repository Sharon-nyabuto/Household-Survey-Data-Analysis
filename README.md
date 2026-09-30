# Household Survey Analysis

An end-to-end household survey project examining **socioeconomic wellbeing and multidimensional vulnerability across households in Kenya**.

The analysis uses **9,400+ cleaned household records across all 47 counties**, covering household demographics, livelihoods and economic wellbeing, education, health, WASH, food security, financial inclusion, and other indicators of vulnerability.

## Research Questions

The analysis focused on:

* What are the socioeconomic characteristics of surveyed households?
* How does access to essential services and economic opportunities vary across counties and households?
* Which households experience multiple forms of vulnerability?
* How does multidimensional vulnerability vary geographically and across household characteristics?
* What patterns in the data can inform programme planning and prioritisation?

## Project Workflow

**Survey Design → Data Collection → Data Quality & Cleaning → Analysis → Visualisation → Reporting**

### 1. Survey Tool & Data Collection

A structured household survey was developed and deployed using **KoboToolbox** to collect information across the key dimensions of household wellbeing and vulnerability.

**Survey tool:** [Household Survey Questionnaire](https://ee.kobotoolbox.org/x/IxZGOQPc)

### 2. Data Quality & Cleaning

The collected data was reviewed for completeness, consistency, duplicates, invalid values, and other data-quality issues. The dataset was then cleaned and prepared for analysis, with decisions and changes documented in a [**cleaning log**](https://sharonnyabuto.com/Data%20Cleaning%20&%20Quality%20Assurance%20Log.pdf).


### 3. Data Analysis

The cleaned dataset was analysed using **PostgreSQL/SQL**, including the construction of household-level indicators and aggregation of results for comparison across counties and population groups.

A **Multidimensional Vulnerability Index (MVI)** was developed by bringing together indicators across several dimensions of household wellbeing. This provided a broader assessment of vulnerability than looking at individual indicators in isolation.

### 4. Dashboard & Visualisation

The results were developed into an interactive **Power BI dashboard**, allowing users to explore key household and county-level patterns across the different dimensions of the survey.

**View the Power BI dashboard:** [Household Survey Dashboard](https://sharonnyabuto.com/dashboard)

### 5. Findings & Recommendations

The analysis was consolidated into a final **findings and recommendations report**, highlighting the main patterns identified in the data and their implications for programme planning and decision-making.

**Final report:** [Findings and Recommendations Report](https://sharonnyabuto.com/Kenya_HH_Survey_Findings%20Report.pdf)

## Tools

**KoboToolbox** - survey design and data collection  
**PostgreSQL / SQL** - data cleaning, transformation and analysis  
**Excel** - data review and supporting analysis  
**Power BI** - data modelling, analysis and interactive visualisation

## Project Documentation

The complete project documentation, including the survey tool, analysis plan, data-quality and cleaning documentation, datasets, SQL analysis, dashboard, and final report, is available here [Kenya Household Survey Analysis](https://sharonnyabuto.com/dashboard)
