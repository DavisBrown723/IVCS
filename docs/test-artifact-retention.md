# Test artifact retention

Cleanup on 25 October 2026 reclaimed approximately **40.55 GB (37.77 GiB)** of logical file data.

| Removed artifacts | Space |
| --- | ---: |
| 92 completed temporary test missions | 39.368 GB |
| 97 project-linked profiler files | 0.314 GB |
| 6 obsolete generated map backups | 0.829 GB |
| Paired raw frame CSVs and duplicate per-frame report detail | 41.2 MB |

Repository evidence decreased from 53.9 MB to 12.7 MB. Fifteen JSON reports preserve all aggregate fields and mark removed per-frame arrays with `retired_frame_details`. Thirty-seven raw frame CSVs had matching summary JSON reports retained. An initial broad compaction was rejected by automatic approval review; the narrower cleanup preserved every aggregate metric.

Published Altis output, native vehicle-damage calibration observations, runnable tests, comparison fixtures and historical result summaries remain. Unrelated profiler captures were retained. Old RPT, capture and temporary-source paths in historical reports identify artifacts that have now been retired. To analyze individual frames again, record a fresh workload; historical summary reports retain the timing distributions and conclusions.

`tests/tasks/run.ps1` now removes reproducible runtime copies, compiled mission packages and animation caches after the server exits, including preparation failures. RPT logs and the test input remain available to the map-indexing pipeline and analysis tools. Use `-KeepArtifacts` to retain the bulky files for a specific investigation. Existing positional arguments keep their order.

Verification covered a successful native engine smoke run, preservation of its readable RPT, cleanup of its generated copies/packages/cache, and cleanup after an intentional setup failure. Published-map and calibration hashes, all runnable SQF tests/fixtures, and unaffected reports matched their pre-cleanup versions. No gameplay SQF files changed.
