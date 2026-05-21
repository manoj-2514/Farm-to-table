-- USE farm_to_table;

-- ═══════════════════════════════════════════════════════════════
-- FARM TO TABLE — SEED DATA (All images browser-verified)
-- Run AFTER create-db-template.sql
-- ═══════════════════════════════════════════════════════════════

-- STEP 1: CLEAR ALL DATA (FK-safe order)
SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE Support_Messages;
TRUNCATE TABLE Messages;
TRUNCATE TABLE Reviews;
TRUNCATE TABLE Order_Items;
TRUNCATE TABLE Orders;
TRUNCATE TABLE Products;
TRUNCATE TABLE Users;
TRUNCATE TABLE Categories;
TRUNCATE TABLE Farms;
SET FOREIGN_KEY_CHECKS = 1;

-- STEP 2: RESET AUTO_INCREMENT
ALTER TABLE Support_Messages AUTO_INCREMENT = 1;
ALTER TABLE Messages         AUTO_INCREMENT = 1;
ALTER TABLE Reviews          AUTO_INCREMENT = 1;
ALTER TABLE Order_Items      AUTO_INCREMENT = 1;
ALTER TABLE Orders           AUTO_INCREMENT = 1;
ALTER TABLE Products         AUTO_INCREMENT = 1;
ALTER TABLE Users            AUTO_INCREMENT = 1;
ALTER TABLE Categories       AUTO_INCREMENT = 1;
ALTER TABLE Farms            AUTO_INCREMENT = 1;

-- STEP 3: CATEGORIES
-- IDs: 1=Vegetables, 2=Dairy, 3=Herbs, 4=Fruits
INSERT INTO Categories (name) VALUES
('Vegetables'), ('Dairy'), ('Herbs'), ('Fruits');

-- STEP 4: FARMS (10 Indian Farms)
INSERT INTO Farms (farm_id, name, location, description, image_url, rating) VALUES
(1,  'Ujjwal Organic Kshetra',    'Punjab, India',           'Premium organic vegetables from the fertile plains of Punjab.',      'https://images.pexels.com/photos/1382394/pexels-photo-1382394.jpeg?w=600', 4.8),
(2,  'Purana Banyan Dugdha Farm', 'Haryana, India',          'Traditional dairy farm with hormone-free A2 milk products.',         'https://images.pexels.com/photos/422218/pexels-photo-422218.jpeg?w=600',   4.9),
(3,  'Neel Parvat Phal-Bagh',     'Himachal Pradesh, India', 'Mountain-grown seasonal fruits from the Himalayan foothills.',       'https://images.pexels.com/photos/257816/pexels-photo-257816.jpeg?w=600',   4.7),
(4,  'Hari Patti Krishi',         'Karnataka, India',        'Hydroponic and field-grown leafy vegetables from Bengaluru region.',  'https://images.pexels.com/photos/1458694/pexels-photo-1458694.jpeg?w=600', 4.6),
(5,  'Shuddh Shikhar Dairy',      'Maharashtra, India',      'High-quality dairy and fresh milk products from the Western Ghats.',  'https://images.pexels.com/photos/735968/pexels-photo-735968.jpeg?w=600',   4.8),
(6,  'Uncha Gaon Jadi Booti',     'Uttarakhand, India',      'Fragrant Himalayan herbs and medicinal plants at high altitude.',     'https://images.pexels.com/photos/1084268/pexels-photo-1084268.jpeg?w=600', 4.7),
(7,  'Sunehri Fasal Anaj',        'Uttar Pradesh, India',    'Farm-fresh grains and pantry staples from the Gangetic plains.',     'https://images.pexels.com/photos/326082/pexels-photo-326082.jpeg?w=600',   4.5),
(8,  'Nadi Ghati Angoor Farm',    'Maharashtra, India',      'Premium Alphonso mangoes and vineyard-fresh tropical fruits.',       'https://images.pexels.com/photos/2294471/pexels-photo-2294471.jpeg?w=600', 4.6),
(9,  'Ghaas Maidan Taaza Farm',   'Tamil Nadu, India',       'Sustainably grown mixed produce from the fertile plains of TN.',     'https://images.pexels.com/photos/2132227/pexels-photo-2132227.jpeg?w=600', 4.8),
(10, 'Chid Pahadi Murgi Farm',    'Kerala, India',           'Free-range country poultry and fresh farm eggs from Kerala.',        'https://images.pexels.com/photos/3214610/pexels-photo-3214610.jpeg?w=600', 4.9);

-- ═══════════════════════════════════════════════════════════════
-- STEP 5: PRODUCTS (4 separate INSERTs — one per category)
-- All image URLs verified by searching Pexels in a browser.
-- ═══════════════════════════════════════════════════════════════

