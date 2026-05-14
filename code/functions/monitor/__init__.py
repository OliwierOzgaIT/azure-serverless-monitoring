import logging
import os
from datetime import datetime, timezone

import azure.functions as func
import requests
from azure.data.tables import TableServiceClient


def main(mytimer: func.TimerRequest) -> None:
    conn_str = os.environ.get("STORAGE_CONNECTION_STRING", "")
    table_name = os.environ.get("STORAGE_TABLE_NAME", "monitoringresults")
    logic_app_url = os.environ.get("LOGIC_APP_TRIGGER_URL", "")
    sites_raw = os.environ.get("SITES_TO_MONITOR", "")
    sites = [s.strip() for s in sites_raw.split(",") if s.strip()]

    for site in sites:
        result = check_site(site)
        store_result(conn_str, table_name, site, result)
        if not result["is_up"] and logic_app_url:
            send_alert(logic_app_url, site, result)


def check_site(url: str) -> dict:
    try:
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36'
        }
        
        start = datetime.now(timezone.utc)
        
        resp = requests.get(url, timeout=10, headers=headers)
        
        elapsed_ms = (datetime.now(timezone.utc) - start).total_seconds() * 1000
        
        return {
            "is_up": resp.status_code < 400,
            "status_code": resp.status_code,
            "response_time_ms": round(elapsed_ms),
            "error_message": "",
        }
    except requests.exceptions.Timeout:
        return {
            "is_up": False,
            "status_code": 0,
            "response_time_ms": 0,
            "error_message": "Timeout",
        }
    except requests.exceptions.ConnectionError as exc:
        return {
            "is_up": False,
            "status_code": 0,
            "response_time_ms": 0,
            "error_message": f"ConnectionError: {exc}",
        }

def store_result(conn_str: str, table_name: str, site_url: str, result: dict) -> None:
    ts = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    service = TableServiceClient.from_connection_string(conn_str)
    table = service.get_table_client(table_name)
    try:
        table.create_table()
        logging.info("Table %s created or already exists.", table_name)
    except Exception:
        pass 

    safe_pk = site_url.replace("https://", "").replace("http://", "").replace("/", "_").replace(":", "_")
    
    entity = {
        "PartitionKey": safe_pk,
        "RowKey": ts,
        "Url": site_url,         
        "StatusCode": result["status_code"],
        "ResponseTimeMs": result["response_time_ms"],
        "IsUp": result["is_up"],
        "ErrorMessage": result["error_message"],
        "CheckedAt": ts,
    }
    table.upsert_entity(entity)
    logging.info("Stored result for %s: up=%s", site_url, result["is_up"])

def send_alert(logic_app_url: str, site_url: str, result: dict) -> None:
    try:
        payload = {
            "site_url": site_url,
            "status_code": result["status_code"],
            "response_time": result["response_time_ms"],
            "checked_at": datetime.now(timezone.utc).isoformat(),
            "error_message": result["error_message"],
        }
        requests.post(logic_app_url, json=payload, timeout=10)
        logging.info("Alert sent for %s", site_url)
    except Exception as exc:
        logging.error("Failed to send alert for %s: %s", site_url, exc)
