-- ───────────────────────────────────────────────────────────────
-- FARM TO TABLE: CORE SCHEMA (Clean Master Template)
-- ───────────────────────────────────────────────────────────────
-- CREATE DATABASE IF NOT EXISTS farm_to_table;
-- USE farm_to_table;


SET FOREIGN_KEY_CHECKS = 0;

-- Drop all existing tables/views/procedures to ensure a clean state
DROP TABLE IF EXISTS Support_Messages;
DROP TABLE IF EXISTS Messages;
DROP TABLE IF EXISTS Reviews;
DROP TABLE IF EXISTS Order_Items;
DROP TABLE IF EXISTS Orders;
DROP TABLE IF EXISTS Products;
DROP TABLE IF EXISTS Users;
DROP TABLE IF EXISTS Customers; 
DROP TABLE IF EXISTS Categories;
DROP TABLE IF EXISTS Farms;
DROP VIEW IF EXISTS vw_Farm_Analytics;
DROP VIEW IF EXISTS vw_Customer_Orders;
DROP VIEW IF EXISTS vw_Farmer_Reviews;
DROP VIEW IF EXISTS vw_Revenue_By_Day;
DROP PROCEDURE IF EXISTS sp_PlaceOrder;

SET FOREIGN_KEY_CHECKS = 1;

-- ─── TABLES ──────────────────────────────────────

CREATE TABLE Farms (
    farm_id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    location VARCHAR(100),
    description TEXT,
    image_url VARCHAR(500),
    rating DECIMAL(2,1) CHECK (rating BETWEEN 0 AND 5)
);

