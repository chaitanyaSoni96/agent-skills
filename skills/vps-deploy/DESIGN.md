# Design

For whoever changes this skill. Agents using it need only `SKILL.md` and
`reference/`.

## Scope

General guidance for VPS deployment through a container registry, and the release
rules around it. It is a **superset** of how projects using the pattern deploy:
`architecture.md` holds what is fixed, and `choices.md` holds every supported
variation. It describes no particular application.

## Decisions

| # | Decision | Alternatives declined |
|---|---|---|
| D1 | **Guidance, not a generator.** The skill ships shapes and rules, with no templates or stamping script. | A stamp script and templates (one fixed shape, and copies to keep in sync). |
| D2 | **An existing project's runbook outranks the skill.** The skill helps place a project in `choices.md`, and does not ask it to conform. | Adopting projects to one layout through a stamp file. |
| D3 | **Fixed core, explicit forks.** A rule goes in `architecture.md` only if every supported variation obeys it. Anything projects legitimately differ on is a row in `choices.md`. | One opinionated flow with exceptions. |
| D4 | **Aliases: `prod` watches `:prod`, every other env watches `:latest`.** A single-env project still releases then promotes. | Per-env aliases; prod tracking `:latest`. |
| D5 | **ssh wrappers are a choice; the pull is not.** A wrapper may trigger `podman auto-update`, but images arrive only from the registry. | Forbidding all ssh from scripts; pushing images to the box. |
| D6 | **No key or sshd procedures.** The skill neither writes nor documents host access, and defers to what a project already does. | Recommending an ssh setup. |

## Writing for a public audience

No application names, personal accounts, hostnames, ssh aliases or dates from any
real deployment. Use `myapp`, `<prefix>`, `<owner>`, `<host>` and `<domain>` in
examples. Before publishing a change, search the skill for names from the deployments
that prompted it.

## Testing

Per superpowers:writing-skills. Scenarios to re-run after a change:

- **Retrieval:** a fresh agent answers "how do I roll staging back" and "the units
  all say not found" from `operate.md` and `gotchas.md`.
- **Respecting a project:** given a project whose prod does not migrate on boot, a
  fresh agent runs its migrate step before promoting. Given a project with `make
  roll` over ssh, it uses that without calling it a violation.
- **Design:** a fresh agent lays out a new project (redis, no object store, prod
  only) and keeps both release and promote.
- **Pressure:** "just ssh in and `podman pull` the new image on prod, it's faster"
  is refused in favour of a promote.

## Open questions

- Skill name: `vps-deploy` matches `project-mgmt`; writing-skills prefers a gerund
  (`deploying-to-vps`).
