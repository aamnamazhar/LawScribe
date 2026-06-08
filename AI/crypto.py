"""At-rest encryption for uploaded documents (SRS S3).

Files on the backend's disk are encrypted with a symmetric key (Fernet/AES) so a
copy of the disk does not expose document contents. Encryption is keyed by the
FILE_ENCRYPTION_KEY environment variable:

  * key set   → files are encrypted on write and decrypted on read
  * key unset → no-op (plaintext), so development still works without setup

Decryption is backward-compatible: files written before encryption was enabled
(or any plaintext file) are returned unchanged instead of failing.
"""
import os

_KEY = os.getenv("FILE_ENCRYPTION_KEY")
_fernet = None
if _KEY:
    try:
        from cryptography.fernet import Fernet
        _fernet = Fernet(_KEY.encode() if isinstance(_KEY, str) else _KEY)
    except Exception as e:  # missing library or malformed key → run plaintext
        print(f"[crypto] File encryption disabled: {e}")
        _fernet = None


def encryption_enabled() -> bool:
    return _fernet is not None


def encrypt_bytes(data: bytes) -> bytes:
    """Encrypt bytes for at-rest storage. No-op when no key is configured."""
    return _fernet.encrypt(data) if _fernet else data


def decrypt_bytes(data: bytes) -> bytes:
    """Decrypt at-rest bytes. Returns the input unchanged for legacy plaintext
    files (or when no key is set), so existing uploads keep working."""
    if not _fernet:
        return data
    try:
        return _fernet.decrypt(data)
    except Exception:
        return data  # legacy/plaintext file written before encryption
