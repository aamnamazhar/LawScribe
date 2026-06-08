import os
import uvicorn

if __name__ == "__main__":
    # HTTPS/TLS (SRS S2): enabled when both cert paths are provided via env, so
    # production runs over TLS while local development can stay on plain HTTP.
    #   set SSL_CERTFILE / SSL_KEYFILE to enable, e.g. a self-signed pair for
    #   testing or a real certificate behind a domain in production.
    ssl_certfile = os.getenv("SSL_CERTFILE")
    ssl_keyfile = os.getenv("SSL_KEYFILE")

    extra = {}
    if ssl_certfile and ssl_keyfile:
        extra = {"ssl_certfile": ssl_certfile, "ssl_keyfile": ssl_keyfile}
        print("Starting LawScribe backend with HTTPS/TLS enabled.")
    else:
        print("Starting LawScribe backend over HTTP (set SSL_CERTFILE/SSL_KEYFILE for HTTPS).")

    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=True, **extra)
