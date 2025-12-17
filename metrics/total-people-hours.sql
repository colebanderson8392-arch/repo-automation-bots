/**
 * Copyright 2021 Google LLC. All Rights Reserved.
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
SELECT SUM(people_hours) as PEOPLE_HOURS, month FROM 
((
    SELECT 
        (SUM(jsonPayload.count * 13.8)) / 60 as people_hours,
        DATE_TRUNC(DATE(timestamp, "America/Los_Angeles"), MONTH) as month
    FROM `repo-automation-bots.automation_metrics.cloudfunctions_googleapis_com_cloud_functions`
        WHERE resource.labels.function_name = "release_please"
        AND jsonPayload.type = "metric"
        AND jsonPayload.event = "release_please.release_created"
    GROUP BY month
)
UNION ALL
(
    SELECT
        (SUM(jsonPayload.count * 4.3)) / 60 as people_hours,
        DATE_TRUNC(DATE(timestamp, "America/Los_Angeles"), MONTH) as month
    FROM `repo-automation-bots.automation_metrics.cloudfunctions_googleapis_com_cloud_functions`
    WHERE resource.labels.function_name = "merge_on_green"
    AND jsonPayload.type = "metric"
    AND jsonPayload.event = "merge_on_green.merged"
    GROUP BY month
)
UNION ALL
(
    SELECT
        (SUM(jsonPayload.count * 4)) / 60 as people_hours,
        DATE_TRUNC(DATE(timestamp, "America/Los_Angeles"), MONTH) as month
    FROM `repo-automation-bots.automation_metrics.cloudfunctions_googleapis_com_cloud_functions`
        WHERE resource.labels.function_name = "trusted_contribution"
        AND jsonPayload.event = "trusted_contribution.labeled"
    GROUP BY month
)
UNION ALL
(
    SELECT
        /* 
         * NEEDS IMPROVEMENT: Using 4.3 minutes (same as merge-on-green estimate).
         * This may not accurately reflect auto-approve time savings.
         * 
         * Action items:
         * - Survey users whose PRs were auto-approved about time saved
         * - Analyze time-to-merge differences between auto-approved and manual
         * - Consider segmenting by PR type (dependency updates vs code changes)
         * 
         * See metrics/README.md for detailed improvement recommendations.
         */
        (SUM(jsonPayload.count * 4.3)) / 60 as people_hours,
        DATE_TRUNC(DATE(timestamp, "America/Los_Angeles"), MONTH) as month
    FROM `repo-automation-bots.automation_metrics.cloudfunctions_googleapis_com_cloud_functions`
        WHERE resource.labels.function_name = "auto_approve"
        AND jsonPayload.event = "auto_approve.approved_tagged"
    GROUP BY month
)
UNION ALL
(
    SELECT
        /* 
         * NEEDS IMPROVEMENT: Conservative 1-minute estimate for generated file warnings.
         * This is a lower-bound guess and likely underestimates actual value.
         * 
         * Action items:
         * - Conduct user survey about helpfulness and actual time saved
         * - Track if users modify correct files after receiving warning
         * - Consider A/B testing to measure actual impact
         * - Add optional feedback mechanism in bot comments
         * 
         * See metrics/README.md for detailed improvement recommendations.
         */
        (SUM(jsonPayload.count * 1)) / 60 as people_hours,
        DATE_TRUNC(DATE(timestamp, "America/Los_Angeles"), MONTH) as month
    FROM `repo-automation-bots.automation_metrics.cloudfunctions_googleapis_com_cloud_functions`
        WHERE resource.labels.function_name = "generated_files_bot"
        AND jsonPayload.event = "generated_files_bot.detected_modified_templated_files"
    GROUP BY month
)
UNION ALL
(
    SELECT
        /*
         * Using 3.5 minutes based on 2020 Yoshi team survey for context-aware commits.
         * This estimate has high confidence as it was derived from actual user feedback.
         * 
         * Note: Consider periodic re-validation (e.g., every 2 years) to ensure
         * estimate remains accurate as workflows and tools evolve.
         */
        (SUM(prs) * 3.5) / 60 as people_hours,
        month_start as month
    FROM `repo-automation-bots.automation_metrics.github_label_metrics`
        WHERE type = "owl-bot-copy"
        OR type = "owl-bot-update-lock"
    GROUP BY month_start
))
GROUP BY month;
