"""Tests for review_logic.py (the cloze review app's non-UI logic)."""
import json
import math
from pathlib import Path

import pandas as pd
import pytest

import review_logic as rl


def make_items_csv(tmp_path: Path, rows: list[dict]) -> Path:
    """Write a minimal review_items.csv with the given rows (spans as lists)."""
    defaults = {
        "study": "2024", "cloze_item": "1", "prompt": "The president said that", "n_sessions": 1,
        "cloze_code": "other", "first_coref_pronoun": "none", "cloze_nonsense": False,
        "cloze_nonsense_reason": "", "spans": [], "blind_order": "", "priority": False,
        "priority_reasons": "",
        **{col: False for col in rl.COREF_COLUMNS},
    }
    full = [{**defaults, **row} for row in rows]
    for row in full:
        row["spans"] = json.dumps(row["spans"])
    path = tmp_path / "review_items.csv"
    pd.DataFrame(full).to_csv(path, index=False)
    return path


def span(text: str, sub: str, kind: str, occurrence: int = 0) -> dict:
    start = -1
    for _ in range(occurrence + 1):
        start = text.index(sub, start + 1)
    return {"start": start, "end": start + len(sub), "kind": kind, "text": sub}


# load_items --------------------------------------------------------------------

def test_load_items_parses_spans_and_assigns_stable_ids(tmp_path):
    text = "she will win"
    path = make_items_csv(tmp_path, [{"response": text, "spans": [span(text, "she", "she")]}])
    items = rl.load_items(path)
    assert items.loc[0, "spans"] == [span(text, "she", "she")]
    assert items.loc[0, "item_id"] == rl.item_id("2024", "1", text)


def test_load_items_rejects_span_that_does_not_match_text(tmp_path):
    bad = {"start": 0, "end": 3, "kind": "she", "text": "her"}
    path = make_items_csv(tmp_path, [{"response": "she will win", "spans": [bad]}])
    with pytest.raises(ValueError, match="does not match"):
        rl.load_items(path)


def test_load_items_rejects_overlapping_spans(tmp_path):
    text = "his or her plan"
    spans = [span(text, "his or her", "hedged"), span(text, "her", "she")]
    path = make_items_csv(tmp_path, [{"response": text, "spans": spans}])
    with pytest.raises(ValueError, match="overlap"):
        rl.load_items(path)


def test_item_id_differs_by_study_item_and_text():
    ids = {rl.item_id("2020", "1", "she"), rl.item_id("2024", "1", "she"),
           rl.item_id("2020", "2", "she"), rl.item_id("2020", "1", "he")}
    assert len(ids) == 4


# render_html -------------------------------------------------------------------

def test_render_html_marks_spans_and_numbers_pronouns_only():
    text = "Harris said she would"
    spans = [span(text, "Harris", "female_candidate_name"), span(text, "she", "she")]
    html = rl.render_html(text, spans)
    assert 'class="ref ref-female_candidate_name"' in html
    assert ">Harris</mark>" in html
    assert ">she<sup>1</sup></mark>" in html
    assert html.startswith("<mark")


def test_render_html_escapes_the_completion():
    html = rl.render_html("<b>x</b> & y", [])
    assert html == "&lt;b&gt;x&lt;/b&gt; &amp; y"


# referents -> codes ---------------------------------------------------------------

def test_prefill_maps_current_codes_to_each_pronoun():
    text = "she told him that he"
    spans = [span(text, "she", "she"), span(text, "him", "he"), span(text, "he", "he", occurrence=1)]
    codes = {col: False for col in rl.COREF_COLUMNS} | {"coref_she": True, "coref_other_he": True}
    prefilled = rl.prefill_referents(spans, codes)
    assert prefilled == {rl.span_key(spans[0]): "target",
                         rl.span_key(spans[1]): "other_office",
                         rl.span_key(spans[2]): "other_office"}


def test_prefill_leaves_ambiguous_kind_undecided():
    # A kind that refers to both office-holders can't be assigned per token.
    text = "he and he"
    spans = [span(text, "he", "he"), span(text, "he", "he", occurrence=1)]
    codes = {col: False for col in rl.COREF_COLUMNS} | {"coref_he": True, "coref_other_he": True}
    assert set(rl.prefill_referents(spans, codes).values()) == {None}


def test_derive_codes_from_referents():
    text = "he said she and they"
    spans = [span(text, "he", "he"), span(text, "she", "she"), span(text, "they", "they")]
    referents = {rl.span_key(spans[0]): "neither", rl.span_key(spans[1]): "target",
                 rl.span_key(spans[2]): "other_office"}
    codes = rl.derive_codes(spans, referents)
    assert codes["coref_she"] and codes["coref_other_they"]
    assert not codes["coref_he"] and not codes["coref_other_he"]
    assert codes["first_coref_pronoun"] == "she"


