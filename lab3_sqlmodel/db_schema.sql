-- Лабораторная работа №2. Завод по изготовлению автомобильных деталей
-- СУБД: SQLite (схема совместима с PostgreSQL). Перед работой: PRAGMA foreign_keys = ON;

CREATE TABLE equipment_type (
    id INTEGER PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE department (
    id INTEGER PRIMARY KEY,
    name VARCHAR(120) NOT NULL UNIQUE,
    dept_type VARCHAR(30) NOT NULL,
    parent_id INTEGER,
    CHECK (dept_type IN ('цех','участок','отдел','служба')),
    FOREIGN KEY (parent_id) REFERENCES department (id) ON DELETE SET NULL
);

CREATE TABLE employee (
    id INTEGER PRIMARY KEY,
    full_name VARCHAR(120) NOT NULL,
    position VARCHAR(80) NOT NULL,
    grade INTEGER,
    department_id INTEGER NOT NULL,
    hire_date DATE NOT NULL,
    is_head BOOLEAN NOT NULL DEFAULT 0,
    CHECK (grade IS NULL OR grade BETWEEN 1 AND 8),
    FOREIGN KEY (department_id) REFERENCES department (id) ON DELETE RESTRICT
);

CREATE TABLE equipment (
    id INTEGER PRIMARY KEY,
    inventory_number VARCHAR(30) NOT NULL UNIQUE,
    equipment_type_id INTEGER NOT NULL,
    model VARCHAR(80) NOT NULL,
    department_id INTEGER NOT NULL,
    commissioned_year INTEGER,
    status VARCHAR(20) NOT NULL DEFAULT 'работает',
    CHECK (status IN ('работает','ремонт','списан')),
    FOREIGN KEY (equipment_type_id) REFERENCES equipment_type (id) ON DELETE RESTRICT,
    FOREIGN KEY (department_id) REFERENCES department (id) ON DELETE RESTRICT
);

CREATE TABLE product (
    id INTEGER PRIMARY KEY,
    article VARCHAR(30) NOT NULL UNIQUE,
    name VARCHAR(120) NOT NULL,
    product_type VARCHAR(30) NOT NULL,
    modification VARCHAR(60),
    mass_kg NUMERIC(8,3),
    unit VARCHAR(10) NOT NULL DEFAULT 'шт',
    price NUMERIC(12,2) NOT NULL,
    drawing_url VARCHAR(255),
    CHECK (product_type IN ('диск','ступица','шатун','палец')),
    CHECK (mass_kg > 0),
    CHECK (price >= 0)
);

CREATE TABLE material (
    id INTEGER PRIMARY KEY,
    name VARCHAR(120) NOT NULL,
    metal_grade VARCHAR(40) NOT NULL,
    unit VARCHAR(10) NOT NULL,
    current_price NUMERIC(12,2) NOT NULL,
    min_stock NUMERIC(12,3) NOT NULL DEFAULT 0,
    CHECK (current_price >= 0)
);

CREATE TABLE bom_item (
    product_id INTEGER NOT NULL,
    material_id INTEGER NOT NULL,
    quantity_per_unit NUMERIC(10,4) NOT NULL,
    CHECK (quantity_per_unit > 0),
    PRIMARY KEY (product_id, material_id),
    FOREIGN KEY (product_id) REFERENCES product (id) ON DELETE CASCADE,
    FOREIGN KEY (material_id) REFERENCES material (id) ON DELETE RESTRICT
);

CREATE TABLE route (
    id INTEGER PRIMARY KEY,
    product_id INTEGER NOT NULL,
    version INTEGER NOT NULL DEFAULT 1,
    status VARCHAR(20) NOT NULL DEFAULT 'действует',
    CHECK (status IN ('действует','архив')),
    FOREIGN KEY (product_id) REFERENCES product (id) ON DELETE RESTRICT,
    UNIQUE (product_id, version)
);

CREATE TABLE route_operation (
    id INTEGER PRIMARY KEY,
    route_id INTEGER NOT NULL,
    seq_no INTEGER NOT NULL,
    name VARCHAR(100) NOT NULL,
    equipment_type_id INTEGER NOT NULL,
    time_norm_min NUMERIC(8,2) NOT NULL,
    CHECK (seq_no > 0),
    CHECK (time_norm_min > 0),
    FOREIGN KEY (route_id) REFERENCES route (id) ON DELETE CASCADE,
    FOREIGN KEY (equipment_type_id) REFERENCES equipment_type (id) ON DELETE RESTRICT,
    UNIQUE (route_id, seq_no)
);

CREATE TABLE customer (
    id INTEGER PRIMARY KEY,
    name VARCHAR(150) NOT NULL,
    customer_type VARCHAR(30) NOT NULL,
    inn VARCHAR(12) NOT NULL UNIQUE,
    contact_person VARCHAR(120),
    phone VARCHAR(30),
    address VARCHAR(255),
    CHECK (customer_type IN ('сборочный завод','дистрибьютор'))
);

CREATE TABLE customer_order (
    id INTEGER PRIMARY KEY,
    customer_id INTEGER NOT NULL,
    order_date DATE NOT NULL,
    ship_deadline DATE NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'новый',
    total_amount NUMERIC(14,2) NOT NULL DEFAULT 0,
    CHECK (status IN ('новый','в работе','отгружен','закрыт','отменён')),
    FOREIGN KEY (customer_id) REFERENCES customer (id) ON DELETE RESTRICT,
    CHECK (ship_deadline >= order_date)
);

CREATE TABLE order_item (
    order_id INTEGER NOT NULL,
    line_no INTEGER NOT NULL,
    product_id INTEGER NOT NULL,
    quantity INTEGER NOT NULL,
    price NUMERIC(12,2) NOT NULL,
    CHECK (line_no > 0),
    CHECK (quantity > 0),
    CHECK (price >= 0),
    PRIMARY KEY (order_id, line_no),
    FOREIGN KEY (order_id) REFERENCES customer_order (id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES product (id) ON DELETE RESTRICT
);

CREATE TABLE production_order (
    id INTEGER PRIMARY KEY,
    product_id INTEGER NOT NULL,
    order_id INTEGER,
    planned_qty INTEGER NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE,
    melt_number VARCHAR(40),
    status VARCHAR(20) NOT NULL DEFAULT 'запланировано',
    CHECK (planned_qty > 0),
    CHECK (status IN ('запланировано','в работе','выполнено','отменено')),
    FOREIGN KEY (product_id) REFERENCES product (id) ON DELETE RESTRICT,
    FOREIGN KEY (order_id) REFERENCES customer_order (id) ON DELETE SET NULL
);

CREATE TABLE operation_log (
    id INTEGER PRIMARY KEY,
    production_order_id INTEGER NOT NULL,
    route_operation_id INTEGER NOT NULL,
    equipment_id INTEGER NOT NULL,
    employee_id INTEGER NOT NULL,
    started_at TIMESTAMP NOT NULL,
    finished_at TIMESTAMP,
    good_qty INTEGER NOT NULL DEFAULT 0,
    defect_qty INTEGER NOT NULL DEFAULT 0,
    CHECK (good_qty >= 0),
    CHECK (defect_qty >= 0),
    FOREIGN KEY (production_order_id) REFERENCES production_order (id) ON DELETE RESTRICT,
    FOREIGN KEY (route_operation_id) REFERENCES route_operation (id) ON DELETE RESTRICT,
    FOREIGN KEY (equipment_id) REFERENCES equipment (id) ON DELETE RESTRICT,
    FOREIGN KEY (employee_id) REFERENCES employee (id) ON DELETE RESTRICT,
    CHECK (finished_at IS NULL OR finished_at >= started_at)
);

CREATE TABLE quality_check (
    id INTEGER PRIMARY KEY,
    production_order_id INTEGER NOT NULL,
    inspector_id INTEGER NOT NULL,
    check_date DATE NOT NULL,
    check_type VARCHAR(20) NOT NULL,
    result VARCHAR(20) NOT NULL,
    protocol VARCHAR(255),
    CHECK (check_type IN ('входной','операционный','приёмочный')),
    CHECK (result IN ('годна','брак','условно годна')),
    FOREIGN KEY (production_order_id) REFERENCES production_order (id) ON DELETE RESTRICT,
    FOREIGN KEY (inspector_id) REFERENCES employee (id) ON DELETE RESTRICT
);

CREATE TABLE defect (
    id INTEGER PRIMARY KEY,
    quality_check_id INTEGER NOT NULL,
    reason VARCHAR(120) NOT NULL,
    quantity INTEGER NOT NULL,
    decision VARCHAR(20) NOT NULL,
    CHECK (quantity > 0),
    CHECK (decision IN ('исправить','утилизировать')),
    FOREIGN KEY (quality_check_id) REFERENCES quality_check (id) ON DELETE CASCADE
);

CREATE TABLE supplier (
    id INTEGER PRIMARY KEY,
    name VARCHAR(150) NOT NULL,
    inn VARCHAR(12) NOT NULL UNIQUE,
    contacts VARCHAR(255),
    rating INTEGER,
    CHECK (rating IS NULL OR rating BETWEEN 1 AND 5)
);

CREATE TABLE purchase (
    id INTEGER PRIMARY KEY,
    supplier_id INTEGER NOT NULL,
    material_id INTEGER NOT NULL,
    quantity NUMERIC(12,3) NOT NULL,
    price NUMERIC(12,2) NOT NULL,
    delivery_date DATE NOT NULL,
    melt_number VARCHAR(40) NOT NULL,
    certificate VARCHAR(80),
    CHECK (quantity > 0),
    CHECK (price >= 0),
    FOREIGN KEY (supplier_id) REFERENCES supplier (id) ON DELETE RESTRICT,
    FOREIGN KEY (material_id) REFERENCES material (id) ON DELETE RESTRICT
);

CREATE TABLE warehouse (
    id INTEGER PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    location VARCHAR(150)
);

CREATE TABLE stock_movement (
    id INTEGER PRIMARY KEY,
    movement_type VARCHAR(10) NOT NULL,
    material_id INTEGER,
    product_id INTEGER,
    warehouse_id INTEGER NOT NULL,
    quantity NUMERIC(12,3) NOT NULL,
    movement_date DATE NOT NULL,
    document_type VARCHAR(30),
    document_id INTEGER,
    CHECK (movement_type IN ('приход','расход')),
    CHECK (quantity > 0),
    FOREIGN KEY (material_id) REFERENCES material (id) ON DELETE RESTRICT,
    FOREIGN KEY (product_id) REFERENCES product (id) ON DELETE RESTRICT,
    FOREIGN KEY (warehouse_id) REFERENCES warehouse (id) ON DELETE RESTRICT,
    CHECK ((material_id IS NOT NULL AND product_id IS NULL) OR (material_id
        IS NULL AND product_id IS NOT NULL))
);

CREATE TABLE shipment (
    id INTEGER PRIMARY KEY,
    order_id INTEGER NOT NULL,
    ship_date DATE NOT NULL,
    carrier VARCHAR(100),
    waybill_number VARCHAR(30) NOT NULL UNIQUE,
    status VARCHAR(20) NOT NULL DEFAULT 'в пути',
    CHECK (status IN ('подготовлена','в пути','доставлена')),
    FOREIGN KEY (order_id) REFERENCES customer_order (id) ON DELETE RESTRICT
);

CREATE TABLE downtime (
    id INTEGER PRIMARY KEY,
    equipment_id INTEGER NOT NULL,
    kind VARCHAR(20) NOT NULL,
    started_at TIMESTAMP NOT NULL,
    finished_at TIMESTAMP,
    reason VARCHAR(255),
    performer_id INTEGER,
    CHECK (kind IN ('плановый','аварийный')),
    FOREIGN KEY (equipment_id) REFERENCES equipment (id) ON DELETE RESTRICT,
    FOREIGN KEY (performer_id) REFERENCES employee (id) ON DELETE SET NULL,
    CHECK (finished_at IS NULL OR finished_at >= started_at)
);

CREATE INDEX ix_operation_log_order ON operation_log (production_order_id);
CREATE INDEX ix_operation_log_equipment ON operation_log (equipment_id, finished_at);
CREATE INDEX ix_production_order_melt ON production_order (melt_number);
CREATE INDEX ix_purchase_melt ON purchase (melt_number);
CREATE INDEX ix_order_customer ON customer_order (customer_id);
CREATE INDEX ix_stock_material ON stock_movement (material_id, warehouse_id);
CREATE INDEX ix_downtime_equipment ON downtime (equipment_id);
