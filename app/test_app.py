"""
Unit tests for the Banking REST API
Run with: pytest test_app.py -v
"""

import pytest
import json
from app import app, db, Account

API_KEY = "changeme-secret-key"
HEADERS = {"X-API-Key": API_KEY, "Content-Type": "application/json"}


@pytest.fixture
def client():
    app.config["TESTING"] = True
    app.config["SQLALCHEMY_DATABASE_URI"] = "sqlite:///:memory:"
    with app.app_context():
        db.create_all()
        yield app.test_client()
        db.drop_all()


def create_account(client, acc_num="ACC001", owner="John Doe", balance=1000.00):
    return client.post("/accounts", headers=HEADERS, json={
        "account_number": acc_num,
        "owner_name": owner,
        "initial_balance": balance,
    })


# ── Health ──────────────────────────────────────────────────────────────────────
def test_health_check(client):
    res = client.get("/health")
    assert res.status_code == 200
    assert res.get_json()["status"] == "healthy"


# ── Create Account ──────────────────────────────────────────────────────────────
def test_create_account(client):
    res = create_account(client)
    assert res.status_code == 201
    data = res.get_json()
    assert data["account"]["account_number"] == "ACC001"
    assert data["account"]["balance"] == 1000.00


def test_create_duplicate_account(client):
    create_account(client)
    res = create_account(client)
    assert res.status_code == 409


def test_create_account_missing_fields(client):
    res = client.post("/accounts", headers=HEADERS, json={"account_number": "ACC002"})
    assert res.status_code == 400


# ── Get Balance ─────────────────────────────────────────────────────────────────
def test_get_balance(client):
    create_account(client)
    res = client.get("/accounts/ACC001/balance", headers=HEADERS)
    assert res.status_code == 200
    assert res.get_json()["balance"] == 1000.00


def test_get_balance_not_found(client):
    res = client.get("/accounts/NOTEXIST/balance", headers=HEADERS)
    assert res.status_code == 404


# ── Deposit ─────────────────────────────────────────────────────────────────────
def test_deposit(client):
    create_account(client)
    res = client.post("/accounts/ACC001/deposit", headers=HEADERS, json={"amount": 500})
    assert res.status_code == 200
    assert res.get_json()["new_balance"] == 1500.00


def test_deposit_negative_amount(client):
    create_account(client)
    res = client.post("/accounts/ACC001/deposit", headers=HEADERS, json={"amount": -100})
    assert res.status_code == 400


# ── Withdraw ────────────────────────────────────────────────────────────────────
def test_withdraw(client):
    create_account(client)
    res = client.post("/accounts/ACC001/withdraw", headers=HEADERS, json={"amount": 200})
    assert res.status_code == 200
    assert res.get_json()["new_balance"] == 800.00


def test_withdraw_insufficient_funds(client):
    create_account(client, balance=100.00)
    res = client.post("/accounts/ACC001/withdraw", headers=HEADERS, json={"amount": 500})
    assert res.status_code == 400
    assert "Insufficient" in res.get_json()["message"]


# ── Delete Account ──────────────────────────────────────────────────────────────
def test_delete_account(client):
    create_account(client, balance=0.00)
    res = client.delete("/accounts/ACC001", headers=HEADERS)
    assert res.status_code == 200


def test_delete_account_with_balance(client):
    create_account(client, balance=500.00)
    res = client.delete("/accounts/ACC001", headers=HEADERS)
    assert res.status_code == 400


# ── Auth ────────────────────────────────────────────────────────────────────────
def test_missing_api_key(client):
    res = client.get("/accounts/ACC001/balance")
    assert res.status_code == 401


def test_invalid_api_key(client):
    res = client.get("/accounts/ACC001/balance", headers={"X-API-Key": "wrongkey"})
    assert res.status_code == 401


# ── Transactions ────────────────────────────────────────────────────────────────
def test_transaction_history(client):
    create_account(client)
    client.post("/accounts/ACC001/deposit",  headers=HEADERS, json={"amount": 300})
    client.post("/accounts/ACC001/withdraw", headers=HEADERS, json={"amount": 100})
    res = client.get("/accounts/ACC001/transactions", headers=HEADERS)
    assert res.status_code == 200
    assert len(res.get_json()["transactions"]) == 2
