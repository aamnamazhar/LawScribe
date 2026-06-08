"""Concurrent load test for the LawScribe backend (SRS NFR P6: 100 users).

Fires many concurrent requests at a lightweight endpoint and reports success
rate, throughput, and latency percentiles. Uses /health by default so it does
not consume Groq/LLM quota.

Usage (backend must be running):
    python load_test.py
    python load_test.py http://127.0.0.1:8000/health 100 500
        args: <url> <concurrency> <total-requests>
"""
import sys
import time
import statistics
import urllib.request
from concurrent.futures import ThreadPoolExecutor

URL = sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:8000/health"
CONCURRENCY = int(sys.argv[2]) if len(sys.argv) > 2 else 100
TOTAL = int(sys.argv[3]) if len(sys.argv) > 3 else 500


_errors = {}


def _one_request(_):
    start = time.perf_counter()
    try:
        with urllib.request.urlopen(URL, timeout=30) as resp:
            resp.read()
            ok = resp.status == 200
    except Exception as e:
        ok = False
        reason = f"{type(e).__name__}: {e}"
        _errors[reason] = _errors.get(reason, 0) + 1
    return ok, (time.perf_counter() - start) * 1000.0  # latency in ms


def main():
    print(f"Load test -> {URL}")
    print(f"Concurrency = {CONCURRENCY}, total requests = {TOTAL}\n")

    t0 = time.perf_counter()
    with ThreadPoolExecutor(max_workers=CONCURRENCY) as pool:
        results = list(pool.map(_one_request, range(TOTAL)))
    elapsed = time.perf_counter() - t0

    latencies = sorted(lat for ok, lat in results if ok)
    failures = sum(1 for ok, _ in results if not ok)

    print(f"Completed {TOTAL} requests in {elapsed:.2f}s")
    print(f"Throughput : {TOTAL / elapsed:.1f} req/s")
    print(f"Success    : {len(latencies)}/{TOTAL} "
          f"({100.0 * len(latencies) / TOTAL:.1f}%)")
    print(f"Failures   : {failures}")
    if _errors:
        print("Failure reasons:")
        for reason, n in sorted(_errors.items(), key=lambda x: -x[1]):
            print(f"  {n}x  {reason}")
    if latencies:
        p95 = latencies[min(len(latencies) - 1, int(len(latencies) * 0.95))]
        print(f"Latency ms : avg={statistics.mean(latencies):.1f} "
              f"p50={latencies[len(latencies) // 2]:.1f} "
              f"p95={p95:.1f} "
              f"max={latencies[-1]:.1f}")


if __name__ == "__main__":
    main()
