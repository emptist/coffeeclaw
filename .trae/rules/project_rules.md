# Project Rules for CoffeeClaw

## Git Commit Discipline

**CRITICAL: Commit early, commit often.**

- Each logical unit of work = 1 commit
- Commit after:
  - Adding a new function
  - Adding a UI element
  - Fixing a bug
  - Before moving to the next feature
- Test after each commit
- Never mix multiple features in one commit
- Large commits cause:
  - Hard to isolate bugs
  - Can't easily revert specific changes
  - Cherry-pick conflicts when code diverges
  - Mixed concerns (encryption + features + UI)

## Development Workflow

1. Make one small change
2. Test the change
3. Commit with clear message
4. Repeat

## Code Style

- Use English in code and comments
- Use CoffeeScript for main process
- Follow existing patterns in the codebase
- Keep functions small and focused
