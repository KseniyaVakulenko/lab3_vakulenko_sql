"""
demo.py — демонстрация запросов из requests.py на тестовых данных.
Запуск:  python seed.py && python demo.py
"""
from datetime import date, datetime

import requests as q            # локальный файл requests.py с запросами к БД
from database import engine
from sqlmodel import Session


def show(title: str, rows) -> None:
    print(f"\n=== {title} ===")
    rows = list(rows.items()) if isinstance(rows, dict) else list(rows)
    if not rows:
        print("(нет данных)")
    for row in rows:
        print("  ", tuple(row) if not isinstance(row, tuple) and hasattr(row, "_mapping") else row)


with Session(engine) as session:
    sep_start, oct_start = datetime(2026, 9, 1), datetime(2026, 10, 1)

    show("Заказы клиента №1", [(o.id, o.order_date, o.status, o.total_amount) for o in q.get_customer_orders(session, 1)])
    show("Состав заказа №2", q.get_order_composition(session, 2))
    show("Незавершённые заказы", q.get_open_orders(session))
    show("Просроченные заказы на 06.11.2026", q.get_overdue_orders(session, date(2026, 11, 6)))
    show("Продажи по клиентам", q.get_sales_by_customer(session))

    show("Производственные задания «в работе»", q.get_production_orders(session, "в работе"))
    show("Маршрут изделия №4 (шатун)", q.get_route(session, 4))
    show("Ход выполнения задания №1", q.get_production_progress(session, 1))
    show("Потребность в материалах для задания №3", q.get_material_requirements(session, 3))
    show("Выработка сотрудников за сентябрь", q.get_employee_output(session, sep_start, oct_start))

    show("Процент брака по станкам за сентябрь", q.get_defect_rate_by_equipment(session, sep_start, oct_start))
    show("Брак по причинам", q.get_defects_by_reason(session))
    show("Прослеживаемость плавки П-24-0915", q.trace_by_melt(session, "П-24-0915"))

    show("Остатки материалов", q.get_material_stock(session))
    show("Материалы ниже минимального запаса", q.get_materials_below_min(session))
    show("Остатки готовой продукции", q.get_product_stock(session))
    show("Закупки по поставщикам", q.get_supplier_purchases(session))

    show("Простои станков, часы (с 01.09 по 01.11)", q.get_equipment_downtime(session, sep_start, datetime(2026, 11, 1), now=datetime(2026, 11, 6)))
    show("Станки в ремонте", q.get_equipment_in_repair(session))

    new_order = q.create_order(session, customer_id=3, ship_deadline=date(2026, 12, 15),
                               items=[(1, 100), (4, 50)], order_date=date(2026, 11, 6))
    show("Создан заказ", [(new_order.id, new_order.status, new_order.total_amount)])
    show("Состав созданного заказа", q.get_order_composition(session, new_order.id))
