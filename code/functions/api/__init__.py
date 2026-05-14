import json
import logging
import os
from datetime import datetime, timedelta, timezone

import azure.functions as func
from azure.core.exceptions import ResourceNotFoundError
from azure.data.tables import TableServiceClient

_CORS = {"Access-Control-Allow-Origin": "*"}


def main(req: func.HttpRequest) -> func.HttpResponse:
    conn_str = os.environ.get("STORAGE_CONNECTION_STRING", "")
    table_name = os.environ.get("STORAGE_TABLE_NAME", "monitoringresults")
    sites_raw = os.environ.get("SITES_TO_MONITOR", "")
    sites = [s.strip() for s in sites_raw.split(",") if s.strip()]

    site_filter = req.params.get("site")
    try:
        hours = min(int(req.params.get("hours", 24)), 168)
    except ValueError:
        hours = 24

    cutoff = datetime.now(timezone.utc) - timedelta(hours=hours)
    cutoff_str = cutoff.strftime("%Y%m%dT%H%M%SZ")

    if site_filter:
        sites = [s for s in sites if site_filter in s]

    try:
        service = TableServiceClient.from_connection_string(conn_str)
        table = service.get_table_client(table_name)
        results = [_build_site_summary(table, url, cutoff_str) for url in sites]
    except Exception as exc:
        logging.error("Table Storage query failed: %s", exc)
        return func.HttpResponse(
            json.dumps({"error": str(exc)}),
            status_code=500,
            mimetype="application/json",
            headers=_CORS,
        )

    # DOWN sites first, then alphabetical
    results.sort(key=lambda s: (s["current_status"] != "DOWN", s["url"]))

    body = json.dumps(
        {
            "generated_at": datetime.now(timezone.utc).isoformat(),
            "hours_shown": hours,
            "sites": results,
        }
    )
    return func.HttpResponse(
        body,
        mimetype="application/json",
        headers={**_CORS, "Cache-Control": "no-cache"},
    )


def _build_site_summary(table, url: str, cutoff_str: str) -> dict:
    entities = []
  
    safe_pk = url.replace("https://", "").replace("http://", "").replace("/", "_").replace(":", "_")

    try:
        query = f"PartitionKey eq '{safe_pk}' and RowKey ge '{cutoff_str}'"
        entities = sorted(table.query_entities(query), key=lambda r: r["RowKey"])
    except ResourceNotFoundError:
        pass

    checks = [
        {
            "timestamp": e["RowKey"],
            "is_up": e.get("IsUp", False),
            "status_code": e.get("StatusCode", 0),
            "response_time_ms": e.get("ResponseTimeMs", 0),
        }
        for e in entities
    ]

    total = len(checks)
    up_count = sum(1 for c in checks if c["is_up"])
    uptime = round(up_count / total * 100, 2) if total else 0
    avg_rt = round(sum(c["response_time_ms"] for c in checks) / total) if total else 0
    latest = checks[-1] if checks else None

    return {
        "url": url,
        "current_status": "UP" if (latest and latest["is_up"]) else "DOWN",
        "last_checked": latest["timestamp"] if latest else None,
        "last_status_code": latest["status_code"] if latest else None,
        "uptime_percent": uptime,
        "avg_response_ms": avg_rt,
        "total_checks": total,
        "checks": checks[-100:],
    }
