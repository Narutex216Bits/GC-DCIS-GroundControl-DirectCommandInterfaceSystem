#!/bin/bash
echo "=== COMPILANDO MESA-MAPA C4I ==="

g++ -std=c++17 \
    src/main.cpp \
    src/MQTTClient.cpp \
    src/PlayerManager.cpp \
    -o mesamapa \
    $(pkg-config --cflags --libs gtkmm-3.0 champlain-0.12 champlain-gtk-0.12 clutter-1.0) \
    -I/usr/include -I/usr/local/include \
    -lmosquitto -lmosquittopp -lpthread \
    -Wno-deprecated-declarations \
    -Wall -Wextra

if [ $? -eq 0 ]; then
    echo "✅ Compilação bem-sucedida!"
    echo "Execute com: ./mesamapa"
else
    echo "❌ Erro na compilação"
fi