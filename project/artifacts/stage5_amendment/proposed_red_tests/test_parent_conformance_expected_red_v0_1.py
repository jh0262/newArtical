"""Prepared expected-red contracts. NOT EXECUTED under current authorization."""

import pytest


pytestmark = pytest.mark.expected_red_not_authorized_for_execution


def test_parent_parameter_sampling_contract_expected_red():
    pytest.fail("EXPECTED_RED: complete SHADE 1.1.1 sampling API is not authorized for implementation")


def test_parent_donor_archive_and_memory_contract_expected_red():
    pytest.fail("EXPECTED_RED: parent donor/archive/memory conformance is not implemented")


def test_parent_full_trace_and_inactive_cvgr_equivalence_expected_red():
    pytest.fail("EXPECTED_RED: full optimizer trace and inactive-path equivalence are not implemented")