-- VEGETABLES (category_id = 1)
INSERT INTO Products (farm_id, category_id, name, price, image_url, description, rating, stock_quantity, harvest_date, shelf_life_days) VALUES
(1, 1, 'Desi Tomatoes',           40.00, 'https://images.pexels.com/photos/1327838/pexels-photo-1327838.jpeg?w=600',  'Sun-ripened desi tomatoes from the fertile fields of Punjab.',          4.8, 150, CURRENT_DATE - INTERVAL 2 DAY,  7),
(1, 1, 'Aloo (Potatoes)',         30.00, 'https://images.pexels.com/photos/7774212/pexels-photo-7774212.jpeg?w=600',  'Freshly dug earth-grown potatoes from the farms of Amritsar, Punjab.',  4.9, 300, CURRENT_DATE - INTERVAL 5 DAY, 30),
(4, 1, 'Palak (Spinach)',         20.00, 'https://images.pexels.com/photos/2325843/pexels-photo-2325843.jpeg?w=600',  'Iron-rich fresh baby spinach leaves harvested from Karnataka.',          4.7, 100, CURRENT_DATE - INTERVAL 1 DAY,  3),
(4, 1, 'Bhindi (Okra)',           50.00, 'https://images.pexels.com/photos/2583187/pexels-photo-2583187.jpeg?w=600',  'Tender and fresh green ladyfingers (okra) harvested daily in Karnataka.',4.6, 120, CURRENT_DATE - INTERVAL 2 DAY,  5),
(9, 1, 'Baingan (Brinjal)',       45.00, 'https://images.pexels.com/photos/321551/pexels-photo-321551.jpeg?w=600',    'Glossy long purple brinjals (eggplant) from the heart of Tamil Nadu.',  4.5,  80, CURRENT_DATE - INTERVAL 3 DAY,  7),
(9, 1, 'Karela (Bitter Gourd)',   60.00, 'https://images.pexels.com/photos/13569982/pexels-photo-13569982.jpeg?w=600','Fresh bitter gourds grown in the tropical climate of Tamil Nadu.',       4.4,  60, CURRENT_DATE - INTERVAL 4 DAY, 10),
(1, 1, 'Shimla Mirch (Capsicum)', 80.00, 'https://images.pexels.com/photos/594137/pexels-photo-594137.jpeg?w=600',   'Crisp and colorful red, yellow, green capsicums from Punjab polyhouses.',4.8,  90, CURRENT_DATE - INTERVAL 2 DAY,  8),
(4, 1, 'Pyaaz (Onions)',          35.00, 'https://images.pexels.com/photos/144248/pexels-photo-144248.jpeg?w=600',   'Strong-flavored red onions directly from the farms of Karnataka.',       4.9, 250, CURRENT_DATE - INTERVAL 10 DAY,60);

-- DAIRY (category_id = 2)
INSERT INTO Products (farm_id, category_id, name, price, image_url, description, rating, stock_quantity, harvest_date, shelf_life_days) VALUES
(2, 2, 'Paneer (Cottage Cheese)', 120.00, 'https://images.pexels.com/photos/30858402/pexels-photo-30858402.jpeg?w=600','Soft, fresh malai paneer made from pure A2 milk in Haryana.',           4.9, 100, CURRENT_DATE - INTERVAL 1 DAY,   5),
(2, 2, 'Desi Ghee',              650.00, 'https://images.pexels.com/photos/20689436/pexels-photo-20689436.jpeg?w=600','Traditional bilona-method clarified butter from pure Haryana cow milk.', 5.0,  50, CURRENT_DATE - INTERVAL 15 DAY,180),
(2, 2, 'Dahi (Curd)',             40.00, 'https://images.pexels.com/photos/10809260/pexels-photo-10809260.jpeg?w=600','Thick and creamy set curd made fresh daily at Purana Banyan Farm.',      4.8, 120, CURRENT_DATE - INTERVAL 1 DAY,   7),
(5, 2, 'Lassi',                   30.00, 'https://images.pexels.com/photos/6808666/pexels-photo-6808666.jpeg?w=600',  'Refreshing sweet lassi churned fresh from Maharashtra dairy belts.',     4.7, 200, CURRENT_DATE - INTERVAL 1 DAY,   2),
(5, 2, 'Makhan (White Butter)',   250.00, 'https://images.pexels.com/photos/531334/pexels-photo-531334.jpeg?w=600',   'Traditional hand-churned white makhan from Maharashtra dairy farms.',    4.9,  40, CURRENT_DATE - INTERVAL 2 DAY,  15),
(2, 2, 'Desi Cow Milk',           65.00, 'https://images.pexels.com/photos/725998/pexels-photo-725998.jpeg?w=600',   'Pure A2 desi cow milk from the green pastures of Haryana.',             5.0, 150, CURRENT_DATE - INTERVAL 1 DAY,   3);

