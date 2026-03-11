"""
Banking Application REST API
Supports CRUD operations on bank accounts: balance, deposit, withdraw
"""

import os
import logging
from datetime import datetime
from flask import Flask, jsonify, request, abort
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy.exc import SQLAlchemyError
from functools import wraps

# ── Logging setup ──────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
logger = logging.getLogger(__name__)

# ── App & DB setup ─────────────────────────────────────────────────────────────
app = Flask(__name__)

DB_USER     = os.getenv("DB_USER",     "bankuser")
DB_PASSWORD = os.getenv("DB_PASSWORD", "bankpassword")
DB_HOST     = os.getenv("DB_HOST",     "localhost")
DB_PORT     = os.getenv("DB_PORT",     "5432")
DB_NAME     = os.getenv("DB_NAME",     "bankdb")
API_KEY     = os.getenv("API_KEY",     "changeme-secret-key")

# Allow DATABASE_URL override (used in tests for SQLite in-memory)
_default_db_url = f"postgresql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
app.config["SQLALCHEMY_DATABASE_URI"] = os.getenv("DATABASE_URL", _default_db_url)
app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False

db = SQLAlchemy(app)

# ── Models ─────────────────────────────────────────────────────────────────────
class Account(db.Model):
    __tablename__ = "accounts"

    id             = db.Column(db.Integer, primary_key=True)
    account_number = db.Column(db.String(20), unique=True, nullable=False)
    owner_name     = db.Column(db.String(100), nullable=False)
    balance        = db.Column(db.Numeric(15, 2), nullable=False, default=0.00)
    created_at     = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at     = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    def to_dict(self):
        return {
            "id":             self.id,
            "account_number": self.account_number,
            "owner_name":     self.owner_name,
            "balance":        float(self.balance),
            "created_at":     self.created_at.isoformat(),
            "updated_at":     self.updated_at.isoformat(),
        }


class Transaction(db.Model):
    __tablename__ = "transactions"

    id               = db.Column(db.Integer, primary_key=True)
    account_id       = db.Column(db.Integer, db.ForeignKey("accounts.id"), nullable=False)
    transaction_type = db.Column(db.String(10), nullable=False)   # deposit / withdraw
    amount           = db.Column(db.Numeric(15, 2), nullable=False)
    balance_after    = db.Column(db.Numeric(15, 2), nullable=False)
    timestamp        = db.Column(db.DateTime, default=datetime.utcnow)

    def to_dict(self):
        return {
            "id":               self.id,
            "account_id":       self.account_id,
            "transaction_type": self.transaction_type,
            "amount":           float(self.amount),
            "balance_after":    float(self.balance_after),
            "timestamp":        self.timestamp.isoformat(),
        }

# ── Security: API-key auth decorator ──────────────────────────────────────────
def require_api_key(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        key = request.headers.get("X-API-Key")
        if key != API_KEY:
            logger.warning("Unauthorized access attempt from %s", request.remote_addr)
            abort(401, description="Invalid or missing API key")
        return f(*args, **kwargs)
    return decorated

# ── Health check ───────────────────────────────────────────────────────────────
@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "healthy", "timestamp": datetime.utcnow().isoformat()}), 200

# ── Account endpoints ──────────────────────────────────────────────────────────

@app.route("/accounts", methods=["POST"])
@require_api_key
def create_account():
    """CREATE — open a new bank account."""
    data = request.get_json()
    if not data or not data.get("account_number") or not data.get("owner_name"):
        abort(400, description="account_number and owner_name are required")

    if Account.query.filter_by(account_number=data["account_number"]).first():
        abort(409, description="Account number already exists")

    account = Account(
        account_number=data["account_number"],
        owner_name=data["owner_name"],
        balance=data.get("initial_balance", 0.00),
    )
    db.session.add(account)
    db.session.commit()
    logger.info("Account created: %s", account.account_number)
    return jsonify({"message": "Account created", "account": account.to_dict()}), 201


@app.route("/accounts/<account_number>/balance", methods=["GET"])
@require_api_key
def get_balance(account_number):
    """READ — get current balance."""
    account = Account.query.filter_by(account_number=account_number).first_or_404(
        description=f"Account {account_number} not found"
    )
    logger.info("Balance checked for account: %s", account_number)
    return jsonify({
        "account_number": account.account_number,
        "owner_name":     account.owner_name,
        "balance":        float(account.balance),
    }), 200


