"""Cloze review app: blind recoding of a random sample, and review of the
completions whose codes rest on hand judgments. See README.md.

Run from the repo root:
    .venv/bin/streamlit run shared/cloze_review/app.py
"""
import html
import json
import os
from datetime import datetime
from pathlib import Path

import streamlit as st

import review_logic as rl

HERE = Path(__file__).parent
ITEMS_FILE = HERE / "review_items.csv"
# CLOZE_REVIEW_DECISIONS_DIR is only for tests (tests/test_app.py).
DECISIONS_DIR = Path(os.environ.get("CLOZE_REVIEW_DECISIONS_DIR", HERE / "decisions"))
DECISIONS_FILES = {"blind": DECISIONS_DIR / "blind.csv", "review": DECISIONS_DIR / "review.csv"}
MODE_LABELS = {"blind": "Blind recode (random sample)", "review": "Review (hand-judged completions)"}

# Highlight colours by kind of reference; pronouns are the ones to judge.
CSS = """
<style>
.cloze { font-size: 1.25rem; line-height: 2.2; }
.cloze .prompt { color: #6b6b6b; }
mark.ref { padding: 0.1em 0.25em; border-radius: 0.25em; color: inherit; }
mark.ref sup { font-weight: 700; margin-left: 0.1em; }
mark.ref-she { background: rgba(217, 95, 2, 0.35); }
mark.ref-he { background: rgba(27, 158, 119, 0.35); }
mark.ref-they { background: rgba(117, 112, 179, 0.40); }
mark.ref-hedged { background: rgba(150, 150, 150, 0.45); }
mark.ref-female_candidate_name, mark.ref-male_candidate_name, mark.ref-other_candidate_name {
  background: transparent; border-bottom: 3px solid #e6ab02; border-radius: 0; }
mark.ref-target_office_np, mark.ref-other_office_np, mark.ref-generic_np {
  background: transparent; border-bottom: 3px dashed #1f78b4; border-radius: 0; }
</style>
"""
LEGEND = ("Highlighted: pronouns (numbered; say who each refers to) · "
          "<span style='border-bottom:3px solid #e6ab02'>candidate names</span> · "
          "<span style='border-bottom:3px dashed #1f78b4'>office / winner noun phrases</span>. "
          "Highlights are what the coding rules matched; anything they missed is not highlighted.")


def code_labels(study: str) -> dict:
    office, other_office = ("vice president", "president") if study == "2020" else ("president", "vice president")
    return {
        "she": "she (her, hers, herself)",
        "he": "he (him, his, himself)",
        "they": "they (them, their, ...)",
        "hedged": "hedged (he or she, his/her, s/he, ...)",
        "female_candidate_name": "Harris / Kamala",
        "male_candidate_name": "Pence" if study == "2020" else "Trump / Donald",
        "other_candidate_name": "Biden / Trump (other office)" if study == "2020" else "(no other candidates in 2024)",
        "target_office_np": f"'the {office}' (target office)",
        "other_office_np": f"'the {other_office}' (other office)",
        "generic_np": "'the winner' / 'the candidate'",
        "other": "none of these",
        "blank": "blank",
    }


def referent_labels(study: str) -> dict:
    office, other_office = ("vice president", "president") if study == "2020" else ("president", "vice president")
    return {"target": f"the {office} (target)", "other_office": f"the {other_office}",
            "neither": "someone / something else, or not referential"}


@st.cache_data
def load_items():
    return rl.load_items(ITEMS_FILE)


def mode_order(items, mode: str) -> list[str]:
    if mode == "blind":
        return list(items.dropna(subset=["blind_order"]).sort_values("blind_order")["item_id"])
    return list(items[items["priority"]]["item_id"])


def initial_values(item, mode: str, decisions) -> dict:
    """The form's starting values: an earlier decision for this item if there
    is one; otherwise the current codes (review) or nothing (blind)."""
    earlier = decisions[decisions["item_id"] == item["item_id"]]
    if len(earlier):
        row = earlier.iloc[0]
        return {"referents": json.loads(row["referents"]), "cloze_code": row["cloze_code"],
                "nonsense": rl.as_bool(row["cloze_nonsense"]), "reason": row["cloze_nonsense_reason"] or None,
                "note": row["note"]}
    if mode == "review":
        return {"referents": rl.prefill_referents(item["spans"], item), "cloze_code": item["cloze_code"],
                "nonsense": item["cloze_nonsense"], "reason": item["cloze_nonsense_reason"] or None, "note": ""}
    return {"referents": {}, "cloze_code": None, "nonsense": None, "reason": None, "note": ""}


def index_of(options: list, value):
    return options.index(value) if value in options else None


def show_current_codes(item, labels: dict) -> None:
    nonsense = f"yes ({item['cloze_nonsense_reason']})" if item["cloze_nonsense"] else "no"
    st.markdown(f"**Current codes** · first reference: {labels[item['cloze_code']]} · "
                f"first target pronoun: {item['first_coref_pronoun']} · nonsense: {nonsense}  \n"
                f"Priority because: {item['priority_reasons']}")


