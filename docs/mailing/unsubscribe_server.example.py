#!/usr/bin/env python3
"""Exemplo sanitizado de endpoint de unsubscribe.

Não contém persistência, credenciais ou configuração de produção.
"""
import hashlib
import hmac
import os

SECRET = os.environ["OC_MAILING_UNSUBSCRIBE_SECRET"]

def valid_token(email, campaign, token):
    payload = f"{campaign}|{email}|{SECRET}".encode()
    expected = hashlib.sha256(payload).hexdigest()
    return hmac.compare_digest(expected, token)

def record_optout(email, campaign):
    # Persistir em storage privado e marcar o contato como não enviável.
    raise NotImplementedError

def handle_unsubscribe(email, campaign, token):
    if not valid_token(email, campaign, token):
        return 400, "Invalid unsubscribe link"
    record_optout(email, campaign)
    return 200, "You have been unsubscribed"
