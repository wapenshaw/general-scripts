from datetime import datetime

import pytest

from outlook_mail import core


def test_filter_escapes_quotes_so_user_text_cannot_break_out():
    dasl = core.build_filter("o'brien", None, None, False, False)
    assert "'%o''brien%'" in dasl and dasl.startswith("@SQL=")


def test_query_terms_are_anded_each_across_subject_body_sender():
    dasl = core.build_filter("budget q4", None, None, False, False)
    assert dasl.count(" AND ") == 1 and dasl.count("textdescription") == 2


def test_no_criteria_means_no_filter():
    assert core.build_filter(None, None, None, False, False) is None
    assert core.build_filter("  ", None, None, False, False) is None


def test_unread_and_attachment_clauses():
    dasl = core.build_filter(None, "bob", None, True, True)
    assert '"urn:schemas:httpmail:read" = 0' in dasl
    assert '"urn:schemas:httpmail:hasattachment" = 1' in dasl
    assert core.PR_SENDER_SMTP_ADDRESS in dasl


def test_bare_until_date_includes_that_whole_day():
    assert core.parse_when("2026-11-24", end=True) == datetime(2026, 11, 25)
    assert core.parse_when("2026-11-24T10:30", end=True) == datetime(2026, 11, 24, 10, 30)
    assert core.parse_when("2026-11-24") == datetime(2026, 11, 24)


def test_bad_date_is_a_user_error():
    with pytest.raises(core.OutlookError):
        core.parse_when("last tuesday")


def test_clean_text_normalizes_crlf_and_blank_runs():
    assert core.clean_text("a  \r\n\r\n\r\n\r\nb\r\n") == "a\n\nb"
