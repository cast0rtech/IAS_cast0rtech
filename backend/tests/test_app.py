import os
import pytest
from fastapi.testclient import TestClient
from sqlmodel import Session, SQLModel, create_engine
from sqlmodel.pool import StaticPool

import sys
from pathlib import Path

# Add backend directory to sys.path so 'app' can be imported just like in Docker container
backend_dir = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(backend_dir))

os.environ["EMA_DATABASE_PATH"] = ":memory:"
os.environ["EMA_SIMULATION_MODE"] = "true"
os.environ["EMA_CSV_PATH"] = str(backend_dir.parent / "alarme.csv")

from app.main import app
from app.database import get_session
from app.notifications import csv_key, alarm_map
from app.models import DataPoint


# In-memory test engine for isolated database tests
@pytest.fixture(name="session")
def session_fixture():
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    SQLModel.metadata.create_all(engine)
    with Session(engine) as session:
        yield session


@pytest.fixture(name="client")
def client_fixture(session: Session):
    def get_session_override():
        return session

    app.dependency_overrides[get_session] = get_session_override
    with TestClient(app) as client:
        yield client
    app.dependency_overrides.clear()


def test_health_check(client: TestClient):
    response = client.get("/api/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"
    assert data["simulation_mode"] is True


def test_create_and_list_points(client: TestClient):
    payload = {
        "name": "Fire Detector Zone 1",
        "source_type": "modbus",
        "address": "M1",
        "host": "192.168.1.100",
        "port": 502,
        "function_code": 1,
        "unit_id": 1,
        "x": 25.5,
        "y": 40.0,
        "state": False,
    }
    create_res = client.post("/api/points", json=payload)
    assert create_res.status_code == 201
    created = create_res.json()
    assert created["id"] is not None
    assert created["name"] == "Fire Detector Zone 1"
    assert created["address"] == "M1"

    list_res = client.get("/api/points")
    assert list_res.status_code == 200
    points = list_res.json()
    assert len(points) == 1
    assert points[0]["id"] == created["id"]


def test_update_and_delete_point(client: TestClient):
    payload = {
        "name": "Motion Sensor",
        "source_type": "modbus",
        "address": "M4",
        "port": 502,
        "function_code": 2,
        "unit_id": 1,
        "x": 10.0,
        "y": 15.0,
        "state": False,
    }
    create_res = client.post("/api/points", json=payload)
    point_id = create_res.json()["id"]

    # Test update
    patch_res = client.patch(f"/api/points/{point_id}", json={"state": True, "name": "Motion Sensor Hall"})
    assert patch_res.status_code == 200
    updated = patch_res.json()
    assert updated["state"] is True
    assert updated["name"] == "Motion Sensor Hall"

    # Test delete
    del_res = client.delete(f"/api/points/{point_id}")
    assert del_res.status_code == 204

    # Confirm deleted
    list_res = client.get("/api/points")
    assert list_res.status_code == 200
    assert len(list_res.json()) == 0


def test_point_not_found(client: TestClient):
    assert client.get("/api/points/999").status_code == 404 if hasattr(client, "get") else True
    assert client.patch("/api/points/999", json={"name": "none"}).status_code == 404
    assert client.delete("/api/points/999").status_code == 404


def test_websocket_connection(client: TestClient):
    with client.websocket_connect("/ws") as websocket:
        websocket.send_text("ping")
        # Connection established and message sent successfully without error


def test_csv_key_normalization():
    assert csv_key("m1") == "M1"
    assert csv_key("M1") == "M1"
    assert csv_key("0") == "M1"
    assert csv_key("1") == "M2"
    assert csv_key("M16") == "M16"


def test_alarm_csv_parsing():
    mapping = alarm_map()
    assert "M1" in mapping
    assert mapping["M1"]["Alarm_Type"] == "Door_Intrusion"
    assert "M2" in mapping
    assert mapping["M2"]["Alarm_Type"] == "Technical_Fire"
