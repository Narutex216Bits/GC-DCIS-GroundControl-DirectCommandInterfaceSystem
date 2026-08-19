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
        subscribe("cdc/#");
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