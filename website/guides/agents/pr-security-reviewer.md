`pr-security-reviewer` reviews a pull request, or the current branch, for security
problems before it merges. It works out which files changed, runs the Vulnetix
scanners that apply to them in parallel, checks every newly added direct
dependency with the [`dependency-choice`]({{< relref "/docs/skills/dependency-choice" >}})
skill, and writes one review with an APPROVE or REQUEST_CHANGES verdict at the
top. With your confirmation it posts that review to the pull request with `gh`.

## When it runs

It is a Claude Code subagent. Claude Code picks a subagent from its
description, so it is chosen when you ask for something that description
covers: reviewing a high-stakes pull request, gating a release branch,
producing one review comment for a PR, or running all the scanners as one
review. You can also name it: *use the pr-security-reviewer agent on PR 142*.

The definition also carries `triggers` (`pr review`, `security review`,
`pre-merge gate`), `chain` (`code-review-security`, `verify-fix`),
`outputBudget` and `cooldown` keys. Nothing in the plugin reads these today, so
they do not start the agent or run anything after it. There is no
`code-review-security` skill.

The agent ships in the Claude Code plugin (`/plugin install
vulnetix@vulnetix-plugins`; see [Install]({{< relref "/docs/install" >}})).
Registry installs (`gh skill install`, `npx skills add`) copy skills only.

## Inputs

| Input | Effect |
| --- | --- |
| A pull request number (`--pr <num>`) | With `gh` available, the changed files come from `gh pr diff <num> --name-only`, and the review can be posted to that pull request. |
| `BASE` | Without a pull request number, the changed files come from `git diff --name-only "${BASE:-origin/main}"...HEAD`. Set `BASE` to compare against another branch. |
| `.vulnetix/capabilities.yaml` | Read first. It says whether `gh` is available (`binaries.gh`), which decides between the two ways of finding the diff. See [capabilities.yaml]({{< relref "/docs/data-structures/capabilities-yaml" >}}). |

## What it does

1. **Scope.** It lists the changed files and sorts them into source code,
   manifests, Dockerfiles and Containerfiles, Terraform and OpenTofu files, and
   files that often hold secrets (Helm values, YAML, env files).
2. **Scan.** It starts only the scanners whose category changed, all at once,
   and writes their output under `.vulnetix/review/`:

   | Scanner | Runs when | Output |
   | --- | --- | --- |
   | SAST, `vulnetix scan --evaluate-sast` | source code changed | `sast.sarif` |
   | SCA, `vulnetix scan --evaluate-sca` | a manifest changed | `sca.json` |
   | Secrets, `vulnetix scan --evaluate-secrets` | always | `secrets.json` |
   | Containers, `vulnetix containers` | a Dockerfile or Containerfile changed | `containers.json` |
   | IaC, `vulnetix iac` | a Terraform or OpenTofu file changed | `iac.json` |
   | Licences, `vulnetix license -o json-spdx` | a manifest changed | `licenses.json` |

   A category with no changed files contributes nothing.
3. **Check new dependencies.** For each direct dependency the diff adds, it
   runs `dependency-choice <package>` and collects the verdicts. Dependencies
   that were already there are not checked again.
4. **Write the review.** A Markdown review with one section per scanner and a
   findings table of at most 50 rows, sorted by severity and by where the
   finding sits.
5. **Post, if you agree.** Given a pull request number and a working `gh`, it
   asks before posting, then runs:

   ```bash
   gh pr review "$PR" --comment --body-file .vulnetix/review/${TIMESTAMP}.summary.md
   ```

   It never posts without asking.
6. **Record.** It writes one `event: pr-security-review` entry with the summary
   counts to `.vulnetix/memory.yaml`. It does not change decisions already
   recorded there for individual vulnerabilities.

## Tools and skills

- **Tools.** The definition lists `Bash`, `Read`, `Glob`, `Grep`, `Edit` and
  `Write`. `Bash` runs the scanners, `git` and `gh`; `Write` saves the review.
- **Skills.** [`dependency-choice`]({{< relref "/docs/skills/dependency-choice" >}})
  for each new direct dependency.
- **Model.** `sonnet`, with medium effort and at most 18 turns.
- **Programs.** The Vulnetix CLI, `git`, and optionally `gh`, logged in
  (`gh auth status`), for pull request scope and posting.

## Output

The verdict comes first:

- **APPROVE**: no critical or high blockers.
- **REQUEST_CHANGES**: at least one blocker, which is a critical or high
  finding, a BLOCK from the dependency check, or a new secret.

Then a section per scanner that ran and the findings table. The scanner output
stays in `.vulnetix/review/`, and the review posted to GitHub is
`.vulnetix/review/<timestamp>.summary.md`. In CI, treat REQUEST_CHANGES as the
failing gate.

## Vulnetix data in the review

The SAST, secrets, container and IaC scanners run locally on the CLI's rules.
The Vulnetix vulnerability database (VDB) comes in through two routes:

- **SCA** matches the packages in the changed manifests against the VDB, so
  dependency findings carry the VDB's advisories and severities.
- **`dependency-choice`** looks each new package up with `vulnetix vdb packages
  search`, `vulnetix vdb packages get` (health, end of life, scorecard) and
  `vulnetix vdb package-vulns` (advisory history), which is what its verdict on
  the package rests on.

## Plans and limits

- **It works on every plan, including Community.** The verdict rests on
  severities, secrets and the dependency check, none of which needs a paid
  plan.
- **VDB lookups count against your daily limit.** The SCA scan and each
  `dependency-choice` lookup are API queries. The Community plan's default is
  50 a day, so a pull request that adds several dependencies uses a visible
  share of it. See [rate limiting](https://docs.cli.vulnetix.com/docs/cli-reference/vdb/#rate-limiting).
- **Without a credential** the CLI runs on its built-in Community key: reads
  work, the daily limit is shared with everyone else on that key, and scans
  produce no stored snapshot. A free key of your own:
  [vulnetix.com/resolve/register](https://www.vulnetix.com/resolve/register),
  then `vulnetix auth login`.
- **The agent's own turns are model usage**, billed by whoever bills your
  Claude Code usage.

## Example

```
> Use the pr-security-reviewer agent on PR 142.
```

On a pull request that changes `api/handlers.go`, `package.json` and a
Dockerfile, the agent runs SAST, SCA, secrets, containers and licences (no IaC,
since no Terraform changed), checks the one dependency the PR adds, and replies
with a review shaped like this:

```markdown
**Verdict: REQUEST_CHANGES**

1 blocker: a high-severity SQL injection finding in api/handlers.go.

| Severity | Scanner | Location | Finding |
| --- | --- | --- | --- |
| High | SAST | api/handlers.go:57 | query built by string concatenation from a request parameter |
| Medium | Containers | Dockerfile:1 | base image runs as root |
| Low | Licences | package.json | new dependency is MPL-2.0 |
```

It then asks whether to post the review to PR 142.

## Limitations

- **The scans cover the project, not only the diff.** The definition passes
  the changed paths with `--paths`. In the current CLI, `--paths` is a hidden,
  deprecated alias for `--show-introduced-paths`, not a list of paths, so the
  scanners scan the project and the review can include findings in files the
  pull request did not touch.
- The slowest scanner sets the wall-clock time, usually SAST on a large
  repository.
- Pull request scope needs `binaries.gh: true` and a valid `gh auth status`.
  Without them the agent compares against `origin/main` (or `BASE`).
