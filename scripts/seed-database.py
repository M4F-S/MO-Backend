#!/usr/bin/env python3
# =============================================================================
# seed-database.py — Generates realistic seed data for development & testing
#
# Usage: python seed-database.py --schema users,orders,products --count 1000 --format sql
#
# Supported schemas: users, products, orders, posts, comments, tags
# Output formats: sql (INSERT statements), json (JSON array per table)
# =============================================================================

import argparse
import json
import random
import sys
from datetime import datetime, timedelta
from typing import List, Dict, Any, Optional

# ── Try importing faker; provide fallback if not installed ─────────────────
try:
    from faker import Faker
    FAKER_AVAILABLE = True
except ImportError:
    FAKER_AVAILABLE = False
    print("Warning: 'faker' not installed. Install with: pip install faker", file=sys.stderr)


# ── Configuration ───────────────────────────────────────────────────────────
DEFAULT_COUNT = 100
SCHEMAS = {"users", "products", "orders", "posts", "comments", "tags"}
OUTPUT_FORMATS = {"sql", "json"}

ROLES = ["admin", "user", "guest", "moderator"]
ORDER_STATUSES = ["pending", "paid", "shipped", "delivered", "cancelled"]
PRODUCT_CATEGORIES = ["Electronics", "Books", "Clothing", "Food", "Sports", "Home", "Toys", "Software"]
POST_STATUSES = ["draft", "published", "archived"]
TAG_NAMES = ["python", "javascript", "golang", "rust", "docker", "kubernetes",
             "react", "vue", "angular", "postgres", "redis", "aws", "gcp", "azure"]


# ── Faker wrapper ───────────────────────────────────────────────────────────
class FakeDataGenerator:
    """Generates realistic fake data using Faker."""

    def __init__(self, locale: str = "en_US"):
        if FAKER_AVAILABLE:
            self.fake = Faker(locale)
            self.fake.seed_instance(42)  # reproducible
        else:
            self.fake = None

    def user(self, index: int) -> Dict[str, Any]:
        if self.fake:
            return {
                "id": index + 1,
                "email": self.fake.unique.email(),
                "username": self.fake.user_name() + str(index),
                "first_name": self.fake.first_name(),
                "last_name": self.fake.last_name(),
                "avatar": f"https://i.pravatar.cc/150?u={index}",
                "role": random.choice(ROLES),
                "is_active": random.random() > 0.1,
                "created_at": self.fake.date_time_between(start_date="-2y", end_date="now").isoformat(),
            }
        # Fallback without faker
        return {
            "id": index + 1,
            "email": f"user{index}@example.com",
            "username": f"user{index}",
            "first_name": f"First{index}",
            "last_name": f"Last{index}",
            "avatar": f"https://i.pravatar.cc/150?u={index}",
            "role": random.choice(ROLES),
            "is_active": True,
            "created_at": datetime.now().isoformat(),
        }

    def product(self, index: int) -> Dict[str, Any]:
        if self.fake:
            return {
                "id": index + 1,
                "name": self.fake.catch_phrase(),
                "description": self.fake.text(max_nb_chars=200),
                "category": random.choice(PRODUCT_CATEGORIES),
                "price": round(random.uniform(5.0, 500.0), 2),
                "stock": random.randint(0, 1000),
                "is_active": random.random() > 0.15,
                "created_at": self.fake.date_time_between(start_date="-1y", end_date="now").isoformat(),
            }
        return {
            "id": index + 1,
            "name": f"Product {index}",
            "description": f"Description for product {index}",
            "category": random.choice(PRODUCT_CATEGORIES),
            "price": round(random.uniform(5.0, 500.0), 2),
            "stock": random.randint(0, 1000),
            "is_active": True,
            "created_at": datetime.now().isoformat(),
        }

    def order(self, index: int, user_ids: List[int]) -> Dict[str, Any]:
        if self.fake:
            created = self.fake.date_time_between(start_date="-6m", end_date="now")
        else:
            created = datetime.now() - timedelta(days=random.randint(1, 180))

        return {
            "id": index + 1,
            "user_id": random.choice(user_ids) if user_ids else random.randint(1, 100),
            "status": random.choice(ORDER_STATUSES),
            "total_amount": round(random.uniform(10.0, 2000.0), 2),
            "created_at": created.isoformat(),
            "updated_at": (created + timedelta(days=random.randint(0, 5))).isoformat(),
        }

    def post(self, index: int, user_ids: List[int]) -> Dict[str, Any]:
        if self.fake:
            return {
                "id": index + 1,
                "user_id": random.choice(user_ids) if user_ids else random.randint(1, 100),
                "title": self.fake.sentence(nb_words=6),
                "content": self.fake.paragraph(nb_sentences=5),
                "status": random.choice(POST_STATUSES),
                "view_count": random.randint(0, 10000),
                "created_at": self.fake.date_time_between(start_date="-1y", end_date="now").isoformat(),
            }
        return {
            "id": index + 1,
            "user_id": random.choice(user_ids) if user_ids else random.randint(1, 100),
            "title": f"Post Title {index}",
            "content": f"Content for post {index}",
            "status": random.choice(POST_STATUSES),
            "view_count": random.randint(0, 1000),
            "created_at": datetime.now().isoformat(),
        }

    def comment(self, index: int, user_ids: List[int], post_ids: List[int]) -> Dict[str, Any]:
        if self.fake:
            return {
                "id": index + 1,
                "post_id": random.choice(post_ids) if post_ids else random.randint(1, 100),
                "user_id": random.choice(user_ids) if user_ids else random.randint(1, 100),
                "content": self.fake.paragraph(nb_sentences=2),
                "created_at": self.fake.date_time_between(start_date="-6m", end_date="now").isoformat(),
            }
        return {
            "id": index + 1,
            "post_id": random.choice(post_ids) if post_ids else random.randint(1, 100),
            "user_id": random.choice(user_ids) if user_ids else random.randint(1, 100),
            "content": f"Comment {index}",
            "created_at": datetime.now().isoformat(),
        }

    def tag(self, index: int) -> Dict[str, Any]:
        name = TAG_NAMES[index % len(TAG_NAMES)]
        return {
            "id": index + 1,
            "name": f"{name}-{index}" if index >= len(TAG_NAMES) else name,
            "slug": f"{name}-{index}" if index >= len(TAG_NAMES) else name,
        }


