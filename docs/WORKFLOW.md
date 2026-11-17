# How we build Your Personal Planet

Two people, two AI agents, one repository. **You never have to learn Git** - your agent does
the Git part. This page exists so both agents follow the same rules, and so you know what is
happening when you see it.

Board: https://github.com/users/krabikdev/projects/1

---

## 60-second version

1. You tell your agent an idea, or point it at a card on the board.
2. The agent checks the board, works in its own copy, runs the checks, and merges its work
   through a pull request.
3. You get a short summary. Nothing on your side to type.

The only thing you may run yourself is `sync` (below), and even that is optional.

---

## Setup, once per machine

**Windows**

```powershell
winget install --id GitHub.cli --exact
gh auth login
gh auth refresh -s project
winget install --id GodotEngine.GodotEngine
git clone https://github.com/krabikdev/your-personal-planet.git
cd your-personal-planet
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\setup-git.ps1
```

**Linux / macOS**

```bash
sudo apt install gh          # or: https://cli.github.com
gh auth login
gh auth refresh -s project
# install Godot 4.7 and put it on PATH as `godot`, or export GODOT=/path/to/godot
git clone https://github.com/krabikdev/your-personal-planet.git
cd your-personal-planet
./scripts/setup-git.sh
```

`gh auth refresh -s project` is what lets the board commands work. Without it, every
`gh project ...` call stops with "missing required scopes".

Then open `project.godot` in Godot once so the project is imported, and install the check tools:
`uv tool install gdtoolkit` (or `pipx install gdtoolkit`).

Ask the repository owner to invite you as a collaborator, and accept the invitation in your
email or on GitHub.

---

## The board is the shared memory

Every idea, problem, question and decision lives on the project board, **not** in chat.

**Humans** use the repo's *Issues* tab, where two forms are available:

- **Idea** - something we could add. Label `idea`.
- **Problem** - something broken or annoying. Label `problem`.

**Agents** read the board before starting anything, and write notes back. Useful commands:

```bash
# what is on the board, with fields and item ids
gh project item-list 1 --owner krabikdev --format json

# field ids (Kind, Area, Status, Claimed by)
gh project field-list 1 --owner krabikdev --format json

# who is working on what
gh issue list --state open --json number,title,labels
```

To add a card:

```bash
gh issue create --title "[Idea] Snow footprints" --label idea --body "The boy leaves prints for 3 seconds."
gh project item-add 1 --owner krabikdev --url <the issue URL printed above>
```

To show a card as taken, comment on it and fill *Claimed by* with the agent, person and machine:

```bash
gh issue comment 12 --body "Claimed by Codex on putzwirk-linux"
```

Move it to **In Progress** on the board once work starts, and to **Done** when the pull request
is merged. Record decisions as comments on the card, with a link to the pull request.

**Do not** use the board for secrets, tokens or personal data. It is public.

---

## The two commands a human may run

