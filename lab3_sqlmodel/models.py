"""
models.py — модели SQLModel для базы данных завода по изготовлению автомобильных деталей.

Модели соответствуют таблицам, спроектированным в лабораторной работе №2
(см. db_schema.sql): 22 таблицы, 29 внешних ключей, ограничения CHECK и индексы.
Имена таблиц заданы явно (__tablename__), чтобы они совпадали со скриптом db_schema.sql.

Примечание: поля типа datetime объявлены как NaiveDatetime, т.к. SQLite не хранит
таймзону, а тестовые данные (seed_data.sql) заданы без неё.
"""
from datetime import date
from decimal import Decimal
from typing import List, Optional

from sqlalchemy import CheckConstraint, Column, ForeignKey, Index, UniqueConstraint
from pydantic import NaiveDatetime
from sqlmodel import Field, Relationship, SQLModel


# ====================================================================
# 1. Ресурсы и персонал
# ====================================================================
class EquipmentType(SQLModel, table=True):
    """Тип оборудования (справочник)."""
    __tablename__ = "equipment_type"

    id: Optional[int] = Field(default=None, primary_key=True)
    name: str = Field(max_length=100, unique=True)


class Department(SQLModel, table=True):
    """Подразделение (цех, участок, отдел, служба); поддерживает иерархию."""
    __tablename__ = "department"
    __table_args__ = (
        CheckConstraint("dept_type IN ('цех','участок','отдел','служба')", name="ck_department_type"),
    )

    id: Optional[int] = Field(default=None, primary_key=True)
    name: str = Field(max_length=120, unique=True)
    dept_type: str = Field(max_length=30)
    parent_id: Optional[int] = Field(
        default=None,
        sa_column=Column(ForeignKey("department.id", ondelete="SET NULL"), nullable=True),
    )


class Employee(SQLModel, table=True):
    """Сотрудник."""
    __tablename__ = "employee"
    __table_args__ = (
        CheckConstraint("grade IS NULL OR grade BETWEEN 1 AND 8", name="ck_employee_grade"),
    )

    id: Optional[int] = Field(default=None, primary_key=True)
    full_name: str = Field(max_length=120)
    position: str = Field(max_length=80)
    grade: Optional[int] = None
    department_id: int = Field(foreign_key="department.id")
    hire_date: date
    is_head: bool = Field(default=False)


class Equipment(SQLModel, table=True):
    """Оборудование (станки и агрегаты)."""
    __tablename__ = "equipment"
    __table_args__ = (
        CheckConstraint("status IN ('работает','ремонт','списан')", name="ck_equipment_status"),
    )

    id: Optional[int] = Field(default=None, primary_key=True)
    inventory_number: str = Field(max_length=30, unique=True)
    equipment_type_id: int = Field(foreign_key="equipment_type.id")
    model: str = Field(max_length=80)
    department_id: int = Field(foreign_key="department.id")
    commissioned_year: Optional[int] = None
    status: str = Field(default="работает", max_length=20)


class Downtime(SQLModel, table=True):
    """Простой или ремонт станка."""
    __tablename__ = "downtime"
    __table_args__ = (
        CheckConstraint("kind IN ('плановый','аварийный')", name="ck_downtime_kind"),
        CheckConstraint("finished_at IS NULL OR finished_at >= started_at", name="ck_downtime_period"),
        Index("ix_downtime_equipment", "equipment_id"),
    )

    id: Optional[int] = Field(default=None, primary_key=True)
    equipment_id: int = Field(foreign_key="equipment.id")
    kind: str = Field(max_length=20)
    started_at: NaiveDatetime
    finished_at: Optional[NaiveDatetime] = None
    reason: Optional[str] = Field(default=None, max_length=255)
    performer_id: Optional[int] = Field(
        default=None,
        sa_column=Column(ForeignKey("employee.id", ondelete="SET NULL"), nullable=True),
    )


