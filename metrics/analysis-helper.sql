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
 * Data Analysis Helper Queries
 * 
 * This file contains queries to help validate and improve metric estimates.
 * These are NOT production metrics, but tools for data analysis.
 */

-- =============================================================================
-- Query 1: Auto-Approve Time Analysis
-- Purpose: Compare time-to-merge for different approval types
-- =============================================================================
/*
SELECT 
    DATE_TRUNC(DATE(timestamp, "America/Los_Angeles"), MONTH) as month,
    COUNT(jsonPayload.count) as auto_approvals,
    'auto_approve' as source
FROM `repo-automation-bots.automation_metrics.cloudfunctions_googleapis_com_cloud_functions`
WHERE resource.labels.function_name = "auto_approve"
    AND jsonPayload.event = "auto_approve.approved_tagged"
GROUP BY month
ORDER BY month DESC;

-- TODO: Enhance this query to join with GitHub data to calculate actual
-- time from approval to merge, broken down by:
-- - PR author (bot vs human)
-- - PR size (lines changed)
-- - Repository type
*/

-- =============================================================================
-- Query 2: Generated Files Bot Effectiveness
-- Purpose: Analyze if users are modifying the correct files after warnings
-- =============================================================================
/*
SELECT 
    DATE_TRUNC(DATE(timestamp, "America/Los_Angeles"), MONTH) as month,
    COUNT(jsonPayload.count) as warnings_issued,
    'generated_files' as bot
FROM `repo-automation-bots.automation_metrics.cloudfunctions_googleapis_com_cloud_functions`
WHERE resource.labels.function_name = "generated_files_bot"
    AND jsonPayload.event = "generated_files_bot.detected_modified_templated_files"
GROUP BY month
ORDER BY month DESC;

-- TODO: Track follow-up actions:
-- - Did the PR get updated after the warning?
-- - Were the correct (non-generated) files modified?
-- - Was the PR eventually merged or closed?
*/

-- =============================================================================
-- Query 3: Metric Confidence Score
-- Purpose: Identify which metrics need the most attention
-- =============================================================================
/*
This is a manual assessment based on the README.md documentation.
Metrics needing improvement (in priority order):

1. AUTO-APPROVE (Current: 4.3 min, Confidence: LOW)
   - Using proxy estimate from merge-on-green
   - Needs dedicated user survey
   - High volume → high impact potential

2. GENERATED-FILES-BOT (Current: 1 min, Confidence: LOW)
   - Conservative lower-bound estimate
   - No validation data available
   - Moderate volume → moderate impact

3. MERGE-ON-GREEN (Current: 4.3 min, Confidence: HIGH)
   - Based on user survey
   - Well-established estimate
   - Consider re-validation every 2 years

4. RELEASE-PLEASE (Current: 13.8 min, Confidence: HIGH)
   - Based on user survey
   - Well-established estimate
   - Consider re-validation every 2 years

5. OWL-BOT (Current: 3.5 min, Confidence: HIGH)
   - Based on Yoshi team survey
   - Well-established estimate
   - Consider re-validation every 2 years
*/

-- =============================================================================
-- Query 4: Volume Analysis for Impact Prioritization
-- Purpose: Identify which metrics affect the most events (for prioritization)
-- =============================================================================
SELECT 
    resource.labels.function_name as bot,
    jsonPayload.event as event_type,
    COUNT(*) as event_count,
    DATE_TRUNC(DATE(timestamp, "America/Los_Angeles"), YEAR) as year
FROM `repo-automation-bots.automation_metrics.cloudfunctions_googleapis_com_cloud_functions`
WHERE jsonPayload.type = "metric"
    AND DATE(timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 365 DAY)
GROUP BY bot, event_type, year
ORDER BY event_count DESC
LIMIT 20;

-- Use this to determine which metrics to prioritize for improvement.
-- High-volume metrics with low confidence should be addressed first.

-- =============================================================================
-- Query 5: Monthly Trend Analysis
-- Purpose: Identify unusual patterns that might indicate data quality issues
-- =============================================================================
SELECT 
    DATE_TRUNC(DATE(timestamp, "America/Los_Angeles"), MONTH) as month,
    resource.labels.function_name as bot,
    COUNT(*) as event_count
FROM `repo-automation-bots.automation_metrics.cloudfunctions_googleapis_com_cloud_functions`
WHERE jsonPayload.type = "metric"
    AND DATE(timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 730 DAY)
GROUP BY month, bot
ORDER BY bot, month;

-- Look for:
-- - Sudden drops to zero (missing data)
-- - Unexpected spikes (duplicate data or events)
-- - Gradual trends (normal growth or decline)

-- =============================================================================
-- Query 6: Cross-Bot Correlation
-- Purpose: Understand relationships between different bot activities
-- =============================================================================
/*
SELECT 
    month,
    SUM(CASE WHEN bot = 'auto_approve' THEN events ELSE 0 END) as auto_approve,
    SUM(CASE WHEN bot = 'merge_on_green' THEN events ELSE 0 END) as merge_on_green,
    SUM(CASE WHEN bot = 'release_please' THEN events ELSE 0 END) as release_please
FROM (
    SELECT 
        DATE_TRUNC(DATE(timestamp, "America/Los_Angeles"), MONTH) as month,
        resource.labels.function_name as bot,
        COUNT(*) as events
    FROM `repo-automation-bots.automation_metrics.cloudfunctions_googleapis_com_cloud_functions`
    WHERE jsonPayload.type = "metric"
    GROUP BY month, bot
)
GROUP BY month
ORDER BY month DESC;

-- Use this to understand if bots are often used together
-- (e.g., auto-approve → merge-on-green pipeline)
*/

-- =============================================================================
-- Data Collection Recommendations
-- =============================================================================
/*
To improve metric accuracy, consider collecting additional data points:

1. For AUTO-APPROVE:
   - Timestamp when approval happens
   - Timestamp when merge happens
   - Whether the PR was auto-merged or manually merged after approval
   - PR metadata: size, author, repository

2. For GENERATED-FILES-BOT:
   - Whether the PR was updated after the warning
   - Which files were modified in subsequent commits
   - Final PR outcome (merged, closed, abandoned)
   - Optional user feedback link click tracking

3. For all metrics:
   - User satisfaction scores (optional survey)
   - Error rates (false positives, missed cases)
   - Time of day patterns (affects perceived time savings)
   - Repository characteristics (size, activity level, team size)

See metrics/README.md for implementation guidance.
*/
