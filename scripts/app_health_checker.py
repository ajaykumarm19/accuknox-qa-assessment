#!/usr/bin/env python3
"""Application Health Checker using HTTP status codes."""

import argparse
import logging
import ssl
import sys
import time
import urllib.error
import urllib.request

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler("app_health.log"),
    ],
)


def check_application(url: str, timeout: int = 5, insecure: bool = False) -> bool:
    """Checks an application endpoint and returns True if UP, False if DOWN."""
    ssl_context = None
    if insecure and url.startswith("https://"):
        ssl_context = ssl._create_unverified_context()

    request = urllib.request.Request(
        url,
        headers={"User-Agent": "AppHealthChecker/1.0"},
        method="GET",
    )

    start_time = time.perf_counter()
    try:
        with urllib.request.urlopen(
            request, timeout=timeout, context=ssl_context
        ) as response:
            latency_ms = (time.perf_counter() - start_time) * 1000
            status_code = response.getcode()

            if 200 <= status_code < 400:
                logging.info(
                    "STATUS: UP   | URL: %s | HTTP %d | Response Time: %.2f ms",
                    url,
                    status_code,
                    latency_ms,
                )
                return True

            logging.error(
                "STATUS: DOWN | URL: %s | Unexpected HTTP %d | Response Time: %.2f ms",
                url,
                status_code,
                latency_ms,
            )
            return False

    except urllib.error.HTTPError as err:
        latency_ms = (time.perf_counter() - start_time) * 1000
        logging.error(
            "STATUS: DOWN | URL: %s | HTTP %d (%s) | Response Time: %.2f ms",
            url,
            err.code,
            err.reason,
            latency_ms,
        )
        return False

    except urllib.error.URLError as err:
        logging.error(
            "STATUS: DOWN | URL: %s | Connection Failed: %s",
            url,
            err.reason,
        )
        return False

    except TimeoutError:
        logging.error(
            "STATUS: DOWN | URL: %s | Request timed out after %ds",
            url,
            timeout,
        )
        return False


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Check HTTP/HTTPS application uptime and health status."
    )
    parser.add_argument(
        "urls",
        nargs="+",
        help="One or more application URLs to check (e.g., https://wisecow.local)",
    )
    parser.add_argument(
        "-t",
        "--timeout",
        type=int,
        default=5,
        help="Request timeout in seconds (default: 5)",
    )
    parser.add_argument(
        "-k",
        "--insecure",
        action="store_true",
        help="Skip TLS certificate verification (useful for self-signed certificates)",
    )
    args = parser.parse_args()

    all_healthy = True
    for target_url in args.urls:
        if not check_application(target_url, timeout=args.timeout, insecure=args.insecure):
            all_healthy = False

    sys.exit(0 if all_healthy else 1)


if __name__ == "__main__":
    main()
