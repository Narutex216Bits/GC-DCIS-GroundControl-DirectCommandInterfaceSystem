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