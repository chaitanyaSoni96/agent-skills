---
name: project-mgmt
description: |
  Manages project artifacts in the .agents/ directory — requirements (with PRDs and SOWs), technical specs, implementation plans, and documents. Handles the full artifact lifecycle: creating new artifacts with correct directory structure and YAML frontmatter, progressing requirements (requirement.md → prd.md → sow.md), moving plans between status directories (todo → in-progress → completed → punted) with tracker file management, cross-linking related artifacts, and keeping INDEX.md updated. Also ingests existing project documentation — READMEs, implementation plans, specs, feature docs, or any scattered markdown — into the .agents/ system by classifying, converting, and cross-linking them. Use this skill whenever the user wants to create or manage requirements, PRDs, SOWs, specs, plans, trackers, or project documents. Also trigger when the user mentions progressing, moving, archiving, or tracking project work, updating project status, asks what's in flight, or wants to import/ingest/bootstrap/onboard existing docs into the project management system — even if they don't explicitly mention the .agents directory.
---

# Project Management

A self-contained project management system. All artifacts live in `.agents/` at the project root with standardized structure, frontmatter, and cross-linking. This skill contains every convention needed to operate the system — no external configuration files are required.

## Directory Structure

The `.agents/` directory has four artifact directories and an index. If `.agents/` doesn't exist, create it along with all subdirectories.

```
.agents/
  requirements/     # Product requirements, PRDs, SOWs
  spec/             # Technical specifications and system design
  plans/            # Execution plans with task breakdowns
    todo/           # Planned work not yet started
    in-progress/    # Actively being worked on
    completed/      # Finished work with full history
    punted/         # Deferred or deprioritized work
  documents/        # ADRs, research spikes, retrospectives, notes
  INDEX.md          # Single flat index of all artifacts
```

## Lifecycle

Artifacts flow through a pipeline. Each stage links to its upstream and downstream counterparts.

```
requirements/  →  spec/  →  plans/todo/  →  plans/in-progress/  →  plans/completed/
(what & why)     (how)     (when & who)
```

A requirement spawns a spec when technical design begins. A spec spawns a plan when execution is ready. Not every artifact needs the full pipeline — a quick research document or a standalone spec is fine.

## Naming

- All files and folders use `kebab-case`
- Documents use optional date prefix: `YYYY-MM-DD-<name>.md`
- Requirements are always **folders** (they accumulate prd.md, sow.md)
- Plans are always **folders** (they accumulate tracker files)
- Specs and documents can be flat files or folders

## Frontmatter

Every `.md` artifact starts with YAML frontmatter:

```yaml
---
title: Short descriptive name
status: <valid-status-for-type>
created: YYYY-MM-DD
links: [relative/path/to/upstream.md, relative/path/to/downstream/]
---
```

- `created`: use today's date
- `links`: relative paths from the file's location. Maintain bidirectional links — if A links to B, B should link back to A
- `source`: added only on ingested artifacts, points to the original file path for provenance

## Requirements

A requirement is a **folder** in `requirements/`. Files inside track its maturity:

```
requirements/<feature-name>/
  requirement.md      # Initial need — problem, user impact, success criteria
  prd.md              # Product requirements — detailed scope, user stories, acceptance criteria
  sow.md              # Statement of work — deliverables, timeline, cost, constraints
```

### Frontmatter per file

```yaml
# requirement.md / prd.md / sow.md
---
title: Feature Name
status: draft | review | accepted | rejected
created: YYYY-MM-DD
links: [../spec/<feature-name>.md]
---
```

### Lifecycle gates

- A requirement folder starts with `requirement.md` only
- `prd.md` is added when the product scope is being defined
- `sow.md` is added when deliverables, timeline, and cost are being locked
- Ready for spec work when `requirement.md` is accepted
- Ready for planning when `sow.md` is accepted

### Content structure

**requirement.md**: Problem, User Impact, Success Criteria

**prd.md**: A comprehensive product requirements document. Include whatever sections the feature demands — the goal is a complete product definition, not a rigid template. Common sections include: Overview, Scope (in/out), User Stories with acceptance criteria, API contracts, data models, UI wireframes, non-functional requirements, success metrics, and open questions. Let the complexity of the feature dictate the depth. A simple toggle might need one page; a payment system might need ten.

**sow.md**: Deliverables, Timeline, Cost, Constraints

## Specs

