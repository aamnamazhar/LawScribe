import os
from dotenv import load_dotenv
load_dotenv()

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.routes import health, documents, extraction, ai
from app.core.firebase import initialize_firebase

initialize_firebase()

app = FastAPI(title="LawScribe Backend")

# CORS: read allowed origins from env, comma-separated.
# Browsers reject `*` together with credentials, so we never combine the two.
_origins_env = os.getenv("CORS_ALLOWED_ORIGINS", "")
_allowed_origins = [o.strip() for o in _origins_env.split(",") if o.strip()]
if _allowed_origins:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=_allowed_origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
else:
    # No origins configured — fall back to fully-open CORS without credentials.
    # Set CORS_ALLOWED_ORIGINS in production.
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=False,
        allow_methods=["*"],
        allow_headers=["*"],
    )

app.include_router(health.router)
app.include_router(documents.router)
app.include_router(extraction.router)
app.include_router(ai.router)


@app.get("/")
def root():
    return {"message": "Backend is running"}
