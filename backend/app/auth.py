import os
from dotenv import load_dotenv
import requests
import bcrypt
from datetime import datetime, timezone, timedelta
from fastapi.security import OAuth2PasswordBearer
from fastapi import Depends, HTTPException
from jose import jwt, JWTError
from sqlmodel import Session, select

from app.models import User
from app.database import get_session

load_dotenv

# Security config for JWT
SECRET_KEY = os.getenv('JWT_SECRET_KEY')
ALGORITHM = 'HS256'
ACCESS_TOKEN_EXPIRY_MINUTES = 30000

# Method to extract token
oauth2_scheme = OAuth2PasswordBearer(tokenUrl = 'token')

# Verify password
def verify_password(plain_password: str, hashed_password: str) -> bool:
    # Convert strings to bytes
    pwd_bytes = plain_password.encode('utf-8')
    hash_pwd_bytes = hashed_password.encode('utf-8')
    
    return bcrypt.checkpw(pwd_bytes, hash_pwd_bytes)

# Hash password
def get_password_hash(password: str) -> str:
    # Convert string pwd to bytes
    pwd_bytes = password.encode('utf-8')
    
    # Generate a salt and hash the password
    salt = bcrypt.gensalt()
    hashed_password = bcrypt.hashpw(pwd_bytes, salt)

    # Convert bytes to string
    return hashed_password.decode('utf-8')

# Create JWT access token -> header.payload.signature
def create_access_token(data: dict):
    # Header is created automatically and signature is created by applying the algorithm with header payload and secret key 
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + timedelta(minutes=ACCESS_TOKEN_EXPIRY_MINUTES)
    
    to_encode.update({'exp': expire}) # Payload
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt


# Get current user to let the endpoints know who is making the request
def get_current_user(token: str = Depends(oauth2_scheme), session: Session = Depends(get_session)):
    credentials_exception = HTTPException(
        status_code=401,
        detail="Could not validate credentials",
        headers={'WWW-Authenticate':'Bearer'}
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username: str = payload.get('sub')
        if username is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception
    
    # Find user in database
    user = session.exec(select(User).where(User.username == username)).first()
    if user is None:
        raise credentials_exception
    return user


async def send_otp_email(email: str, otp: str, subject: str = 'Your Verification Code'):
    url = "https://api.brevo.com/v3/smtp/email"

    api_key = os.getenv('BREVO_API_KEY')
    sender_email = os.getenv('MAIL_USERNAME')

    headers = {
        'accept': 'application/json',
        'api-key': api_key,
        'content-type': 'application/json'
    }

    html = f"""
    <div style="font-family: Arial, sans-serif; padding: 20px">
    <h2>Universal Scrobbler Security</h2>
    <p>Your One-Time Password (OTP) is :</p>
    <h1 style="color: #697565; letter-spacing: 5px;">{otp}</h1>
    <p>This code expires in 10 minutes</p>
    <p>If you did not request this, please ignore this email.</p>
    </div>
    """

    payload = {
        'sender': {'email': sender_email, 'name': 'Universal Scrobbler'},
        'to': [{'email': email}],
        'subject': subject,
        'htmlContent': html
    }

    try:
        response = requests.post(url, json=payload, headers=headers)
        if response.status_code == 201:
            print(f'Email sent successfully to {email}')
        else:
            print(f"Brevo error: {response.text}")

    except Exception as e:
        print(f"Email exception: {e}")