def test_derive_codes_ignores_non_pronoun_spans_and_reports_none():
    text = "Harris wins"
    spans = [span(text, "Harris", "female_candidate_name")]
    codes = rl.derive_codes(spans, {})
    assert codes["first_coref_pronoun"] == "none"
    assert not any(codes[col] for col in rl.COREF_COLUMNS)


def test_derive_codes_requires_every_pronoun_decided():
    text = "she wins"
    spans = [span(text, "she", "she")]
    with pytest.raises(ValueError, match="undecided"):
        rl.derive_codes(spans, {rl.span_key(spans[0]): None})


# decisions file ----------------------------------------------------------------------

def test_decisions_round_trip_and_upsert(tmp_path):
    path = tmp_path / "decisions.csv"
    decisions = rl.load_decisions(path)
    assert decisions.empty and list(decisions.columns) == rl.DECISION_COLUMNS
    first = {col: "" for col in rl.DECISION_COLUMNS} | {"item_id": "a", "cloze_code": "she"}
    decisions = rl.upsert_decision(decisions, first)
    decisions = rl.upsert_decision(decisions, first | {"cloze_code": "he"})
    rl.save_decisions(decisions, path)
    reloaded = rl.load_decisions(path)
    assert len(reloaded) == 1 and reloaded.loc[0, "cloze_code"] == "he"


def test_upsert_rejects_unknown_columns():
    with pytest.raises(ValueError, match="columns"):
        rl.upsert_decision(rl.empty_decisions(), {"item_id": "a", "surprise": 1})


def test_next_undone_item():
    assert rl.next_undone(["a", "b", "c"], {"a", "c"}) == "b"
    assert rl.next_undone(["a"], {"a"}) is None


# agreement ----------------------------------------------------------------------------

def test_cohen_kappa_known_values():
    assert rl.cohen_kappa(["a", "b", "a", "b"], ["a", "b", "a", "b"]) == 1
    # 2x2 table [[20, 5], [10, 15]]: po = .7, pe = .5 -> kappa = .4
    a = ["y"] * 25 + ["n"] * 25
    b = ["y"] * 20 + ["n"] * 5 + ["y"] * 10 + ["n"] * 15
    assert rl.cohen_kappa(a, b) == pytest.approx(0.4)


def test_cohen_kappa_undefined_when_both_constant():
    assert math.isnan(rl.cohen_kappa(["a", "a"], ["a", "a"]))


def test_agreement_restricts_coreference_to_items_with_that_pronoun(tmp_path):
    she_text, plain_text = "she wins", "the end"
    path = make_items_csv(tmp_path, [
        {"response": she_text, "spans": [span(she_text, "she", "she")], "coref_she": True,
         "cloze_code": "she", "first_coref_pronoun": "she"},
        {"response": plain_text, "spans": []},
    ])
    items = rl.load_items(path)
    decisions = pd.DataFrame([
        {col: "" for col in rl.DECISION_COLUMNS} | {"item_id": items.loc[0, "item_id"], "cloze_code": "she",
                                                    "first_coref_pronoun": "she", "cloze_nonsense": "False",
                                                    **{c: str(c == "coref_she") for c in rl.COREF_COLUMNS}},
        {col: "" for col in rl.DECISION_COLUMNS} | {"item_id": items.loc[1, "item_id"], "cloze_code": "other",
                                                    "first_coref_pronoun": "none", "cloze_nonsense": "False",
                                                    **{c: "False" for c in rl.COREF_COLUMNS}},
    ])
    table = rl.agreement_table(items, decisions).set_index("code")
    assert table.loc["coref_she", "n"] == 1
    assert table.loc["coref_he", "n"] == 0
    assert table.loc["cloze_code", "n"] == 2
    assert table.loc["cloze_code", "agreement"] == 1


def test_review_changes_lists_only_fields_that_differ(tmp_path):
    text = "he wins"
    path = make_items_csv(tmp_path, [{"response": text, "spans": [span(text, "he", "he")], "coref_he": True,
                                      "cloze_code": "he", "first_coref_pronoun": "he"}])
    items = rl.load_items(path)
    decision = {col: "" for col in rl.DECISION_COLUMNS} | {
        "item_id": items.loc[0, "item_id"], "cloze_code": "he", "first_coref_pronoun": "none",
        "cloze_nonsense": "False", "note": "he = Trump",
        **{c: str(c == "coref_other_he") for c in rl.COREF_COLUMNS}}
    changes = rl.review_changes(items, pd.DataFrame([decision]))
    assert set(changes["field"]) == {"coref_he", "coref_other_he", "first_coref_pronoun"}
    assert changes.set_index("field").loc["coref_he", "current"] == "True"
    assert changes.set_index("field").loc["coref_he", "coder"] == "False"
    assert (changes["note"] == "he = Trump").all()
