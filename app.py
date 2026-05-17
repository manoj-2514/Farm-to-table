from flask import Flask, jsonify, request
from flask_cors import CORS
import mysql.connector
import datetime
import json

app = Flask(__name__)
CORS(app)

# Database connection
def get_db():
    return mysql.connector.connect(
        host="localhost",
        user="root",
        password="12qwas34erdf..",
        database="farm_to_table"
    )

# ─── FARMS ───────────────────────────────
@app.route('/farms', methods=['GET'])
def get_farms():
    db = get_db()
    cursor = db.cursor(dictionary=True)
    try:
        cursor.execute("SELECT * FROM Farms")
        farms = cursor.fetchall()
        return jsonify(farms)
    finally:
        cursor.close()
        db.close()

# ─── PRODUCTS ────────────────────────────
@app.route('/products', methods=['GET'])
def get_products():
    category = request.args.get('category', '').strip()

    db = get_db()
    cursor = db.cursor(dictionary=True)

    if category and category.lower() != 'all':
        cursor.execute("""
            SELECT p.*, c.name AS category_name
            FROM Products p
            JOIN Categories c ON p.category_id = c.category_id
            WHERE c.name = %s AND p.is_active = 1
        """, (category,))
    else:
        cursor.execute("""
            SELECT p.*, c.name AS category_name
            FROM Products p
            LEFT JOIN Categories c ON p.category_id = c.category_id
            WHERE p.is_active = 1
        """)

    products = cursor.fetchall()
    cursor.close()
    db.close()

    today = datetime.date.today()

    for p in products:
        # Defaults
        p['original_price'] = p['price']
        p['is_discounted']  = False
        p['days_remaining'] = None

        if p.get('harvest_date') and p.get('shelf_life_days'):
            h_date = p['harvest_date']
            days_since = (today - h_date).days
            days_remaining = p['shelf_life_days'] - days_since
            p['days_remaining'] = days_remaining
            
            # Serialize date for JSON
            p['harvest_date'] = h_date.strftime('%Y-%m-%d')

            # Apply 30% Food Waste Discount if expiring in 3 days or less
            if 0 < days_remaining <= 3:
                p['is_discounted'] = True
                discounted = float(p['price']) * 0.70
                p['price'] = round(discounted, 2)
            elif days_remaining <= 0:
                # Optionally mark as expired or 50% discount. Let's do 50% for 0 or negative!
                p['is_discounted'] = True
                discounted = float(p['price']) * 0.50
                p['price'] = round(discounted, 2)

    return jsonify(products)

# ─── AUTH: REGISTER ─────────────────────────
@app.route('/register', methods=['POST'])
def register():
    data = request.json
    required = ['first_name', 'last_name', 'email', 'password']
    if not all(data.get(f) for f in required):
        return jsonify({'error': 'First name, last name, email, and password are required'}), 400

    db = get_db()
    cursor = db.cursor(dictionary=True)
    try:
        # Check if email already exists
        cursor.execute('SELECT user_id FROM Users WHERE email = %s', (data['email'],))
        if cursor.fetchone():
            return jsonify({'error': 'Email already registered. Please log in.'}), 409

        # Extract role or default to Customer
        role = data.get('role', 'Customer')
        if role not in ['Customer', 'Farmer']:
            role = 'Customer'
            
        farm_id = None
        if role == 'Farmer':
            # Auto-create a farm profile for the new farmer
            cursor.execute(
                "INSERT INTO Farms (name, description, rating) VALUES (%s, %s, 0.0)", 
                (f"{data['first_name']}'s Farm", "A newly joined local farm.")
            )
            farm_id = cursor.lastrowid

        # Plain text password for student project as requested
        password = data['password']

        cursor.execute(
            'INSERT INTO Users (first_name, last_name, email, password, role, farm_id) VALUES (%s, %s, %s, %s, %s, %s)',
            (data['first_name'], data['last_name'], data['email'], password, role, farm_id)
        )
        db.commit()
        user_id = cursor.lastrowid
        return jsonify({
            'message': 'Registration successful!',
            'user_id': user_id,
            'farm_id':    farm_id,
            'first_name': data['first_name'],
            'last_name':  data['last_name'],
            'email':      data['email'],
            'role':       role
        }), 201
    except Exception as e:
        db.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        cursor.close()
        db.close()

