-- SQL-эквиваленты запросов из requests.py (для проверки результатов в любой СУБД)
-- Q01 get_customer_orders (клиент 1)
SELECT id, order_date, status, total_amount FROM customer_order WHERE customer_id = 1 ORDER BY order_date DESC;
-- Q02 get_order_composition (заказ 2)
SELECT oi.line_no, p.article, p.name, oi.quantity, oi.price, oi.quantity*oi.price AS line_sum
FROM order_item oi JOIN product p ON p.id = oi.product_id WHERE oi.order_id = 2 ORDER BY oi.line_no;
-- Q03 get_open_orders
SELECT o.id, c.name, o.order_date, o.ship_deadline, o.status, o.total_amount
FROM customer_order o JOIN customer c ON c.id = o.customer_id
WHERE o.status IN ('новый','в работе') ORDER BY o.ship_deadline;
-- Q04 get_overdue_orders (на 2026-11-06)
SELECT o.id, c.name, o.ship_deadline, o.status
FROM customer_order o JOIN customer c ON c.id = o.customer_id
WHERE o.status IN ('новый','в работе') AND o.ship_deadline < '2026-11-06' ORDER BY o.ship_deadline;
-- Q05 get_sales_by_customer
SELECT c.name, COUNT(o.id) AS orders, SUM(o.total_amount) AS total
FROM customer c JOIN customer_order o ON o.customer_id = c.id GROUP BY c.id, c.name ORDER BY total DESC;
-- Q06 get_production_orders (в работе)
SELECT po.id, p.article, p.name, po.planned_qty, po.start_date, po.end_date, po.melt_number, po.status
FROM production_order po JOIN product p ON p.id = po.product_id WHERE po.status = 'в работе' ORDER BY po.start_date;
-- Q07 get_route (изделие 4)
SELECT ro.seq_no, ro.name, et.name, ro.time_norm_min
FROM route r JOIN route_operation ro ON ro.route_id = r.id JOIN equipment_type et ON et.id = ro.equipment_type_id
WHERE r.product_id = 4 AND r.status = 'действует' ORDER BY ro.seq_no;
-- Q08 get_production_progress (задание 1)
SELECT ro.seq_no, ro.name, SUM(l.good_qty) AS good, SUM(l.defect_qty) AS defect,
       SUM(CASE WHEN l.finished_at IS NULL THEN 1 ELSE 0 END) AS open_runs
FROM operation_log l JOIN route_operation ro ON ro.id = l.route_operation_id
WHERE l.production_order_id = 1 GROUP BY ro.seq_no, ro.name ORDER BY ro.seq_no;
-- Q09 get_material_requirements (задание 3)
SELECT m.name, m.unit, b.quantity_per_unit * po.planned_qty AS required
FROM production_order po JOIN bom_item b ON b.product_id = po.product_id JOIN material m ON m.id = b.material_id
WHERE po.id = 3;
-- Q10 get_employee_output (сентябрь 2026)
SELECT e.full_name, e.position, SUM(l.good_qty) AS good, SUM(l.defect_qty) AS defect
FROM operation_log l JOIN employee e ON e.id = l.employee_id
WHERE l.started_at >= '2026-09-01' AND l.started_at < '2026-10-01'
GROUP BY e.id, e.full_name, e.position ORDER BY good DESC;
-- Q11 get_defect_rate_by_equipment (сентябрь 2026)
SELECT eq.inventory_number, eq.model, SUM(l.good_qty) AS good, SUM(l.defect_qty) AS defect,
       ROUND(SUM(l.defect_qty)*100.0/(SUM(l.good_qty)+SUM(l.defect_qty)),2) AS defect_pct
FROM operation_log l JOIN equipment eq ON eq.id = l.equipment_id
WHERE l.started_at >= '2026-09-01' AND l.started_at < '2026-10-01'
GROUP BY eq.id, eq.inventory_number, eq.model HAVING SUM(l.good_qty)+SUM(l.defect_qty) > 0
ORDER BY SUM(l.defect_qty)*100.0/(SUM(l.good_qty)+SUM(l.defect_qty)) DESC;
-- Q12 get_defects_by_reason
SELECT reason, SUM(quantity) AS quantity FROM defect GROUP BY reason ORDER BY quantity DESC;
-- Q13 trace_by_melt (П-24-0915)
SELECT pu.melt_number, s.name, pu.certificate, m.name, po.id, p.article, o.id, c.name
FROM purchase pu JOIN supplier s ON s.id = pu.supplier_id JOIN material m ON m.id = pu.material_id
LEFT JOIN production_order po ON po.melt_number = pu.melt_number
LEFT JOIN product p ON p.id = po.product_id
LEFT JOIN customer_order o ON o.id = po.order_id
LEFT JOIN customer c ON c.id = o.customer_id
WHERE pu.melt_number = 'П-24-0915' ORDER BY po.id;
-- Q14 get_material_stock
SELECT m.name, w.name, SUM(CASE WHEN sm.movement_type='приход' THEN sm.quantity ELSE -sm.quantity END) AS balance, m.unit
FROM stock_movement sm JOIN material m ON m.id = sm.material_id JOIN warehouse w ON w.id = sm.warehouse_id
GROUP BY m.id, m.name, w.id, w.name, m.unit ORDER BY m.name;
-- Q15 get_materials_below_min
SELECT m.name, SUM(CASE WHEN sm.movement_type='приход' THEN sm.quantity ELSE -sm.quantity END) AS balance, m.min_stock
FROM stock_movement sm JOIN material m ON m.id = sm.material_id
GROUP BY m.id, m.name, m.min_stock
HAVING SUM(CASE WHEN sm.movement_type='приход' THEN sm.quantity ELSE -sm.quantity END) < m.min_stock ORDER BY m.name;
-- Q16 get_product_stock
SELECT p.article, p.name, w.name, SUM(CASE WHEN sm.movement_type='приход' THEN sm.quantity ELSE -sm.quantity END) AS balance
FROM stock_movement sm JOIN product p ON p.id = sm.product_id JOIN warehouse w ON w.id = sm.warehouse_id
GROUP BY p.id, p.article, p.name, w.id, w.name ORDER BY p.article;
-- Q17 get_supplier_purchases
SELECT s.name, s.rating, COUNT(pu.id) AS deliveries, SUM(pu.quantity*pu.price) AS amount
FROM supplier s JOIN purchase pu ON pu.supplier_id = s.id GROUP BY s.id, s.name, s.rating ORDER BY amount DESC;
-- Q18 get_equipment_downtime (сырые данные; часы считаются в Python)
SELECT e.inventory_number, d.started_at, d.finished_at
FROM downtime d JOIN equipment e ON e.id = d.equipment_id
WHERE d.started_at >= '2026-09-01' AND d.started_at < '2026-11-01';
-- Q19 get_equipment_in_repair
SELECT e.inventory_number, e.model, d.kind, d.started_at, d.reason
FROM equipment e LEFT JOIN downtime d ON d.equipment_id = e.id AND d.finished_at IS NULL
WHERE e.status = 'ремонт';
