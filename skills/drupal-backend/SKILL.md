---
name: drupal-backend-engineering
description: Implement or review Drupal custom modules and backend features using the host project's conventions, APIs, access rules, cache metadata, and tests.
---

# Drupal backend engineering

Use this skill when implementing or reviewing Drupal custom code. Treat the
repository as the authority for supported Drupal and PHP versions, architecture,
and validation commands.

## Before changing code

1. Read the repository's `AGENTS.md`, contribution guidance, `composer.json`, and
   relevant module documentation.
2. Inspect nearby code and tests. Follow established services, plugins,
   configuration, and naming patterns unless there is a concrete reason to
   change them.
3. Confirm the supported core and PHP versions from project metadata. Do not
   introduce APIs or syntax that exceed those constraints.
4. Trace the full behavior: route, access, validation, persistence, cache
   invalidation, translation, and user-facing output.

## Implementation rules

- Use dependency injection for services. Avoid new calls to the global service
  container in application code.
- Define explicit permissions and access checks for routes, entities, forms,
  and operations that expose or change data.
- Preserve cache contexts, tags, and max-age when rendering or returning
  cacheable data. Invalidate the narrowest relevant tags after writes.
- Add configuration schema for new configuration and configuration entities.
- Make user-visible strings translatable and respect language negotiation.
- Validate input at the boundary and use Drupal APIs for database queries,
  entity access, and output escaping.
- Keep hooks, plugins, services, and controllers small and aligned with their
  Drupal extension points. Add a dependency only when the feature needs it.
- Do not silently change existing behavior, data formats, permissions, or
  update paths. Provide an update hook when stored data or configuration needs
  migration.

## Verification and reporting

- Run the narrowest relevant test first, then the repository's required lint,
  coding-standard, and test commands.
- Review the final diff for access-control gaps, cacheability, schema changes,
  translation, and accidental unrelated edits.
- Report the files changed and the exact checks run. Name checks that were
  unavailable or skipped; do not imply they passed.
