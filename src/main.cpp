#include <gtkmm.h>
#include <champlain/champlain.h>
#include <champlain-gtk/champlain-gtk.h>
#include <clutter/clutter.h>
#include <iostream>
#include <map>
#include <mutex>
#include <glibmm/dispatcher.h>
#include <nlohmann/json.hpp>
#include "MQTTClient.h"
#include "PlayerManager.h"
#include "Player.h"

using json = nlohmann::json;

int main(int argc, char* argv[]) {
    std::cout << "=== MESA-MAPA C4I v0.1 ===" << std::endl;

    // Inicializa o Clutter (obrigatório para o Champlain)
    ClutterInitError clutter_err = clutter_init(&argc, &argv);
    if (clutter_err != CLUTTER_INIT_SUCCESS) {
        std::cerr << "Erro ao inicializar Clutter: " << clutter_err << std::endl;
        return 1;
    }

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
    GtkWidget* champlain_widget = gtk_champlain_embed_new();
    ChamplainView* view = gtk_champlain_embed_get_view(GTK_CHAMPLAIN_EMBED(champlain_widget));
    champlain_view_center_on(view, -23.5505, -46.6333);
    champlain_view_set_zoom_level(view, 12);

    gtk_box_pack_start(GTK_BOX(box_esquerda.gobj()), champlain_widget, TRUE, TRUE, 0);

    // Cria uma camada de marcadores e adiciona ao view
    ChamplainMarkerLayer* marker_layer = champlain_marker_layer_new();
    champlain_view_add_layer(view, CHAMPLAIN_LAYER(marker_layer));

    // Painel direito
    Gtk::Box box_direita(Gtk::ORIENTATION_VERTICAL, 10);
    box_direita.set_margin_top(10);
    box_direita.set_margin_bottom(10);
    box_direita.set_margin_start(10);
    box_direita.set_margin_end(10);

    Gtk::Label lbl_titulo;
    lbl_titulo.set_markup("<span font='18' weight='bold'>Esquadrão</span>");

    Gtk::Label lbl_status;
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

    // ====================
    // Gerenciador de jogadores e marcadores
    // ====================
    PlayerManager playerManager;
    std::map<std::string, ChamplainMarker*> markers;
    std::mutex dataMutex;

    Glib::Dispatcher dispatcher;

    // ====================
    // MQTT
    // ====================
    MQTTClient mqtt("mesa_mapa", "localhost", 1883);

    mqtt.set_message_callback([&](const std::string& /*topic*/, const std::string& payload) {
        try {
            json j = json::parse(payload);

            Player p;
            p.id = j.value("id", "desconhecido");
            p.nome = j.value("nome", "Jogador");
            p.latitude = j.value("lat", 0.0);
            p.longitude = j.value("lon", 0.0);
            p.magazines = j.value("mag", 0);
            p.ammo = j.value("ammo", 0);
            p.alive = true;

            {
                std::lock_guard<std::mutex> lock(dataMutex);
                playerManager.updatePlayer(p);
            }

            dispatcher.emit();
        } catch (const std::exception& e) {
            std::cerr << "Erro no JSON: " << e.what() << std::endl;
        }
    });

    dispatcher.connect([&]() {
        std::map<std::string, std::shared_ptr<Player>> players;
        {
            std::lock_guard<std::mutex> lock(dataMutex);
            players = playerManager.getAllPlayers();
        }

        // Atualiza o status no painel
        std::string status_text = "<span font='12'>";
        for (const auto& [id, player] : players) {
            status_text += player->nome + " (" + player->id + ")";
            if (player->alive)
                status_text += " <span color='green'>●</span>";
            else
                status_text += " <span color='red'>●</span>";
            status_text += "\n";
        }
        status_text += "</span>";
        lbl_status.set_markup(status_text);

        // Para cada jogador, cria ou move marcador
        for (const auto& [id, player] : players) {
            ChamplainMarker* marker = nullptr;
            auto it = markers.find(id);
            if (it != markers.end()) {
                marker = it->second;
            } else {
                // Cria o marcador e faz cast do ClutterActor para ChamplainMarker
                ClutterActor* actor = champlain_marker_new();
                marker = CHAMPLAIN_MARKER(actor);

                // Define o texto (usando API de label)
                champlain_label_set_text(CHAMPLAIN_LABEL(marker), player->nome.c_str());

                // Define a cor (azul)
                ClutterColor color = { 0, 0, 255, 255 }; // RGBA
                champlain_label_set_color(CHAMPLAIN_LABEL(marker), &color);

                // Adiciona à camada de marcadores
                champlain_marker_layer_add_marker(marker_layer, marker);
                markers[id] = marker;
            }

            // Move o marcador para a posição atual
            champlain_location_set_location(CHAMPLAIN_LOCATION(marker), player->latitude, player->longitude);
        }

        // Opcional: centralizar no primeiro jogador
        if (!players.empty()) {
            auto first = players.begin()->second;
            champlain_view_center_on(view, first->latitude, first->longitude);
        }
    });

    mqtt.start_loop();

    return app->run(window);
}