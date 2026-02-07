# Contributing

Thanks for wanting to improve the agent context system. This is a template project, so contributions should make the template more useful for everyone who forks it.

## What to contribute

- **Script improvements** — Make `promote.sh`, `compress.sh`, `validate.sh`, or `init-agent-context.sh` more robust
- **Better placeholder examples** — The template files ship with Next.js/Prisma examples; examples for other stacks help users understand the format
- **Documentation** — Clearer explanations, additional research findings, better quick-start guides
- **Bug fixes** — Anything that breaks on common shells, OS configurations, or edge cases

## How to contribute

1. Fork the repo
2. Create a branch (`git checkout -b improve-promote-script`)
3. Make your changes
4. Run the tests: `./tests/run-tests.sh`
5. If you changed scripts, add test cases for your changes
6. Submit a pull request with a clear description of what changed and why

## Running tests

```bash
./tests/run-tests.sh
```

Tests create temporary git repos, exercise each script, and clean up after themselves. All tests should pass before submitting a PR.

## Validating placeholders

After editing `AGENTS.md` or `agent_docs/`, run:

```bash
./scripts/validate.sh
```

This checks for remaining template placeholders. The template files are expected to have placeholders (that's the point), but if you're testing with a "filled-in" version, validation should pass.

## Guidelines

- Keep `AGENTS.md` under 120 lines. The instruction budget constraint is a feature.
- Scripts should work on macOS and Linux with bash 4+. Avoid bashisms that break on older shells where possible.
- No external dependencies. The template works with just bash and standard Unix tools.
- Test your changes against the edge cases they're meant to handle.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
