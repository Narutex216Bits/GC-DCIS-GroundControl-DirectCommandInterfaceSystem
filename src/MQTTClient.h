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