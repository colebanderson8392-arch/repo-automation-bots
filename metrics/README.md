# Metrics Documentation

This directory contains SQL queries used to measure the impact and effectiveness of various automation bots in the repository. These metrics help quantify time savings and automation benefits across the Google GitHub organization.

## Overview

The metrics track various automation activities including:
- Pull request approvals (auto-approve)
- Automated merging (merge-on-green)
- Release automation (release-please)
- Trusted contribution labeling
- Generated files detection
- Label-based metrics (OwlBot)

## Time Savings Methodology

### Current Estimates

The time savings estimates are based on a combination of:
1. **User surveys**: Direct feedback from developers about time spent on tasks
2. **Industry research**: Standard estimates for common development activities
3. **Internal analysis**: Observation of workflow patterns and task completion times

### Estimate Values Used

| Bot/Activity | Time Saved (minutes) | Confidence | Source |
|-------------|---------------------|------------|--------|
| Release creation (release-please) | 13.8 | High | User survey (2020) |
| Auto-merge (merge-on-green) | 4.3 | High | User survey: time spent on non-code-review PR tasks |
| Trusted contribution labeling | 4.0 | Medium | Estimated manual CI trigger time |
| Auto-approve | 4.3 | Low | **Needs improvement** - Currently using merge-on-green estimate |
| Generated files detection | 1.0 | Low | **Needs improvement** - Rough estimate, needs validation |
| Context-aware commits (OwlBot) | 3.5 | High | Yoshi team survey |

### Recommendations for Improvement

#### 1. Auto-Approve Bot (Priority: High)
**Current Issue**: Using the same 4.3-minute estimate as merge-on-green, which may not be accurate.

**Recommended Actions**:
- Conduct a targeted survey of users whose PRs have been auto-approved
- Measure typical time from approval to merge for auto-approved vs. manually approved PRs
- Consider breaking down by PR type (dependency updates, minor fixes, etc.)

**Proposed Analysis**:
```sql
-- Compare time-to-merge for auto-approved PRs vs manual
SELECT 
  CASE WHEN auto_approved THEN 'auto' ELSE 'manual' END as approval_type,
  AVG(TIMESTAMP_DIFF(merged_at, approved_at, MINUTE)) as avg_minutes_to_merge,
  COUNT(*) as pr_count
FROM pr_events
GROUP BY approval_type;
```

#### 2. Generated Files Bot (Priority: High)
**Current Issue**: Using a conservative 1-minute estimate with no validation.

**Recommended Actions**:
- Track user behavior after generated files warning (do they modify the right files?)
- Survey users on whether the warning was helpful and time saved
- Consider A/B testing periods with/without the bot to measure impact

**Data Collection Needs**:
- Add tracking for: warning shown → correct action taken
- Add tracking for: files modified after warning vs. before warning
- Collect feedback through optional survey link in bot comments

#### 3. Data Validation Queries

Consider adding automated validation queries to ensure data quality:
- Check for outliers in time calculations
- Verify event counts match expected patterns
- Monitor for missing or duplicate events

## Query Files

### Production Metrics
- `total-people-hours.sql` - Aggregate time savings across all bots
- `auto-approve.sql` - Auto-approve bot specific metrics
- `merge-on-green-labeled.sql` - Merge-on-green labeling events
- `merge-on-green-merged.sql` - Merge-on-green merge events
- `release-please-releases.sql` - Release automation metrics

### Supporting Queries
- `github-label-metrics.sql` - Label-based event aggregation
- `owlbot-label-metrics.sql` - OwlBot specific metrics
- `legacy-dashboards.sql` - Deprecated queries (for reference only)

## Best Practices

### When Adding New Metrics

1. **Start Conservative**: Use lower-bound estimates initially
2. **Document Assumptions**: Always include comments explaining the estimate source
3. **Plan for Validation**: Include a timeline for validating estimates with real data
4. **Consider Context**: Different types of PRs/tasks may have different time savings
5. **Track Confidence**: Mark estimates as low/medium/high confidence

### When Updating Estimates

1. **Document Changes**: Note what changed and why in comments
2. **Provide Evidence**: Link to surveys, studies, or data analysis supporting the new value
3. **Gradual Updates**: Consider ramping up estimates over time as confidence increases
4. **Version History**: Keep notes on previous estimates and why they were updated

## Future Enhancements

### Recommended Additions

1. **Segmented Metrics**: Break down time savings by:
   - Repository size/type
   - Developer experience level
   - PR complexity
   - Time of day/week

2. **Quality Metrics**: Beyond time savings, track:
   - Error rates prevented
   - Security issues caught
   - Consistency improvements

3. **User Satisfaction**: Implement periodic surveys to measure:
   - Bot helpfulness ratings
   - Friction points
   - Feature requests

4. **Cost-Benefit Analysis**: Calculate:
   - Infrastructure costs of running bots
   - Development/maintenance time
   - Net value delivered

## Contact

For questions about these metrics or to propose improvements, please:
- Open an issue in this repository
- Reach out to the automation team
- Review existing discussions about metrics methodology

## References

- [User Survey Results 2020](https://internal-link) - Original time estimates
- [Bot Architecture](../architecture.png) - Overall system design
- [Contributing Guidelines](../CONTRIBUTING.md) - How to contribute improvements