# ── SQL Formatters ──────────────────────────────────────────────────────────
def to_sql_insert(table: str, records: List[Dict[str, Any]]) -> str:
    """Convert a list of records to SQL INSERT statements."""
    if not records:
        return ""

    lines = []
    columns = list(records[0].keys())
    col_str = ", ".join(f'"{c}"' for c in columns)

    for record in records:
        values = []
        for col in columns:
            val = record[col]
            if val is None:
                values.append("NULL")
            elif isinstance(val, bool):
                values.append("TRUE" if val else "FALSE")
            elif isinstance(val, (int, float)):
                values.append(str(val))
            elif isinstance(val, str):
                # Escape single quotes for SQL
                escaped = val.replace("'", "''")
                values.append(f"'{escaped}'")
            else:
                values.append(f"'{str(val)}'")
        lines.append(f"INSERT INTO {table} ({col_str}) VALUES ({', '.join(values)});")

    return "\n".join(lines)


def to_sql_file(tables_data: Dict[str, List[Dict[str, Any]]]) -> str:
    """Generate a full SQL file with all inserts and foreign key constraints."""
    lines = [
        "-- Auto-generated seed data",
        f"-- Generated: {datetime.now().isoformat()}",
        "",
        "BEGIN;",
        "",
    ]
    for table, records in tables_data.items():
        if records:
            lines.append(f"-- {table} ({len(records)} records)")
            lines.append(to_sql_insert(table, records))
            lines.append("")
    lines.append("COMMIT;")
    return "\n".join(lines)


# ── JSON Formatters ───────────────────────────────────────────────────────────
def to_json_output(tables_data: Dict[str, List[Dict[str, Any]]]) -> str:
    """Generate a JSON output with all tables."""
    return json.dumps(tables_data, indent=2, ensure_ascii=False)


