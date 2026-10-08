"""End-to-end tests of app.py with Streamlit's AppTest, on the real review_items.csv."""
import json
from pathlib import Path

import pytest
from streamlit.testing.v1 import AppTest

import review_logic as rl

APP = str(Path(__file__).parent.parent / "app.py")


@pytest.fixture
def app(tmp_path, monkeypatch):
    monkeypatch.setenv("CLOZE_REVIEW_DECISIONS_DIR", str(tmp_path))
    at = AppTest.from_file(APP, default_timeout=30)
    at.run()
    assert not at.exception
    return at


def fill_and_save(at, referent="neither", code="other"):
    at.sidebar.text_input(key="coder").set_value("tester")
    for radio in at.radio:
        if radio.label.endswith("refers to"):
            radio.set_value(referent)
    at.selectbox[0].set_value(code)
    at.radio(key=[r.key for r in at.radio if r.key and r.key.endswith("-nonsense")][0]).set_value(False)
    at.button[0].click()  # the form's "Save and next"
    at.run()


def test_blind_mode_hides_current_codes_and_starts_empty(app):
    assert app.sidebar.radio[0].value == "blind"
    assert not any("Current codes" in m.value for m in app.markdown)
    assert app.selectbox[0].value is None


def test_saving_a_blind_item_writes_a_decision_and_advances(app, tmp_path):
    first_heading = app.subheader[0].value
    fill_and_save(app)
    assert not app.exception
    decisions = rl.load_decisions(tmp_path / "blind.csv")
    assert len(decisions) == 1 and decisions.loc[0, "coder"] == "tester"
    assert decisions.loc[0, "cloze_code"] == "other"
    referents = json.loads(decisions.loc[0, "referents"])
    assert set(referents.values()) <= {"neither"}
    assert app.subheader[0].value != first_heading


def test_saving_without_answers_shows_errors_and_writes_nothing(app, tmp_path):
    app.button[0].click()
    app.run()
    assert len(app.error) >= 2
    assert not (tmp_path / "blind.csv").exists()


def test_review_mode_shows_current_codes_prefilled(app):
    app.sidebar.radio[0].set_value("review")
    app.run()
    assert not app.exception
    assert any("Current codes" in m.value for m in app.markdown)
    assert app.selectbox[0].value is not None


def test_prompt_and_completion_are_visibly_separated(app):
    cloze = next(m.value for m in app.markdown if "class='cloze'" in m.value)
    prompt_end = cloze.index("</span>")
    assert cloze.index("class='prompt-end'") > prompt_end
    assert cloze.index("class='prompt-end'") < cloze.index("class='completion'")


def test_app_picks_up_a_regenerated_items_file(tmp_path, monkeypatch):
    # Regression: the item list was cached for the life of the app, so a
    # regenerated review_items.csv (new columns) crashed a running app.
    items_file = tmp_path / "review_items.csv"
    original = (Path(APP).parent / "review_items.csv").read_text()
    lines = original.splitlines(keepends=True)
    items_file.write_text("".join(lines[:200]))  # header + 199 completions
    monkeypatch.setenv("CLOZE_REVIEW_ITEMS_FILE", str(items_file))
    monkeypatch.setenv("CLOZE_REVIEW_DECISIONS_DIR", str(tmp_path))
    at = AppTest.from_file(APP, default_timeout=30)
    at.run()
    at.sidebar.radio[0].set_value("review")
    at.run()
    before = at.subheader[0].value
    items_file.write_text(original)
    at.run()
    assert not at.exception
    assert at.subheader[0].value != before


def test_nonsense_reasons_include_doesnt_make_sense(app):
    reason_box = next(s for s in app.selectbox if s.label.startswith("If nonsense"))
    assert "doesn't make sense" in reason_box.options
