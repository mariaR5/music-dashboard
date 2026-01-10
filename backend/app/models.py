from sqlmodel import SQLModel, Field
from sqlalchemy import BigInteger
from typing import Optional
from datetime import datetime, timezone

# USER TABLE
class User(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    username: str = Field(index=True, unique=True)
    email: str = Field(index=True, unique=True)
    hashed_password:  str

    # Verification fields
    is_verified: bool = Field(default=False)
    otp_code: Optional[str] = None
    otp_expiry: Optional[datetime] = None

    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    rec_period: int = Field(default=1) 


# SCROBBLE TABLE
class Scrobble(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(foreign_key='user.id')
    title: str
    artist: str
    package: str
    timestamp: int = Field(sa_type=BigInteger)
    # Time server recieved data
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))

    # Spotify data
    spotify_id: Optional[str] = None
    duration_ms: int = Field(default=0)
    image_url: Optional[str] = None
    artist_image: Optional[str] = None
    genres: Optional[str] = None


# CACHE TABLE -> Stores AI recs results
class AICache(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    seed_title: str
    seed_artist: str
    rec_type: str
    data_json: str
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))

# Handle request endpoint
class ScrobbleRequest(SQLModel):
    title: str
    artist: str
    package: str
    timestamp: int

# Handle signup requests
class UserCreate(SQLModel):
    username: str
    email: str
    password: str

# Handle email-otp verification
class VerifyRequest(SQLModel):
    email: str
    otp: str

# Handle forgot password endpoint
class ForgotPasswordRequest(SQLModel):
    email: str


# Handle reset password endpoint
class ResetPasswordRequest(SQLModel):
    email: str
    otp: str
    new_password: str


# Handle recommendation period 
class PreferenceUpdate(SQLModel):
    rec_period: int