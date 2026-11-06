"""database.py — подключение к базе данных SQLite и создание таблиц."""
import warnings
from pathlib import Path

from sqlalchemy import event
from sqlmodel import Session, SQLModel, create_engine

# SQLite хранит NUMERIC без точного типа Decimal — SQLAlchemy предупреждает об этом при каждом запуске
warnings.filterwarnings("ignore", message=".*Decimal objects natively.*")

DB_PATH = Path(__file__).with_name("factory.db")
engine = create_engine(f"sqlite:///{DB_PATH}", echo=False)


@event.listens_for(engine, "connect")
def _enable_foreign_keys(dbapi_connection, _record):
    """В SQLite внешние ключи по умолчанию выключены — включаем для каждого соединения."""
    cursor = dbapi_connection.cursor()
    cursor.execute("PRAGMA foreign_keys=ON")
    cursor.close()


def create_db_and_tables() -> None:
    """Создаёт все таблицы по моделям из models.py (если их ещё нет)."""
    import models  # noqa: F401  — импорт регистрирует модели в SQLModel.metadata
    SQLModel.metadata.create_all(engine)


def get_session():
    """Генератор сессии (пригодится в лабораторной работе №4 как зависимость FastAPI)."""
    with Session(engine) as session:
        yield session
