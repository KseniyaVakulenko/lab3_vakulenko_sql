"""
requests.py — запросы к базе данных завода (SQLModel) для основных процессов предметной области.

Процессы: продажи (заказы клиентов), производство (партии, операции), контроль качества,
снабжение и склад, обслуживание оборудования. Каждая функция принимает сессию SQLModel
и возвращает результат выборки; изменяющая функция одна — create_order.
"""
from datetime import date, datetime
from decimal import Decimal
from typing import Iterable, Optional

from sqlalchemy import case, desc, func
from sqlmodel import Session, col, select

from models import (
    BomItem, Customer, CustomerOrder, Defect, Downtime, Employee, Equipment, EquipmentType,
    Material, OperationLog, OrderItem, Product, ProductionOrder, Purchase, QualityCheck,
    Route, RouteOperation, StockMovement, Supplier, Warehouse,
)

OPEN_ORDER_STATUSES = ("новый", "в работе")


# ====================================================================
# 1. Продажи: заказы клиентов
# ====================================================================
def get_customer_orders(session: Session, customer_id: int):
    """Все заказы клиента, новые сверху."""
    stmt = (
        select(CustomerOrder)
        .where(CustomerOrder.customer_id == customer_id)
        .order_by(desc(CustomerOrder.order_date))
    )
    return session.exec(stmt).all()


def get_order_composition(session: Session, order_id: int):
    """Состав заказа: позиции с артикулом, количеством, ценой и суммой по строке."""
    line_sum = (OrderItem.quantity * OrderItem.price).label("line_sum")
    stmt = (
        select(OrderItem.line_no, Product.article, Product.name,
               OrderItem.quantity, OrderItem.price, line_sum)
        .select_from(OrderItem)
        .join(Product, Product.id == OrderItem.product_id)
        .where(OrderItem.order_id == order_id)
        .order_by(OrderItem.line_no)
    )
    return session.exec(stmt).all()


def get_open_orders(session: Session):
    """Незавершённые заказы (новые и в работе) с названием клиента."""
    stmt = (
        select(CustomerOrder.id, Customer.name.label("customer"), CustomerOrder.order_date,
               CustomerOrder.ship_deadline, CustomerOrder.status, CustomerOrder.total_amount)
        .select_from(CustomerOrder)
        .join(Customer, Customer.id == CustomerOrder.customer_id)
        .where(col(CustomerOrder.status).in_(OPEN_ORDER_STATUSES))
        .order_by(CustomerOrder.ship_deadline)
    )
    return session.exec(stmt).all()


def get_overdue_orders(session: Session, today: Optional[date] = None):
    """Заказы, срок отгрузки которых прошёл, а они ещё не отгружены."""
    today = today or date.today()
    stmt = (
        select(CustomerOrder.id, Customer.name.label("customer"),
               CustomerOrder.ship_deadline, CustomerOrder.status)
        .select_from(CustomerOrder)
        .join(Customer, Customer.id == CustomerOrder.customer_id)
        .where(col(CustomerOrder.status).in_(OPEN_ORDER_STATUSES),
               CustomerOrder.ship_deadline < today)
        .order_by(CustomerOrder.ship_deadline)
    )
    return session.exec(stmt).all()


def get_sales_by_customer(session: Session):
    """Количество заказов и общая сумма по каждому клиенту."""
    total = func.sum(CustomerOrder.total_amount)
    stmt = (
        select(Customer.name, func.count(CustomerOrder.id).label("orders"), total.label("total"))
        .select_from(Customer)
        .join(CustomerOrder, CustomerOrder.customer_id == Customer.id)
        .group_by(Customer.id, Customer.name)
        .order_by(desc(total))
    )
    return session.exec(stmt).all()


def create_order(
    session: Session,
    customer_id: int,
    ship_deadline: date,
    items: Iterable[tuple[int, int]],
    order_date: Optional[date] = None,
) -> CustomerOrder:
    """
    Создаёт заказ с позициями. items — пары (id изделия, количество).
    Цена в позиции фиксируется по текущей цене изделия, сумма заказа пересчитывается.
    """
    order = CustomerOrder(
        customer_id=customer_id,
        order_date=order_date or date.today(),
        ship_deadline=ship_deadline,
        status="новый",
    )
    session.add(order)
    session.flush()                      # получаем order.id до фиксации транзакции
    total = Decimal("0")
    for line_no, (product_id, quantity) in enumerate(items, start=1):
        product = session.get(Product, product_id)
        if product is None:
            raise ValueError(f"Изделие с id={product_id} не найдено")
        session.add(OrderItem(order_id=order.id, line_no=line_no, product_id=product_id,
                              quantity=quantity, price=product.price))
        total += product.price * quantity
    order.total_amount = total
    session.add(order)
    session.commit()
    session.refresh(order)
    return order


