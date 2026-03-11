# Agent Filesystem Unification Project Management Plan

## 1. Objective

Move the product from the current notepad-centric tool/runtime model to the filesystem-centric architecture defined in [`agent-filesystem-design.md`](docs/plans/agent-filesystem-design.md) and the migration map in [`agent-filesystem-before-after.md`](docs/plans/agent-filesystem-before-after.md).

The delivery goal is not a partial refactor. The goal is a controlled migration to a **single filesystem authority** for:

- persistent storage
- open-file runtime state
- AI-facing file handles (`path`)
- dynamic tool activation by file type

## 2. Executive Direction

As project owner, I would run this as a 4-stream migration with explicit stage gates.

### Delivery principle

1. Build the new filesystem stack first.
2. Wire the sandbox boundary second.
3. Move tool behavior from `tabId` to `path` third.
4. Cut over host/runtime/UI integration last.
5. Delete legacy surfaces only after green tests and call-flow verification.

This reduces the risk of breaking the current call experience while large cross-cutting changes are in flight.

## 3. Current-State Impact Map

The design touches a narrow but high-risk set of architectural centers.

### 3.1 Core dependency centers

- Tool dependency container: [`ToolContext`](../lib/services/tools_runtime/tool_context.dart:18)
- Worker bootstrap: [`toolSandboxWorker()`](../lib/services/tools_runtime/tool_sandbox_worker.dart:30)
- Host routing: [`ToolSandboxManager._handleHostCall()`](../lib/services/tools_runtime/tool_sandbox_manager.dart:455)
- Tool registration root: [`RootToolbox.create()`](../lib/tools/tools.dart:44)
- Call-time tool initialization: [`CallService._initializeToolsForCall()`](../lib/services/call_service.dart:283)
- Existing runtime authority to be absorbed: [`NotepadService`](../lib/services/notepad_service.dart:22)
- Repository composition root: [`RepositoryFactory`](../lib/repositories/repository_factory.dart:20)
- Current document read contract still keyed by `tabId`: [`DocumentReadTool.execute()`](../lib/tools/builtin/document/document_read_tool.dart:33)
- Assistant instruction payload that must reflect the new workflow: [`AssistantConfig.defaultInstructions`](../lib/models/assistant_config.dart:20)

### 3.2 Architectural debt that must be retired

- `notepad` host API channel
- `toolStorage` host API channel
- `memory_*` tools
- `notepad_*` tools
- flat immutable tool registration in [`RootToolbox.create()`](../lib/tools/tools.dart:44)
- tab-based contracts in document and spreadsheet tools

## 4. Delivery Scope

## In scope

- persistent virtual filesystem repository/service
- open file runtime state managed under filesystem authority
- new `filesystem` sandbox API
- new core tools: `fs_list`, `fs_open`, `fs_close`, `fs_delete`, `fs_move`, `fs_active_files`
- path-based document/spreadsheet tool contracts
- dynamic tool injection/removal during a live session
- notepad UI converted into a view of open filesystem state
- removal of obsolete notepad/memory/toolStorage AI surfaces
- test expansion for migration boundaries

## Out of scope for this project

- rich files browser UI
- session history / rollback for filesystem activity
- POSIX-like permissions or locking
- encryption/compression
- large-file streaming

## 5. Work Breakdown Structure

## Stream A — Persistence and domain model

### Goal
Create the filesystem as a stable storage and domain layer before touching tool behavior.

### Deliverables

- [`lib/models/virtual_file.dart`](../lib/models/virtual_file.dart)
- [`lib/interfaces/virtual_filesystem_repository.dart`](../lib/interfaces/virtual_filesystem_repository.dart)
- [`lib/repositories/json_virtual_filesystem_repository.dart`](../lib/repositories/json_virtual_filesystem_repository.dart)
- [`lib/services/virtual_filesystem_service.dart`](../lib/services/virtual_filesystem_service.dart)
- [`RepositoryFactory.filesystem`](../lib/repositories/repository_factory.dart:20) integration

### Acceptance criteria

