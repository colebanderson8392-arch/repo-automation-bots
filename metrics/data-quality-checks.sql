/**
 * Copyright 2025 Google LLC. All Rights Reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/*
 * Data Quality Validation Queries
 * 
 * These queries help identify data quality issues in automation metrics.
 * Run these periodically to ensure metrics are accurate and complete.
 */

-- =============================================================================
-- Check 1: Missing Data Detection
-- Purpose: Identify months with zero or suspiciously low activity
-- =============================================================================
/*
WITH monthly_counts AS (
  SELECT 
    DATE_TRUNC(DATE(timestamp, "America/Los_Angeles"), MONTH) as month,
    resource.labels.function_name as bot,
    COUNT(*) as event_count
  FROM `repo-automation-bots.automation_metrics.cloudfunctions_googleapis_com_cloud_functions`
  WHERE jsonPayload.type = "metric"
    AND DATE(timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 730 DAY)
  GROUP BY month, bot
),
avg_counts AS (
  SELECT 
    bot,
    AVG(event_count) as avg_events,
    STDDEV(event_count) as stddev_events
  FROM monthly_counts
  GROUP BY bot
)
SELECT 
  m.month,
  m.bot,
  m.event_count,
  a.avg_events,
  ROUND((m.event_count - a.avg_events) / NULLIF(a.stddev_events, 0), 2) as z_score
FROM monthly_counts m
JOIN avg_counts a ON m.bot = a.bot
WHERE ABS((m.event_count - a.avg_events) / NULLIF(a.stddev_events, 0)) > 2
ORDER BY ABS((m.event_count - a.avg_events) / NULLIF(a.stddev_events, 0)) DESC;

-- Flag: Z-score > 2 indicates unusual activity (too high or too low)
*/

-- =============================================================================
-- Check 2: Duplicate Event Detection
-- Purpose: Identify potential duplicate logging
-- =============================================================================
/*
SELECT 
  DATE_TRUNC(DATE(timestamp, "America/Los_Angeles"), HOUR) as hour,
  resource.labels.function_name as bot,
  jsonPayload.event as event_type,
  COUNT(*) as event_count,
  COUNT(DISTINCT jsonPayload.repo) as distinct_repos
FROM `repo-automation-bots.automation_metrics.cloudfunctions_googleapis_com_cloud_functions`
WHERE jsonPayload.type = "metric"
  AND DATE(timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
GROUP BY hour, bot, event_type
HAVING event_count > 100 AND event_count / distinct_repos > 10
ORDER BY event_count DESC;

-- Flag: High event count with low repo diversity might indicate duplicates
*/

-- =============================================================================
-- Check 3: Data Completeness Across Bots
-- Purpose: Ensure all expected bots are reporting metrics
-- =============================================================================
/*
WITH recent_bots AS (
  SELECT DISTINCT 
    resource.labels.function_name as bot,
    MAX(DATE(timestamp)) as last_seen
  FROM `repo-automation-bots.automation_metrics.cloudfunctions_googleapis_com_cloud_functions`
  WHERE jsonPayload.type = "metric"
    AND DATE(timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
  GROUP BY bot
)
SELECT 
  bot,
  last_seen,
  DATE_DIFF(CURRENT_DATE(), last_seen, DAY) as days_since_last_event
FROM recent_bots
WHERE DATE_DIFF(CURRENT_DATE(), last_seen, DAY) > 14
ORDER BY days_since_last_event DESC;

-- Flag: Bots not reporting for > 14 days may have issues
*/

-- =============================================================================
-- Check 4: Metric Value Reasonableness
-- Purpose: Identify suspiciously high or low metric counts
-- =============================================================================
/*
SELECT 
  DATE(timestamp) as date,
  resource.labels.function_name as bot,
  jsonPayload.event as event_type,
  jsonPayload.count as reported_count,
  jsonPayload.repo as repo
FROM `repo-automation-bots.automation_metrics.cloudfunctions_googleapis_com_cloud_functions`
WHERE jsonPayload.type = "metric"
  AND DATE(timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
  AND (
    jsonPayload.count < 0  -- Negative counts are invalid
    OR jsonPayload.count > 1000  -- Unusually high counts
  )
ORDER BY reported_count DESC;

-- Flag: Negative or extremely high counts need investigation
*/

