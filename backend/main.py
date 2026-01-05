from fastapi import FastAPI
from sqlmodel import SQLModel

from app.database import engine
from app.routers import auth, recommendations, scrobble, stats, users

# Initialise a server
app = FastAPI(title="Cue API")

# Runs when server 'starts', creates all tables in SQLModel metadata
@app.on_event("startup")
def on_startup():
    SQLModel.metadata.create_all(engine)

# Connect to the routers
app.include_router(auth.router)
app.include_router(recommendations.router)
app.include_router(scrobble.router)
app.include_router(stats.router)
app.include_router(users.router)


# Health check
@app.get("/") # "/" sending request to root path
def home():
    return {
        "status" : "online",
        "system" : "Cue Backend"
    }
