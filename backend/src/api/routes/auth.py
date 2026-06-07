"""Authentication routes."""

from datetime import timedelta

from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel

from src.core.security import SecurityManager

router = APIRouter()


class LoginRequest(BaseModel):
    """Login request."""

    username: str
    password: str


class TokenResponse(BaseModel):
    """Token response."""

    access_token: str
    token_type: str = "bearer"


@router.post("/login", response_model=TokenResponse)
async def login(request: LoginRequest):
    """Login endpoint."""
    # TODO: Implement user validation with database
    if request.username == "admin" and request.password == "admin":
        access_token = SecurityManager.create_access_token(
            data={"sub": request.username}, expires_delta=timedelta(hours=24)
        )
        return {"access_token": access_token}

    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials"
    )