# ─── AUTH: LOGIN ───────────────────────────
@app.route('/login', methods=['POST'])
def login():
    data = request.json
    email = data.get('email', '').strip()
    password = data.get('password', '')
    
    if not email or not password:
        return jsonify({'error': 'Email and password are required'}), 400

    db = get_db()
    cursor = db.cursor(dictionary=True)
    try:
        cursor.execute(
            'SELECT user_id, first_name, last_name, email, password, role, farm_id FROM Users WHERE email = %s',
            (email,)
        )
        user = cursor.fetchone()
        
        # Simple password check
        if not user or user['password'] != password:
            return jsonify({'error': 'Invalid email or password.'}), 401
            
        # Don't send the password back to the client
        del user['password']
        
        return jsonify({'message': 'Login successful!', **user}), 200
    finally:
        cursor.close()
        db.close()


# ─── ORDERS ────────────────────────────────────────
@app.route('/orders', methods=['POST'])
def place_order():
    data = request.json

    # Validate required fields
    if not data or 'items' not in data or not data['items']:
        return jsonify({"error": "Cart is empty or invalid request"}), 400

    customer_id = data.get('customer_id')
    if not customer_id:
        return jsonify({"error": "customer_id is required"}), 400
    total_amount = data.get('total_amount', 0)
    items        = data['items']

    db = get_db()
    cursor = db.cursor()
    try:
        # Pass items as JSON string to the stored procedure
        items_json = json.dumps(items)
        
        # Call the Stored Procedure (Handles transaction and inserts)
        cursor.execute(
            "CALL sp_PlaceOrder(%s, %s, %s, @p_order_id)",
            (customer_id, total_amount, items_json)
        )
        
        # Retrieve the OUT variable (the new order_id)
        cursor.execute("SELECT @p_order_id")
        result = cursor.fetchone()
        order_id = result[0] if result else None

        # Note: sp_PlaceOrder already commits internally; no extra commit needed
        return jsonify({"message": "Order placed!", "order_id": order_id}), 201

    except mysql.connector.Error as err:
        db.rollback()
        error_msg = str(err)
        # Surface user-friendly error if stock falls below 0 (CHECK constraint fails)
        if "check constraint" in error_msg.lower() or "stock_quantity" in error_msg.lower():
            error_msg = "Transaction failed: One or more items are out of stock or requested quantity exceeds available stock."
        return jsonify({"error": error_msg}), 400
    except Exception as e:
        db.rollback()
        return jsonify({"error": str(e)}), 500

    finally:
        cursor.close()
        db.close()

@app.route('/orders', methods=['GET'])
def get_orders():
    customer_id = request.args.get('customer_id')
    db = get_db()
    cursor = db.cursor(dictionary=True)
    try:
        if customer_id:
            cursor.execute("""
                SELECT * FROM vw_Customer_Orders
                WHERE customer_id = %s
                ORDER BY order_id DESC, product_name ASC
            """, (customer_id,))
        else:
            cursor.execute("""
                SELECT * FROM vw_Customer_Orders
                ORDER BY order_id DESC, product_name ASC
            """)
        rows = cursor.fetchall()

        # Serialize datetime so JSON doesn't choke
        for r in rows:
            if r.get('created_at'):
                r['created_at'] = r['created_at'].strftime('%Y-%m-%d %H:%M')

        return jsonify(rows)
    finally:
        cursor.close()
        db.close()