-- =============================================================================
-- Check 5: Time Calculation Validation
-- Purpose: Verify people-hours calculations are reasonable
-- =============================================================================
/*
WITH monthly_hours AS (
  SELECT 
    DATE_TRUNC(DATE(timestamp, "America/Los_Angeles"), MONTH) as month,
    resource.labels.function_name as bot,
    SUM(jsonPayload.count) as total_events,
    CASE 
      WHEN resource.labels.function_name = 'release_please' THEN SUM(jsonPayload.count * 13.8) / 60
      WHEN resource.labels.function_name = 'merge_on_green' THEN SUM(jsonPayload.count * 4.3) / 60
      WHEN resource.labels.function_name = 'auto_approve' THEN SUM(jsonPayload.count * 4.3) / 60
      WHEN resource.labels.function_name = 'generated_files_bot' THEN SUM(jsonPayload.count * 1) / 60
      WHEN resource.labels.function_name = 'trusted_contribution' THEN SUM(jsonPayload.count * 4) / 60
    END as people_hours
  FROM `repo-automation-bots.automation_metrics.cloudfunctions_googleapis_com_cloud_functions`
  WHERE jsonPayload.type = "metric"
    AND DATE(timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 365 DAY)
  GROUP BY month, bot
)
SELECT 
  month,
  bot,
  total_events,
  ROUND(people_hours, 1) as people_hours,
  ROUND(people_hours / 730, 1) as people_years_equivalent
FROM monthly_hours
WHERE people_hours > 1000  -- Flag unusually high hour counts
ORDER BY people_hours DESC;

-- Flag: If saving > 1000 hours/month, verify the data and calculations
*/

-- =============================================================================
-- Check 6: Consistency Check Across Data Sources
-- Purpose: Compare metrics from logger vs GitHub Archive (when available)
-- =============================================================================
/*
-- This query would compare logged metrics with GitHub Archive data
-- to identify discrepancies. Implementation depends on having both
-- data sources available.

-- Example pattern:
WITH logged_metrics AS (
  SELECT 
    DATE_TRUNC(DATE(timestamp, "America/Los_Angeles"), MONTH) as month,
    SUM(jsonPayload.count) as logged_count
  FROM `repo-automation-bots.automation_metrics.cloudfunctions_googleapis_com_cloud_functions`
  WHERE resource.labels.function_name = "merge_on_green"
    AND jsonPayload.event = "merge_on_green.merged"
  GROUP BY month
)
-- JOIN with github_archive data here to compare
SELECT * FROM logged_metrics
ORDER BY month DESC;
*/

-- =============================================================================
-- Check 7: Repository Coverage Analysis
-- Purpose: Ensure metrics represent expected repository set
-- =============================================================================
/*
SELECT 
  DATE_TRUNC(DATE(timestamp, "America/Los_Angeles"), MONTH) as month,
  resource.labels.function_name as bot,
  COUNT(DISTINCT jsonPayload.repo) as distinct_repos,
  COUNT(*) as total_events,
  ROUND(COUNT(*) / COUNT(DISTINCT jsonPayload.repo), 1) as avg_events_per_repo
FROM `repo-automation-bots.automation_metrics.cloudfunctions_googleapis_com_cloud_functions`
WHERE jsonPayload.type = "metric"
  AND DATE(timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 180 DAY)
GROUP BY month, bot
ORDER BY month DESC, bot;

-- Monitor: Sudden changes in distinct_repos might indicate data issues
*/

-- =============================================================================
-- Recommended Monitoring Frequency
-- =============================================================================
/*
Run these checks on the following schedule:

- Check 1 (Missing Data): Weekly
- Check 2 (Duplicates): Daily
- Check 3 (Completeness): Weekly
- Check 4 (Value Reasonableness): Daily
- Check 5 (Time Calculations): Monthly
- Check 6 (Cross-source Consistency): Monthly
- Check 7 (Repository Coverage): Weekly

Set up alerts for:
- Any bot not reporting for > 14 days
- Z-scores > 3 in monthly counts
- Negative or extremely high event counts
- Total people-hours > 2000/month (potential calculation error)
*/

-- =============================================================================
-- Interpreting Results
-- =============================================================================
/*
When a check flags an issue:

1. Investigate the root cause:
   - Check bot logs for errors
   - Verify logging configuration
   - Review recent code changes

2. Assess impact:
   - How many metrics are affected?
   - What time period is impacted?
   - Do dashboards need correction?

3. Remediate:
   - Fix the underlying issue
   - Backfill missing data if possible
   - Document the incident

4. Update metrics:
   - Add notes about data quality issues
   - Adjust estimates if necessary
   - Improve monitoring to prevent recurrence
*/