# ====================================================================
# 2. Производство
# ====================================================================
def get_production_orders(session: Session, status: Optional[str] = None):
    """Производственные задания с изделием; можно отфильтровать по статусу."""
    stmt = (
        select(ProductionOrder.id, Product.article, Product.name, ProductionOrder.planned_qty,
               ProductionOrder.start_date, ProductionOrder.end_date, ProductionOrder.melt_number,
               ProductionOrder.status)
        .select_from(ProductionOrder)
        .join(Product, Product.id == ProductionOrder.product_id)
        .order_by(ProductionOrder.start_date)
    )
    if status:
        stmt = stmt.where(ProductionOrder.status == status)
    return session.exec(stmt).all()


def get_route(session: Session, product_id: int):
    """Действующий технологический маршрут изделия: операции по порядку."""
    stmt = (
        select(RouteOperation.seq_no, RouteOperation.name, EquipmentType.name.label("equipment_type"),
               RouteOperation.time_norm_min)
        .select_from(Route)
        .join(RouteOperation, RouteOperation.route_id == Route.id)
        .join(EquipmentType, EquipmentType.id == RouteOperation.equipment_type_id)
        .where(Route.product_id == product_id, Route.status == "действует")
        .order_by(RouteOperation.seq_no)
    )
    return session.exec(stmt).all()


def get_production_progress(session: Session, production_order_id: int):
    """Ход выполнения партии: по каждой операции — годные, брак и число незавершённых запусков."""
    open_runs = func.sum(case((col(OperationLog.finished_at).is_(None), 1), else_=0))
    stmt = (
        select(RouteOperation.seq_no, RouteOperation.name,
               func.sum(OperationLog.good_qty).label("good"),
               func.sum(OperationLog.defect_qty).label("defect"),
               open_runs.label("open_runs"))
        .select_from(OperationLog)
        .join(RouteOperation, RouteOperation.id == OperationLog.route_operation_id)
        .where(OperationLog.production_order_id == production_order_id)
        .group_by(RouteOperation.seq_no, RouteOperation.name)
        .order_by(RouteOperation.seq_no)
    )
    return session.exec(stmt).all()


def get_material_requirements(session: Session, production_order_id: int):
    """Потребность в материалах для партии: норма на изделие × плановое количество."""
    required = (BomItem.quantity_per_unit * ProductionOrder.planned_qty).label("required")
    stmt = (
        select(Material.name, Material.unit, required)
        .select_from(ProductionOrder)
        .join(BomItem, BomItem.product_id == ProductionOrder.product_id)
        .join(Material, Material.id == BomItem.material_id)
        .where(ProductionOrder.id == production_order_id)
    )
    return session.exec(stmt).all()


def get_employee_output(session: Session, start: datetime, end: datetime):
    """Выработка сотрудников (годные и брак) за период [start, end)."""
    good = func.sum(OperationLog.good_qty)
    stmt = (
        select(Employee.full_name, Employee.position, good.label("good"),
               func.sum(OperationLog.defect_qty).label("defect"))
        .select_from(OperationLog)
        .join(Employee, Employee.id == OperationLog.employee_id)
        .where(OperationLog.started_at >= start, OperationLog.started_at < end)
        .group_by(Employee.id, Employee.full_name, Employee.position)
        .order_by(desc(good))
    )
    return session.exec(stmt).all()


# ====================================================================
# 3. Контроль качества и прослеживаемость
# ====================================================================
def get_defect_rate_by_equipment(session: Session, start: datetime, end: datetime):
    """Процент брака по станкам за период [start, end), худшие станки первыми."""
    good = func.sum(OperationLog.good_qty)
    bad = func.sum(OperationLog.defect_qty)
    pct = (bad * 100.0 / (good + bad)).label("defect_pct")
    stmt = (
        select(Equipment.inventory_number, Equipment.model,
               good.label("good"), bad.label("defect"), pct)
        .select_from(OperationLog)
        .join(Equipment, Equipment.id == OperationLog.equipment_id)
        .where(OperationLog.started_at >= start, OperationLog.started_at < end)
        .group_by(Equipment.id, Equipment.inventory_number, Equipment.model)
        .having(good + bad > 0)
        .order_by(desc(bad * 100.0 / (good + bad)))
    )
    return session.exec(stmt).all()


def get_defects_by_reason(session: Session):
    """Брак по причинам (основа диаграммы Парето)."""
    total = func.sum(Defect.quantity)
    stmt = (
        select(Defect.reason, total.label("quantity"))
        .group_by(Defect.reason)
        .order_by(desc(total))
    )
    return session.exec(stmt).all()


