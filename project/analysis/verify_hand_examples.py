"""Exact arithmetic checks of fixed mathematical examples; no optimizer runs."""
from fractions import Fraction as Q
from itertools import combinations
from pathlib import Path
import json


def hv_union(points, reference):
    # Independent rectangle-union calculation by inclusion-exclusion.
    total = Q(0)
    for size in range(1, len(points) + 1):
        for group in combinations(points, size):
            corner = tuple(max(p[d] for p in group) for d in range(2))
            area = max(Q(0), reference[0] - corner[0]) * max(
                Q(0), reference[1] - corner[1]
            )
            total += area if size % 2 else -area
    return total


def individual_loss(points, index):
    return (points[index + 1][0] - points[index][0]) * (
        points[index - 1][1] - points[index][1]
    )


def main():
    reference = (Q(11, 10), Q(11, 10))
    triangle = [(Q(0), Q(1)), (Q(1, 2), Q(1, 2)), (Q(1), Q(0))]
    a, b, c = triangle
    area = abs((b[0] - a[0]) * (c[1] - a[1]) -
               (b[1] - a[1]) * (c[0] - a[0])) / 2
    loss = hv_union(triangle, reference) - hv_union([a, c], reference)
    assert area == 0 and loss == Q(1, 4)
    assert hv_union(triangle, reference) == Q(46, 100)
    assert hv_union([a, c], reference) == Q(21, 100)

    four = [(Q(i, 3), Q(3-i, 3)) for i in range(4)]
    separate = sum(individual_loss(four, i) for i in [1, 2])
    joint = hv_union(four, reference) - hv_union([four[0], four[3]], reference)
    cross = (four[3][0] - four[2][0]) * (four[0][1] - four[1][1])
    assert separate == Q(2, 9) and joint == Q(1, 3)
    assert joint == separate + cross

    five = [(Q(i, 4), Q(4-i, 4)) for i in range(5)]
    nonadjacent = hv_union(five, reference) - hv_union(
        [five[i] for i in [0, 2, 4]], reference
    )
    summed = sum(individual_loss(five, i) for i in [1, 3])
    assert nonadjacent == summed == Q(1, 8)
    report = {
        "status": "PASS_FIXED_ANALYTIC_EXAMPLES",
        "arithmetic": "exact_rational",
        "independent_check": "rectangle_union_inclusion_exclusion",
        "collinear_triangle_area": str(area),
        "collinear_point_hv_loss": str(loss),
        "adjacent_sum_of_individual_losses": str(separate),
        "adjacent_joint_loss": str(joint),
        "adjacent_interaction": str(cross),
        "nonadjacent_joint_loss": str(nonadjacent),
        "new_optimizer_performance_runs": 0,
        "limitations": "Fixed examples only; not novelty, general proof, or optimizer performance evidence."
    }
    output = Path(__file__).with_name("analytic_checks.json")
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False))


if __name__ == "__main__":
    main()
