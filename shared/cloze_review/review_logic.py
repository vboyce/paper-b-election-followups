"""Non-UI logic for the cloze review app (app.py): loading items, highlighting,
turning per-pronoun referent choices into codes, saving decisions, and
scoring agreement. Testable without Streamlit (tests/test_review_logic.py).
"""
import hashlib
import html
import json
import math
import os
from collections import Counter
from pathlib import Path

import pandas as pd

PRONOUN_KINDS = ["hedged", "she", "he", "they"]
# Coreference column for each pronoun kind ("hedged" spans -> coref_hedge).
_COREF_SUFFIX = {"hedged": "hedge", "she": "she", "he": "he", "they": "they"}
COREF_COLUMNS = ([f"coref_{_COREF_SUFFIX[k]}" for k in PRONOUN_KINDS] +
                 [f"coref_other_{_COREF_SUFFIX[k]}" for k in PRONOUN_KINDS])
# The pronoun kind each coref_* column is about.
COREF_COLUMN_KIND = {f"{prefix}{_COREF_SUFFIX[k]}": k for prefix in ("coref_", "coref_other_") for k in PRONOUN_KINDS}

# What a pronoun can refer to.
REFERENTS = ["target", "other_office", "neither"]

CLOZE_CODES = ["she", "he", "they", "hedged", "female_candidate_name", "male_candidate_name",
               "other_candidate_name", "target_office_np", "other_office_np", "generic_np", "other", "blank"]
# The reasons the coding uses (cloze_nonsense_reason), plus "doesnt_make_sense"
# for the coder (added 2026-10-08).
NONSENSE_REASONS = ["doesnt_make_sense", "blank", "filler_or_number", "pasted_id", "copied_context", "pasted_text",
                    "single_word"]

DECISION_COLUMNS = (["item_id", "study", "cloze_item", "response", "coder", "saved_at", "cloze_code",
                     "referents"] + COREF_COLUMNS +
                    ["first_coref_pronoun", "cloze_nonsense", "cloze_nonsense_reason", "note"])


# Items ------------------------------------------------------------------------------

def item_id(study: str, cloze_item: str, response: str) -> str:
    """Stable id for a unique completion, so decisions survive regenerating the items."""
    key = "\x1f".join([str(study), str(cloze_item), response])
    return hashlib.sha1(key.encode("utf-8")).hexdigest()[:12]


def _check_spans(response: str, spans: list[dict]) -> None:
    for s in spans:
        if response[s["start"]:s["end"]] != s["text"]:
            raise ValueError(f"Span {s} does not match the text of {response!r}")
    for previous, current in zip(spans, spans[1:]):
        if current["start"] < previous["end"]:
            raise ValueError(f"Spans {previous} and {current} overlap in {response!r}")


def load_items(path: Path) -> pd.DataFrame:
    """Read review_items.csv (from prepare_cloze_review.R), parse and check the spans."""
    items = pd.read_csv(path, dtype={"study": str, "cloze_item": str, "response": str},
                        keep_default_na=False, na_values={"blind_order": [""]})
    items["spans"] = [sorted(json.loads(s), key=lambda sp: sp["start"]) for s in items["spans"]]
    for response, spans in zip(items["response"], items["spans"]):
        _check_spans(response, spans)
    for col in COREF_COLUMNS + ["cloze_nonsense", "priority"]:
        items[col] = items[col].map(as_bool)
    items["item_id"] = [item_id(s, i, r) for s, i, r in zip(items["study"], items["cloze_item"], items["response"])]
    if items["item_id"].duplicated().any():
        raise ValueError("Duplicate completions in the items file")
    return items


def as_bool(value) -> bool:
    if isinstance(value, bool):
        return value
    text = str(value).strip().lower()
    if text in ("true", "1"):
        return True
    if text in ("false", "0"):
        return False
    raise ValueError(f"Not a TRUE/FALSE value: {value!r}")


# Highlighting -----------------------------------------------------------------------------

def render_html(response: str, spans: list[dict]) -> str:
    """The completion as HTML, each matched reference in a <mark> with class
    ref-<kind>. Pronouns are numbered (<sup>) to match the referent controls."""
    parts, position, pronoun_number = [], 0, 0
    for s in spans:
        parts.append(html.escape(response[position:s["start"]]))
        label = ""
        if s["kind"] in PRONOUN_KINDS:
            pronoun_number += 1
            label = f"<sup>{pronoun_number}</sup>"
        parts.append(f'<mark class="ref ref-{s["kind"]}" title="{s["kind"]}">'
                     f'{html.escape(s["text"])}{label}</mark>')
        position = s["end"]
    parts.append(html.escape(response[position:]))
    return "".join(parts)


