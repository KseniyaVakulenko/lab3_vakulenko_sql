BEGIN TRANSACTION;
CREATE TABLE bom_item (
	product_id INTEGER NOT NULL, 
	material_id INTEGER NOT NULL, 
	quantity_per_unit NUMERIC(10, 4) NOT NULL, 
	PRIMARY KEY (product_id, material_id), 
	CONSTRAINT ck_bom_quantity CHECK (quantity_per_unit > 0), 
	FOREIGN KEY(product_id) REFERENCES product (id), 
	FOREIGN KEY(material_id) REFERENCES material (id)
);
INSERT INTO "bom_item" VALUES(1,1,9.4);
INSERT INTO "bom_item" VALUES(2,1,6.3);
INSERT INTO "bom_item" VALUES(3,3,5.6);
INSERT INTO "bom_item" VALUES(4,2,0.95);
INSERT INTO "bom_item" VALUES(5,4,0.14);
CREATE TABLE customer (
	id INTEGER NOT NULL, 
	name VARCHAR(150) NOT NULL, 
	customer_type VARCHAR(30) NOT NULL, 
	inn VARCHAR(12) NOT NULL, 
	contact_person VARCHAR(120), 
	phone VARCHAR(30), 
	address VARCHAR(255), 
	PRIMARY KEY (id), 
	CONSTRAINT ck_customer_type CHECK (customer_type IN ('сборочный завод','дистрибьютор')), 
	UNIQUE (inn)
);
INSERT INTO "customer" VALUES(1,'ООО «Автосборка-Север»','сборочный завод','7801234567','Павлов И. А.','+7 812 555-01-01','Санкт-Петербург, ул. Заводская, 12');
INSERT INTO "customer" VALUES(2,'АО «Моторные системы»','сборочный завод','7802345678','Егорова Т. В.','+7 812 555-01-02','Санкт-Петербург, пр. Индустриальный, 40');
INSERT INTO "customer" VALUES(3,'ООО «АвтоДеталь-Опт»','дистрибьютор','7803456789','Белов С. К.','+7 495 555-01-03','Москва, ул. Складская, 5');
INSERT INTO "customer" VALUES(4,'ИП Сидоров В. Н.','дистрибьютор','780412345678',NULL,'+7 911 555-01-04','Выборг, ул. Торговая, 3');
CREATE TABLE customer_order (
	id INTEGER NOT NULL, 
	customer_id INTEGER NOT NULL, 
	order_date DATE NOT NULL, 
	ship_deadline DATE NOT NULL, 
	status VARCHAR(20) NOT NULL, 
	total_amount NUMERIC(14, 2) NOT NULL, 
	PRIMARY KEY (id), 
	CONSTRAINT ck_order_status CHECK (status IN ('новый','в работе','отгружен','закрыт','отменён')), 
	CONSTRAINT ck_order_dates CHECK (ship_deadline >= order_date), 
	FOREIGN KEY(customer_id) REFERENCES customer (id)
);
INSERT INTO "customer_order" VALUES(1,1,'2026-08-25','2026-09-30','отгружен',1145000);
INSERT INTO "customer_order" VALUES(2,2,'2026-09-05','2026-10-20','в работе',717000);
INSERT INTO "customer_order" VALUES(3,3,'2026-09-20','2026-10-31','в работе',609500);
INSERT INTO "customer_order" VALUES(4,1,'2026-10-10','2026-11-30','новый',362500);
INSERT INTO "customer_order" VALUES(5,4,'2026-09-15','2026-10-15','отгружен',320000);
INSERT INTO "customer_order" VALUES(6,3,'2026-11-06','2026-12-15','новый',232500);
CREATE TABLE defect (
	id INTEGER NOT NULL, 
	quality_check_id INTEGER NOT NULL, 
	reason VARCHAR(120) NOT NULL, 
	quantity INTEGER NOT NULL, 
	decision VARCHAR(20) NOT NULL, 
	PRIMARY KEY (id), 
	CONSTRAINT ck_defect_qty CHECK (quantity > 0), 
	CONSTRAINT ck_defect_decision CHECK (decision IN ('исправить','утилизировать')), 
	FOREIGN KEY(quality_check_id) REFERENCES quality_check (id)
);
INSERT INTO "defect" VALUES(1,3,'Размер вне допуска',4,'исправить');
INSERT INTO "defect" VALUES(2,4,'Раковины в отливке',12,'утилизировать');
INSERT INTO "defect" VALUES(3,3,'Следы вибрации при резании',2,'исправить');
INSERT INTO "defect" VALUES(4,1,'Раковины в отливке',3,'утилизировать');
CREATE TABLE department (
	id INTEGER NOT NULL, 
	name VARCHAR(120) NOT NULL, 
	dept_type VARCHAR(30) NOT NULL, 
	parent_id INTEGER, 
	PRIMARY KEY (id), 
	CONSTRAINT ck_department_type CHECK (dept_type IN ('цех','участок','отдел','служба')), 
	UNIQUE (name), 
	FOREIGN KEY(parent_id) REFERENCES department (id) ON DELETE SET NULL
);
INSERT INTO "department" VALUES(1,'Литейный цех','цех',NULL);
INSERT INTO "department" VALUES(2,'Механообрабатывающий цех','цех',NULL);
INSERT INTO "department" VALUES(3,'Термический участок','участок',2);
INSERT INTO "department" VALUES(4,'Участок покрытия и упаковки','участок',2);
INSERT INTO "department" VALUES(5,'Отдел технического контроля','отдел',NULL);
INSERT INTO "department" VALUES(6,'Отдел снабжения','отдел',NULL);
INSERT INTO "department" VALUES(7,'Коммерческий отдел','отдел',NULL);
INSERT INTO "department" VALUES(8,'Складская служба','служба',NULL);
INSERT INTO "department" VALUES(9,'Служба главного механика','служба',NULL);
CREATE TABLE downtime (
	id INTEGER NOT NULL, 
	equipment_id INTEGER NOT NULL, 
	kind VARCHAR(20) NOT NULL, 
	started_at DATETIME NOT NULL, 
	finished_at DATETIME, 
	reason VARCHAR(255), 
	performer_id INTEGER, 
	PRIMARY KEY (id), 
	CONSTRAINT ck_downtime_kind CHECK (kind IN ('плановый','аварийный')), 
	CONSTRAINT ck_downtime_period CHECK (finished_at IS NULL OR finished_at >= started_at), 
	FOREIGN KEY(equipment_id) REFERENCES equipment (id), 
	FOREIGN KEY(performer_id) REFERENCES employee (id) ON DELETE SET NULL
);
INSERT INTO "downtime" VALUES(1,5,'аварийный','2026-10-25 09:00:00',NULL,'Износ шпинделя',10);
INSERT INTO "downtime" VALUES(2,2,'плановый','2026-09-30 08:00:00','2026-09-30 14:00:00','Плановое ТО-2',10);
INSERT INTO "downtime" VALUES(3,1,'аварийный','2026-10-02 10:30:00','2026-10-02 18:30:00','Прорыв гидравлики',10);
CREATE TABLE employee (
	id INTEGER NOT NULL, 
	full_name VARCHAR(120) NOT NULL, 
	position VARCHAR(80) NOT NULL, 
	grade INTEGER, 
	department_id INTEGER NOT NULL, 
	hire_date DATE NOT NULL, 
	is_head BOOLEAN NOT NULL, 
	PRIMARY KEY (id), 
	CONSTRAINT ck_employee_grade CHECK (grade IS NULL OR grade BETWEEN 1 AND 8), 
	FOREIGN KEY(department_id) REFERENCES department (id)
);
INSERT INTO "employee" VALUES(1,'Кузнецов Алексей Викторович','Начальник литейного цеха',NULL,1,'2012-05-14',1);
INSERT INTO "employee" VALUES(2,'Смирнов Дмитрий Олегович','Литейщик',5,1,'2016-09-01',0);
INSERT INTO "employee" VALUES(3,'Попов Сергей Иванович','Токарь-оператор ЧПУ',5,2,'2018-02-12',0);
INSERT INTO "employee" VALUES(4,'Соколова Марина Андреевна','Фрезеровщик',4,2,'2019-06-03',0);
INSERT INTO "employee" VALUES(5,'Лебедев Игорь Павлович','Шлифовщик',5,2,'2017-11-20',0);
INSERT INTO "employee" VALUES(6,'Новиков Андрей Николаевич','Термист',4,3,'2020-01-13',0);
INSERT INTO "employee" VALUES(7,'Морозова Елена Сергеевна','Начальник ОТК',NULL,5,'2014-04-07',1);
INSERT INTO "employee" VALUES(8,'Волков Артём Игоревич','Контролёр ОТК',4,5,'2021-03-15',0);
INSERT INTO "employee" VALUES(9,'Фёдорова Ольга Петровна','Специалист по закупкам',NULL,6,'2019-09-09',0);
INSERT INTO "employee" VALUES(10,'Орлов Николай Фёдорович','Слесарь-ремонтник',5,9,'2013-08-26',0);
CREATE TABLE equipment (
	id INTEGER NOT NULL, 
	inventory_number VARCHAR(30) NOT NULL, 
	equipment_type_id INTEGER NOT NULL, 
	model VARCHAR(80) NOT NULL, 
	department_id INTEGER NOT NULL, 
	commissioned_year INTEGER, 
	status VARCHAR(20) NOT NULL, 
	PRIMARY KEY (id), 
	CONSTRAINT ck_equipment_status CHECK (status IN ('работает','ремонт','списан')), 
	UNIQUE (inventory_number), 
	FOREIGN KEY(equipment_type_id) REFERENCES equipment_type (id), 
	FOREIGN KEY(department_id) REFERENCES department (id)
);
INSERT INTO "equipment" VALUES(1,'ЛМ-001',1,'ЛПД-2500',1,2014,'работает');
INSERT INTO "equipment" VALUES(2,'ТС-101',2,'DMG CTX 310',2,2018,'работает');
INSERT INTO "equipment" VALUES(3,'ТС-102',2,'Haas ST-20',2,2020,'работает');
INSERT INTO "equipment" VALUES(4,'ФС-201',3,'Haas VF-2',2,2019,'работает');
INSERT INTO "equipment" VALUES(5,'ШС-301',4,'Studer S33',2,2017,'ремонт');
INSERT INTO "equipment" VALUES(6,'ПТ-401',5,'СНО-8.16',3,2015,'работает');
CREATE TABLE equipment_type (
	id INTEGER NOT NULL, 
	name VARCHAR(100) NOT NULL, 
	PRIMARY KEY (id), 
	UNIQUE (name)
);
INSERT INTO "equipment_type" VALUES(1,'Литейная машина');
INSERT INTO "equipment_type" VALUES(2,'Токарный станок с ЧПУ');
INSERT INTO "equipment_type" VALUES(3,'Фрезерный станок');
INSERT INTO "equipment_type" VALUES(4,'Шлифовальный станок');
INSERT INTO "equipment_type" VALUES(5,'Печь термообработки');
CREATE TABLE material (
	id INTEGER NOT NULL, 
	name VARCHAR(120) NOT NULL, 
	metal_grade VARCHAR(40) NOT NULL, 
	unit VARCHAR(10) NOT NULL, 
	current_price NUMERIC(12, 2) NOT NULL, 
	min_stock NUMERIC(12, 3) NOT NULL, 
	PRIMARY KEY (id), 
	CONSTRAINT ck_material_price CHECK (current_price >= 0)
);
INSERT INTO "material" VALUES(1,'Чугун СЧ25 (чушка)','СЧ25','кг',68.5,2000);
INSERT INTO "material" VALUES(2,'Сталь 40Х (прокат)','40Х','кг',92,1500);
INSERT INTO "material" VALUES(3,'Сталь 45 (круг)','45','кг',84,800);
INSERT INTO "material" VALUES(4,'Сталь 20Х (заготовка)','20Х','кг',88,300);
CREATE TABLE operation_log (
	id INTEGER NOT NULL, 
	production_order_id INTEGER NOT NULL, 
	route_operation_id INTEGER NOT NULL, 
	equipment_id INTEGER NOT NULL, 
	employee_id INTEGER NOT NULL, 
	started_at DATETIME NOT NULL, 
	finished_at DATETIME, 
	good_qty INTEGER NOT NULL, 
	defect_qty INTEGER NOT NULL, 
	PRIMARY KEY (id), 
	CONSTRAINT ck_oplog_good CHECK (good_qty >= 0), 
	CONSTRAINT ck_oplog_defect CHECK (defect_qty >= 0), 
	CONSTRAINT ck_oplog_period CHECK (finished_at IS NULL OR finished_at >= started_at), 
	FOREIGN KEY(production_order_id) REFERENCES production_order (id), 
	FOREIGN KEY(route_operation_id) REFERENCES route_operation (id), 
	FOREIGN KEY(equipment_id) REFERENCES equipment (id), 
	FOREIGN KEY(employee_id) REFERENCES employee (id)
);
INSERT INTO "operation_log" VALUES(1,1,1,1,2,'2026-09-01 08:00:00','2026-09-04 16:00:00',508,12);
INSERT INTO "operation_log" VALUES(2,1,2,2,3,'2026-09-05 08:00:00','2026-09-09 15:00:00',503,5);
INSERT INTO "operation_log" VALUES(3,1,3,5,5,'2026-09-10 08:00:00','2026-09-12 16:00:00',500,3);
INSERT INTO "operation_log" VALUES(4,2,6,3,3,'2026-09-03 08:00:00','2026-09-08 16:00:00',207,3);
INSERT INTO "operation_log" VALUES(5,2,7,4,4,'2026-09-09 08:00:00','2026-09-12 16:00:00',203,4);
INSERT INTO "operation_log" VALUES(6,2,8,6,6,'2026-09-13 08:00:00','2026-09-17 16:00:00',200,3);
INSERT INTO "operation_log" VALUES(7,3,9,4,4,'2026-10-01 08:00:00','2026-10-06 16:00:00',306,4);
INSERT INTO "operation_log" VALUES(8,3,10,6,6,'2026-10-08 08:00:00',NULL,0,0);
INSERT INTO "operation_log" VALUES(9,4,12,2,3,'2026-09-20 08:00:00','2026-09-23 16:00:00',1012,12);
INSERT INTO "operation_log" VALUES(10,4,13,6,6,'2026-09-24 08:00:00','2026-09-26 16:00:00',1005,7);
INSERT INTO "operation_log" VALUES(11,4,14,5,5,'2026-09-27 08:00:00','2026-09-29 16:00:00',1000,5);
INSERT INTO "operation_log" VALUES(12,5,4,1,2,'2026-10-05 08:00:00','2026-10-08 16:00:00',412,12);
INSERT INTO "operation_log" VALUES(13,5,5,3,3,'2026-10-10 08:00:00',NULL,0,0);
CREATE TABLE order_item (
	order_id INTEGER NOT NULL, 
	line_no INTEGER NOT NULL, 
	product_id INTEGER NOT NULL, 
	quantity INTEGER NOT NULL, 
	price NUMERIC(12, 2) NOT NULL, 
	PRIMARY KEY (order_id, line_no), 
	CONSTRAINT ck_order_item_line CHECK (line_no > 0), 
	CONSTRAINT ck_order_item_qty CHECK (quantity > 0), 
	CONSTRAINT ck_order_item_price CHECK (price >= 0), 
	FOREIGN KEY(order_id) REFERENCES customer_order (id), 
	FOREIGN KEY(product_id) REFERENCES product (id)
);
INSERT INTO "order_item" VALUES(1,1,1,500,1450);
INSERT INTO "order_item" VALUES(1,2,3,200,2100);
INSERT INTO "order_item" VALUES(2,1,4,300,1750);
INSERT INTO "order_item" VALUES(2,2,5,600,320);
INSERT INTO "order_item" VALUES(3,1,2,400,980);
INSERT INTO "order_item" VALUES(3,2,1,150,1450);
INSERT INTO "order_item" VALUES(4,1,1,250,1450);
INSERT INTO "order_item" VALUES(5,1,5,1000,320);
INSERT INTO "order_item" VALUES(6,1,1,100,1450);
INSERT INTO "order_item" VALUES(6,2,4,50,1750);
CREATE TABLE product (
	id INTEGER NOT NULL, 
	article VARCHAR(30) NOT NULL, 
	name VARCHAR(120) NOT NULL, 
	product_type VARCHAR(30) NOT NULL, 
	modification VARCHAR(60), 
	mass_kg NUMERIC(8, 3), 
	unit VARCHAR(10) NOT NULL, 
	price NUMERIC(12, 2) NOT NULL, 
	drawing_url VARCHAR(255), 
	PRIMARY KEY (id), 
	CONSTRAINT ck_product_type CHECK (product_type IN ('диск','ступица','шатун','палец')), 
	CONSTRAINT ck_product_mass CHECK (mass_kg > 0), 
	CONSTRAINT ck_product_price CHECK (price >= 0), 
	UNIQUE (article)
);
INSERT INTO "product" VALUES(1,'TD-2108-01','Тормозной диск вентилируемый R15','диск','вентилируемый',7.8,'шт',1450,NULL);
INSERT INTO "product" VALUES(2,'TD-2108-02','Тормозной диск сплошной R14','диск','сплошной',5.2,'шт',980,NULL);
INSERT INTO "product" VALUES(3,'ST-3302','Ступица колеса передняя','ступица','передняя',4.6,'шт',2100,NULL);
INSERT INTO "product" VALUES(4,'SH-4011','Шатун двигателя','шатун',NULL,0.72,'шт',1750,NULL);
INSERT INTO "product" VALUES(5,'PP-5005','Поршневой палец','палец',NULL,0.11,'шт',320,NULL);
CREATE TABLE production_order (
	id INTEGER NOT NULL, 
	product_id INTEGER NOT NULL, 
	order_id INTEGER, 
	planned_qty INTEGER NOT NULL, 
	start_date DATE NOT NULL, 
	end_date DATE, 
	melt_number VARCHAR(40), 
	status VARCHAR(20) NOT NULL, 
	PRIMARY KEY (id), 
	CONSTRAINT ck_prod_order_qty CHECK (planned_qty > 0), 
	CONSTRAINT ck_prod_order_status CHECK (status IN ('запланировано','в работе','выполнено','отменено')), 
	FOREIGN KEY(product_id) REFERENCES product (id), 
	FOREIGN KEY(order_id) REFERENCES customer_order (id)
);
INSERT INTO "production_order" VALUES(1,1,1,500,'2026-09-01','2026-09-12','П-24-0915','выполнено');
INSERT INTO "production_order" VALUES(2,3,1,200,'2026-09-03','2026-09-18','С-24-0733','выполнено');
INSERT INTO "production_order" VALUES(3,4,2,300,'2026-10-01',NULL,'С-24-0802','в работе');
INSERT INTO "production_order" VALUES(4,5,5,1000,'2026-09-20','2026-09-29','С-24-0811','выполнено');
INSERT INTO "production_order" VALUES(5,2,3,400,'2026-10-05',NULL,'П-24-0915','в работе');
INSERT INTO "production_order" VALUES(6,1,NULL,100,'2026-11-10',NULL,NULL,'запланировано');
CREATE TABLE purchase (
	id INTEGER NOT NULL, 
	supplier_id INTEGER NOT NULL, 
	material_id INTEGER NOT NULL, 
	quantity NUMERIC(12, 3) NOT NULL, 
	price NUMERIC(12, 2) NOT NULL, 
	delivery_date DATE NOT NULL, 
	melt_number VARCHAR(40) NOT NULL, 
	certificate VARCHAR(80), 
	PRIMARY KEY (id), 
	CONSTRAINT ck_purchase_qty CHECK (quantity > 0), 
	CONSTRAINT ck_purchase_price CHECK (price >= 0), 
	FOREIGN KEY(supplier_id) REFERENCES supplier (id), 
	FOREIGN KEY(material_id) REFERENCES material (id)
);
INSERT INTO "purchase" VALUES(1,1,1,5000,66.8,'2026-08-20','П-24-0915','СК-2026-1187');
INSERT INTO "purchase" VALUES(2,2,3,2000,83,'2026-08-25','С-24-0733','СК-2026-1201');
INSERT INTO "purchase" VALUES(3,2,2,1800,90.5,'2026-09-22','С-24-0802','СК-2026-1310');
INSERT INTO "purchase" VALUES(4,3,4,400,86,'2026-09-10','С-24-0811','СК-2026-1255');
CREATE TABLE quality_check (
	id INTEGER NOT NULL, 
	production_order_id INTEGER NOT NULL, 
	inspector_id INTEGER NOT NULL, 
	check_date DATE NOT NULL, 
	check_type VARCHAR(20) NOT NULL, 
	result VARCHAR(20) NOT NULL, 
	protocol VARCHAR(255), 
	PRIMARY KEY (id), 
	CONSTRAINT ck_qc_type CHECK (check_type IN ('входной','операционный','приёмочный')), 
	CONSTRAINT ck_qc_result CHECK (result IN ('годна','брак','условно годна')), 
	FOREIGN KEY(production_order_id) REFERENCES production_order (id), 
	FOREIGN KEY(inspector_id) REFERENCES employee (id)
);
INSERT INTO "quality_check" VALUES(1,1,7,'2026-09-12','приёмочный','годна','ПР-0912-01');
INSERT INTO "quality_check" VALUES(2,2,8,'2026-09-18','приёмочный','годна','ПР-0918-02');
INSERT INTO "quality_check" VALUES(3,3,8,'2026-10-07','операционный','условно годна','ПР-1007-03');
INSERT INTO "quality_check" VALUES(4,5,7,'2026-10-09','операционный','брак','ПР-1009-04');
INSERT INTO "quality_check" VALUES(5,4,7,'2026-09-29','приёмочный','годна','ПР-0929-05');
CREATE TABLE route (
	id INTEGER NOT NULL, 
	product_id INTEGER NOT NULL, 
	version INTEGER NOT NULL, 
	status VARCHAR(20) NOT NULL, 
	PRIMARY KEY (id), 
	CONSTRAINT ck_route_status CHECK (status IN ('действует','архив')), 
	CONSTRAINT uq_route_product_version UNIQUE (product_id, version), 
	FOREIGN KEY(product_id) REFERENCES product (id)
);
INSERT INTO "route" VALUES(1,1,1,'действует');
INSERT INTO "route" VALUES(2,2,1,'действует');
INSERT INTO "route" VALUES(3,3,1,'действует');
INSERT INTO "route" VALUES(4,4,1,'действует');
INSERT INTO "route" VALUES(5,5,1,'действует');
CREATE TABLE route_operation (
	id INTEGER NOT NULL, 
	route_id INTEGER NOT NULL, 
	seq_no INTEGER NOT NULL, 
	name VARCHAR(100) NOT NULL, 
	equipment_type_id INTEGER NOT NULL, 
	time_norm_min NUMERIC(8, 2) NOT NULL, 
	PRIMARY KEY (id), 
	CONSTRAINT ck_route_operation_seq CHECK (seq_no > 0), 
	CONSTRAINT ck_route_operation_norm CHECK (time_norm_min > 0), 
	CONSTRAINT uq_route_operation_seq UNIQUE (route_id, seq_no), 
	FOREIGN KEY(route_id) REFERENCES route (id), 
	FOREIGN KEY(equipment_type_id) REFERENCES equipment_type (id)
);
INSERT INTO "route_operation" VALUES(1,1,1,'Литьё',1,8.5);
INSERT INTO "route_operation" VALUES(2,1,2,'Токарная обработка',2,6);
INSERT INTO "route_operation" VALUES(3,1,3,'Шлифование',4,4);
INSERT INTO "route_operation" VALUES(4,2,1,'Литьё',1,7);
INSERT INTO "route_operation" VALUES(5,2,2,'Токарная обработка',2,5);
INSERT INTO "route_operation" VALUES(6,3,1,'Токарная обработка',2,12);
INSERT INTO "route_operation" VALUES(7,3,2,'Фрезерование',3,9);
INSERT INTO "route_operation" VALUES(8,3,3,'Термообработка',5,25);
INSERT INTO "route_operation" VALUES(9,4,1,'Фрезерование',3,10);
INSERT INTO "route_operation" VALUES(10,4,2,'Термообработка',5,30);
INSERT INTO "route_operation" VALUES(11,4,3,'Шлифование',4,7.5);
INSERT INTO "route_operation" VALUES(12,5,1,'Токарная обработка',2,2.5);
INSERT INTO "route_operation" VALUES(13,5,2,'Термообработка',5,20);
INSERT INTO "route_operation" VALUES(14,5,3,'Шлифование',4,3);
CREATE TABLE shipment (
	id INTEGER NOT NULL, 
	order_id INTEGER NOT NULL, 
	ship_date DATE NOT NULL, 
	carrier VARCHAR(100), 
	waybill_number VARCHAR(30) NOT NULL, 
	status VARCHAR(20) NOT NULL, 
	PRIMARY KEY (id), 
	CONSTRAINT ck_shipment_status CHECK (status IN ('подготовлена','в пути','доставлена')), 
	FOREIGN KEY(order_id) REFERENCES customer_order (id), 
	UNIQUE (waybill_number)
);
INSERT INTO "shipment" VALUES(1,1,'2026-09-30','ТК «Север»','НКЛ-2026-0101','доставлена');
INSERT INTO "shipment" VALUES(2,5,'2026-10-02','ТК «Балтика»','НКЛ-2026-0102','доставлена');
CREATE TABLE stock_movement (
	id INTEGER NOT NULL, 
	movement_type VARCHAR(10) NOT NULL, 
	material_id INTEGER, 
	product_id INTEGER, 
	warehouse_id INTEGER NOT NULL, 
	quantity NUMERIC(12, 3) NOT NULL, 
	movement_date DATE NOT NULL, 
	document_type VARCHAR(30), 
	document_id INTEGER, 
	PRIMARY KEY (id), 
	CONSTRAINT ck_stock_type CHECK (movement_type IN ('приход','расход')), 
	CONSTRAINT ck_stock_qty CHECK (quantity > 0), 
	CONSTRAINT ck_stock_material_or_product CHECK ((material_id IS NOT NULL AND product_id IS NULL) OR (material_id IS NULL AND product_id IS NOT NULL)), 
	FOREIGN KEY(material_id) REFERENCES material (id), 
	FOREIGN KEY(product_id) REFERENCES product (id), 
	FOREIGN KEY(warehouse_id) REFERENCES warehouse (id)
);
INSERT INTO "stock_movement" VALUES(1,'приход',1,NULL,1,5000,'2026-08-20','purchase',1);
INSERT INTO "stock_movement" VALUES(2,'приход',3,NULL,1,2000,'2026-08-25','purchase',2);
INSERT INTO "stock_movement" VALUES(3,'приход',2,NULL,1,1800,'2026-09-22','purchase',3);
INSERT INTO "stock_movement" VALUES(4,'приход',4,NULL,1,400,'2026-09-10','purchase',4);
INSERT INTO "stock_movement" VALUES(5,'расход',1,NULL,1,4700,'2026-09-01','production_order',1);
INSERT INTO "stock_movement" VALUES(6,'расход',3,NULL,1,1120,'2026-09-03','production_order',2);
INSERT INTO "stock_movement" VALUES(7,'расход',2,NULL,1,285,'2026-10-01','production_order',3);
INSERT INTO "stock_movement" VALUES(8,'расход',4,NULL,1,140,'2026-09-20','production_order',4);
INSERT INTO "stock_movement" VALUES(9,'приход',NULL,1,3,500,'2026-09-12','production_order',1);
INSERT INTO "stock_movement" VALUES(10,'приход',NULL,3,3,200,'2026-09-18','production_order',2);
INSERT INTO "stock_movement" VALUES(11,'приход',NULL,5,3,1000,'2026-09-29','production_order',4);
INSERT INTO "stock_movement" VALUES(12,'расход',NULL,1,3,500,'2026-09-30','shipment',1);
INSERT INTO "stock_movement" VALUES(13,'расход',NULL,3,3,200,'2026-09-30','shipment',1);
INSERT INTO "stock_movement" VALUES(14,'расход',NULL,5,3,1000,'2026-10-02','shipment',2);
INSERT INTO "stock_movement" VALUES(15,'приход',NULL,2,3,150,'2026-10-12','production_order',5);
INSERT INTO "stock_movement" VALUES(16,'приход',NULL,4,3,120,'2026-10-15','production_order',3);
CREATE TABLE supplier (
	id INTEGER NOT NULL, 
	name VARCHAR(150) NOT NULL, 
	inn VARCHAR(12) NOT NULL, 
	contacts VARCHAR(255), 
	rating INTEGER, 
	PRIMARY KEY (id), 
	CONSTRAINT ck_supplier_rating CHECK (rating IS NULL OR rating BETWEEN 1 AND 5), 
	UNIQUE (inn)
);
INSERT INTO "supplier" VALUES(1,'ООО «Литейные металлы»','7811111111','sales@litmet.example',5);
INSERT INTO "supplier" VALUES(2,'АО «Сталь-Снаб»','7822222222','+7 812 555-02-02',4);
INSERT INTO "supplier" VALUES(3,'ООО «Спецпрокат»','7833333333',NULL,3);
CREATE TABLE warehouse (
	id INTEGER NOT NULL, 
	name VARCHAR(100) NOT NULL, 
	location VARCHAR(150), 
	PRIMARY KEY (id), 
	UNIQUE (name)
);
INSERT INTO "warehouse" VALUES(1,'Склад металла','Корпус 1');
INSERT INTO "warehouse" VALUES(2,'Склад заготовок','Корпус 2');
INSERT INTO "warehouse" VALUES(3,'Склад готовой продукции','Корпус 3');
CREATE INDEX ix_order_customer ON customer_order (customer_id);
CREATE INDEX ix_purchase_melt ON purchase (melt_number);
CREATE INDEX ix_stock_material ON stock_movement (material_id, warehouse_id);
CREATE INDEX ix_downtime_equipment ON downtime (equipment_id);
CREATE INDEX ix_production_order_melt ON production_order (melt_number);
CREATE INDEX ix_operation_log_equipment ON operation_log (equipment_id, finished_at);
CREATE INDEX ix_operation_log_order ON operation_log (production_order_id);
COMMIT;