- path normalization works as specified in [`agent-filesystem-design.md`](docs/plans/agent-filesystem-design.md:810)
- repository persistence uses [`KeyValueStore`](../lib/interfaces/key_value_store.dart:2)
- quotas and validation are enforced centrally
- repository/service unit tests are green

### Primary risks

- path normalization defects create hidden data aliasing
- recursive listing semantics drift from design
- quota enforcement implemented in the wrong layer

## Stream B — Sandbox and host-call migration

### Goal
Replace old host-call dependencies with the filesystem channel while keeping tool execution stable.

### Deliverables

- [`lib/services/tools_runtime/apis/filesystem_api.dart`](../lib/services/tools_runtime/apis/filesystem_api.dart)
- [`lib/services/tools_runtime/host/filesystem_host_api.dart`](../lib/services/tools_runtime/host/filesystem_host_api.dart)
- `ToolContext` replacement of `notepadApi`/`toolStorageApi` with `filesystemApi`
- worker client creation changes in [`_WorkerController._createApiClients()`](../lib/services/tools_runtime/tool_sandbox_worker.dart:214)
- host router changes in [`ToolSandboxManager._handleHostCall()`](../lib/services/tools_runtime/tool_sandbox_manager.dart:455)

### Acceptance criteria

- worker can execute filesystem-backed host calls end-to-end
- no tool runtime path still depends on `notepad` or `toolStorage`
- integration tests cover request routing and failure behavior

### Primary risks

- mixed old/new APIs coexisting too long and producing ambiguous ownership
- isolate serialization issues for new payload shapes
- hidden dependency from tests or text-agent execution on removed APIs

## Stream C — Tool surface and dynamic activation

### Goal
Move AI-facing operations to the filesystem model and make active tools derive from opened file types.

### Deliverables

- new files under [`lib/tools/builtin/filesystem/`](../lib/tools/builtin/filesystem/)
- [`lib/services/file_type_registry.dart`](../lib/services/file_type_registry.dart)
- path-based rewrites of files in [`lib/tools/builtin/document/`](../lib/tools/builtin/document/)
- path-based rewrites of files in [`lib/tools/builtin/spreadsheet/`](../lib/tools/builtin/spreadsheet/)
- toolbox restructuring replacing the flat list in [`RootToolbox.create()`](../lib/tools/tools.dart:44)
- active tool recomputation in [`CallService._initializeToolsForCall()`](../lib/services/call_service.dart:283) and adjacent call-session logic

### Acceptance criteria

- all content tools require `path`
- tools reject unopened files
- `fs_open` injects the correct bundle
- `fs_close` removes only the closed file contribution
- union behavior across multiple open files is verified

### Primary risks

- tool duplication when two open files share the same bundle
- session tool palette drift from actual open-file state
- regressions in text-agent tool visibility

## Stream D — UI, cutover, and deletion

### Goal
Switch the visible runtime from notepad-owned tabs to filesystem-owned open files, then remove dead code.

### Deliverables

- [`lib/models/open_file_state.dart`](../lib/models/open_file_state.dart)
- notepad pane updates in [`lib/feat/call/panes/notepad.dart`](../lib/feat/call/panes/notepad.dart)
- historical/session rendering review in [`lib/feat/session/segments/notepad.dart`](../lib/feat/session/segments/notepad.dart) and [`lib/feat/session/widgets/historical_notepad_view.dart`](../lib/feat/session/widgets/historical_notepad_view.dart)
- assistant instructions update in [`AssistantConfig.defaultInstructions`](../lib/models/assistant_config.dart:20)
- removal of legacy files:
  - [`lib/services/tools_runtime/apis/notepad_api.dart`](../lib/services/tools_runtime/apis/notepad_api.dart)
  - [`lib/services/tools_runtime/host/notepad_host_api.dart`](../lib/services/tools_runtime/host/notepad_host_api.dart)
  - [`lib/services/tools_runtime/apis/tool_storage_api.dart`](../lib/services/tools_runtime/apis/tool_storage_api.dart)
  - [`lib/services/tools_runtime/host/tool_storage_host_api.dart`](../lib/services/tools_runtime/host/tool_storage_host_api.dart)
  - [`lib/interfaces/tool_storage.dart`](../lib/interfaces/tool_storage.dart)
  - [`lib/repositories/json_tool_storage.dart`](../lib/repositories/json_tool_storage.dart)
  - [`lib/tools/builtin/notepad/`](../lib/tools/builtin/notepad/)
  - [`lib/tools/builtin/memory/`](../lib/tools/builtin/memory/)