Technical design documents. Can be a single file (`spec/<feature-name>.md`) or a folder with sub-documents (`spec/<feature-name>/`).

```yaml
---
title: Feature Name Technical Spec
status: draft | review | accepted | superseded
created: YYYY-MM-DD
links: [../requirements/<feature-name>/, ../plans/todo/<feature-name>/]
---
```

Content covers: Approach, API Contracts / Data Models (if applicable), Trade-offs, Risks.

A spec links back to its requirement and forward to its plan.

## Plans

A plan is a **folder** in the appropriate status subdirectory. Contains a main plan file and, when in-progress, a tracker.

```
plans/in-progress/<plan-name>/
  <plan-name>.md              # Scope, approach, task breakdown
  <plan-name>-tracker.md      # Granular progress log (required while in-progress)
```

```yaml
---
title: Plan Name
status: todo | in-progress | completed | punted
created: YYYY-MM-DD
links: [../../requirements/<feature-name>/, ../../spec/<feature-name>.md]
---
```

Plan status is determined by which subdirectory the folder lives in. Never change the status without moving the folder.

Content structure: Scope, Approach, Task Breakdown. Use GitHub-flavored task list markers:

- `- [ ]` not started
- `- [~]` in progress
- `- [x]` complete

### Tracker

Every plan in `in-progress/` **must** have a `<plan>-tracker.md`. The tracker is the narrative record of execution. Each entry includes: date, what was done, decisions and their reasoning. Use the same `- [ ]` / `- [~]` / `- [x]` markers as the plan file.

## Documents

Catch-all for artifacts that aren't requirements, specs, or plans: ADRs, research spikes, retrospectives, meeting notes. Can be flat files or folders.

```yaml
---
title: Technology X vs Technology Y Comparison
type: research | adr | retrospective | notes
status: draft | final
created: YYYY-MM-DD
links: [../spec/<feature-name>.md]
---
```

## INDEX.md

A single flat index of all artifacts at `.agents/INDEX.md`. One line per entry, grouped by directory, under 120 characters per line. Update it on every create, move, or delete.

Each entry uses a solid text status label after the em-dash — no emojis. Use the exact status values that live in the frontmatter (`draft`, `review`, `accepted`, `rejected`, `todo`, `in-progress`, `completed`, `punted`, `superseded`, `final`). For requirements that have progressed through multiple files, list each file with its current status, comma-separated.

```markdown
# Index

All project artifacts across directories. One line per entry.

## Requirements
- [Feature Name](requirements/feature-name/) — requirement: accepted, prd: draft

## Specs
- [Feature Name Spec](spec/feature-name.md) — accepted

## Plans
- [Feature Name](plans/in-progress/feature-name/) — in-progress

## Documents
- [Tech Comparison](documents/YYYY-MM-DD-tech-comparison.md) — research, final
```

## Operations

### Create requirement

1. Create `requirements/<name>/requirement.md` with `status: draft`
2. Content: Problem, User Impact, Success Criteria
3. Update INDEX.md

### Progress requirement

