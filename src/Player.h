#ifndef PLAYER_H
#define PLAYER_H

#include <string>

struct Player {
    std::string id;
    std::string nome;
    double latitude = 0.0;
    double longitude = 0.0;
    int magazines = 0;   // carregadores restantes
    int ammo = 0;        // munição no carregador atual
    bool alive = true;
    int kills = 0;
    int deaths = 0;
};

#endif