# ====================================================================
# 2. Продукция и технология
# ====================================================================
class Product(SQLModel, table=True):
    """Изделие (автомобильная деталь)."""
    __tablename__ = "product"
    __table_args__ = (
        CheckConstraint("product_type IN ('диск','ступица','шатун','палец')", name="ck_product_type"),
        CheckConstraint("mass_kg > 0", name="ck_product_mass"),
        CheckConstraint("price >= 0", name="ck_product_price"),
    )

    id: Optional[int] = Field(default=None, primary_key=True)
    article: str = Field(max_length=30, unique=True)
    name: str = Field(max_length=120)
    product_type: str = Field(max_length=30)
    modification: Optional[str] = Field(default=None, max_length=60)
    mass_kg: Optional[Decimal] = Field(default=None, max_digits=8, decimal_places=3)
    unit: str = Field(default="шт", max_length=10)
    price: Decimal = Field(max_digits=12, decimal_places=2)
    drawing_url: Optional[str] = Field(default=None, max_length=255)


class Material(SQLModel, table=True):
    """Материал (сырьё, заготовки)."""
    __tablename__ = "material"
    __table_args__ = (
        CheckConstraint("current_price >= 0", name="ck_material_price"),
    )

    id: Optional[int] = Field(default=None, primary_key=True)
    name: str = Field(max_length=120)
    metal_grade: str = Field(max_length=40)
    unit: str = Field(max_length=10)
    current_price: Decimal = Field(max_digits=12, decimal_places=2)
    min_stock: Decimal = Field(default=Decimal("0"), max_digits=12, decimal_places=3)


class BomItem(SQLModel, table=True):
    """Спецификация: расход материала на единицу изделия (связь M:N)."""
    __tablename__ = "bom_item"
    __table_args__ = (
        CheckConstraint("quantity_per_unit > 0", name="ck_bom_quantity"),
    )

    product_id: int = Field(foreign_key="product.id", primary_key=True)
    material_id: int = Field(foreign_key="material.id", primary_key=True)
    quantity_per_unit: Decimal = Field(max_digits=10, decimal_places=4)


class Route(SQLModel, table=True):
    """Технологический маршрут (версия технологии изделия)."""
    __tablename__ = "route"
    __table_args__ = (
        CheckConstraint("status IN ('действует','архив')", name="ck_route_status"),
        UniqueConstraint("product_id", "version", name="uq_route_product_version"),
    )

    id: Optional[int] = Field(default=None, primary_key=True)
    product_id: int = Field(foreign_key="product.id")
    version: int = Field(default=1)
    status: str = Field(default="действует", max_length=20)


class RouteOperation(SQLModel, table=True):
    """Операция технологического маршрута."""
    __tablename__ = "route_operation"
    __table_args__ = (
        CheckConstraint("seq_no > 0", name="ck_route_operation_seq"),
        CheckConstraint("time_norm_min > 0", name="ck_route_operation_norm"),
        UniqueConstraint("route_id", "seq_no", name="uq_route_operation_seq"),
    )

    id: Optional[int] = Field(default=None, primary_key=True)
    route_id: int = Field(foreign_key="route.id")
    seq_no: int
    name: str = Field(max_length=100)
    equipment_type_id: int = Field(foreign_key="equipment_type.id")
    time_norm_min: Decimal = Field(max_digits=8, decimal_places=2)


# ====================================================================
# 3. Продажи
# ====================================================================
class Customer(SQLModel, table=True):
    """Клиент."""
    __tablename__ = "customer"
    __table_args__ = (
        CheckConstraint("customer_type IN ('сборочный завод','дистрибьютор')", name="ck_customer_type"),
    )

    id: Optional[int] = Field(default=None, primary_key=True)
    name: str = Field(max_length=150)
    customer_type: str = Field(max_length=30)
    inn: str = Field(max_length=12, unique=True)
    contact_person: Optional[str] = Field(default=None, max_length=120)
    phone: Optional[str] = Field(default=None, max_length=30)
    address: Optional[str] = Field(default=None, max_length=255)

    orders: List["CustomerOrder"] = Relationship(back_populates="customer")


