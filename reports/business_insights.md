\# Business Insights



Source: UCI Online Retail dataset, a UK-based online gift retailer, covering 2010-12-01 to 2011-12-09, cleaned to 531,170 rows.



All figures are in GBP. Queries are available in `sql/03\_sales\_analysis.sql`.



\## Headline Numbers



| Metric | Value |

|---|---:|

| Gross revenue | 10,246,269 |

| Cancelled value | 475,901 (4.6% of gross) |

| Net revenue | 9,770,368 |

| Orders | 19,773 |

| Average order value | 518 |

| Identified customers | 4,362 |

| Repeat customer rate | 65.3% |



\## 1. Revenue Is Strongly Seasonal



September to November 2011 generated 3.58M, accounting for 35% of the year's gross revenue. November was the peak month at 1.45M, up 31.6% compared with October.



From January to August 2011, monthly revenue ranged between 508K and 740K without a clear trend. January also included an order worth approximately 77K for storage jars that was cancelled in the same month.



December 2011 appears to show a sharp decline of 57.7%, but this is due to incomplete data, as the dataset ends on December 9.



\*\*Action:\*\* Plan inventory and marketing activities around the September to November peak. Use quieter months for clearance sales and wholesale promotions.



\## 2. Trading Follows a Business-Day Pattern



Thursday generated 2.13M in revenue and Tuesday generated 2.08M. Together, these two days accounted for 41% of revenue. Sunday was the weakest day, generating 0.80M. No Saturday transactions appear in the dataset.



Approximately 74% of revenue was generated between 10:00 and 15:59. Very little activity occurred before 08:00 or after 18:00.



\*\*Action:\*\* Schedule email campaigns and promotions for Tuesday to Thursday mornings. Investigate the absence of Saturday transactions to determine whether it reflects a B2B-focused customer base or a data collection or operational limitation.



\## 3. Revenue Depends Heavily on the UK Market



The UK accounted for 85.1% of revenue. The next largest markets were the Netherlands at 2.8%, Ireland at 2.6%, Germany at 2.0%, France at 1.8%, and Australia at 1.4%.



The Netherlands generated 284K from 9 customers, while Ireland generated 271K from just 3 customers. This suggests that a small number of wholesale accounts drive revenue in these markets. Germany and France each have approximately 90 customers, providing a more diversified customer base.



\*\*Action:\*\* Maintain strong relationships with major export accounts in the Netherlands and Ireland. Prioritize Germany and France for broader customer acquisition and international growth.



\## 4. Revenue Is Concentrated Among a Small Group of Customers



The top 20% of customers generated 73.7% of net revenue, while the bottom 40% contributed only 5.2%.



The RFM analysis uses fixed thresholds for recency of 30, 90, 180, and 270 days, and purchase frequency of 1, 2, 3 to 4, 5 to 9, and 10 or more orders.



Champions represent 1,030 customers, or approximately 24% of the 4,320 scored customers. They generated 71.2% of net revenue, averaging 11.3 orders per customer. Their most recent purchase occurred approximately 21 days before the end of the dataset.



The At Risk segment contains 134 customers who averaged 5.2 orders but had not purchased for approximately 190 days. Despite their inactivity, they contributed 264K in net revenue, equivalent to 3.2%.



The Lost segment contains 775 customers who had not purchased for approximately 274 days and averaged 1.2 orders. They contributed 3.5% of net revenue.



The New / Promising segment contains 1,157 customers who averaged 1.4 orders and contributed 7.2% of net revenue. These customers represent an opportunity to encourage a second purchase.



| Segment | Customers | Avg recency (days) | Avg orders | Net revenue | Share |

|---|---:|---:|---:|---:|---:|

| Champions | 1,030 | 21 | 11.3 | 5,891,118 | 71.2% |

| Loyal | 834 | 50 | 3.5 | 1,037,430 | 12.5% |

| New / Promising | 1,157 | 41 | 1.4 | 595,705 | 7.2% |

| Lost | 775 | 274 | 1.2 | 290,418 | 3.5% |

| At Risk (was loyal) | 134 | 190 | 5.2 | 263,943 | 3.2% |

| Needs Attention | 390 | 137 | 1.4 | 190,470 | 2.3% |



\*\*Action:\*\* Reward Champions with early access and volume pricing. Contact the 134 At Risk customers directly, as they have demonstrated established purchasing behavior. Offer second-purchase incentives to New / Promising customers.



\## 5. Retention Is Reasonable but Lower Among Newer Cohorts



The December 2010 cohort shows relatively strong retention. Between 32% and 40% of its 884 customers remained active in subsequent months, reaching 50% in November 2011.



Cohorts acquired between January and October 2011 showed lower month-one retention, ranging from 15% to 24%.



The November 2011 cohort recorded 11% month-one retention. However, December data covers only nine days, meaning this figure and the final observed month for other cohorts are understated.



\*\*Action:\*\* Use the behavior of early customers to understand what drives long-term loyalty. Introduce onboarding campaigns and second-purchase offers for customers acquired during the peak season to improve retention.



\## 6. Cancellations Are Frequent, with Some Exceptionally Large Orders



Approximately 14.8% of invoices were cancellations, representing 3,422 of 23,195 invoices. The monthly cancellation rate remained relatively stable, ranging from 12.6% to 18.6%.



Two products appear to be best sellers based on gross sales but generate misleading results after cancellations are considered.



\- Paper Craft, Little Birdie: 80,995 units sold and 80,995 units cancelled, resulting in zero net units.

\- Medium Ceramic Top Storage Jar: 78,033 units sold and 74,494 units cancelled.



Product rankings based on gross sales would therefore be misleading. This project uses net revenue for product and customer rankings.



December recorded approximately 174K in cancelled value, almost entirely attributable to a single Paper Craft cancellation.



The leading products by net revenue were Regency Cakestand 3 Tier at 164K, White Hanging Heart T-Light Holder at 100K, Party Bunting at 98K, and Jumbo Bag Red Retrospot at 92K.



\*\*Action:\*\* Introduce an approval process or deposit requirement for exceptionally large orders before fulfilment. This could reduce the risk of allocating inventory to orders that are subsequently cancelled.



\## Data Caveats



\- Monthly figures are based on gross sales. Several large orders were cancelled shortly after being placed, including approximately 168K in December 2011 and 77K in January 2011. Gross revenue and average order value for these months are therefore overstated. December's average order value was 753, compared with a typical range of 420 to 620. Monthly net revenue accounts for cancellations.

\- Approximately 24.8% of rows, or 131,516 records, have no `customer\_id`. These records are included in revenue calculations but excluded from customer analyses, including RFM segmentation, cohort analysis, and repeat purchase rate.

\- Non-product lines, including postage, bank charges, manual adjustments, and vouchers, as well as rows with prices less than or equal to zero, were removed. Consequently, the revenue figures are lower than the total reported in the raw dataset.

\- RFM thresholds are based on business-defined rules. Different cut-offs, such as a 60-day recency threshold for Champions, would change customer segment assignments.

\- The dataset covers approximately one year. Seasonality patterns should be validated using multiple years of data before being treated as consistent long-term trends.

