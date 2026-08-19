#!/bin/bash

# ============================================
#  Script de Criação do Projeto Mesa-Mapa C4I
# ============================================

echo "=== CRIANDO ESTRUTURA DO PROJETO ==="

# Define diretório base
BASE=~/mesa_mapa

# Cria diretórios
mkdir -p $BASE/{src,simulador,build,data,assets,docs}

# ============================================
# Cria CMakeLists.txt (corrigido)
# ============================================
cat > $BASE/CMakeLists.txt << 'EOF'
cmake_minimum_required(VERSION 3.10)
project(MesaMapa VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(PkgConfig REQUIRED)

# GTKmm
pkg_check_modules(GTKMM REQUIRED gtkmm-3.0)
# Champlain
pkg_check_modules(CHAMPLAIN REQUIRED champlain-0.12)

# Mosquitto (sem pkg-config, usar find_path/find_library)
find_path(MOSQUITTO_INCLUDE_DIR NAMES mosquitto.h)
find_path(MOSQUITTOPP_INCLUDE_DIR NAMES mosquittopp.h)
find_library(MOSQUITTO_LIBRARY NAMES mosquitto)
find_library(MOSQUITTOPP_LIBRARY NAMES mosquittopp)

if(NOT MOSQUITTO_INCLUDE_DIR OR NOT MOSQUITTOPP_INCLUDE_DIR OR NOT MOSQUITTO_LIBRARY OR NOT MOSQUITTOPP_LIBRARY)
    message(FATAL_ERROR "Mosquitto não encontrado")
endif()

# nlohmann/json (header-only)
find_path(JSON_INCLUDE_DIR NAMES nlohmann/json.hpp PATHS /usr/include /usr/local/include)

add_executable(mesamapa
    src/main.cpp
    src/MQTTClient.cpp
    src/PlayerManager.cpp
)

target_include_directories(mesamapa PRIVATE
    ${GTKMM_INCLUDE_DIRS}
    ${CHAMPLAIN_INCLUDE_DIRS}
    ${MOSQUITTO_INCLUDE_DIR}
    ${MOSQUITTOPP_INCLUDE_DIR}
    ${JSON_INCLUDE_DIR}
)

target_link_libraries(mesamapa
    ${GTKMM_LIBRARIES}
    ${CHAMPLAIN_LIBRARIES}
    ${MOSQUITTO_LIBRARY}
    ${MOSQUITTOPP_LIBRARY}
    pthread
)

target_compile_options(mesamapa PRIVATE -Wall -Wextra)
EOF

# ============================================
# Cria build.sh (compilação alternativa)
# ============================================
cat > $BASE/build.sh << 'EOF'
#!/bin/bash
echo "=== COMPILANDO MESA-MAPA C4I ==="

g++ -std=c++17 \
    src/main.cpp \
    src/MQTTClient.cpp \
    src/PlayerManager.cpp \
    -o mesamapa \
    $(pkg-config --cflags --libs gtkmm-3.0 champlain-0.12) \
    -I/usr/include -I/usr/local/include \
    -lmosquitto -lmosquittopp -lpthread \
    -Wall -Wextra

if [ $? -eq 0 ]; then
    echo "✅ Compilação bem-sucedida!"
    echo "Execute com: ./mesamapa"
else
    echo "❌ Erro na compilação"
fi
EOF

chmod +x $BASE/build.sh

# ============================================
# Cria src/Player.h
# ============================================
cat > $BASE/src/Player.h << 'EOF'
#ifndef PLAYER_H
#define PLAYER_H

#include <string>

struct Player {
    std::string id;
    std::string nome;
    double latitude = 0.0;
    double longitude = 0.0;
    int magazines = 0;
    int ammo = 0;
    bool alive = true;
    int kills = 0;
    int deaths = 0;
};

#endif
EOF

# ============================================
# Cria src/PlayerManager.h
# ============================================
cat > $BASE/src/PlayerManager.h << 'EOF'
#ifndef PLAYERMANAGER_H
#define PLAYERMANAGER_H

#include <map>
#include <memory>
#include "Player.h"

class PlayerManager {
public:
    void updatePlayer(const Player& p);
    std::shared_ptr<Player> getPlayer(const std::string& id);
    std::map<std::string, std::shared_ptr<Player>> getAllPlayers() const;

private:
    std::map<std::string, std::shared_ptr<Player>> players_;
};

#endif
EOF

# ============================================
# Cria src/PlayerManager.cpp
# ============================================
cat > $BASE/src/PlayerManager.cpp << 'EOF'
#include "PlayerManager.h"

void PlayerManager::updatePlayer(const Player& p) {
    auto it = players_.find(p.id);
    if (it == players_.end()) {
        players_[p.id] = std::make_shared<Player>(p);
    } else {
        *it->second = p;
    }
}

std::shared_ptr<Player> PlayerManager::getPlayer(const std::string& id) {
    auto it = players_.find(id);
    if (it != players_.end()) return it->second;
    return nullptr;
}

std::map<std::string, std::shared_ptr<Player>> PlayerManager::getAllPlayers() const {
    return players_;
}
EOF

# ============================================
# Cria src/MQTTClient.h
# ============================================
cat > $BASE/src/MQTTClient.h << 'EOF'
#ifndef MQTTCLIENT_H
#define MQTTCLIENT_H

#include <mosquittopp.h>
#include <string>
#include <functional>

class MQTTClient : public mosqpp::mosquittopp {
public:
    using MessageCallback = std::function<void(const std::string&, const std::string&)>;

    MQTTClient(const std::string& id, const std::string& host, int port);
    ~MQTTClient();

    void set_message_callback(MessageCallback cb);
    void start_loop();
    void stop_loop();
    void subscribe(const std::string& topic);

private:
    void on_connect(int rc) override;
    void on_message(const struct mosquitto_message* message) override;
    void on_disconnect(int rc) override;

    MessageCallback callback_;
    bool running_ = false;
};

#endif
EOF

# ============================================
# Cria src/MQTTClient.cpp
# ============================================
cat > $BASE/src/MQTTClient.cpp << 'EOF'
#include "MQTTClient.h"
#include <iostream>
#include <thread>
#include <chrono>

MQTTClient::MQTTClient(const std::string& id, const std::string& host, int port)
    : mosquittopp(id.c_str()) {
    connect(host.c_str(), port, 60);
}

MQTTClient::~MQTTClient() {
    disconnect();
    loop_stop();
}

void MQTTClient::set_message_callback(MessageCallback cb) {
    callback_ = cb;
}

void MQTTClient::start_loop() {
    running_ = true;
    loop_start();
}

void MQTTClient::stop_loop() {
    running_ = false;
    loop_stop();
}

void MQTTClient::subscribe(const std::string& topic) {
    mosquittopp::subscribe(nullptr, topic.c_str());
}

void MQTTClient::on_connect(int rc) {
    if (rc == 0) {
        std::cout << "[MQTT] Conectado ao broker!" << std::endl;
        subscribe("cdc/#");  // assina todos os tópicos de CDC
    } else {
        std::cerr << "[MQTT] Falha na conexão: " << rc << std::endl;
    }
}

void MQTTClient::on_message(const struct mosquitto_message* message) {
    if (callback_) {
        std::string topic(message->topic);
        std::string payload(static_cast<char*>(message->payload), message->payloadlen);
        callback_(topic, payload);
    }
}

void MQTTClient::on_disconnect(int rc) {
    std::cout << "[MQTT] Desconectado: " << rc << std::endl;
}
EOF

# ============================================
# Cria src/main.cpp (janela principal com mapa)
# ============================================
cat > $BASE/src/main.cpp << 'EOF'
#include <gtkmm.h>
#include <champlain/champlain.h>
#include <champlain-gtk/champlain-gtk.h>
#include <iostream>
#include "MQTTClient.h"
#include "PlayerManager.h"

int main(int argc, char* argv[]) {
    std::cout << "=== MESA-MAPA C4I v0.1 ===" << std::endl;

    auto app = Gtk::Application::create(argc, argv, "org.mesamapa.c4i");

    Gtk::Window window;
    window.set_title("Mesa-Mapa C4I - Centro de Comando Tático");
    window.set_default_size(1200, 800);
    window.set_position(Gtk::WIN_POS_CENTER);

    // Layout principal
    Gtk::Paned paned(Gtk::ORIENTATION_HORIZONTAL);

    // Área do mapa (esquerda)
    Gtk::Box box_esquerda(Gtk::ORIENTATION_VERTICAL);

    // Cria widget do mapa
    Champlain::Embed* embed = new Champlain::Embed();
    Champlain::View* view = champlain_embed_get_view(CHAMPLAIN_EMBED(embed->gobj()));

    // Centraliza em São Paulo (exemplo)
    champlain_view_center_on(CHAMPLAIN_VIEW(view), -23.5505, -46.6333);
    champlain_view_set_zoom_level(CHAMPLAIN_VIEW(view), 12);

    box_esquerda.pack_start(*embed, Gtk::PACK_EXPAND_WIDGET);

    // Painel direito
    Gtk::Box box_direita(Gtk::ORIENTATION_VERTICAL, 10);
    box_direita.set_margin_top(10);
    box_direita.set_margin_bottom(10);
    box_direita.set_margin_start(10);
    box_direita.set_margin_end(10);

    Gtk::Label lbl_titulo("Esquadrão");
    lbl_titulo.set_markup("<span font='18' weight='bold'>Esquadrão</span>");

    Gtk::Label lbl_status("Aguardando jogadores...");
    lbl_status.set_markup("<span font='12'>Aguardando jogadores...</span>");

    Gtk::Button btn_teste("Testar MQTT");
    btn_teste.signal_clicked().connect([&lbl_status]() {
        lbl_status.set_markup("<span font='12' color='green'>Teste MQTT OK!</span>");
    });

    box_direita.pack_start(lbl_titulo, Gtk::PACK_SHRINK);
    box_direita.pack_start(lbl_status, Gtk::PACK_SHRINK);
    box_direita.pack_start(btn_teste, Gtk::PACK_SHRINK);

    paned.pack1(box_esquerda, true, false);
    paned.pack2(box_direita, false, false);

    window.add(paned);
    window.show_all();

    // Inicializa MQTT (não usado ainda, mas instanciado para teste)
    MQTTClient mqtt("mesa_mapa", "localhost", 1883);
    mqtt.set_message_callback([&lbl_status](const std::string& topic, const std::string& payload) {
        lbl_status.set_markup("<span font='12'>Msg recebida: " + topic + "</span>");
    });
    mqtt.start_loop();

    return app->run(window);
}
EOF

# ============================================
# Cria simulador/simulador.py
# ============================================
cat > $BASE/simulador/simulador.py << 'EOF'
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
            "lat": jog["lat"],
            "lon": jog["lon"],
            "mag": random.randint(2, 6),
            "ammo": random.randint(10, 30),
            "carregador": 1
        }
        client.publish(f"cdc/{jog['id']}/status", json.dumps(payload))
        print(f"Enviado {jog['id']}: {payload}")
    time.sleep(5)
EOF

chmod +x $BASE/simulador/simulador.py

echo ""
echo "✅ Estrutura criada com sucesso em $BASE"
echo ""
echo "Arquivos criados:"
find $BASE -type f | sort
echo ""
echo "Próximos passos:"
echo "1. cd $BASE"
echo "2. ./build.sh   (para compilar)"
echo "3. ./mesamapa   (para executar)"
echo "4. Em outro terminal: source venv/bin/activate && python3 simulador/simulador.py"