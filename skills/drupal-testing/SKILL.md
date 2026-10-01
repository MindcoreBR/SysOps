---
name: drupal-testing-and-ci
description: Design, run, and diagnose Drupal PHP lint, PHPCS, PHPUnit, kernel, functional, and CI checks without overstating test coverage.
---

# Drupal testing and CI

Use this skill when adding tests, changing CI, or diagnosing Drupal test
failures. First read the project's test configuration and existing CI workflow;
the repository's commands take precedence over generic examples.

## Choose the right test

- Use unit tests for isolated logic with mocked collaborators.
- Use kernel tests when Drupal services, entities, schemas, or database behavior
  are part of the contract.
- Use functional tests for routes, forms, permissions, and rendered behavior.
- Use a focused smoke test for a deployment or integration boundary, and keep
  external services replaceable in local and CI runs.

## Run checks in a useful order

1. Lint changed PHP files.
2. Run the smallest relevant PHPUnit test class or suite.
3. Run PHPCS with the project's configured standard.
4. Run broader unit, kernel, and functional suites that the environment supports.
5. Check generated logs for secrets, personal data, or production records before
   making them CI artifacts.

Do not add arbitrary sleeps to make tests pass. Use deterministic fixtures,
explicit service boundaries, and Drupal's test APIs. Tests must clean up their
own state and must not depend on production services.

## Diagnose before changing

- Preserve the first failure and relevant command output.
- Separate environment failures (missing extensions, services, or credentials)
  from assertion failures.
- Reproduce the narrow failing test before changing production code.
- Do not weaken assertions, skip tests, or change CI permissions to hide a
  failure.
- If a check cannot run, state the missing prerequisite and leave the result
  unverified.

## CI hygiene

- Run checks on pull requests and the protected default branch.
- Grant the workflow the minimum permissions it needs.
- Pin or review action versions according to the repository's maintenance
  policy.
- Keep credentials in secret storage and provide test-only values to CI.
- Make required checks fail clearly when required tools or test configuration
  are missing; optional examples must say when a check was skipped.
