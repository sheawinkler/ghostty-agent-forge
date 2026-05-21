# Repo Governance

Recommended GitHub settings for this repo:

- default branch: `main`
- delete branch on merge: enabled
- squash merge: enabled
- merge commits: optional
- rebase merge: optional
- force pushes to `main`: disabled
- branch deletion on `main`: disabled
- direct pushes to `main`: restricted to the owner/admin account or blocked by a ruleset

## PR Approval Reality

GitHub does not treat a pull request author's own review as an approval. The practical solo-admin setup is:

- require pull requests for normal changes
- allow repository admin bypass
- restrict who can push or bypass to the owner account

That gives the owner/admin account final control without pretending self-review is a GitHub approval.

## Local Release Gate

Before merging:

```zsh
tests/smoke.zsh
git diff --check
```

After merging:

```zsh
git checkout main
git pull --ff-only origin main
git status --short
git rev-parse HEAD
git rev-parse origin/main
```