CREATE TABLE Categories (
    category_id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE Users (
    user_id INT PRIMARY KEY AUTO_INCREMENT,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    role ENUM('Customer', 'Farmer') DEFAULT 'Customer',
    farm_id    INT,
    address    VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (farm_id) REFERENCES Farms(farm_id) ON DELETE SET NULL
);

CREATE TABLE Products (
    product_id INT PRIMARY KEY AUTO_INCREMENT,
    farm_id INT NOT NULL,
    category_id INT NOT NULL,
    name VARCHAR(100) NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    image_url VARCHAR(500),
    description TEXT,
    rating DECIMAL(2,1) DEFAULT 0.0,
    stock_quantity INT DEFAULT 0 CHECK (stock_quantity >= 0),
    is_active TINYINT(1) DEFAULT 1,
    harvest_date DATE,
    shelf_life_days INT,
    FOREIGN KEY (farm_id) REFERENCES Farms(farm_id) ON DELETE CASCADE,
    FOREIGN KEY (category_id) REFERENCES Categories(category_id) ON DELETE CASCADE
);

CREATE TABLE Orders (
    order_id INT PRIMARY KEY AUTO_INCREMENT,
    customer_id INT NOT NULL,
    total_amount DECIMAL(10,2) NOT NULL,
    status ENUM('Pending', 'Shipped', 'Completed', 'Cancelled') DEFAULT 'Pending',
    order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES Users(user_id) ON DELETE CASCADE
);

CREATE TABLE Order_Items (
    item_id INT PRIMARY KEY AUTO_INCREMENT,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    FOREIGN KEY (order_id) REFERENCES Orders(order_id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES Products(product_id) ON DELETE CASCADE
);

CREATE TABLE Reviews (
    review_id INT PRIMARY KEY AUTO_INCREMENT,
    customer_id INT NOT NULL,
    product_id INT NOT NULL,
    rating INT CHECK (rating BETWEEN 1 AND 5),
    comment TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES Users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES Products(product_id) ON DELETE CASCADE
);

CREATE TABLE Messages (
    message_id INT AUTO_INCREMENT PRIMARY KEY,
    sender_id INT NOT NULL,
    receiver_id INT NOT NULL,
    content TEXT NOT NULL,
    sent_at DATETIME DEFAULT NOW(),
    FOREIGN KEY (sender_id) REFERENCES Users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (receiver_id) REFERENCES Users(user_id) ON DELETE CASCADE
);

CREATE TABLE Support_Messages (
    support_id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    email VARCHAR(100),
    subject VARCHAR(200),
    message TEXT,
    submitted_at DATETIME DEFAULT NOW()
);

-- ─── PROCEDURES & TRIGGERS ─────────────────────────
-- Note: Triggers (trg_deduct_stock and trg_update_rating) are omitted here because shared cloud
-- databases (like Clever Cloud, AWS RDS) restrict SUPER privileges required for triggers.
-- Instead, stock deduction is handled directly within the sp_PlaceOrder procedure,
-- and product ratings are updated manually in the backend code (app.py) after inserting reviews.

DELIMITER //

CREATE PROCEDURE sp_PlaceOrder(
    IN p_customer_id INT, 
    IN p_total_amount DECIMAL(10,2), 
    IN p_items_json JSON,
    OUT p_order_id INT
)
BEGIN
    DECLARE v_idx INT DEFAULT 0;
    DECLARE v_count INT DEFAULT JSON_LENGTH(p_items_json);
    DECLARE v_prod_id INT;
    DECLARE v_qty INT;
    DECLARE v_price DECIMAL(10,2);
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;
    INSERT INTO Orders (customer_id, total_amount) VALUES (p_customer_id, p_total_amount);
    SET p_order_id = LAST_INSERT_ID();
    
    WHILE v_idx < v_count DO
        SET v_prod_id = JSON_UNQUOTE(JSON_EXTRACT(p_items_json, CONCAT('$[', v_idx, '].product_id')));
        SET v_qty = JSON_UNQUOTE(JSON_EXTRACT(p_items_json, CONCAT('$[', v_idx, '].quantity')));
        SET v_price = JSON_UNQUOTE(JSON_EXTRACT(p_items_json, CONCAT('$[', v_idx, '].price')));
        
        INSERT INTO Order_Items (order_id, product_id, quantity, price) 
        VALUES (p_order_id, v_prod_id, v_qty, v_price);
        
        -- Deduct stock directly inside procedure (replicates trigger trg_deduct_stock)
        UPDATE Products 
        SET stock_quantity = stock_quantity - v_qty 
        WHERE product_id = v_prod_id;
        
        SET v_idx = v_idx + 1;
    END WHILE;
    COMMIT;
END //

DELIMITER ;

-- ─── VIEWS ────────────────────────────────────────

CREATE VIEW vw_Farm_Analytics AS
SELECT 
    f.farm_id,
    f.name AS farm_name,
    COUNT(DISTINCT o.order_id) AS total_orders,
    COALESCE(SUM(oi.quantity * oi.price), 0) AS total_revenue,
    AVG(p.rating) AS average_product_rating
FROM Farms f
LEFT JOIN Products p ON f.farm_id = p.farm_id
LEFT JOIN Order_Items oi ON p.product_id = oi.product_id
LEFT JOIN Orders o ON oi.order_id = o.order_id
GROUP BY f.farm_id, f.name;

CREATE VIEW vw_Customer_Orders AS
SELECT 
    o.order_id,
    o.customer_id,
    o.total_amount,
    o.status,
    o.order_date AS created_at,
    oi.quantity,
    oi.price AS item_price,
    p.product_id,
    p.name AS product_name
FROM Orders o
JOIN Order_Items oi ON o.order_id = oi.order_id
JOIN Products p ON oi.product_id = p.product_id;

CREATE VIEW vw_Farmer_Reviews AS
SELECT
    r.review_id,
    r.rating,
    r.comment,
    r.created_at,
    p.name      AS product_name,
    p.farm_id,
    u.first_name AS customer_first,
    u.last_name  AS customer_last
FROM Reviews r
JOIN Products p ON r.product_id = p.product_id
JOIN Users    u ON r.customer_id = u.user_id;

CREATE VIEW vw_Revenue_By_Day AS
SELECT
    DATE(o.order_date)          AS order_day,
    p.farm_id,
    SUM(oi.price * oi.quantity) AS daily_revenue
FROM Orders o
JOIN Order_Items oi ON o.order_id  = oi.order_id
JOIN Products    p  ON oi.product_id = p.product_id
WHERE o.status != 'Cancelled'
GROUP BY DATE(o.order_date), p.farm_id;