### Acceptance criteria

- human-visible tabs reflect filesystem open state
- close/save semantics are correct
- no runtime references remain to deleted APIs
- smoke test of real call flow passes

### Primary risks

- UI still expecting tab metadata or MIME fields
- saved session history assumptions breaking after model changes
- deletion happening before all references are removed

## 6. Stage Gates

## Gate 0 — Design baseline approved

Entry:
- design documents accepted as source of truth

Exit:
- this project plan accepted
- ownership and sequencing agreed

## Gate 1 — Filesystem foundation complete

Entry:
- Stream A started

Exit:
- repository/service merged
- unit tests green
- no tool/UI changes required yet

## Gate 2 — Sandbox contract complete

Entry:
- filesystem service stable

Exit:
- `filesystem` host channel live
- [`ToolContext`](../lib/services/tools_runtime/tool_context.dart:18) migrated
- old APIs no longer needed for new work

## Gate 3 — Tool contract migration complete

Entry:
- sandbox route stable

Exit:
- filesystem core tools available
- document/spreadsheet tools path-based
- active tool injection verified under call tests

## Gate 4 — Cutover complete

Entry:
- path-based tools verified

Exit:
- notepad UI bound to open-file state
- legacy APIs removed
- assistant instructions updated
- regression suite green

## 6.1 Review Checkpoints for Prime Contractor Review

The prime contractor should not be asked to review the whole migration as one opaque refactor. They should review **phase-complete increments** aligned to stage gates, with explicit scope and explicit non-scope.

### Review Point R0 — Design / execution baseline review

**Timing:** before Stream A starts
**Submission package:**
- architecture source of truth: [`agent-filesystem-design.md`](docs/plans/agent-filesystem-design.md)
- migration map: [`agent-filesystem-before-after.md`](docs/plans/agent-filesystem-before-after.md)
- delivery/control plan: [`agent-filesystem-project-management.md`](docs/plans/agent-filesystem-project-management.md)

**What the prime contractor can review:**
- whether the migration goal is correctly defined as filesystem unification
- whether phase boundaries and stage gates are reasonable
- whether deletion timing for legacy APIs is conservative enough
- whether acceptance criteria are concrete enough to contract against

**What we want reviewed:**
- architecture direction
- risk containment strategy
- cutover order
- approval criteria per gate

**What we do NOT want reviewed at this point:**
- naming minutiae
- low-level class decomposition details
- UI polish questions
- implementation style before code exists

**Review output expected:**
- approval/revision of delivery baseline
- explicit go/no-go for Stream A

### Review Point R1 — Filesystem foundation review

**Timing:** Gate 1 exit
**Submission package:**
- filesystem model/repository/service implementation
- unit test results for normalization, validation, quota, list/move/delete
- short note on unresolved design deltas, if any

**What the prime contractor can review:**
- path contract correctness
- storage model consistency with design
- test evidence for persistence and safety rules
- whether this foundation is stable enough for downstream sandbox work

**What we want reviewed:**
- behavior against the agreed filesystem specification
- completeness of acceptance criteria for Stream A
- risk of rework propagation into later phases

**What we do NOT want reviewed at this point:**
- dynamic tool injection behavior
- notepad UI behavior
- final deletion plan execution
- cosmetic code-style comments that do not affect the contract

**Review output expected:**
- acceptance/rework decision for Gate 1
- permission to start Stream B

### Review Point R2 — Sandbox contract review