class CustomerOrder(SQLModel, table=True):
    """Заказ клиента."""
    __tablename__ = "customer_order"
    __table_args__ = (
        CheckConstraint(
            "status IN ('новый','в работе','отгружен','закрыт','отменён')",
            name="ck_order_status",
        ),
        CheckConstraint("ship_deadline >= order_date", name="ck_order_dates"),
        Index("ix_order_customer", "customer_id"),
    )

    id: Optional[int] = Field(default=None, primary_key=True)
    customer_id: int = Field(foreign_key="customer.id")
    order_date: date
    ship_deadline: date
    status: str = Field(default="новый", max_length=20)
    total_amount: Decimal = Field(default=Decimal("0"), max_digits=14, decimal_places=2)

    customer: Optional[Customer] = Relationship(back_populates="orders")
    items: List["OrderItem"] = Relationship(back_populates="order")


class OrderItem(SQLModel, table=True):
    """Позиция заказа (связь «Заказ – Изделие», M:N)."""
    __tablename__ = "order_item"
    __table_args__ = (
        CheckConstraint("line_no > 0", name="ck_order_item_line"),
        CheckConstraint("quantity > 0", name="ck_order_item_qty"),
        CheckConstraint("price >= 0", name="ck_order_item_price"),
    )

    order_id: int = Field(foreign_key="customer_order.id", primary_key=True)
    line_no: int = Field(primary_key=True)
    product_id: int = Field(foreign_key="product.id")
    quantity: int
    price: Decimal = Field(max_digits=12, decimal_places=2)

    order: Optional[CustomerOrder] = Relationship(back_populates="items")


class Shipment(SQLModel, table=True):
    """Отгрузка клиенту."""
    __tablename__ = "shipment"
    __table_args__ = (
        CheckConstraint("status IN ('подготовлена','в пути','доставлена')", name="ck_shipment_status"),
    )

    id: Optional[int] = Field(default=None, primary_key=True)
    order_id: int = Field(foreign_key="customer_order.id")
    ship_date: date
    carrier: Optional[str] = Field(default=None, max_length=100)
    waybill_number: str = Field(max_length=30, unique=True)
    status: str = Field(default="в пути", max_length=20)


# ====================================================================
# 4. Производство и качество
# ====================================================================
class ProductionOrder(SQLModel, table=True):
    """Производственное задание (партия)."""
    __tablename__ = "production_order"
    __table_args__ = (
        CheckConstraint("planned_qty > 0", name="ck_prod_order_qty"),
        CheckConstraint(
            "status IN ('запланировано','в работе','выполнено','отменено')", name="ck_prod_order_status"
        ),
        Index("ix_production_order_melt", "melt_number"),
    )

    id: Optional[int] = Field(default=None, primary_key=True)
    product_id: int = Field(foreign_key="product.id")
    order_id: Optional[int] = Field(default=None, foreign_key="customer_order.id")
    planned_qty: int
    start_date: date
    end_date: Optional[date] = None
    melt_number: Optional[str] = Field(default=None, max_length=40)
    status: str = Field(default="запланировано", max_length=20)


class OperationLog(SQLModel, table=True):
    """Выполнение операции: факт производства."""
    __tablename__ = "operation_log"
    __table_args__ = (
        CheckConstraint("good_qty >= 0", name="ck_oplog_good"),
        CheckConstraint("defect_qty >= 0", name="ck_oplog_defect"),
        CheckConstraint("finished_at IS NULL OR finished_at >= started_at", name="ck_oplog_period"),
        Index("ix_operation_log_order", "production_order_id"),
        Index("ix_operation_log_equipment", "equipment_id", "finished_at"),
    )

    id: Optional[int] = Field(default=None, primary_key=True)
    production_order_id: int = Field(foreign_key="production_order.id")
    route_operation_id: int = Field(foreign_key="route_operation.id")
    equipment_id: int = Field(foreign_key="equipment.id")
    employee_id: int = Field(foreign_key="employee.id")
    started_at: NaiveDatetime
    finished_at: Optional[NaiveDatetime] = None
    good_qty: int = Field(default=0)
    defect_qty: int = Field(default=0)


