Linter results (2025-12-28)

- shellcheck: installed (v0.9.0)
  - Files checked: `deploy-clean.sh`, `deploy-marketing-clean.sh`, `deploy.sh` (wrapper)
  - Result: No critical shellcheck errors remain; a few benign warnings (unused vars, sourcing .env) are noted.

- flake8: not installable in this environment due to "externally-managed-environment" (PEP 668). Python static checks performed via `python -m compileall` succeeded (all Python files compile).

Notes & Recommendations:
- I created `deploy-clean.sh` and `deploy-marketing-clean.sh` as safe, cleaned versions. They are executable and pass `shellcheck`.
- The original `deploy-full.sh` and `deploy-marketing-full.sh` are preserved as raw copies; they still contain garbled / odd characters and need careful manual cleanup if you want to use them directly.
- Next step: I can proceed with a thorough manual cleanup of `deploy-full.sh` and `deploy-marketing-full.sh` (replace corrupted sections with cleaned versions) if you approve.

If you'd like, I can also try installing `flake8` in a virtualenv or using `pipx` and run the full Python linting pass.