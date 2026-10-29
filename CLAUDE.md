# Agent rules for this repo

Fabric CI/CD demo. `fabric/` holds the BI items (semantic model + PBIR reports) that sync via
Git integration to the Dev workspace and are promoted by the deployment pipeline.
Lakehouses live in the separate "Oceaneering Demo Data - *" workspaces and are never in Git.

## Branches and commits

- Never commit to `main`. Work only in branches named `feature/AB<id>-<short-name>`,
  created from an up-to-date `main` (e.g. `feature/AB1002-sales-by-product`).
- Commit messages: `<Short description> #AB<id>` (e.g. `Add Sales by Product report #AB1002`).

## Scope

- Only edit files under `fabric/`.
- Never add or commit lakehouses (`*.Lakehouse` folders) or any other data items.
- Never commit Power BI Desktop local files (`.pbi/localSettings.json`, `.pbi/cache.abf`).

## Before every commit

- Validate every changed report:
  `powerbi-report-author validate "fabric/<Name>.Report"` must return `succeeded` with no errors.
- If any TMDL under `fabric/*.SemanticModel/definition/` changed, validate the model loads
  (Power BI Modeling MCP or opening the `.pbip` in Power BI Desktop) and fix all errors.

## Pull requests

- Push the branch and open a PR to `main` with `gh pr create --base main`.
- Never merge a PR. Merging is done by a human reviewer.
