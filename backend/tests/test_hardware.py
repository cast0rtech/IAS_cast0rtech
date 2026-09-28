import pytest


def parse_modbus_address(raw_str: str) -> int:
    raw_address = raw_str.strip().upper()
    address = int(raw_address[1:]) - 1 if raw_address.startswith("M") and raw_address[1:].isdigit() else int(raw_address)
    if address < 0 or address > 65535:
        raise ValueError(f"Address {address} out of bounds")
    return address


def test_address_conversion():
    assert parse_modbus_address("M1") == 0
    assert parse_modbus_address("m1") == 0
    assert parse_modbus_address("M16") == 15
    assert parse_modbus_address("0") == 0
    assert parse_modbus_address("500") == 500


def test_invalid_address():
    with pytest.raises(ValueError):
        parse_modbus_address("invalid")

    with pytest.raises(ValueError):
        parse_modbus_address("M0")  # results in -1

    with pytest.raises(ValueError):
        parse_modbus_address("70000")
