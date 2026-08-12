"""
Reference Bedrock Agent Action Group executor.

Bedrock invokes this Lambda synchronously and passes the selected function
name plus its resolved parameters in the event body. The response must be
wrapped in the exact `messageVersion: "1.0"` envelope the Agent runtime
expects, or the agent will fail to parse the tool result.

Replace `TOOL_IMPLEMENTATIONS` with real business logic (calls to internal
APIs, databases, etc.) -- this reference implementation returns deterministic
mock data so the wiring can be validated end-to-end before any backend
integration exists.
"""
import json
import logging
from typing import Any

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def _get_order_status(parameters: dict[str, Any]) -> dict[str, Any]:
    order_id = parameters.get("orderId", "UNKNOWN")
    return {
        "orderId": order_id,
        "status": "IN_TRANSIT",
        "estimatedDelivery": "2026-08-15",
    }


TOOL_IMPLEMENTATIONS = {
    "getOrderStatus": _get_order_status,
}


def lambda_handler(event: dict[str, Any], context: Any) -> dict[str, Any]:
    logger.info("Received Bedrock Agent action group event: %s", json.dumps(event))

    action_group = event.get("actionGroup", "unknown-action-group")
    function_name = event.get("function", "")
    raw_parameters = event.get("parameters", [])
    parameters = {p["name"]: p.get("value") for p in raw_parameters}

    handler = TOOL_IMPLEMENTATIONS.get(function_name)
    if handler is None:
        body = {"error": f"No implementation registered for function '{function_name}'"}
    else:
        body = handler(parameters)

    return {
        "messageVersion": "1.0",
        "response": {
            "actionGroup": action_group,
            "function": function_name,
            "functionResponse": {
                "responseBody": {
                    "TEXT": {
                        "body": json.dumps(body),
                    }
                }
            },
        },
    }
