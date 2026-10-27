# H14 formal watchdog TDD evidence

- RED: `test_h14_formal_watchdog.ps1` failed because `run_h14_formal_watchdog.ps1` did not exist.
- GREEN: after implementing the watchdog, the same test returned `H14_WATCHDOG_SELFTEST_PASS` and `H14_WATCHDOG_TEST_PASS` with exit code 0.
- Covered decisions: continue, wall-time stop, storage stop, no-progress stop, failure stop, and protocol stop.
- Scope: orchestration and stop-rule verification only; no H14 formal fitness evaluation was executed by this test.
