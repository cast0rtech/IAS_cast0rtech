import os


def env_bool(name: str, default: bool) -> bool:
    return os.getenv(name, str(default)).strip().lower() in {"1", "true", "yes", "on"}


DATABASE_PATH = os.getenv("EMA_DATABASE_PATH", "/data/ema.db")
SIMULATION_MODE = env_bool("EMA_SIMULATION_MODE", True)
MODBUS_ENABLED = env_bool("EMA_MODBUS_ENABLED", False) and not SIMULATION_MODE
MODBUS_HOST = os.getenv("EMA_MODBUS_HOST", "127.0.0.1")
MODBUS_PORT = int(os.getenv("EMA_MODBUS_PORT", "502"))
MODBUS_UNIT_ID = int(os.getenv("EMA_MODBUS_UNIT_ID", "1"))
MODBUS_POLL_SECONDS = max(1.0, float(os.getenv("EMA_MODBUS_POLL_SECONDS", "2")))
CSV_PATH = os.getenv("EMA_CSV_PATH", "/app/alarme.csv")
