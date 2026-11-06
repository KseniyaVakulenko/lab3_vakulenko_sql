# Лабораторная работа №3. Использование SQLModel

Предметная область: завод по изготовлению автомобильных деталей.
СУБД: SQLite 3 (база хранится в файле `factory.db`).

## Состав
| Файл | Назначение |
|---|---|
| `models.py` | Модели SQLModel (22 таблицы, соответствуют схеме из лабораторной работы №2) |
| `requests.py` | Запросы к БД для основных процессов (19 функций) |
| `database.py` | Подключение к SQLite, включение внешних ключей, создание таблиц |
| `seed.py`, `seed_data.sql` | Создание базы и загрузка минимального набора тестовых данных |
| `demo.py` | Пример вызова всех запросов с выводом результатов |
| `db_schema.sql` | Скрипт создания БД (из лабораторной работы №2) |
| `queries.sql` | SQL-эквиваленты запросов из `requests.py` |
| `factory.db`, `factory_dump.sql` | Готовая база данных и её дамп (SQLite) |

## Запуск
```bash
python -m venv .venv
.venv\Scripts\activate          # Windows;  source .venv/bin/activate — Linux/macOS
pip install -r requirements.txt
python seed.py                  # создаёт factory.db по моделям и заполняет данными
python demo.py                  # выполняет запросы и печатает результаты
```
Восстановить базу из дампа без Python: `sqlite3 factory.db < factory_dump.sql`.

## Пример использования
```python
from datetime import date
from sqlmodel import Session
from database import engine
import requests as q

with Session(engine) as session:
    print(q.get_open_orders(session))
    print(q.trace_by_melt(session, "П-24-0915"))
    q.create_order(session, customer_id=3, ship_deadline=date(2026, 12, 15), items=[(1, 100), (4, 50)])
```
