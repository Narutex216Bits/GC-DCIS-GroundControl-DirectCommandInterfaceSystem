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