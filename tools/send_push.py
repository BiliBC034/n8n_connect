#!/usr/bin/env python3
"""Envía un push de solo datos (data-only) de n8n Connect, para probar la app sin n8n.

El mensaje no lleva bloque 'notification': la app lo recibe en segundo plano
y construye la notificación/acción a partir de los campos 'data'.

Ejemplos:

  Programar una alarma a las 07:30 (acción set_alarm):
    python3 tools/send_push.py --token FCM_TOKEN --title "Gym" --body "07:30" --actions '[{"type":"set_alarm","hour":7,"minute":30,"label":"Gym"}]'

  Enviar una notificación simple de una app:
    python3 tools/send_push.py --token FCM_TOKEN --title "Hola" --body "Prueba desde el PC" --app "gym"

Credenciales: pasa --service-account o define la variable GOOGLE_APPLICATION_CREDENTIALS
con la ruta al JSON de la cuenta de servicio de Firebase.
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
        parser.error(f"--actions no es JSON válido: {e}")
    if not isinstance(actions, list):
        parser.error("--actions debe ser una lista JSON, por ejemplo '[]'")
    return actions


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Envía un push data-only de n8n Connect mediante FCM."
    )
    parser.add_argument(
        "--service-account",
        metavar="PATH",
        help="JSON de la cuenta de servicio de Firebase (por defecto: GOOGLE_APPLICATION_CREDENTIALS)",
    )
    parser.add_argument("--token", required=True, help="Token FCM del dispositivo destino")
    parser.add_argument("--title", default="n8n Connect", help="Título (por defecto: 'n8n Connect')")
    parser.add_argument("--body", default="", help="Cuerpo (por defecto: vacío)")
    parser.add_argument(
        "--actions",
        default="[]",
        help="Lista JSON de acciones, por ejemplo '[]' (por defecto: '[]')",
    )
    parser.add_argument("--app", default="", help="Nombre de la app de n8n asociada (por defecto: vacío)")
    args = parser.parse_args(argv)

    actions = parse_actions(args.actions, parser)

    service_account = args.service_account or os.environ.get("GOOGLE_APPLICATION_CREDENTIALS")
    if not service_account:
        parser.error("indica --service-account o define GOOGLE_APPLICATION_CREDENTIALS")

    try:
        cred = credentials.Certificate(service_account)
    except (OSError, ValueError) as e:
        sys.exit(f"error: no se pudo leer la cuenta de servicio: {e}")
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
        sys.exit(f"error: FCM rechazó el envío: {e}")
    print(message_id)


if __name__ == "__main__":
    main()