# ─── FARMER DASHBOARD ──────────────────────────
@app.route('/farmer/dashboard/<int:farm_id>', methods=['GET'])
def get_farmer_dashboard(farm_id):
    db = get_db()
    cursor = db.cursor(dictionary=True)
    try:
        # 1. Analytics (Total revenue, order count)
        cursor.execute("SELECT * FROM vw_Farm_Analytics WHERE farm_id = %s", (farm_id,))
        analytics = cursor.fetchone()
        if not analytics:
            analytics = {"total_orders": 0, "total_revenue": 0.0, "average_product_rating": 0.0}

        # 2. Inventory (Current stock levels)
        cursor.execute("SELECT * FROM Products WHERE farm_id = %s ORDER BY stock_quantity ASC", (farm_id,))
        inventory = cursor.fetchall()
        for p in inventory:
            if p.get('harvest_date'):
                p['harvest_date'] = p['harvest_date'].strftime('%Y-%m-%d')

        # 3. Recent Orders for this farm's products
        cursor.execute("""
            SELECT o.order_id, o.order_date, o.status, oi.quantity, oi.price,
                   p.name as product_name, u.first_name, u.last_name, u.address
            FROM Orders o
            JOIN Order_Items oi ON o.order_id = oi.order_id
            JOIN Products p ON oi.product_id = p.product_id
            JOIN Users u ON o.customer_id = u.user_id
            WHERE p.farm_id = %s
            ORDER BY o.order_date DESC
        """, (farm_id,))
        orders = cursor.fetchall()
        for o in orders:
            if o.get('order_date'):
                o['order_date'] = o['order_date'].strftime('%Y-%m-%d %H:%M')

        # 4. Orders by status breakdown (for donut chart)
        cursor.execute("""
            SELECT o.status, COUNT(DISTINCT o.order_id) as count
            FROM Orders o
            JOIN Order_Items oi ON o.order_id = oi.order_id
            JOIN Products p ON oi.product_id = p.product_id
            WHERE p.farm_id = %s
            GROUP BY o.status
        """, (farm_id,))
        status_rows = cursor.fetchall()
        orders_by_status = {"Pending": 0, "Shipped": 0, "Completed": 0, "Cancelled": 0}
        for row in status_rows:
            orders_by_status[row['status']] = row['count']

        # 5. Top-selling product this month
        cursor.execute("""
            SELECT p.name, SUM(oi.quantity) as units_sold
            FROM Order_Items oi
            JOIN Products p ON oi.product_id = p.product_id
            JOIN Orders o ON oi.order_id = o.order_id
            WHERE p.farm_id = %s
              AND MONTH(o.order_date) = MONTH(CURRENT_DATE)
              AND YEAR(o.order_date)  = YEAR(CURRENT_DATE)
              AND o.status != 'Cancelled'
            GROUP BY p.product_id, p.name
            ORDER BY units_sold DESC
            LIMIT 1
        """, (farm_id,))
        top_row = cursor.fetchone()
        top_product = top_row if top_row else {"name": "N/A", "units_sold": 0}

        # 6. Revenue by day — last 7 days (for line chart)
        cursor.execute("""
            SELECT order_day AS date,
                   COALESCE(daily_revenue, 0) AS revenue
            FROM vw_Revenue_By_Day
            WHERE farm_id = %s
              AND order_day >= CURDATE() - INTERVAL 6 DAY
            ORDER BY order_day ASC
        """, (farm_id,))
        rev_rows = cursor.fetchall()
        revenue_by_day = []
        for r in rev_rows:
            revenue_by_day.append({
                "date": r['date'].strftime('%Y-%m-%d'),
                "revenue": float(r['revenue'])
            })

        # 7. Pending orders count
        pending_count = orders_by_status.get("Pending", 0)
        analytics['pending_orders'] = pending_count

        return jsonify({
            "analytics":        analytics,
            "inventory":        inventory,
            "orders":           orders,
            "orders_by_status": orders_by_status,
            "top_product":      top_product,
            "revenue_by_day":   revenue_by_day
        })
    finally:
        cursor.close()
        db.close()

