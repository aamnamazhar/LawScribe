"""Generate a self-signed TLS certificate (cert.pem + key.pem) for local HTTPS
testing of the backend — no openssl needed (uses the `cryptography` library).

Usage:
    python gen_cert.py            # CN=localhost
    python gen_cert.py 192.168.1.4
"""
import sys
import ipaddress
import datetime
from cryptography import x509
from cryptography.x509.oid import NameOID
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa

host = sys.argv[1] if len(sys.argv) > 1 else "localhost"

key = rsa.generate_private_key(public_exponent=65537, key_size=2048)

# Subject Alternative Names: always include localhost; add the host as an IP or
# DNS name depending on what was passed.
sans = [x509.DNSName("localhost")]
try:
    sans.append(x509.IPAddress(ipaddress.ip_address(host)))
except ValueError:
    if host != "localhost":
        sans.append(x509.DNSName(host))

name = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, host)])
cert = (
    x509.CertificateBuilder()
    .subject_name(name)
    .issuer_name(name)
    .public_key(key.public_key())
    .serial_number(x509.random_serial_number())
    .not_valid_before(datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=1))
    .not_valid_after(datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(days=365))
    .add_extension(x509.SubjectAlternativeName(sans), critical=False)
    .sign(key, hashes.SHA256())
)

with open("key.pem", "wb") as f:
    f.write(key.private_bytes(
        serialization.Encoding.PEM,
        serialization.PrivateFormat.TraditionalOpenSSL,
        serialization.NoEncryption(),
    ))
with open("cert.pem", "wb") as f:
    f.write(cert.public_bytes(serialization.Encoding.PEM))

print(f"Wrote cert.pem and key.pem (valid 365 days) for host: {host}")