# Referents <-> codes ---------------------------------------------------------------------------

def span_key(span: dict) -> str:
    return f'{span["start"]}-{span["end"]}-{span["kind"]}'


def pronoun_spans(spans: list[dict]) -> list[dict]:
    return [s for s in spans if s["kind"] in PRONOUN_KINDS]


def prefill_referents(spans: list[dict], codes: dict) -> dict:
    """Per-pronoun referents implied by the current codes. The codes are per
    pronoun kind, so a kind that refers to both office-holders is left
    undecided (None) for the coder."""
    prefilled = {}
    for s in pronoun_spans(spans):
        suffix = _COREF_SUFFIX[s["kind"]]
        target, other = as_bool(codes[f"coref_{suffix}"]), as_bool(codes[f"coref_other_{suffix}"])
        if target and other:
            prefilled[span_key(s)] = None
        elif target:
            prefilled[span_key(s)] = "target"
        elif other:
            prefilled[span_key(s)] = "other_office"
        else:
            prefilled[span_key(s)] = "neither"
    return prefilled


def derive_codes(spans: list[dict], referents: dict) -> dict:
    """coref_* columns and first_coref_pronoun from per-pronoun referents."""
    codes = {col: False for col in COREF_COLUMNS}
    first = "none"
    for s in pronoun_spans(spans):  # spans are in text order
        referent = referents.get(span_key(s))
        if referent not in REFERENTS:
            raise ValueError(f"Pronoun {s['text']!r} at {s['start']} is undecided")
        suffix = _COREF_SUFFIX[s["kind"]]
        if referent == "target":
            codes[f"coref_{suffix}"] = True
            if first == "none":
                first = s["kind"]
        elif referent == "other_office":
            codes[f"coref_other_{suffix}"] = True
    codes["first_coref_pronoun"] = first
    return codes


# Decisions ----------------------------------------------------------------------------------------

def empty_decisions() -> pd.DataFrame:
    return pd.DataFrame(columns=DECISION_COLUMNS, dtype=str)


def load_decisions(path: Path) -> pd.DataFrame:
    if not Path(path).exists():
        return empty_decisions()
    decisions = pd.read_csv(path, dtype=str, keep_default_na=False)
    if list(decisions.columns) != DECISION_COLUMNS:
        raise ValueError(f"{path} has columns {list(decisions.columns)}, expected {DECISION_COLUMNS}")
    return decisions


def upsert_decision(decisions: pd.DataFrame, row: dict) -> pd.DataFrame:
    """Add a decision, replacing any earlier one for the same item."""
    if set(row) != set(DECISION_COLUMNS):
        raise ValueError(f"Decision columns {sorted(row)} differ from {sorted(DECISION_COLUMNS)}")
    kept = decisions[decisions["item_id"] != row["item_id"]]
    new = pd.DataFrame([{col: str(row[col]) for col in DECISION_COLUMNS}])
    return pd.concat([kept, new], ignore_index=True) if len(kept) else new


def save_decisions(decisions: pd.DataFrame, path: Path) -> None:
    """Write via a temporary file, so a crash can't leave a half-written file."""
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".tmp")
    decisions.to_csv(tmp, index=False)
    os.replace(tmp, path)


def next_undone(order: list[str], done: set[str]):
    return next((i for i in order if i not in done), None)


# Agreement --------------------------------------------------------------------------------------------

def cohen_kappa(a: list, b: list) -> float:
    """Cohen's kappa for two raters' labels; NaN if chance agreement is 1."""
    if len(a) != len(b) or not a:
        raise ValueError("Need two equally long, non-empty label lists")
    n = len(a)
    observed = sum(x == y for x, y in zip(a, b)) / n
    count_a, count_b = Counter(a), Counter(b)
    expected = sum(count_a[label] * count_b[label] for label in set(a) | set(b)) / n ** 2
    if expected == 1:
        return math.nan
    return (observed - expected) / (1 - expected)


SCORED_CODES = ["cloze_code", "first_coref_pronoun", "cloze_nonsense"] + COREF_COLUMNS