@app.route('/farmer/inventory/<int:product_id>', methods=['PUT'])
def update_inventory(product_id):
    data = request.json or {}
    new_stock    = data.get('stock_quantity')
    is_active    = data.get('is_active')
    harvest_date = data.get('harvest_date')

    if new_stock is None and is_active is None and harvest_date is None:
        return jsonify({"error": "At least one field (stock_quantity, is_active, harvest_date) is required"}), 400

    db = get_db()
    cursor = db.cursor()
    try:
        fields, values = [], []
        if new_stock is not None:
            fields.append("stock_quantity = %s")
            values.append(new_stock)
        if is_active is not None:
            fields.append("is_active = %s")
            values.append(int(is_active))
        if harvest_date is not None:
            fields.append("harvest_date = %s")
            values.append(harvest_date)
        values.append(product_id)
        cursor.execute(f"UPDATE Products SET {', '.join(fields)} WHERE product_id = %s", tuple(values))
        db.commit()
        return jsonify({"message": "Product updated successfully!"})
    except Exception as e:
        db.rollback()
        return jsonify({"error": str(e)}), 500
    finally:
        cursor.close()
        db.close()


# ─── FARMER: ADD PRODUCT ───────────────────────
@app.route('/farmer/products', methods=['POST'])
def add_farmer_product():
    data = request.json or {}
    required = ['name', 'category_id', 'farm_id', 'price', 'stock_quantity']
    if not all(data.get(f) is not None for f in required):
        return jsonify({"error": f"Required fields: {', '.join(required)}"}), 400

    db = get_db()
    cursor = db.cursor()
    try:
        cursor.execute("""
            INSERT INTO Products
                (farm_id, category_id, name, price, stock_quantity, harvest_date, image_url, description, is_active)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, 1)
        """, (
            data['farm_id'],
            data['category_id'],
            data['name'],
            data['price'],
            data['stock_quantity'],
            data.get('harvest_date'),
            data.get('image_url', ''),
            data.get('description', '')
        ))
        db.commit()
        return jsonify({"message": "Product added!", "product_id": cursor.lastrowid}), 201
    except Exception as e:
        db.rollback()
        return jsonify({"error": str(e)}), 500
    finally:
        cursor.close()
        db.close()


# ─── FARMER: REVIEWS ───────────────────────────
@app.route('/farmer/reviews/<int:farm_id>', methods=['GET'])
def get_farmer_reviews(farm_id):
    db = get_db()
    cursor = db.cursor(dictionary=True)
    try:
        cursor.execute("""
            SELECT * FROM vw_Farmer_Reviews
            WHERE farm_id = %s
            ORDER BY created_at DESC
        """, (farm_id,))
        reviews = cursor.fetchall()
        for r in reviews:
            if r.get('created_at'):
                r['created_at'] = r['created_at'].strftime('%Y-%m-%d %H:%M')
        return jsonify(reviews)
    finally:
        cursor.close()
        db.close()

# ─── REVIEWS ─────────────────────────────────
@app.route('/reviews', methods=['POST'])
def add_review():
    data = request.json
    customer_id = data.get('customer_id')
    product_id  = data.get('product_id')
    rating      = data.get('rating')
    comment     = data.get('comment', '')
    
    if not all([customer_id, product_id, rating]):
        return jsonify({"error": "Missing required fields"}), 400
        
    db = get_db()
    cursor = db.cursor()
    try:
        # Business Logic: Ensure they actually bought the product
        cursor.execute("""
            SELECT oi.item_id FROM Order_Items oi 
            JOIN Orders o ON oi.order_id = o.order_id 
            WHERE o.customer_id = %s AND oi.product_id = %s LIMIT 1
        """, (customer_id, product_id))
        
        if not cursor.fetchone():
            return jsonify({"error": "You can only review products you have purchased."}), 403

        # Insert review. The trg_update_rating trigger will auto-fire and update Products.rating!
        cursor.execute(
            "INSERT INTO Reviews (product_id, customer_id, rating, comment) VALUES (%s, %s, %s, %s)",
            (product_id, customer_id, rating, comment)
        )
        db.commit()
        return jsonify({"message": "Review submitted successfully! Thank you."})
    except mysql.connector.Error as err:
        db.rollback()
        if "check constraint" in str(err).lower():
            return jsonify({"error": "Rating must be between 1 and 5."}), 400
        return jsonify({"error": str(err)}), 500
    finally:
        cursor.close()
        db.close()

