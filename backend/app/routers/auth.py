import random
from datetime import datetime, timezone, timedelta
from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import SQLModel, Session, select
from fastapi.security import OAuth2PasswordRequestForm

from app.database import get_session
from app.models import User, UserCreate
from app.auth import get_password_hash, send_otp_email, verify_password, create_access_token


router = APIRouter(tags=["Authentication"])

@router.post('/register')
async def register_user(user: UserCreate, session: Session = Depends(get_session)):
    # Check if username exists
    existing_user = session.exec(select(User).where((User.username == user.username) | (User.email == user.email))).first()

    if existing_user:
        if existing_user.is_verified:
            if existing_user.username == user.username:
                detail = 'Username already taken'
            else:
                detail = 'Email already registered'
            raise HTTPException(status_code=400, detail=detail)
        else:
            session.delete(existing_user)
            session.commit()

    
    otp = str(random.randint(100000, 999999))
    otp_exp = datetime.now(timezone.utc) + timedelta(minutes=10)

    # Hash password and save to database
    hashed_pwd = get_password_hash(user.password)
    new_user = User(
        username=user.username, 
        email=user.email,
        hashed_password=hashed_pwd,
        otp_code=otp,
        otp_expiry=otp_exp,
        is_verified=False
    )    

    session.add(new_user)
    session.commit()

    try:
        await send_otp_email(user.email, otp)
    except Exception as e:
        print(f"Email failed: {e}")

    return {'message': 'Account created. Please verify your email', 'email': user.email}

class VerifyRequest(SQLModel):
    email: str
    otp: str

@router.post('/verify-email')
def verify_email(req: VerifyRequest, session: Session = Depends(get_session)):
    user = session.exec(select(User).where(User.email == req.email)).first()

    if not user:
        raise HTTPException(status_code=404, detail='User not found')
    
    if user.is_verified:
        return {'message': 'User already verified'}
    
    now = datetime.now(timezone.utc)

    if user.otp_expiry.tzinfo is None:
        user.otp_expiry = user.otp_expiry.replace(tzinfo=timezone.utc)

    if user.otp_code != req.otp or now > user.otp_expiry:
        raise HTTPException(status_code=400, detail='Invalid or expired otp')
    

    user.is_verified = True
    user.otp_code = None # Clear OTP
    session.add(user)
    session.commit()

    return {'message': 'Email verified successfully. You can now login'}

class ForgotPasswordRequest(SQLModel):
    email: str

@router.post('/forgot-password')
async def forgot_password(req: ForgotPasswordRequest, session: Session = Depends(get_session)):
    user = session.exec(select(User).where(User.email == req.email)).first()

    if not user:
        return {'message': 'If that email exists, an OTP has been sent'}
    
    otp = str(random.randint(100000, 999999))
    user.otp_code = otp
    user.otp_expiry = datetime.now(timezone.utc) + timedelta(minutes=10)

    session.add(user)
    session.commit()

    await send_otp_email(req.email, otp, subject='Reset Your Password')
    return {'message': 'If that email exists, an OTP has been sent'}


class ResetPasswordRequest(SQLModel):
    email: str
    otp: str
    new_password: str

@router.post('/reset-password')
def reset_password(req: ResetPasswordRequest, session: Session = Depends(get_session)):
    user = session.exec(select(User).where(User.email == req.email)).first()

    if not user:
        raise HTTPException(status_code=404, detail='User not found')
    
    now = datetime.now(timezone.utc)

    if user.otp_expiry.tzinfo is None:
        user.otp_expiry = user.otp_expiry.replace(tzinfo=timezone.utc)

    if user.otp_code != req.otp or now > user.otp_expiry:
        raise HTTPException(status_code=400, detail='Invalid or expired otp')
    
    user.hashed_password = get_password_hash(req.new_password)
    user.otp_code = None
    session.add(user)
    session.commit()

    return {'message': 'Password updated successfully. Please login'}


@router.post('/token')
def login_for_access_token(form_data: OAuth2PasswordRequestForm = Depends(), session: Session = Depends(get_session)):
    # Find user
    user = session.exec(select(User).where(User.username == form_data.username)).first()

    if not user or not verify_password(form_data.password, user.hashed_password):
        raise HTTPException(status_code=401, detail='Incorrect username or password')
    
    if not user.is_verified:
        raise HTTPException(status_code=403, detail='Email not verified. Please verify your account')
    
    access_token = create_access_token(data={'sub': user.username})
    return {'access_token': access_token, 'token_type': 'bearer'}