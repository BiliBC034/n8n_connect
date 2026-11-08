#!/usr/bin/env python3
"""Sends a data-only n8n Connect push, to test the app without n8n.

The message has no 'notification' block: the app receives it in the background
and builds the notification/action from the 'data' fields.

Examples:

  Schedule an alarm at 07:30 (set_alarm action):
    python3 tools/send_push.py --token FCM_TOKEN --title "Gym" --body "07:30" --actions '[{"type":"set_alarm","hour":7,"minute":30,"label":"Gym"}]'

  Send a simple notification from an app:
    python3 tools/send_push.py --token FCM_TOKEN --title "Hello" --body "Test from the PC" --app "gym"

Credentials: pass --service-account or set the GOOGLE_APPLICATION_CREDENTIALS variable
to the path of the Firebase service account JSON file.
"""

import argparse
import json
import os
import sys
import uuid

import firebase_admin
from firebase_admin import credentials, exceptions, messaging


def parse_actions(raw, parser):
    try:
        actions = json.loads(raw)
    except json.JSONDecodeError as e:
        parser.error(f"--actions is not valid JSON: {e}")
    if not isinstance(actions, list):
        parser.error("--actions must be a JSON list, for example '[]'")
    return actions


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Sends a data-only n8n Connect push through FCM."
    )
    parser.add_argument(
        "--service-account",
        metavar="PATH",
        help="Firebase service account JSON file (default: GOOGLE_APPLICATION_CREDENTIALS)",
    )
    parser.add_argument("--token", required=True, help="FCM token of the target device")
    parser.add_argument("--title", default="n8n Connect", help="Title (default: 'n8n Connect')")
    parser.add_argument("--body", default="", help="Body (default: empty)")
    parser.add_argument(
        "--actions",
        default="[]",
        help="JSON list of actions, for example '[]' (default: '[]')",
    )
    parser.add_argument("--app", default="", help="Name of the associated n8n app (default: empty)")
    args = parser.parse_args(argv)

    actions = parse_actions(args.actions, parser)

    service_account = args.service_account or os.environ.get("GOOGLE_APPLICATION_CREDENTIALS")
    if not service_account:
        parser.error("use --service-account or set GOOGLE_APPLICATION_CREDENTIALS")

    try:
        cred = credentials.Certificate(service_account)
    except (OSError, ValueError) as e:
        sys.exit(f"error: could not read the service account: {e}")
    firebase_admin.initialize_app(cred)

    message = messaging.Message(
        token=args.token,
        data={
            "nc": "1",
            "id": uuid.uuid4().hex,
            "title": args.title,
            "body": args.body,
            "actions": json.dumps(actions, separators=(",", ":"), ensure_ascii=False),
            "app": args.app,
        },
        android=messaging.AndroidConfig(priority="high", ttl=3600),
    )

    try:
        message_id = messaging.send(message)
    except exceptions.FirebaseError as e:
        sys.exit(f"error: FCM rejected the message: {e}")
    print(message_id)


if __name__ == "__main__":
    main()
