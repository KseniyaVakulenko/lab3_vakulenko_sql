"""
seed.py — создание базы данных и наполнение её тестовыми данными.

Запуск:  python seed.py
Таблицы создаются по моделям SQLModel (models.py), данные загружаются из seed_data.sql.
"""
import sqlite3
from pathlib import Path

from database import DB_PATH, create_db_and_tables

SEED_FILE = Path(__file__).with_name("seed_data.sql")


def seed(reset: bool = True) -> None:
    if reset and DB_PATH.exists():
        DB_PATH.unlink()
    create_db_and_tables()
    sql = SEED_FILE.read_text(encoding="utf-8")
    with sqlite3.connect(DB_PATH) as conn:
        conn.execute("PRAGMA foreign_keys=ON")
        conn.executescript(sql)
    print(f"База данных создана и заполнена: {DB_PATH}")


if __name__ == "__main__":
    seed()
