from fastapi import APIRouter, Depends
from app.dependencies.auth import verify_firebase_token

router = APIRouter(tags=["Health"])

@router.get("/health")
def health_check():
    return {"status": "ok"}

@router.get("/protected")
def protected_route(user=Depends(verify_firebase_token)):
    return {
        "message": "Access granted",
        "uid": user["uid"],
        "email": user.get("email")
    }