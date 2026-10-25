# BDR-005: Spend alerts fire before the budget is exceeded

## Status

Accepted

## Behavior

The account's on-call channel receives an alert when forecasted spend is likely to cross the monthly budget, and again when actual spend crosses it.

## Context

An unmonitored account can run for weeks before anyone notices. Forecasted alerts give time to act; actual alerts confirm the overrun.

## Acceptance Criteria

- A monthly cost budget exists with the configured limit.
- A forecasted alert fires at 80% of the limit.
- An actual alert fires at 100% of the limit.
- Alerts are delivered to an SNS topic that reaches the on-call channel.

## Verification

### Scenario: Forecast crosses the threshold

- **Given** spend trending above the budget
- **When** the forecast exceeds 80% of the limit
- **Then** the SNS topic publishes one alert and the subscribed address receives it

### Scenario: Actual spend crosses the limit

- **Given** actual spend above the budget
- **When** the budget is evaluated
- **Then** the 100% actual notification fires
