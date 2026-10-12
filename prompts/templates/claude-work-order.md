# Work order template (FORGE-00 / Codex → a FORGE worker)

Use `python tools/forge.py prompt <ID>` to compile a task into a self-contained prompt; use this template for larger briefs.

A. Identity and responsibility · B. Objective (exact outcome) · C. Available context (files, decisions, prior work — links) · D. Functional requirements · E. Visual requirements · F. Architecture and integration points (contracts) · G. Required tools · H. Constraints (performance, platform policy, user decisions) · I. Validation (automated vs Studio; how to prove it) · J. Deliverables (files, tests, renders, docs) · K. Completion criteria (gates G1–G8) · L. Knowledge capture (lessons, reusable modules to extract)

After execution, record in `prompts/evaluations/<prompt-id>.md`: version, outcome, rework caused by ambiguity, missing requirements, what to change next time.
