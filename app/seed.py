cat > seed.py << 'EOF'
"""테이블 생성 + 샘플 데이터 시딩 (member DB, payment DB, DynamoDB cart)"""
import os, json, boto3, pymysql

REGION = os.getenv("AWS_REGION", "ap-northeast-2")
sm = boto3.client("secretsmanager", region_name=REGION)

def conn_from_secret(name):
    s = json.loads(sm.get_secret_value(SecretId=name)["SecretString"])
    return pymysql.connect(host=s["host"], user=s["username"],
                           password=s["password"], database=s.get("dbname", "mysql"),
                           autocommit=True)

# --- member DB ---
c = conn_from_secret(os.environ["MEMBER_DB_SECRET"])
with c.cursor() as cur:
    cur.execute("""CREATE TABLE IF NOT EXISTS members (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(50), email VARCHAR(100))""")
    cur.execute("SELECT COUNT(*) FROM members")
    if cur.fetchone()[0] == 0:
        cur.executemany("INSERT INTO members (name, email) VALUES (%s, %s)", [
            ("김철수", "chulsoo@example.com"),
            ("이영희", "younghee@example.com"),
            ("박민수", "minsoo@example.com")])
c.close()
print("[OK] member DB: members 테이블 + 3건")

# --- payment DB ---
c = conn_from_secret(os.environ["PAYMENT_DB_SECRET"])
with c.cursor() as cur:
    cur.execute("""CREATE TABLE IF NOT EXISTS payments (
        id INT AUTO_INCREMENT PRIMARY KEY,
        member_id INT, amount DECIMAL(10,2), status VARCHAR(20))""")
    cur.execute("SELECT COUNT(*) FROM payments")
    if cur.fetchone()[0] == 0:
        cur.executemany("INSERT INTO payments (member_id, amount, status) VALUES (%s, %s, %s)", [
            (1, 35000, "COMPLETED"), (2, 128000, "COMPLETED"), (3, 9900, "PENDING")])
c.close()
print("[OK] payment DB: payments 테이블 + 3건")

# --- DynamoDB cart ---
table = boto3.resource("dynamodb", region_name=REGION).Table(os.environ["CART_TABLE"])
table.put_item(Item={"member_id": "1", "items": [
    {"product": "무선 키보드", "qty": 1}, {"product": "모니터암", "qty": 2}]})
print("[OK] DynamoDB: member_id=1 장바구니 1건")
EOF