Add the next file to an existing requirement folder:
- `prd.md` (`status: draft`) — comprehensive product requirements (see Content structure above for guidance; adapt sections to the feature's complexity)
- `sow.md` (`status: draft`) — Deliverables, Timeline, Cost, Constraints

Link to downstream artifacts (spec, plan) if they exist.
Update INDEX.md.

### Create spec

1. Create `spec/<name>.md` or `spec/<name>/` with `status: draft`
2. Link back to the requirement
3. Content: Approach, API Contracts / Data Models (if applicable), Trade-offs, Risks
4. Update INDEX.md

### Create plan

1. Create `plans/todo/<name>/<name>.md` with `status: todo`
2. Link to requirement and spec
3. Content: Scope, Approach, Task Breakdown (using `- [ ]` markers)
4. Update INDEX.md

### Start plan (todo → in-progress)

1. Move folder to `plans/in-progress/<name>/`
2. Create `<name>-tracker.md` inside it
3. Set `status: in-progress` in plan frontmatter
4. Update INDEX.md

### Complete plan (in-progress → completed)

1. Prepend tracker content to main plan file under `## Execution Log`
2. Delete tracker file
3. Set `status: completed`
4. Move folder to `plans/completed/<name>/`
5. Update INDEX.md

### Punt plan (in-progress → punted)

1. Prepend tracker content to main plan file under `## Execution Log`
2. Add `## Punt Reason` section with explanation
3. Delete tracker file
4. Set `status: punted`
5. Move folder to `plans/punted/<name>/`
6. Update INDEX.md

### Update tracker

Append to the tracker file in `plans/in-progress/<name>/`. Each entry: date, what was done, decisions and reasoning. Use `- [ ]` / `- [~]` / `- [x]` markers.

### Create document

1. Create `documents/<name>.md` (date prefix optional: `YYYY-MM-DD-<name>.md`)
2. Frontmatter with `type` and `status: draft`
3. Link to related artifacts
4. Update INDEX.md

### Update status

Requirements and specs: `draft` → `review` → `accepted` or `rejected`. Specs can also go `accepted` → `superseded`.

Plans: move the folder between subdirectories — the subdirectory is the status.

Always update frontmatter and INDEX.md together.

## Ingest

Bootstraps the `.agents/` system from existing project documentation. Use when onboarding a project that already has docs scattered across the repo.

### Discovery

Scan the project for documentation. Common locations:
- `README.md`, `docs/`, `documentation/`
- `implementation_plans/`, `plans/`, `roadmap/`
- `specs/`, `spec/`, `design/`, `rfcs/`
- `requirements/`, `features/`, `prd/`
- Any `.md` files in the project root

Also check for structured data inside docs — task tables with status columns, phase/sprint breakdowns, endpoint lists, schema definitions.

### Classification

Read each document and classify its content. A single source document may map to multiple artifact types:

| Content pattern | Maps to | Example |
|---|---|---|
| Problem statement, user needs, success criteria | `requirements/` requirement.md | Feature spec intro sections |
| Scope, user stories, acceptance criteria | `requirements/` prd.md | PRD documents, detailed feature specs |
| Deliverables, timeline, milestones, cost | `requirements/` sow.md | Project plans with dates and phases |
| Technical approach, API design, data models, trade-offs | `spec/` | Architecture docs, design docs, RFCs |
| Task breakdowns, sprint plans, phased work with status markers | `plans/` | Implementation plans, roadmaps |
| Research, decisions, comparisons, meeting notes | `documents/` | ADRs, spike results, meeting notes |

### Ingest procedure

**Core rule: never modify original content.** Ingested documents carry over their full contents unmodified. The only additions are frontmatter for tracking/organizing and cross-links to related artifacts. Never restructure, summarize, or rewrite the source material.

1. **Scan** — find all documentation files, present the list to the user
2. **Propose** — for each source document, propose which `.agents/` artifact to create and where it goes. A single source document maps to one artifact — place it in the directory that best matches its primary content. Present the mapping for user approval before proceeding
3. **Wrap** — copy the source document's full content into the target artifact, prepending only the YAML frontmatter block. The body below the frontmatter is the original content, untouched:
   ```yaml
   ---
   title: Backend Architecture
   status: accepted
   created: YYYY-MM-DD
   source: docs/architecture.md
   links: [../requirements/<project-name>/, ../plans/completed/<plan-name>/]
   ---

   <!-- original document content below, unmodified -->

   # Project Architecture
   
   > System design, patterns, and technical decisions.
   ...
   ```
4. **Derive status** — infer artifact status from the source material:
   - Task tables with completed markers (`- [x]`, "done", "shipped", ✅) → `plans/completed/`
   - In-progress markers (`- [~]`, "current sprint", 🔄) → `plans/in-progress/` with a tracker
   - Not-started items → `plans/todo/`
   - Existing architecture/design docs → `spec/` with `status: accepted` (they're already in use)

   Note: legacy source documents may use emoji markers. Read them as signals, but when you write the ingested artifact, normalize to the text markers above.
5. **Cross-link** — connect all created artifacts to each other via the frontmatter `links:` field
6. **Populate INDEX.md** — add all created artifacts

### Splitting large documents

When a single source document genuinely covers multiple artifact types (e.g., an implementation plan that contains both a feature spec and sprint tasks), it can be split into multiple artifacts. When splitting:
- Each artifact gets the **full relevant section** from the source, not a summary
- The `source:` field in every artifact points to the same original file
- Add a comment at the split boundary noting where the rest lives: `<!-- Continued in ../plans/completed/<plan-name>/ -->`

### Incremental ingest

Supports re-ingesting after the initial bootstrap. When the user points to a new or updated document:
- Check if related artifacts already exist in `.agents/`
- Update existing artifacts rather than creating duplicates
- Add new artifacts only for genuinely new content
- Update cross-links and INDEX.md