# ── Main Generator ────────────────────────────────────────────────────────────
def generate_data(schemas: List[str], count: int, fmt: str) -> str:
    """Generate seed data for the requested schemas and format."""
    fake = FakeDataGenerator()
    tables_data: Dict[str, List[Dict[str, Any]]] = {}

    # Track IDs for foreign key relationships
    user_ids: List[int] = []
    product_ids: List[int] = []
    post_ids: List[int] = []

    # Generate users first (needed for FKs)
    if "users" in schemas:
        tables_data["users"] = [fake.user(i) for i in range(count)]
        user_ids = [u["id"] for u in tables_data["users"]]
        info(f"Generated {count} users")

    # Generate products
    if "products" in schemas:
        tables_data["products"] = [fake.product(i) for i in range(count)]
        product_ids = [p["id"] for p in tables_data["products"]]
        info(f"Generated {count} products")

    # Generate orders (FK to users)
    if "orders" in schemas:
        tables_data["orders"] = [fake.order(i, user_ids) for i in range(count)]
        info(f"Generated {count} orders")

    # Generate posts (FK to users)
    if "posts" in schemas:
        tables_data["posts"] = [fake.post(i, user_ids) for i in range(count)]
        post_ids = [p["id"] for p in tables_data["posts"]]
        info(f"Generated {count} posts")

    # Generate comments (FK to users and posts)
    if "comments" in schemas:
        tables_data["comments"] = [fake.comment(i, user_ids, post_ids) for i in range(count)]
        info(f"Generated {count} comments")

    # Generate tags (no FKs)
    if "tags" in schemas:
        # Tags are usually fewer; cap at min(count, 50) or use count
        tag_count = min(count, 50)
        tables_data["tags"] = [fake.tag(i) for i in range(tag_count)]
        info(f"Generated {tag_count} tags")

    # Format output
    if fmt == "sql":
        return to_sql_file(tables_data)
    elif fmt == "json":
        return to_json_output(tables_data)
    else:
        raise ValueError(f"Unknown format: {fmt}")


# ── CLI ─────────────────────────────────────────────────────────────────────
def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate realistic seed data for development databases.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s --schema users,products --count 100 --format sql
  %(prog)s --schema users,orders,posts,comments --count 1000 --format json
  %(prog)s --schema all --count 500 --format sql > seed.sql

Supported schemas: users, products, orders, posts, comments, tags (or 'all')
        """
    )
    parser.add_argument(
        "--schema",
        type=str,
        required=True,
        help="Comma-separated list of schemas to generate (or 'all')"
    )
    parser.add_argument(
        "--count",
        type=int,
        default=DEFAULT_COUNT,
        help=f"Number of records per schema (default: {DEFAULT_COUNT})"
    )
    parser.add_argument(
        "--format",
        type=str,
        choices=OUTPUT_FORMATS,
        default="sql",
        help="Output format: sql or json (default: sql)"
    )
    parser.add_argument(
        "--output",
        type=str,
        default=None,
        help="Output file path (default: stdout)"
    )
    parser.add_argument(
        "--locale",
        type=str,
        default="en_US",
        help="Faker locale for realistic data (default: en_US)"
    )
    return parser.parse_args()


def info(msg: str) -> None:
    print(f"[INFO] {msg}", file=sys.stderr)


def main() -> int:
    args = parse_args()

    # Parse schema list
    if args.schema.lower() == "all":
        schemas = list(SCHEMAS)
    else:
        schemas = [s.strip().lower() for s in args.schema.split(",")]
        invalid = set(schemas) - SCHEMAS
        if invalid:
            print(f"Error: Invalid schemas: {', '.join(invalid)}", file=sys.stderr)
            print(f"Valid schemas: {', '.join(sorted(SCHEMAS))}", file=sys.stderr)
            return 1

    # Generate data
    info(f"Generating seed data: schemas={schemas}, count={args.count}, format={args.format}")
    output = generate_data(schemas, args.count, args.format)

    # Write output
    if args.output:
        with open(args.output, "w", encoding="utf-8") as f:
            f.write(output)
        info(f"Output written to: {args.output}")
    else:
        print(output)

    return 0


if __name__ == "__main__":
    sys.exit(main())