# ─── PHASE 4: ORDER FULFILLMENT ───────────────────
@app.route('/orders/<int:order_id>/status', methods=['PUT'])
def update_order_status(order_id):
    data = request.json
    new_status = data.get('status')
    if new_status not in ['Pending', 'Shipped', 'Completed', 'Cancelled']:
        return jsonify({"error": "Invalid status"}), 400
        
    db = get_db()
    cursor = db.cursor()
    try:
        cursor.execute("UPDATE Orders SET status = %s WHERE order_id = %s", (new_status, order_id))
        db.commit()
        return jsonify({"message": f"Order status updated to {new_status}"})
    except Exception as e:
        db.rollback()
        return jsonify({"error": str(e)}), 500
    finally:
        cursor.close()
        db.close()

# ─── PHASE 4: DIRECT MESSAGING ────────────────────
@app.route('/messages', methods=['POST'])
def send_message():
    data = request.json
    sender_id = data.get('sender_id')
    content = data.get('content')
    receiver_id = data.get('receiver_id')
    farm_id = data.get('farm_id') # For Customer -> Farmer

    if not sender_id or not content:
        return jsonify({"error": "Missing sender_id or content"}), 400

    db = get_db()
    cursor = db.cursor(dictionary=True)
    try:
        if farm_id and not receiver_id:
            cursor.execute("SELECT user_id FROM Users WHERE farm_id = %s AND role = 'Farmer' LIMIT 1", (farm_id,))
            farmer = cursor.fetchone()
            if not farmer:
                return jsonify({"error": "Farmer not found for this farm"}), 404
            receiver_id = farmer['user_id']
            
        if not receiver_id:
            return jsonify({"error": "Missing receiver_id"}), 400

        cursor.execute(
            "INSERT INTO Messages (sender_id, receiver_id, content) VALUES (%s, %s, %s)",
            (sender_id, receiver_id, content)
        )
        db.commit()
        return jsonify({"message": "Message sent successfully!"})
    except Exception as e:
        db.rollback()
        return jsonify({"error": str(e)}), 500
    finally:
        cursor.close()
        db.close()

@app.route('/messages/<int:user_id>', methods=['GET'])
def get_messages(user_id):
    db = get_db()
    cursor = db.cursor(dictionary=True)
    try:
        cursor.execute("""
            SELECT m.message_id, m.sender_id, m.receiver_id, m.content, 
                   DATE_FORMAT(m.sent_at, '%%Y-%%m-%%d %%H:%%i') as sent_at,
                   s.first_name as sender_first, s.last_name as sender_last,
                   r.first_name as receiver_first, r.last_name as receiver_last
            FROM Messages m
            JOIN Users s ON m.sender_id = s.user_id
            JOIN Users r ON m.receiver_id = r.user_id
            WHERE m.sender_id = %s OR m.receiver_id = %s
            ORDER BY m.sent_at ASC
        """, (user_id, user_id))
        messages = cursor.fetchall()
        return jsonify(messages)
    finally:
        cursor.close()
        db.close()

# ─── SUPPORT ─────────────────────────────
@app.route('/support', methods=['POST'])
def support_message():
    data = request.json or {}
    required = ['first_name', 'last_name', 'email', 'subject', 'message']
    if not all(data.get(f) for f in required):
        return jsonify({"error": "All fields (first_name, last_name, email, subject, message) are required"}), 400
    db = get_db()
    cursor = db.cursor()
    try:
        cursor.execute(
            "INSERT INTO Support_Messages (first_name, last_name, email, subject, message) VALUES (%s, %s, %s, %s, %s)",
            (data['first_name'], data['last_name'], data['email'], data['subject'], data['message'])
        )
        db.commit()
        return jsonify({"message": "Support message received!"})
    except Exception as e:
        db.rollback()
        return jsonify({"error": str(e)}), 500
    finally:
        cursor.close()
        db.close()

# ─── CATEGORIES ──────────────────────────
@app.route('/categories', methods=['GET'])
def get_categories():
    db = get_db()
    cursor = db.cursor(dictionary=True)
    try:
        cursor.execute("SELECT * FROM Categories")
        cats = cursor.fetchall()
        return jsonify(cats)
    finally:
        cursor.close()
        db.close()

if __name__ == '__main__':
    app.run(debug=True, port=5000)