**Timing:** Gate 2 exit
**Submission package:**
- new `filesystem` API client/host adapter
- migrated [`ToolContext`](../lib/services/tools_runtime/tool_context.dart:18)
- host routing updates in [`ToolSandboxManager._handleHostCall()`](../lib/services/tools_runtime/tool_sandbox_manager.dart:455)
- integration test evidence for worker ↔ host filesystem calls

**What the prime contractor can review:**
- whether the isolate boundary is now correctly filesystem-centric
- whether old API ownership ambiguity has been removed
- whether call routing and failure handling are contractually safe

**What we want reviewed:**
- boundary contract stability
- migration safety at the sandbox layer
- suitability of the new host-call surface for later tool migration

**What we do NOT want reviewed at this point:**
- every individual tool implementation
- UI rendering details
- assistant instruction wording
- deletion of all legacy files before downstream replacement is proven

**Review output expected:**
- acceptance/rework decision for Gate 2
- permission to start Stream C

### Review Point R3 — Tool surface review

**Timing:** Gate 3 exit
**Submission package:**
- filesystem core tools
- file type registry
- path-based `document_*` / `spreadsheet_*` tools
- test evidence for open-file preconditions and dynamic tool injection
- before/after tool palette examples

**What the prime contractor can review:**
- whether the AI-facing contract is now consistently path-based
- whether file-type bundle activation matches the design
- whether open/close semantics are intelligible and reviewable from a product perspective

**What we want reviewed:**
- external behavior of tools
- correctness of tool availability rules
- session.update/tool-palette behavior from a requirements perspective

**What we do NOT want reviewed at this point:**
- final UI binding details
- cleanup of all dead code not yet removed
- speculative future file types not in current scope
- internal refactors that do not change contract behavior

**Review output expected:**
- acceptance/rework decision for Gate 3
- permission to start Stream D

### Review Point R4 — Runtime cutover and deletion review

**Timing:** Gate 4 exit
**Submission package:**
- notepad UI bound to filesystem open-file state
- legacy API/tool removal diff summary
- regression and smoke test evidence
- updated assistant instructions in [`AssistantConfig.defaultInstructions`](../lib/models/assistant_config.dart:20)

**What the prime contractor can review:**
- whether the product now behaves as a filesystem-first system end-to-end
- whether user-visible runtime behavior remains acceptable
- whether legacy removal happened only after replacement was proven
- whether the migration can be signed off for release

**What we want reviewed:**
- release readiness
- end-to-end behavioral integrity
- deletion safety and completeness
- residual risk assessment

**What we do NOT want reviewed at this point:**
- reopening already approved Gate 1/Gate 2 architecture unless a defect proves it necessary
- introducing new feature scope unrelated to filesystem unification
- optional future UI/browser concepts outside project scope

**Review output expected:**
- final sign-off or targeted punch-list
- release go/no-go decision

### Review operating rules

- Every review point must ship with a **review memo**: scope, changed files, acceptance criteria, known issues, explicit asks.
- Every review point must distinguish **"please review"** from **"informational only"** items.
- The prime contractor reviews **observable contracts and gate evidence**, not every internal implementation preference.
- Comments outside the agreed review scope are logged separately and do not block gate judgment unless they expose risk to the approved contract.
- No downstream phase starts before the current review point is dispositioned as approved or approved-with-conditions.

## 7. Recommended Execution Sequence

### Sprint 1 — Foundation

- implement repository/model/service
- add path validation and quota tests
- wire [`RepositoryFactory`](../lib/repositories/repository_factory.dart:20)

### Sprint 2 — Sandbox migration

- implement filesystem API client/host adapter
- replace `notepadApi` and `toolStorageApi` dependencies in [`ToolContext`](../lib/services/tools_runtime/tool_context.dart:18)
- update worker and host routing
- prove one end-to-end filesystem host call in tests

### Sprint 3 — Core tools and registry

- add filesystem tools
- add file type registry
- restructure toolbox into base/core/type-bound concept
- prepare active tool recomputation path in call service

### Sprint 4 — Tool rewiring

- convert `document_*` tools from `tabId` to `path`
- convert `spreadsheet_*` tools from `tabId` to `path`
- enforce open-file precondition
- add migration-critical tests

