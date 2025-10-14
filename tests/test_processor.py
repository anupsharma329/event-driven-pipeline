from lambda_fn.processor import process_records


def test_process_empty():
    res = process_records([])
    assert res["count"] == 0
    assert res["sums"] == {}


def test_process_numeric_sums():
    records = [{"a": 1, "b": 2}, {"a": 3, "b": 4}]
    res = process_records(records)
    assert res["count"] == 2
    assert res["sums"]["a"] == 4
    assert res["sums"]["b"] == 6
