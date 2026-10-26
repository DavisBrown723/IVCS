# IVCS Graphflow checks

The registered target is development. Required checks take configured IDs, one per line. Use ivcs-manual for the current helicopter demo ticket. The literal value none does not disable verification.

This initial policy uses candidate-bound human verification. Load the exact candidate into a disposable IVCS mission/profile, follow its documented demo launch steps and record both named cases: candidate-scenario and ticket-acceptance. The helicopter ticket requires a BLU_F attack helicopter group, an OPF_F infantry group, an attack waypoint onto the infantry group and observed virtual combat. Unanswered checks stay pending; no automated game coverage is claimed by this policy. Independent specification/correctness reviews and exact-candidate merge gates still apply.

Existing tests/tasks/run.ps1 launches its own server and writes into the ordinary installation. It has not been wired into Graphflow as an isolated check. Automatic server/client verification needs a separate candidate-bound adapter fixture; selecting a check ID cannot replace that work.

Python bytecode, process logs and local runtime state remain on disk and are ignored by Git. Published project/map assets and retained reports remain part of the source snapshot. The baseline commit records current development work, not a reviewed feature baseline or enabled automatic repair policy.