### Sprint 5 — Runtime cutover

- add open-file state model
- bind notepad UI to filesystem open set
- implement `fs_open`/`fs_close` injection-removal behavior in live call flow
- validate session update timing and deduplication

### Sprint 6 — Deletion and hardening

- remove legacy notepad/memory/toolStorage surfaces
- update assistant instructions
- run regression, cleanup, and performance checks

## 8. Backlog in Engineering Task Format

### Epic 1 — Filesystem foundation

- [ ] Create [`virtual_file.dart`](../lib/models/virtual_file.dart)
- [ ] Create [`virtual_filesystem_repository.dart`](../lib/interfaces/virtual_filesystem_repository.dart)
- [ ] Create [`json_virtual_filesystem_repository.dart`](../lib/repositories/json_virtual_filesystem_repository.dart)
- [ ] Create [`virtual_filesystem_service.dart`](../lib/services/virtual_filesystem_service.dart)
- [ ] Add filesystem getter to [`repository_factory.dart`](../lib/repositories/repository_factory.dart)
- [ ] Add unit tests for normalize/list/write/delete/move/quota

### Epic 2 — Sandbox migration

- [ ] Create [`filesystem_api.dart`](../lib/services/tools_runtime/apis/filesystem_api.dart)
- [ ] Create [`filesystem_host_api.dart`](../lib/services/tools_runtime/host/filesystem_host_api.dart)
- [ ] Replace fields in [`tool_context.dart`](../lib/services/tools_runtime/tool_context.dart)
- [ ] Replace client creation in [`tool_sandbox_worker.dart`](../lib/services/tools_runtime/tool_sandbox_worker.dart)
- [ ] Replace routing in [`tool_sandbox_manager.dart`](../lib/services/tools_runtime/tool_sandbox_manager.dart)
- [ ] Remove host/runtime dependence on [`tool_storage_api.dart`](../lib/services/tools_runtime/apis/tool_storage_api.dart)

### Epic 3 — AI tool surface

- [ ] Create [`fs_list_tool.dart`](../lib/tools/builtin/filesystem/fs_list_tool.dart)
- [ ] Create [`fs_open_tool.dart`](../lib/tools/builtin/filesystem/fs_open_tool.dart)
- [ ] Create [`fs_close_tool.dart`](../lib/tools/builtin/filesystem/fs_close_tool.dart)
- [ ] Create [`fs_delete_tool.dart`](../lib/tools/builtin/filesystem/fs_delete_tool.dart)
- [ ] Create [`fs_move_tool.dart`](../lib/tools/builtin/filesystem/fs_move_tool.dart)
- [ ] Create `fs_active_files` tool
- [ ] Create [`file_type_registry.dart`](../lib/services/file_type_registry.dart)
- [ ] Replace flat registration in [`tools.dart`](../lib/tools/tools.dart)

### Epic 4 — Existing tool migration

- [ ] Rewrite [`document_read_tool.dart`](../lib/tools/builtin/document/document_read_tool.dart)
- [ ] Rewrite [`document_overwrite_tool.dart`](../lib/tools/builtin/document/document_overwrite_tool.dart)
- [ ] Rewrite [`document_patch_tool.dart`](../lib/tools/builtin/document/document_patch_tool.dart)
- [ ] Rewrite [`spreadsheet_add_rows_tool.dart`](../lib/tools/builtin/spreadsheet/spreadsheet_add_rows_tool.dart)
- [ ] Rewrite [`spreadsheet_update_rows_tool.dart`](../lib/tools/builtin/spreadsheet/spreadsheet_update_rows_tool.dart)
- [ ] Rewrite [`spreadsheet_delete_rows_tool.dart`](../lib/tools/builtin/spreadsheet/spreadsheet_delete_rows_tool.dart)
- [ ] Remove `tabId` from tool schemas and outputs

### Epic 5 — Runtime/UI cutover

