"""Prepared expected-red modern-matrix contracts. NOT EXECUTED."""

import pytest


pytestmark = pytest.mark.expected_red_not_authorized_for_execution


def test_coco_identity_constraint_vector_and_paired_ffe_expected_red():
    pytest.fail("EXPECTED_RED: COCO adapter and paired oracle are not authorized or installed")


@pytest.mark.parametrize("baseline", ["LSHADE44_IEPSILON", "AL_CMA_ES", "COBYLA"])
def test_external_baseline_identity_and_hidden_call_contract_expected_red(baseline):
    pytest.fail(f"EXPECTED_RED: {baseline} adapter is not authorized for implementation")