@app.route("/accounts/<account_number>/deposit", methods=["POST"])
@require_api_key
def deposit(account_number):
    """UPDATE — deposit money into account."""
    account = Account.query.filter_by(account_number=account_number).first_or_404(
        description=f"Account {account_number} not found"
    )
    data = request.get_json()
    amount = data.get("amount") if data else None

    if not amount or float(amount) <= 0:
        abort(400, description="A positive amount is required")

    account.balance    += float(amount)
    account.updated_at  = datetime.utcnow()

    txn = Transaction(
        account_id=account.id,
        transaction_type="deposit",
        amount=amount,
        balance_after=account.balance,
    )
    db.session.add(txn)
    db.session.commit()
    logger.info("Deposit of %.2f to account %s", float(amount), account_number)
    return jsonify({
        "message":        "Deposit successful",
        "account_number": account.account_number,
        "deposited":      float(amount),
        "new_balance":    float(account.balance),
        "transaction":    txn.to_dict(),
    }), 200


@app.route("/accounts/<account_number>/withdraw", methods=["POST"])
@require_api_key
def withdraw(account_number):
    """UPDATE — withdraw money from account."""
    account = Account.query.filter_by(account_number=account_number).first_or_404(
        description=f"Account {account_number} not found"
    )
    data = request.get_json()
    amount = data.get("amount") if data else None

    if not amount or float(amount) <= 0:
        abort(400, description="A positive amount is required")
    if float(account.balance) < float(amount):
        abort(400, description="Insufficient funds")

    account.balance    -= float(amount)
    account.updated_at  = datetime.utcnow()

    txn = Transaction(
        account_id=account.id,
        transaction_type="withdraw",
        amount=amount,
        balance_after=account.balance,
    )
    db.session.add(txn)
    db.session.commit()
    logger.info("Withdrawal of %.2f from account %s", float(amount), account_number)
    return jsonify({
        "message":        "Withdrawal successful",
        "account_number": account.account_number,
        "withdrawn":      float(amount),
        "new_balance":    float(account.balance),
        "transaction":    txn.to_dict(),
    }), 200


@app.route("/accounts/<account_number>", methods=["DELETE"])
@require_api_key
def delete_account(account_number):
    """DELETE — close a bank account."""
    account = Account.query.filter_by(account_number=account_number).first_or_404(
        description=f"Account {account_number} not found"
    )
    if float(account.balance) > 0:
        abort(400, description="Cannot close account with non-zero balance")

    db.session.delete(account)
    db.session.commit()
    logger.info("Account deleted: %s", account_number)
    return jsonify({"message": f"Account {account_number} closed successfully"}), 200


@app.route("/accounts/<account_number>/transactions", methods=["GET"])
@require_api_key
def get_transactions(account_number):
    """READ — get transaction history."""
    account = Account.query.filter_by(account_number=account_number).first_or_404(
        description=f"Account {account_number} not found"
    )
    txns = Transaction.query.filter_by(account_id=account.id)\
                            .order_by(Transaction.timestamp.desc()).all()
    return jsonify({
        "account_number": account_number,
        "transactions":   [t.to_dict() for t in txns],
    }), 200


# ── Error handlers ─────────────────────────────────────────────────────────────
@app.errorhandler(400)
def bad_request(e):
    return jsonify({"error": "Bad Request", "message": str(e.description)}), 400

@app.errorhandler(401)
def unauthorized(e):
    return jsonify({"error": "Unauthorized", "message": str(e.description)}), 401

@app.errorhandler(404)
def not_found(e):
    return jsonify({"error": "Not Found", "message": str(e.description)}), 404

@app.errorhandler(409)
def conflict(e):
    return jsonify({"error": "Conflict", "message": str(e.description)}), 409

@app.errorhandler(500)
def internal_error(e):
    logger.error("Internal server error: %s", str(e))
    return jsonify({"error": "Internal Server Error"}), 500


# ── DB init & run ──────────────────────────────────────────────────────────────
if __name__ == "__main__":
    with app.app_context():
        db.create_all()
        logger.info("Database tables created")
    app.run(host="0.0.0.0", port=8090, debug=False)
