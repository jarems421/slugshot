# Shared coding conventions

- Luau uses `--!strict`, explicit public parameter/return types, tabs and StyLua. Keep names descriptive: PascalCase modules/types, camelCase functions/locals.
- Prefer small modules with explicit dependencies. Add abstractions when used, not for hypothetical mechanics. Keep startup scripts small.
- Use `game:GetService` for engine services and `WaitForChild` for objects that replicate asynchronously. Add timeouts/error handling where a future runtime requirement calls for recovery.
- Keep server-only state in server containers. Shared code and replicated assets contain no secrets. Any future client request must be validated by the server; exact protocols remain undecided.
- Separate formatting, linting, type analysis, build checks and runtime tests in reports. Selene is not a type checker; building does not execute Luau.
- Keep documents in UTF-8 Markdown. Record decision status, date, sources and verification evidence. Never record credentials.
- Use small, descriptive Git commits. Review `git diff --check` and run relevant checks before committing. Do not publish or choose repository visibility without owner approval.