Windows:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\sync.ps1
```

Linux / macOS:

```bash
./scripts/sync.sh
```

This downloads your friend's latest work. It refuses to act if you have unsaved work and it
never creates a merge you have to fix by hand. `--check` / `-Check` also runs the project checks.

Everything else is the agent's job.

---

## How work reaches master

`master` is protected. Nobody pushes to it, not even the owner - GitHub rejects it.
Every change travels through a pull request:

1. agent syncs and creates `agent/<short-name>-<machine>` from the latest `master`; the machine
   suffix keeps the two agents apart even if they pick the same topic name
2. agent writes the change in small steps
3. `scripts/agent-ship.ps1` (Windows) or `./scripts/agent-ship.sh` (Linux) runs the checks,
   commits, replays the work on top of the newest `master`, pushes, opens a PR and
   squash-merges it
4. master goes back down to the agent's machine, so both copies match GitHub

One pull request = one feature. Squash merge keeps `master` a straight line of readable commits.

---

## Why two agents can work at the same time

- Every agent works on **its own branch**. Two branches never overwrite each other.
- GitHub merges **one pull request at a time**. The second one is simply replayed on top of the
  first (`git rebase`), which is what the ship script does automatically, and retries once.
- The ship script runs `scripts/check.ps1` / `scripts/check.sh` before anything is pushed, so a
  broken merge is unlikely.
- Git remembers how a conflict was solved once (`rerere`), so a repeated clash is resolved by
  itself.
- `master` cannot be force-pushed or deleted. A branch is only force-pushed with
  `--force-with-lease`, and only on the agent's own branch.

That leaves one real risk: **both agents editing the same lines of the same file**. That is a
conflict, not a disaster - the agent resolves it and tells you what it chose. To keep conflicts
rare:

### Hot files - announce before touching

These are shared and grow quickly. Say so on the board (comment on the card) before editing:

- `project.godot` - input map, autoloads, window settings
- `scenes/game.tscn` - the orchestrating scene
- `ui/main_menu.tscn`, `ui/theme/app_theme.tres` - shared UI surface
- `scripts/check.ps1` / `scripts/check.sh` - the verification pipeline
- `scripts/agent-ship.ps1` / `scripts/agent-ship.sh` - the shipping pipeline

Prefer adding a new scene or component over editing a shared one. Two small files that meet
through a signal never conflict; one big scene edited from two sides always does.

---

## When two agents collide

The ship script stops with exit code 2 and lists the files. The agent then:

1. opens each listed file and reads the `<<<<<<<`, `=======`, `>>>>>>>` blocks
2. keeps **both** intentions when possible; if they truly disagree, the earlier card on the
   board wins and the other one gets a comment explaining the decision
3. `git add <file>` then `git rebase --continue`
4. runs `scripts/check.ps1` / `scripts/check.sh` again
5. runs the ship command again

It never resolves a `.tscn` conflict by blindly taking one side: Godot scene files break silently
when nodes are dropped. The agent reopens the scene in Godot or rebuilds it.

If the mess cannot be untangled: `git rebase --abort` returns to the state before the attempt.

---

## If something goes wrong

| Situation | What to say |
| --- | --- |
| "My copy looks weird / old" | "Run the sync script and explain what changed." |
| "There is a conflict" | "Read docs/WORKFLOW.md, resolve the conflict, then ship." |
| "I want to throw away my local edits" | "Abort any rebase, then reset this clone to origin/master." |
| "A check fails" | "Fix the failing check and run it again." |
| "I do not understand a message" | "Explain this error in plain language and fix it." |

Nothing is ever lost for good: every merged change exists on GitHub, and every branch the agent
pushed is recoverable for 30 days.

---

## House rules (for agents)

- **Sync before you touch a file; ship after every green change.** No exceptions, on either
  machine. If `git status` is not clean at the end, the task is not finished.
- Read the board and the open pull requests before starting.
- Never commit or push to `master`. Use `agent-ship` or an equivalent branch + PR.
- Run the full check pipeline after every change. Do not ship red.
- Add or update a GUT test for new behaviour.
- One feature per pull request, imperative title (`feat: add snow footprints`).
- Never reformat third-party code in `addons/`.
- Never commit `.godot/`, `export_presets.cfg`, `.env`, keystores, or anything from `user://`.
- Put decisions on the card, not only in the pull request.

---

## Words you will hear

| Word | Plain meaning |
| --- | --- |
| repository / repo | the project folder on GitHub |
| clone | your own copy of it |
| commit | a saved checkpoint with a message |
| branch | a private line of work that does not affect `master` |
| master | the one true version everyone copies from |
| pull request (PR) | a proposal to put a branch into `master`, with checks |
| merge | accepting that proposal |
| rebase | replaying your work on top of the newest `master` |
| conflict | two changes touched the same lines; someone must choose |
| sync | download the newest `master` |

---

## One more thing

The owner can merge without review (solo-maintainer setup), so a wrong pull request is possible.
The safety net is the check pipeline, not human review. Keep it green.
