"""Reports on the cloze review decisions.

Run from the repo root:
    .venv/bin/python shared/cloze_review/report.py agreement   # blind sample vs. current codes
    .venv/bin/python shared/cloze_review/report.py changes     # review mode: corrections to make

Writes decisions/blind_agreement.csv and decisions/blind_disagreements.csv,
or decisions/review_changes.csv, and prints a summary.
"""
import sys
from pathlib import Path

import pandas as pd

import review_logic as rl

HERE = Path(__file__).parent
DECISIONS = HERE / "decisions"


def main(command: str) -> None:
    items = rl.load_items(HERE / "review_items.csv")
    if command == "agreement":
        decisions = rl.load_decisions(DECISIONS / "blind.csv")
        blind_ids = set(items.dropna(subset=["blind_order"])["item_id"])
        if not set(decisions["item_id"]) <= blind_ids:
            raise ValueError("blind.csv has decisions for items outside the blind sample")
        if decisions.empty:
            raise ValueError("No blind decisions yet")
        print(f"{len(decisions)} of {len(blind_ids)} blind-sample completions coded")
        table = rl.agreement_table(items, decisions)
        table.to_csv(DECISIONS / "blind_agreement.csv", index=False)
        print(table.to_string(index=False, float_format=lambda x: f"{x:.3f}"))
        disagreements = rl.review_changes(items, decisions)
        disagreements.to_csv(DECISIONS / "blind_disagreements.csv", index=False)
        print(f"{len(disagreements)} disagreements -> decisions/blind_disagreements.csv")
    elif command == "changes":
        decisions = rl.load_decisions(DECISIONS / "review.csv")
        if decisions.empty:
            raise ValueError("No review decisions yet")
        changes = rl.review_changes(items, decisions)
        changes.to_csv(DECISIONS / "review_changes.csv", index=False)
        print(f"{len(decisions)} completions reviewed; {changes['response'].nunique()} with changes "
              f"({len(changes)} fields) -> decisions/review_changes.csv")
    else:
        raise ValueError(f"Unknown command {command!r}; use 'agreement' or 'changes'")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
