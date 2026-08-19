#!/usr/bin/env python3
import paho.mqtt.client as mqtt
import time
import json
import random

BROKER = "localhost"
JOGADORES = [
    {"id": "cdc_01", "nome": "Capitão Aço", "lat": -23.55, "lon": -46.63},
    {"id": "cdc_02", "nome": "Sombra", "lat": -23.551, "lon": -46.631},
    {"id": "cdc_03", "nome": "Falcão", "lat": -23.549, "lon": -46.632}
]

client = mqtt.Client()
client.connect(BROKER, 1883, 60)

print("Simulador iniciado. Enviando dados a cada 5 segundos...")
while True:
    for jog in JOGADORES:
        # Simula pequeno deslocamento
        jog["lat"] += random.uniform(-0.0001, 0.0001)
        jog["lon"] += random.uniform(-0.0001, 0.0001)
        payload = {
            "id": jog["id"],
            "nome": jog["nome"],
            "lat": jog["lat"],
            "lon": jog["lon"],
            "mag": random.randint(2, 6),
            "ammo": random.randint(10, 30),
            "carregador": 1
        }
        client.publish(f"cdc/{jog['id']}/status", json.dumps(payload))
        print(f"Enviado {jog['id']}: {payload}")
    time.sleep(5)