class QualityCheck(SQLModel, table=True):
    """Контроль качества партии."""
    __tablename__ = "quality_check"
    __table_args__ = (
        CheckConstraint("check_type IN ('входной','операционный','приёмочный')", name="ck_qc_type"),
        CheckConstraint("result IN ('годна','брак','условно годна')", name="ck_qc_result"),
    )

    id: Optional[int] = Field(default=None, primary_key=True)
    production_order_id: int = Field(foreign_key="production_order.id")
    inspector_id: int = Field(foreign_key="employee.id")
    check_date: date
    check_type: str = Field(max_length=20)
    result: str = Field(max_length=20)
    protocol: Optional[str] = Field(default=None, max_length=255)


class Defect(SQLModel, table=True):
    """Брак (несоответствие), выявленный при проверке."""
    __tablename__ = "defect"
    __table_args__ = (
        CheckConstraint("quantity > 0", name="ck_defect_qty"),
        CheckConstraint("decision IN ('исправить','утилизировать')", name="ck_defect_decision"),
    )

    id: Optional[int] = Field(default=None, primary_key=True)
    quality_check_id: int = Field(foreign_key="quality_check.id")
    reason: str = Field(max_length=120)
    quantity: int
    decision: str = Field(max_length=20)


# ====================================================================
# 5. Снабжение и склад
# ====================================================================
class Supplier(SQLModel, table=True):
    """Поставщик."""
    __tablename__ = "supplier"
    __table_args__ = (
        CheckConstraint("rating IS NULL OR rating BETWEEN 1 AND 5", name="ck_supplier_rating"),
    )

    id: Optional[int] = Field(default=None, primary_key=True)
    name: str = Field(max_length=150)
    inn: str = Field(max_length=12, unique=True)
    contacts: Optional[str] = Field(default=None, max_length=255)
    rating: Optional[int] = None


class Purchase(SQLModel, table=True):
    """Закупка (поставка материала)."""
    __tablename__ = "purchase"
    __table_args__ = (
        CheckConstraint("quantity > 0", name="ck_purchase_qty"),
        CheckConstraint("price >= 0", name="ck_purchase_price"),
        Index("ix_purchase_melt", "melt_number"),
    )

    id: Optional[int] = Field(default=None, primary_key=True)
    supplier_id: int = Field(foreign_key="supplier.id")
    material_id: int = Field(foreign_key="material.id")
    quantity: Decimal = Field(max_digits=12, decimal_places=3)
    price: Decimal = Field(max_digits=12, decimal_places=2)
    delivery_date: date
    melt_number: str = Field(max_length=40)
    certificate: Optional[str] = Field(default=None, max_length=80)


class Warehouse(SQLModel, table=True):
    """Склад."""
    __tablename__ = "warehouse"

    id: Optional[int] = Field(default=None, primary_key=True)
    name: str = Field(max_length=100, unique=True)
    location: Optional[str] = Field(default=None, max_length=150)


class StockMovement(SQLModel, table=True):
    """Складское движение (приход / расход материала или изделия)."""
    __tablename__ = "stock_movement"
    __table_args__ = (
        CheckConstraint("movement_type IN ('приход','расход')", name="ck_stock_type"),
        CheckConstraint("quantity > 0", name="ck_stock_qty"),
        CheckConstraint(
            "(material_id IS NOT NULL AND product_id IS NULL) OR "
            "(material_id IS NULL AND product_id IS NOT NULL)",
            name="ck_stock_material_or_product",
        ),
        Index("ix_stock_material", "material_id", "warehouse_id"),
    )

    id: Optional[int] = Field(default=None, primary_key=True)
    movement_type: str = Field(max_length=10)
    material_id: Optional[int] = Field(default=None, foreign_key="material.id")
    product_id: Optional[int] = Field(default=None, foreign_key="product.id")
    warehouse_id: int = Field(foreign_key="warehouse.id")
    quantity: Decimal = Field(max_digits=12, decimal_places=3)
    movement_date: date
    document_type: Optional[str] = Field(default=None, max_length=30)
    document_id: Optional[int] = None