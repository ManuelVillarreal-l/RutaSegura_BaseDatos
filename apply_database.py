"""Apply the RutaSegura SQL scripts to a PostgreSQL database.

Usage:
    python apply_database.py "<DATABASE_URL>"            # create tables + demo data + views
    python apply_database.py "<DATABASE_URL>" --queries  # only run the example queries (read-only)

The URL can also come from the DATABASE_URL environment variable.
Messages are in Spanish because the user reads them.
"""

import argparse
import os
import re
import sys
from pathlib import Path

import psycopg

SQL_DIR = Path(__file__).resolve().parent / "sql"
SETUP_FILES = ["01_schema.sql", "02_seed.sql", "03_views.sql"]
QUERIES_FILE = "04_queries.sql"
TABLES = ["users", "routes", "stops", "students", "trips", "attendance"]


def normalize_url(url: str) -> str:
    # psycopg understands postgresql:// URLs; SQLAlchemy-style prefixes are converted.
    return re.sub(r"^postgres(ql)?(\+psycopg)?://", "postgresql://", url.strip())


def split_statements(sql: str) -> list[str]:
    # Remove comment lines, then split on semicolons at the end of a line.
    lines = [line for line in sql.splitlines() if not line.strip().startswith("--")]
    parts = re.split(r";\s*\n", "\n".join(lines) + "\n")
    return [part.strip() for part in parts if part.strip()]


def run_setup(conn: psycopg.Connection) -> None:
    for file_name in SETUP_FILES:
        print(f"→ Ejecutando {file_name} ...")
        conn.execute((SQL_DIR / file_name).read_text(encoding="utf-8"))
    print("\nResumen de registros:")
    for table in TABLES:
        count = conn.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
        print(f"  {table:<11} {count}")


def run_queries(conn: psycopg.Connection) -> None:
    statements = split_statements((SQL_DIR / QUERIES_FILE).read_text(encoding="utf-8"))
    for number, statement in enumerate(statements, start=1):
        print(f"\n=== Consulta {number} ===\n{statement}\n")
        cursor = conn.execute(statement)
        columns = [column.name for column in cursor.description]
        print(" | ".join(columns))
        for row in cursor.fetchall():
            print(" | ".join("" if value is None else str(value) for value in row))


def main() -> int:
    parser = argparse.ArgumentParser(description="Aplica los scripts SQL de RutaSegura.")
    parser.add_argument("url", nargs="?", default=os.getenv("DATABASE_URL"), help="URL de PostgreSQL")
    parser.add_argument("--queries", action="store_true", help="Solo ejecutar las consultas de ejemplo")
    parser.add_argument("--yes", action="store_true", help="No pedir confirmación")
    args = parser.parse_args()

    if not args.url:
        print("Falta la URL de la base de datos. Ejemplo:")
        print('  python apply_database.py "postgresql://usuario:clave@host/basededatos"')
        return 1

    with psycopg.connect(normalize_url(args.url), autocommit=True) as conn:
        server = conn.execute("SELECT current_database(), version()").fetchone()
        print(f"Conectado a la base de datos '{server[0]}'")
        print(f"{server[1].split(',')[0]}\n")

        if args.queries:
            run_queries(conn)
            return 0

        if not args.yes:
            print("ATENCIÓN: esto BORRA las tablas actuales y las crea de nuevo con datos de prueba.")
            answer = input("Escriba SI para continuar: ").strip().upper()
            if answer != "SI":
                print("Cancelado. No se hizo ningún cambio.")
                return 0

        run_setup(conn)
        print("\n✔ Base de datos lista.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
