<!--
For Work In Progress Pull Requests, please use the Draft PR feature.
To tick checkboxes put an `x` in the `[ ]`

IMPORTANT: Ensure your PR title follows Conventional Commits format for automated releases:
- feat: description (new features)
- fix: description (bug fixes)
- security: description (security fixes)
- refactor: description (code refactoring)
- perf: description (performance improvements)
- docs: description (documentation)
- test: description (tests)
- chore: description (maintenance)

For breaking changes, add ! after type: feat!: description
-->

# What type of PR is this? (tick all applicable)

- [ ] ✨ Feature (`feat:`)
- [ ] 🐛 Bug Fix (`fix:`)
- [ ] 🔒 Security Fix (`security:`)
- [ ] ♻️ Refactor (`refactor:`)
- [ ] ⚡ Performance (`perf:`)
- [ ] 📝 Documentation Update (`docs:`)
- [ ] 🧪 Test Update (`test:`)
- [ ] 🔧 Chore/Maintenance (`chore:`)
- [ ] 💥 Breaking Change (add `!` after type)
- [ ] 🚀 Release (automated by release-please)

## Description

_Please replace this line with a description of your changes._

## Related Tickets & Documents

<!--
Include a Microsoft Planner Ticket or GitHub issue number
-->

- Microsoft Planner ticket #
- Related documentation (e.g. Confluence) #

## How to test this pull request (PR)

_Please replace this line with instructions on how to test your changes. Testing should be conducted
by the PR raiser. Where possible the approver should verify the changes._

## Run pre-commit hooks?

- [ ] Yes
- [ ] No, and this is why: _please replace this text with why you haven't_

## Added/updated tests?

_We encourage you to keep the code coverage percentage at 80% and above (for supported languages)._

- [ ] Yes
- [ ] No, and this is why: _please replace this text with details on why tests
      have not been included_

## Conventional Commit Title

<!--
Your PR title will be used in the automated changelog. Please ensure it follows the format:
<type>[optional scope]: <description>

Examples:
- feat: add batch upgrade capability
- fix: resolve instance state validation error
- security: update dependencies to patch CVE-2026-1234
- docs: improve authentication setup guide

For breaking changes:
- feat!: change upgrade API signature
-->

**Suggested PR Title:**
```
<type>: <description>
```

## Notes

- The PR raiser is expected to perform the Git merge.
- This PR will be included in the next automated release via release-please.