- [ ] Create [`open_file_state.dart`](../lib/models/open_file_state.dart)
- [ ] Add open-file state ownership to filesystem service
- [ ] Update call-time tool management in [`call_service.dart`](../lib/services/call_service.dart)
- [ ] Rebind [`notepad.dart`](../lib/feat/call/panes/notepad.dart) to filesystem-backed state
- [ ] Review session/history views for compatibility
- [ ] Update [`assistant_config.dart`](../lib/models/assistant_config.dart)

### Epic 6 — Legacy deletion

- [ ] Remove files under [`lib/tools/builtin/notepad/`](../lib/tools/builtin/notepad/)
- [ ] Remove files under [`lib/tools/builtin/memory/`](../lib/tools/builtin/memory/)
- [ ] Remove [`notepad_api.dart`](../lib/services/tools_runtime/apis/notepad_api.dart)
- [ ] Remove [`notepad_host_api.dart`](../lib/services/tools_runtime/host/notepad_host_api.dart)
- [ ] Remove [`tool_storage_api.dart`](../lib/services/tools_runtime/apis/tool_storage_api.dart)
- [ ] Remove [`tool_storage_host_api.dart`](../lib/services/tools_runtime/host/tool_storage_host_api.dart)
- [ ] Remove [`tool_storage.dart`](../lib/interfaces/tool_storage.dart) and [`json_tool_storage.dart`](../lib/repositories/json_tool_storage.dart)

## 9. RACI-style Ownership Model

## Architecture owner

Responsible for:
- filesystem service contract
- file type registry rules
- migration invariants
- stage gate approvals

## Runtime/tooling engineer

Responsible for:
- sandbox worker/host changes
- tool context migration
- toolbox restructuring
- tool execution compatibility

## Application engineer

Responsible for:
- call service dynamic tool updates
- notepad rendering migration
- assistant instruction updates
- session/history compatibility review

## QA owner

Responsible for:
- migration-critical test matrix
- regression test execution
- call-flow smoke validation
- release readiness sign-off

## 10. Risk Register

| ID | Risk | Impact | Likelihood | Mitigation |
|---|---|---|---|---|
| R1 | Old and new authority models coexist too long | High | High | Enforce stage gates and forbid new features on legacy surfaces |
| R2 | Dynamic tool injection causes inconsistent live session state | High | Medium | Add deterministic tool-set recomputation and session.update tests |
| R3 | UI still depends on MIME/title/history assumptions from notepad tabs | High | Medium | Add explicit migration tests for open-file rendering |
| R4 | Path normalization bugs create duplicate file identities | High | Medium | Centralize normalization in service and test aggressively |
| R5 | Removal of `toolStorage` breaks hidden behavior | Medium | Medium | Search references before deletion and replace with FS-backed patterns |
| R6 | Regression coverage is insufficient for call-time tool execution | High | Medium | Add integration tests around sandbox routing and call flow |

## 11. Definition of Done

This project is done only when all conditions below are true:

- AI-facing file handle is universally `path`
- persistent storage authority is the filesystem service/repository
- open working content authority is filesystem open-file state
- dynamic tool bundles activate/deactivate based on open files
- notepad is only a UI projection of open files
- no shipped code path depends on `notepad` or `toolStorage` host APIs
- test suite covers persistence, migration boundaries, and live tool updates
- assistant instructions reflect the new operational model

## 12. Immediate Next Actions

1. Approve this plan as the execution baseline.
2. Start Stream A first; do not mix UI migration into the first PR.
3. Implement the filesystem repository/service behind tests.
4. After Stream A is green, begin sandbox API migration in a separate PR line.
5. Hold legacy deletions until after dynamic tool injection is verified in a live-call regression pass.

## 13. Management Decision

Recommended branch strategy:

- `feature/fs-foundation`
- `feature/fs-sandbox-api`
- `feature/fs-tool-surface`
- `feature/fs-runtime-cutover`
- `feature/fs-legacy-removal`

Recommended review rule:

- no PR crosses more than one stage gate
- no deletion PR lands before replacement behavior is verified
- every migration PR must include tests for the exact boundary it changes

This plan turns the filesystem unification effort into a controlled migration program instead of a single risky refactor.