def trace_by_melt(session: Session, melt_number: str):
    """
    Сквозная прослеживаемость: по номеру плавки — поставка (поставщик, сертификат),
    партии, в которых использован металл, и клиенты, получившие продукцию.
    """
    stmt = (
        select(Purchase.melt_number, Supplier.name.label("supplier"),
               Purchase.certificate, Material.name.label("material"),
               ProductionOrder.id.label("production_order"), Product.article,
               CustomerOrder.id.label("order_id"), Customer.name.label("customer"))
        .select_from(Purchase)
        .join(Supplier, Supplier.id == Purchase.supplier_id)
        .join(Material, Material.id == Purchase.material_id)
        .join(ProductionOrder,
              ProductionOrder.melt_number == Purchase.melt_number, isouter=True)
        .join(Product, Product.id == ProductionOrder.product_id, isouter=True)
        .join(CustomerOrder, CustomerOrder.id == ProductionOrder.order_id, isouter=True)
        .join(Customer, Customer.id == CustomerOrder.customer_id, isouter=True)
        .where(Purchase.melt_number == melt_number)
        .order_by(ProductionOrder.id)
    )
    return session.exec(stmt).all()


# ====================================================================
# 4. Снабжение и склад
# ====================================================================
def _signed_quantity():
    """Количество со знаком: приход — плюс, расход — минус."""
    return case((StockMovement.movement_type == "приход", StockMovement.quantity),
                else_=-StockMovement.quantity)


def get_material_stock(session: Session):
    """Остатки материалов по складам (приход минус расход)."""
    balance = func.sum(_signed_quantity())
    stmt = (
        select(Material.name, Warehouse.name.label("warehouse"), balance.label("balance"), Material.unit)
        .select_from(StockMovement)
        .join(Material, Material.id == StockMovement.material_id)
        .join(Warehouse, Warehouse.id == StockMovement.warehouse_id)
        .group_by(Material.id, Material.name, Warehouse.id, Warehouse.name, Material.unit)
        .order_by(Material.name)
    )
    return session.exec(stmt).all()


def get_materials_below_min(session: Session):
    """Материалы, суммарный остаток которых ниже минимального запаса (нужна закупка)."""
    balance = func.sum(_signed_quantity())
    stmt = (
        select(Material.name, balance.label("balance"), Material.min_stock)
        .select_from(StockMovement)
        .join(Material, Material.id == StockMovement.material_id)
        .group_by(Material.id, Material.name, Material.min_stock)
        .having(balance < Material.min_stock)
        .order_by(Material.name)
    )
    return session.exec(stmt).all()


def get_product_stock(session: Session):
    """Остатки готовой продукции на складах."""
    balance = func.sum(_signed_quantity())
    stmt = (
        select(Product.article, Product.name, Warehouse.name.label("warehouse"), balance.label("balance"))
        .select_from(StockMovement)
        .join(Product, Product.id == StockMovement.product_id)
        .join(Warehouse, Warehouse.id == StockMovement.warehouse_id)
        .group_by(Product.id, Product.article, Product.name, Warehouse.id, Warehouse.name)
        .order_by(Product.article)
    )
    return session.exec(stmt).all()


def get_supplier_purchases(session: Session):
    """Закупки по поставщикам: число поставок и сумма."""
    amount = func.sum(Purchase.quantity * Purchase.price)
    stmt = (
        select(Supplier.name, Supplier.rating, func.count(Purchase.id).label("deliveries"),
               amount.label("amount"))
        .select_from(Supplier)
        .join(Purchase, Purchase.supplier_id == Supplier.id)
        .group_by(Supplier.id, Supplier.name, Supplier.rating)
        .order_by(desc(amount))
    )
    return session.exec(stmt).all()


# ====================================================================
# 5. Оборудование
# ====================================================================
def get_equipment_downtime(session: Session, start: datetime, end: datetime,
                           now: Optional[datetime] = None) -> dict[str, float]:
    """
    Суммарная длительность простоев (часы) по станкам за период [start, end).
    Для незавершённого простоя конец берётся равным now.
    """
    now = now or datetime.now()
    stmt = (
        select(Equipment.inventory_number, Downtime.started_at, Downtime.finished_at)
        .select_from(Downtime)
        .join(Equipment, Equipment.id == Downtime.equipment_id)
        .where(Downtime.started_at >= start, Downtime.started_at < end)
    )
    hours: dict[str, float] = {}
    for inventory_number, started_at, finished_at in session.exec(stmt).all():
        delta = (finished_at or now) - started_at
        hours[inventory_number] = hours.get(inventory_number, 0.0) + delta.total_seconds() / 3600
    return dict(sorted(hours.items(), key=lambda kv: kv[1], reverse=True))


def get_equipment_in_repair(session: Session):
    """Станки, которые сейчас в ремонте, с открытым простоем (если есть)."""
    stmt = (
        select(Equipment.inventory_number, Equipment.model, Downtime.kind, Downtime.started_at, Downtime.reason)
        .select_from(Equipment)
        .join(Downtime, (Downtime.equipment_id == Equipment.id) & col(Downtime.finished_at).is_(None),
              isouter=True)
        .where(Equipment.status == "ремонт")
    )
    return session.exec(stmt).all()
