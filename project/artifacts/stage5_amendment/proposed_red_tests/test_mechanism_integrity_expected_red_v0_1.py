"""Prepared expected-red contracts. NOT EXECUTED under current authorization."""

import pytest


pytestmark = pytest.mark.expected_red_not_authorized_for_execution


@pytest.mark.parametrize("contract_id", [f"MI-{index:02d}" for index in range(1, 11)])
def test_mechanism_integrity_contract_expected_red(contract_id):
    pytest.fail(f"EXPECTED_RED: {contract_id} has no separately authorized green implementation")

