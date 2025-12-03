USE ecommerce_db;

-- ========================================================
-- 1. VIEWS (Tạo 3 views theo yêu cầu)
-- ========================================================

-- View 1: Thống kê đơn hàng theo khách hàng
CREATE OR REPLACE VIEW v_orders_by_customer AS
SELECT 
    c.customer_id, c.full_name, 
    o.order_id, o.order_date, o.total_amount, o.order_status
FROM CUSTOMERS c
JOIN ORDERS o ON c.customer_id = o.customer_id;

-- View 2: Tổng kết doanh thu theo tháng
CREATE OR REPLACE VIEW v_monthly_sales_summary AS
SELECT 
    YEAR(order_date) AS Year, 
    MONTH(order_date) AS Month,
    COUNT(order_id) AS Total_Orders,
    -- Chỉ cộng tiền nếu trạng thái KHÔNG PHẢI là Cancelled
    SUM(CASE 
        WHEN order_status != 'Cancelled' THEN total_amount 
        ELSE 0 
    END) AS Total_Revenue,
    SUM(CASE WHEN order_status = 'Cancelled' THEN 1 ELSE 0 END) AS Total_Cancelled
FROM ORDERS
GROUP BY YEAR(order_date), MONTH(order_date);

-- View 3: Sản phẩm bán chạy
CREATE OR REPLACE VIEW v_popular_products AS
SELECT 
    p.product_id, p.product_name,
    SUM(od.quantity) AS Total_Quantity_Sold,
    SUM(od.subtotal) AS Total_Revenue_Generated
FROM PRODUCTS p
JOIN ORDER_DETAILS od ON p.product_id = od.product_id
JOIN ORDERS o ON od.order_id = o.order_id
WHERE o.order_status != 'Cancelled'
GROUP BY p.product_id, p.product_name

ORDER BY Total_Quantity_Sold DESC;

-- ========================================================
-- 2. STORED PROCEDURES (Tạo 2 procedures)
-- ========================================================

DELIMITER //

-- Proc 1: Báo cáo doanh thu tháng (Input: Year, Month)
CREATE PROCEDURE sp_monthly_revenue_report(IN p_year INT, IN p_month INT)
BEGIN
    SELECT * FROM v_monthly_sales_summary
    WHERE Year = p_year AND Month = p_month;
END //

-- Proc 2: Tạo đơn hàng mới (Đơn giản hóa để demo logic trừ kho)
CREATE PROCEDURE sp_create_simple_order(
    IN p_customer_id INT, 
    IN p_product_id INT, 
    IN p_quantity INT,
    IN p_price DECIMAL(10,2)
)
BEGIN
    DECLARE v_order_id INT;
    
    -- 1. Tạo Order Header
    INSERT INTO ORDERS (customer_id, order_date, order_status) 
    VALUES (p_customer_id, NOW(), 'Pending');
    
    SET v_order_id = LAST_INSERT_ID();
    
    -- 2. Tạo Order Detail
    INSERT INTO ORDER_DETAILS (order_id, product_id, quantity, unit_price)
    VALUES (v_order_id, p_product_id, p_quantity, p_price);
    
    -- 3. Cập nhật Total Amount cho Order
    UPDATE ORDERS SET total_amount = (p_quantity * p_price) WHERE order_id = v_order_id;
    
    SELECT concat('Order created successfully with ID: ', v_order_id) as Message;
END //

DELIMITER ;

-- ========================================================
-- 3. TRIGGERS (Tạo 1 trigger)
-- ========================================================

DELIMITER //

-- 2. Tạo lại Trigger
CREATE TRIGGER trg_decrease_stock_after_order
AFTER INSERT ON ORDER_DETAILS
FOR EACH ROW
BEGIN
    UPDATE PRODUCTS
    SET stock_quantity = stock_quantity - NEW.quantity
    WHERE product_id = NEW.product_id;
END //

DELIMITER ;
