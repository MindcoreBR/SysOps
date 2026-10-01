# Drupal CI and deployment notes

The example at `examples/github-actions/drupal-ci.yml.example` is a starting
point for a Composer-based Drupal project. Adjust the PHP version, document
root, coding-standard paths, PHPUnit configuration, and test prerequisites to
match the project. Keep the example outside `.github/workflows` so GitHub does
not run it before it has been reviewed and adapted.

## CI checks

Prefer fast, deterministic checks on every pull request:

1. Validate `composer.json` and install the locked dependencies.
2. Run PHP syntax checks for custom code.
3. Run the project's configured PHPCS standard.
4. Run PHPUnit unit tests; add kernel or functional tests only when the required
   database and Drupal test environment are configured.
5. Upload useful test logs when a job fails, without including secrets or
   production data.

Use the repository's own `composer.json`, `phpcs.xml*`, `phpunit.xml*`, and
Makefile as the source of truth. Do not report a check as passing if it was
skipped or could not run.

## CD controls

Deployment examples should be project-specific and reviewed before use. A safe
baseline is to deploy a known commit to staging, run health checks, then promote
that same artifact to production through an explicit protected environment.

- Store credentials in GitHub Actions secrets or an external secret manager;
  grant each workflow only the permissions it needs.
- Use protected environments and required reviewers for production.
- Keep runtime configuration, uploads, and secrets outside the release artifact.
- Make a fresh, verified backup before database updates that can change data.
- Keep releases rollback-capable and define how schema changes can be recovered.
- Run Drush updates and cache rebuilds only through a reviewed deployment
  procedure with a clear failure path.
- Never copy a project's hostnames, SSH targets, filesystem paths, or tokens
  into a generic public template.

The deployment workflows in the source projects are tied to their own hosting
and should be treated as design references, not copied into another site.
