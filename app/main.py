import os
import json
import boto3
import pymysql
from fastapi import FastAPI, HTTPException

app = FastAPI(title="ecommerce-db-separation API")

REGION = os.getenv("AWS_REGION", "ap-northeast-2")
MEMBER_SECRET = os.getenv("MEMBER_DB_SECRET")    # Secrets Manager 시크릿 이름
PAYMENT_SECRET = os.getenv("PAYMENT_DB_SECRET")
CART_TABLE = os.getenv("CART_TABLE", "cart")

secrets_client = boto3.client("secretsmanager", region_name=REGION)
dynamodb = boto3.resource("dynamodb", region_name=REGION)


def get_db_conn(secret_name: str):
    """Secrets Manager에서 접속정보 가져와서 MySQL 연결"""
    secret = json.loads(
        secrets_client.get_secret_value(SecretId=secret_name)["SecretString"]
    )
    return pymysql.connect(
        host=secret["host"],
        user=secret["username"],
        password=secret["password"],
        database=secret.get("dbname", "mysql"),
        connect_timeout=3,
        cursorclass=pymysql.cursors.DictCursor,
    )


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/members")
def get_members():
    try:
        conn = get_db_conn(MEMBER_SECRET)
        with conn.cursor() as cur:
            cur.execute("SELECT id, name, email FROM members LIMIT 10")
            rows = cur.fetchall()
        conn.close()
        return {"domain": "member", "data": rows}
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"member DB error: {e}")


@app.get("/payments")
def get_payments():
    try:
        conn = get_db_conn(PAYMENT_SECRET)
        with conn.cursor() as cur:
            cur.execute("SELECT id, member_id, amount, status FROM payments LIMIT 10")
            rows = cur.fetchall()
        conn.close()
        return {"domain": "payment", "data": rows}
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"payment DB error: {e}")


@app.get("/cart/{member_id}")
def get_cart(member_id: str):
    try:
        table = dynamodb.Table(CART_TABLE)
        res = table.get_item(Key={"member_id": member_id})
        return {"domain": "cart", "data": res.get("Item", {})}
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"cart DB error: {e}")