def main():
    st.set_page_config(page_title="Cloze review", layout="wide")
    st.markdown(CSS, unsafe_allow_html=True)
    items = load_items()
    by_id = items.set_index("item_id", drop=False)

    with st.sidebar:
        mode = st.radio("Mode", list(MODE_LABELS), format_func=MODE_LABELS.get)
        coder = st.text_input("Coder", key="coder")
        decisions = rl.load_decisions(DECISIONS_FILES[mode])
        order = mode_order(items, mode)
        done = set(decisions["item_id"])
        st.progress(len(done & set(order)) / len(order), text=f"{len(done & set(order))} of {len(order)} done")
        positions = st.session_state.setdefault("positions", {})
        if mode not in positions:
            first_undone = rl.next_undone(order, done)
            positions[mode] = order.index(first_undone) if first_undone else 0
        if st.button("Go to first undone"):
            first_undone = rl.next_undone(order, done)
            positions[mode] = order.index(first_undone) if first_undone else positions[mode]
        if mode == "blind":
            st.caption("Blind mode hides the current codes. Do it before review mode for the same coder.")

    position = positions[mode]
    item = by_id.loc[order[position]]
    study = item["study"]
    labels, referents = code_labels(study), referent_labels(study)

    status = "done" if item["item_id"] in done else "not done yet"
    st.subheader(f"{position + 1} of {len(order)} ({status})")
    st.caption(f"Study {study} · item {item['cloze_item']} · {item['n_sessions']} session(s) typed this")
    st.markdown(f"<div class='cloze'><span class='prompt'>{html.escape(item['prompt'])}</span> "
                f"{rl.render_html(item['response'], item['spans'])}</div>", unsafe_allow_html=True)
    st.caption(LEGEND, unsafe_allow_html=True)
    if mode == "review":
        show_current_codes(item, labels)

    start = initial_values(item, mode, decisions)
    key = f"{mode}-{item['item_id']}"
    with st.form(key=f"form-{key}"):
        chosen_referents = {}
        for number, span in enumerate(rl.pronoun_spans(item["spans"]), start=1):
            span_id = rl.span_key(span)
            chosen_referents[span_id] = st.radio(
                f"{number}. “{span['text']}” refers to", rl.REFERENTS, format_func=referents.get, horizontal=True,
                index=index_of(rl.REFERENTS, start["referents"].get(span_id)), key=f"{key}-{span_id}")
        cloze_code = st.selectbox(
            "First referring expression in the completion (cloze_code)", rl.CLOZE_CODES, format_func=labels.get,
            index=index_of(rl.CLOZE_CODES, start["cloze_code"]), key=f"{key}-code",
            help="The first expression of any of these kinds, whoever it refers to. Office nouns count after "
                 "a determiner ('the', 'next', 'our', ...) or at the very start; 'will become president' does not.")
        nonsense = st.radio("Nonsense / not a real attempt?", [False, True], horizontal=True,
                            format_func={False: "no", True: "yes"}.get,
                            index=index_of([False, True], start["nonsense"]), key=f"{key}-nonsense")
        reason = st.selectbox("If nonsense: why", rl.NONSENSE_REASONS, index=index_of(rl.NONSENSE_REASONS, start["reason"]),
                              key=f"{key}-reason")
        note = st.text_input("Note (optional: a missed reference, a doubt, ...)", value=start["note"], key=f"{key}-note")
        submitted = st.form_submit_button("Save and next", type="primary")

    if submitted:
        problems = []
        if not coder.strip():
            problems.append("Enter your name under Coder in the sidebar.")
        if any(v is None for v in chosen_referents.values()):
            problems.append("Say who every numbered pronoun refers to.")
        if cloze_code is None:
            problems.append("Choose the first referring expression.")
        if nonsense is None:
            problems.append("Say whether the completion is nonsense.")
        elif nonsense and reason is None:
            problems.append("Choose why it is nonsense.")
        if problems:
            for p in problems:
                st.error(p)
            st.stop()
        row = {"item_id": item["item_id"], "study": study, "cloze_item": item["cloze_item"],
               "response": item["response"], "coder": coder.strip(),
               "saved_at": datetime.now().isoformat(timespec="seconds"), "cloze_code": cloze_code,
               "referents": json.dumps(chosen_referents), **rl.derive_codes(item["spans"], chosen_referents),
               "cloze_nonsense": nonsense, "cloze_nonsense_reason": reason if nonsense else "", "note": note}
        rl.save_decisions(rl.upsert_decision(decisions, row), DECISIONS_FILES[mode])
        positions[mode] = min(position + 1, len(order) - 1)
        st.rerun()

    previous_col, next_col = st.columns(2)
    if previous_col.button("◀ Previous", disabled=position == 0):
        positions[mode] = position - 1
        st.rerun()
    if next_col.button("Skip ▶", disabled=position == len(order) - 1):
        positions[mode] = position + 1
        st.rerun()


main()
