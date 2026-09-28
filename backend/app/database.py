from pathlib import Path
from sqlmodel import SQLModel, Session, create_engine
from .config import DATABASE_PATH

engine = create_engine(f"sqlite:///{DATABASE_PATH}", connect_args={"check_same_thread": False})


def init_db() -> None:
    db_file = Path(DATABASE_PATH)
    if db_file.parent and not db_file.parent.exists():
        db_file.parent.mkdir(parents=True, exist_ok=True)
    SQLModel.metadata.create_all(engine)


def get_session():
    with Session(engine) as session:
        yield session
