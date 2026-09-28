from __future__ import annotations
from sqlmodel import SQLModel, Field


class DataPointBase(SQLModel):
    name: str = Field(min_length=1, max_length=120)
    source_type: str = Field(default="modbus", regex="^(modbus|gpio|usb)$")
    address: str = Field(default="", max_length=120)
    host: str = Field(default="", max_length=255)
    port: int = Field(default=502, ge=502, le=510)
    function_code: int = Field(default=1, ge=1, le=4)
    unit_id: int = Field(default=1, ge=0, le=247)
    x: float = Field(default=50, ge=0, le=100)
    y: float = Field(default=50, ge=0, le=100)
    state: bool = False


class DataPoint(DataPointBase, table=True):
    id: int | None = Field(default=None, primary_key=True)


class DataPointCreate(DataPointBase):
    pass


class DataPointUpdate(SQLModel):
    name: str | None = Field(default=None, min_length=1, max_length=120)
    source_type: str | None = Field(default=None, regex="^(modbus|gpio|usb)$")
    address: str | None = Field(default=None, max_length=120)
    host: str | None = Field(default=None, max_length=255)
    port: int | None = Field(default=None, ge=502, le=510)
    function_code: int | None = Field(default=None, ge=1, le=4)
    unit_id: int | None = Field(default=None, ge=0, le=247)
    x: float | None = Field(default=None, ge=0, le=100)
    y: float | None = Field(default=None, ge=0, le=100)
    state: bool | None = None
