#include <Arduino.h>
#include <ESP8266WiFi.h>

const char* ssid = "ESP32_Hotspot";
const char* password = "password";
int relayPin = 2;

void setup() {
  pinMode(relayPin, OUTPUT);
  digitalWrite(relayPin, LOW);

  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
  }
}

void loop() {
  WiFiClient client;
  if (client.connect("ESP32_Hotspot_IP", 80)) {
    String percentage = client.readStringUntil('\n');
    int batteryPercentage = percentage.toInt();

    if (batteryPercentage > 50) {
      digitalWrite(relayPin, HIGH);
    } else {
      digitalWrite(relayPin, LOW);
    }
  }

  delay(1000);
}