-- HERBS (category_id = 3)
INSERT INTO Products (farm_id, category_id, name, price, image_url, description, rating, stock_quantity, harvest_date, shelf_life_days) VALUES
(6, 3, 'Haldi (Turmeric)',        180.00, 'https://images.pexels.com/photos/7988006/pexels-photo-7988006.jpeg?w=600', 'Potent raw turmeric roots harvested from organic farms of Uttarakhand.', 4.9, 100, CURRENT_DATE - INTERVAL 5 DAY, 20),
(6, 3, 'Adrak (Ginger)',          150.00, 'https://images.pexels.com/photos/5202091/pexels-photo-5202091.jpeg?w=600', 'Spicy and aromatic fresh ginger roots grown in the hills of Uttarakhand.',4.8, 120, CURRENT_DATE - INTERVAL 4 DAY, 15),
(6, 3, 'Pudina (Mint)',            15.00, 'https://images.pexels.com/photos/34525474/pexels-photo-34525474.jpeg?w=600','Refreshing green mint leaves from the high-altitude farm of Uncha Gaon.',4.7, 200, CURRENT_DATE - INTERVAL 1 DAY,  4),
(6, 3, 'Dhaniya (Coriander)',      15.00, 'https://images.pexels.com/photos/10048317/pexels-photo-10048317.jpeg?w=600','Fresh fragrant coriander leaves hand-picked in Uttarakhand.',            4.6, 250, CURRENT_DATE - INTERVAL 1 DAY,  3),
(6, 3, 'Methi (Fenugreek)',        25.00, 'https://images.pexels.com/photos/9344827/pexels-photo-9344827.jpeg?w=600', 'Fresh and slightly bitter methi (fenugreek) leaves from Uttarakhand.',  4.5, 180, CURRENT_DATE - INTERVAL 2 DAY,  4);

-- FRUITS (category_id = 4)
INSERT INTO Products (farm_id, category_id, name, price, image_url, description, rating, stock_quantity, harvest_date, shelf_life_days) VALUES
(8, 4, 'Alphonso Aam (Mango)',    800.00, 'https://images.pexels.com/photos/918643/pexels-photo-918643.jpeg?w=600',   'World-famous Alphonso mangoes from Ratnagiri, Maharashtra.',             5.0, 300, CURRENT_DATE - INTERVAL 3 DAY, 10),
(9, 4, 'Kela (Banana)',            60.00, 'https://images.pexels.com/photos/2872755/pexels-photo-2872755.jpeg?w=600', 'Naturally ripened yellow bananas from the tropical farms of Tamil Nadu.', 4.7, 200, CURRENT_DATE - INTERVAL 1 DAY,  5),
(3, 4, 'Sitaphal (Custard Apple)', 120.00, 'https://images.pexels.com/photos/15589107/pexels-photo-15589107.jpeg?w=600','Sweet and creamy custard apples from orchards of Himachal Pradesh.',    4.6,  50, CURRENT_DATE - INTERVAL 2 DAY,  4),
(3, 4, 'Amla (Gooseberry)',        90.00, 'https://images.pexels.com/photos/34928285/pexels-photo-34928285.jpeg?w=600','Vitamin C-rich amla (Indian gooseberry) from Himachal Pradesh orchards.',4.9, 150, CURRENT_DATE - INTERVAL 5 DAY, 15),
(3, 4, 'Jamun (Blackberry)',      150.00, 'https://images.pexels.com/photos/892808/pexels-photo-892808.jpeg?w=600',   'Deep purple jamun fruits from the foothills of Himachal Pradesh.',      4.8,  70, CURRENT_DATE - INTERVAL 2 DAY,  4),
(8, 4, 'Chikoo (Sapodilla)',       80.00, 'https://images.pexels.com/photos/5945755/pexels-photo-5945755.jpeg?w=600',  'Sweet and grainy chikoo (sapodilla) from coastal orchards of Maharashtra.',4.7, 100, CURRENT_DATE - INTERVAL 3 DAY,  6);

-- ═══════════════════════════════════════════════════════════════
-- STEP 6: SAMPLE USERS (for demo & testing on fresh install)
-- 1 Customer + 1 Farmer linked to Farm 1 (Ujjwal Organic Kshetra)
-- ═══════════════════════════════════════════════════════════════
INSERT INTO Users (first_name, last_name, email, password, role, farm_id, address) VALUES
('Rahul',  'Sharma', 'rahul@example.com', 'customer123', 'Customer', NULL, '12 MG Road, Bengaluru, Karnataka 560001'),
('Priya',  'Patel',  'priya@example.com', 'farmer123',   'Farmer',   1,    'Amritsar, Punjab 143001, India');
