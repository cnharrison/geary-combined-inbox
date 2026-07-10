# Upstream synchronization

Geary Modernized tracks GNOME Geary while preserving a small, reviewable downstream feature set. Upstream changes are merged manually so conflicts and behavior changes receive the same testing as downstream work.

## Required remotes

The local checkout uses these remotes:

- `origin`: `https://gitlab.gnome.org/GNOME/geary.git`
- `github`: `https://github.com/cnharrison/geary-modernized.git`

Verify the URLs instead of guessing or adding aliases:

```sh
test "$(git remote get-url origin)" = "https://gitlab.gnome.org/GNOME/geary.git"
test "$(git remote get-url github)" = "https://github.com/cnharrison/geary-modernized.git"
```

## Cadence

Check upstream weekly, before each release, and before starting a substantial feature. Do not open an empty sync pull request when upstream has not advanced.

```sh
git fetch origin --prune --tags
git fetch github --prune
git rev-list --left-right --count github/main...origin/main
```

The first count is downstream-only commits; the second is upstream-only commits. A zero second count means no sync is needed.

Alpha 1 was released with `origin/main` at `485aea76746e6374a24fb457867178353cf8b196`, with no upstream-only commits outstanding.

## Sync procedure

1. Start from the current downstream branch and create a dated sync branch:

   ```sh
   git switch --create sync/upstream-YYYY-MM-DD github/main
   git merge --no-ff origin/main
   ```

2. Resolve conflicts deliberately. Preserve these downstream invariants unless a separate migration has been approved:

   - All Accounts views remain virtual and never create server-side IMAP folders.
   - All remains paginated; Unread and Starred cover the complete supported scope.
   - Message actions route through each message's real account and folder.
   - Filtered views do not auto-select mail or mark unread mail as read.
   - Search and local Outbox sources do not expose incomplete triage filters.
   - Bare-key shortcuts remain disabled in search, composers, and text fields.
   - Presets remain immutable; editing creates a saved Custom profile.

3. Review upstream database, account, IMAP, composer, conversation-list, shortcut, and localization changes for overlap with downstream code.

4. Run the same quality gates as GitHub CI:

   ```sh
   rm -rf _build
   meson setup --buildtype=debug -Dprofile=development -Dvaladoc=disabled _build
   meson compile -C _build
   xvfb-run -a dbus-run-session -- \
     meson test --verbose --no-stdsplit --num-processes 1 -C _build -t 10
   meson compile -C _build geary-pot
   rm -rf _build
   rm -f po/geary.pot subprojects/.wraplock
   test -z "$(git status --short)"
   ```

5. If application source changed, build and dogfood a new monotonic pacman package before merging.

6. Open a pull request titled `chore: sync GNOME Geary upstream YYYY-MM-DD`. Required CI must pass before merge.

7. Merge upstream sync pull requests with a **merge commit**, not squash or rebase. This preserves GNOME's ancestry so later syncs have the correct merge base. Downstream feature and fix pull requests remain squash-merged by convention.

8. Fetch the merged branch and verify ancestry:

   ```sh
   git fetch --multiple --prune origin github
   git merge-base --is-ancestor origin/main github/main
   ```

## Failure and rollback

Do not bypass failed checks, discard conflicting downstream behavior, or force-push `main`. If a merged sync must be rolled back, revert its merge commit with `git revert -m 1`, validate the full suite, and merge the revert through a pull request.

Published release tags are immutable. If an upstream sync changes an alpha release candidate, publish a new alpha tag rather than moving an existing tag.
