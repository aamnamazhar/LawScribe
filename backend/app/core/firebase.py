import os
import firebase_admin
from firebase_admin import credentials, firestore, storage

_db = None
_bucket = None

# Resolve the service-account JSON relative to this file rather than the
# current working directory, so the backend boots from any cwd.
_DEFAULT_CRED_PATH = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..", "..", "firebase-service-account.json")
)


def initialize_firebase():
    global _db, _bucket
    if not firebase_admin._apps:
        cred_path = os.getenv("FIREBASE_CREDENTIALS", _DEFAULT_CRED_PATH)
        bucket_name = os.getenv("FIREBASE_STORAGE_BUCKET", "c121890.appspot.com")
        cred = credentials.Certificate(cred_path)
        firebase_admin.initialize_app(cred, {
            "storageBucket": bucket_name,
        })
    _db = firestore.client()
    _bucket = storage.bucket()


def get_db():
    return _db


def get_bucket():
    return _bucket