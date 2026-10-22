"""FL-0128U mutation rows (the unit kind as the job on the wire: Types.JOB_IDS, Replication.jobOf, Catalog's citizen-job check).
Run by ../mutations.py (`mutations.py FL-0128U`). One row: (task, file, old, new, spec filter, expected failing test).
G is games/game-001/.
"""
RP = G + "src/shared/Sim/Replication.luau"
TY = G + "src/shared/Kingdom/Types.luau"
M = [
 ("FL-0128U", RP, 'then e.kind else "soldier"', 'then "soldier" else "soldier"', "sim/Replication", "sends soldier, archer, knight and ram as the job of a unit"),
 ("FL-0128U", RP, 'if e.job ~= nil then\n\t\treturn e.job\n\tend', 'if false then\n\t\treturn e.job\n\tend', "sim/Replication", "sends soldier, archer, knight and ram as the job of a unit"),
 ("FL-0128U", TY, '\t"archer",\n\t"knight",\n\t"ram",\n})', '\t"archer",\n\t"knight",\n})', "sim/Replication", "sends soldier, archer, knight and ram as the job of a unit"),
]