def _merge_with_items(items: pd.DataFrame, decisions: pd.DataFrame) -> pd.DataFrame:
    merged = decisions.merge(items, on="item_id", how="inner", suffixes=("_coder", "_current"),
                             validate="one_to_one")
    if len(merged) != len(decisions):
        raise ValueError("Some decisions are for items not in the items file")
    return merged


def _compared_values(rows: pd.DataFrame, code: str) -> tuple[list[str], list[str]]:
    """Coder and current values of one code as comparable strings."""
    coder, current = rows[f"{code}_coder"], rows[f"{code}_current"]
    if code in COREF_COLUMNS or code == "cloze_nonsense":
        coder, current = coder.map(as_bool), current.map(as_bool)
    return [str(v) for v in coder], [str(v) for v in current]


def agreement_table(items: pd.DataFrame, decisions: pd.DataFrame) -> pd.DataFrame:
    """Coder vs. current codes, per code. Coreference columns are scored only
    over completions containing that kind of pronoun (elsewhere both are
    trivially FALSE)."""
    merged = _merge_with_items(items, decisions)
    rows = []
    for code in SCORED_CODES:
        subset = merged
        if code in COREF_COLUMNS:
            kind = COREF_COLUMN_KIND[code]
            subset = merged[merged["spans"].map(lambda spans: any(s["kind"] == kind for s in spans))]
        coder, current = _compared_values(subset, code)
        n = len(subset)
        rows.append({"code": code, "n": n,
                     "agreement": sum(x == y for x, y in zip(coder, current)) / n if n else math.nan,
                     "kappa": cohen_kappa(coder, current) if n else math.nan})
    return pd.DataFrame(rows)


def review_changes(items: pd.DataFrame, decisions: pd.DataFrame) -> pd.DataFrame:
    """One row per (completion, code) where the coder's value differs from the current code."""
    merged = _merge_with_items(items, decisions)
    rows = []
    for code in SCORED_CODES:
        coder, current = _compared_values(merged, code)
        for (_, item), coder_value, current_value in zip(merged.iterrows(), coder, current):
            if coder_value != current_value:
                rows.append({"study": item["study_current"], "cloze_item": item["cloze_item_current"],
                             "response": item["response_current"], "field": code, "current": current_value,
                             "coder": coder_value, "note": item["note"]})
    return pd.DataFrame(rows, columns=["study", "cloze_item", "response", "field", "current", "coder", "note"])


# Hand-review export ---------------------------------------------------------------------------------------

HAND_REVIEW_COLUMNS = (["study", "cloze_item", "response", "source", "coder", "cloze_code"] + COREF_COLUMNS +
                       ["first_coref_pronoun", "cloze_nonsense", "cloze_nonsense_reason", "note"])
_BARE_NUMBER = r"^[0-9\s\W_]+$"


def hand_review_table(items: pd.DataFrame, blind: pd.DataFrame, review: pd.DataFrame) -> pd.DataFrame:
    """The coder's decisions as overrides for the prep (shared/cloze_hand_review.csv).

    - Review decisions apply in full.
    - Blind decisions for completions not reviewed change only the nonsense
      flag; cloze_code and coreference keep the rule codes (the blind
      cloze_code differences were definitional slips, decided 2026-10-08).
    - Bare numbers are always nonsense (by rule); no decision unflags them.
    """
    by_id = items.set_index("item_id")
    rows = []
    for source, decisions in (("review", review), ("blind", blind[~blind["item_id"].isin(review["item_id"])])):
        for _, d in decisions.iterrows():
            item = by_id.loc[d["item_id"]]
            if source == "review":
                codes = {col: d[col] for col in ["cloze_code", "first_coref_pronoun"]}
                codes |= {col: as_bool(d[col]) for col in COREF_COLUMNS}
            else:
                codes = {col: item[col] for col in ["cloze_code", "first_coref_pronoun"] + COREF_COLUMNS}
            nonsense = as_bool(d["cloze_nonsense"])
            reason = d["cloze_nonsense_reason"] if nonsense else ""
            if pd.Series([item["response"]]).str.match(_BARE_NUMBER).iloc[0]:
                nonsense, reason = True, "filler_or_number"
            rows.append({"study": item["study"], "cloze_item": item["cloze_item"], "response": item["response"],
                         "source": source, "coder": d["coder"], **codes, "cloze_nonsense": nonsense,
                         "cloze_nonsense_reason": reason, "note": d["note"]})
    return pd.DataFrame(rows, columns=HAND_REVIEW_COLUMNS)
