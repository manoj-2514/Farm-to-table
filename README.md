# FarmFresh 🌾 — Farm-to-Table Web Portal & DBMS

A premium, full-stack web application that connects local farmers directly with consumers. FarmFresh empowers users to browse organic, locally sourced produce, supports food waste reduction through dynamic **"Rescued Food"** discounts, and provides farmers with detailed visual analytics.

This project features a fully normalized **MySQL Database (3NF)** with atomic transaction controls, automatic triggers, views, and stored procedures to ensure data integrity and performance.

---

## 🚀 Key Features

### 🛒 Customer Experience
- **Dedicated Shopping Portal (`shop.html`)**: Features instant client-side search, category filtering, and sorting (by Newest, Price, and Top Rated).
- **Persistent Cart Sidebar**: Built with a sliding cart drawer synced to `localStorage`, allowing quantity adjustments and subtotal recalculation before checking out.
- **Dynamic "Rescued Food" Badges**: Highlights produce nearing expiry with dynamic strikethrough pricing and automatically applies a **30% discount** (if $\le$ 3 days remaining) or **50% discount** (if $\le$ 0 days remaining).
- **Secure checkout**: Verifies authentication status, auto-fills customer address, and routes orders through transactional database protocols.
- **Customer Dashboard**: Displays past transaction history ("My Orders") with real-time shipping status tracking.
- **Support Center**: Offers a responsive contact portal with interactive FAQ accordions.

### 🧑‍🌾 Farmer Experience
- **Interactive Analytics Dashboard**: Visualizes data through real-time charts powered by Chart.js (Daily Revenue Line Chart & Orders Status Doughnut Chart).
- **Inventory Management**: Allows farmers to add new items, update stock counts, adjust visibility, and change harvest dates.
- **Order Fulfillment**: Review incoming order receipts and update shipping status ('Pending' $\rightarrow$ 'Shipped' $\rightarrow$ 'Completed').
- **Review Center**: Real-time log of customer reviews on the farmer's crops.

---

## 🗂️ Database Architecture & DBMS Concepts

### 1. 📐 3NF Normalized Schema
The database is structured to avoid anomalies and ensure data consistency:
- **1NF**: All table attributes are atomic. `Order_Items` is separated from `Orders` to remove repeating groups.
- **2NF**: Fully complies with no partial dependencies. Order specific attributes reside strictly in `Orders`, while transaction items reside in `Order_Items`.
- **3NF**: No transitive dependencies. Farm details exist exclusively in the `Farms` table, and are referenced via `farm_id` in `Products` and `Users`.

### 2. ⚡ Triggers (Automatic Data Syncing)
- **`trg_deduct_stock`**: Automatically updates inventory. Whenever a new row is inserted into `Order_Items`, this trigger fires and deducts the requested quantity from the `Products` table stock.
- **`trg_update_rating`**: Whenever a customer submits a new rating/review, this trigger automatically recalculates the average rating for the product and updates the `Products.rating` column instantly.

### 3. 👁️ Views (Virtual Tables for Analytics)
- **`vw_Farm_Analytics`**: Securely aggregates total orders, total lifetime revenue, and average product ratings per farm.
- **`vw_Customer_Orders`**: Joins orders, order items, and products to render a flat, human-readable receipt for the customer dashboard.
- **`vw_Farmer_Reviews`**: Aggregates product reviews, star scores, comments, and customer names for the farmer's review center.
- **`vw_Revenue_By_Day`**: Aggregates revenue data grouped by day and farm to generate Chart.js graphs.

### 4. 📦 Stored Procedures & Transaction Control
- **`sp_PlaceOrder`**: Processes checkouts. It takes user parameters, initiates a secure **Transaction (`START TRANSACTION`)**, inserts the order, iterates through cart items to add `Order_Items` records, and **Commits (`COMMIT`)** once successful. If any single query fails, it rolls back entirely (`ROLLBACK`) to prevent orphaned data.

---

## 🛠️ Tech Stack
- **Frontend**: HTML5, Vanilla JavaScript (ES6+), Tailwind CSS (for modern UI styling), Chart.js (for analytics).
- **Backend**: Python Flask, Flask-CORS.
- **Database**: MySQL.

---

## ⚙️ Installation & Setup

### 1. Database Setup
Make sure MySQL server is running. Create the database and import both templates:
```bash
# 1. Initialize schema
mysql -u your_username -p < database/create-db-template.sql

# 2. Seed Indian market items, farms, and demo users
mysql -u your_username -p < database/seed-images-and-products.sql
```

### 2. Flask Backend Setup
Configure your database credentials in `app.py` under `get_db()`, then run:
```bash
# Install dependencies
pip install Flask flask-cors mysql-connector-python

# Run Flask API server (starts on Port 5000)
python app.py
```

### 3. Frontend Web Server Setup
Open the project directory and serve the static files:
```bash
# Start a simple local server
python -m http.server 3000
```
Open your browser and navigate to `http://localhost:3000/index.html` to explore the portal!
