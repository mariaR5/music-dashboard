import os
from dotenv import load_dotenv
from sqlmodel import SQLModel, Session, create_engine

# Load secrets from .env
load_dotenv()

# Setup the database
database_url = os.getenv('DATABASE_URL')

# SQL alchemy require postgresql://, but Render provides postgres://
if database_url and database_url.startswith("postgres://"):
    database_url = database_url.replace("postgres://", "postgresql://", 1)

# Fallback to SQLite if no url found
if not database_url:
    database_url = "sqlite:///music.db"

# Create engine
engine = create_engine(database_url)

# Helper function to get db session
def get_session():
    with Session(engine) as session:
        yield session