from fastapi import FastAPI, Depends
from sqlmodel import SQLModel, Session, create_engine, Field, select
from typing import Optional, List
from datetime import datetime, timezone

# Setup the database
sqllite_file_name = "music.db" # database name
sqllite_url = f"sqlite:///{sqllite_file_name}" # database url

# Create engine -> responsible for database connection
engine = create_engine(sqllite_url)

# Define the table
class Scrobble(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    title: str
    artist: str
    package: str
    timestamp: int
    # Time server recieved data
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


# Initialise a server
app = FastAPI()

# Runs when server 'starts', creates all tables in SQLModel metadata
@app.on_event("startup")
def on_startup():
    SQLModel.metadata.create_all(engine)

# Helper function to get db session
def get_session():
    with Session(engine) as session:
        yield session

# Create POST endpoint (reciever)
@app.post("/scrobble")
async def receive_scrobble(scrobble: Scrobble, session: Session = Depends(get_session)): # Dependancy Injection
    print(f"Saving: {scrobble.title} by {scrobble.artist}")

    # Save to database
    session.add(scrobble)
    session.commit()
    session.refresh(scrobble)

    return {
        "status": "success",
        "id": scrobble.id
    }

# See history : Defines http GET endpoint
@app.get("/history", response_model=List[Scrobble])
def read_history(session: Session = Depends(get_session)):
    scrobbles = session.exec(
        select(Scrobble).order_by(Scrobble.id.desc())
    ).all()
    return scrobbles


# Health check
@app.get("/") # "/" sending request to root path
def home():
    return {
        "status" : "online",
        "system" : "Music Dashboard Backend"
    }
