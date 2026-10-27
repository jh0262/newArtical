"""Prepared expected-red novelty-control contracts. NOT EXECUTED."""

import pytest


pytestmark = pytest.mark.expected_red_not_authorized_for_execution


def test_ray_style_minimum_overlap_no_graph_input_expected_red():
    pytest.fail("EXPECTED_RED: clean-room Ray-style control is not authorized for implementation")


def test_control_roster_rng_fallback_and_ffe_schema_expected_red():
    pytest.fail("EXPECTED_RED: graph-specific control roster and paired-FFE schema are not implemented")

