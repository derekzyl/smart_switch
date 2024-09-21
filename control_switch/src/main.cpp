#include <ESP8266WiFi.h>
#include <ESP8266HTTPClient.h>
#include <ArduinoJson.h>

#define RELAY_PIN 1  // GPIO1
#define LED_PIN 0    // GPIO0

const char* ssid = "ESP32_Battery_Monitor";
const char* password = "";  // Set if the ESP32 has a password
const char* serverIP = "192.168.1.1";  // IP address of the ESP32
const char* deviceId = "myDeviceId";  // Device ID to query

float setPercentage = 50;  // Set this to your threshold percentage

void setup() {
  Serial.begin(115200);
  pinMode(RELAY_PIN, OUTPUT);
  pinMode(LED_PIN, OUTPUT);

  // Initialize WiFi
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("Connected to WiFi");
}

void loop() {
  if (WiFi.status() == WL_CONNECTED) {
    HTTPClient http;
       String url = String("http://") + serverIP + "/getVoltageById?deviceId=" + deviceId;
  
    http.begin(url);

    int httpCode = http.GET();
    if (httpCode > 0) {
           digitalWrite(LED_PIN, LOW); // Turn on LED
      String payload = http.getString();
      Serial.println(payload);

      // Parse JSON response
      StaticJsonDocument<200> jsonDoc;
      DeserializationError error = deserializeJson(jsonDoc, payload);
      if (!error) {
        float voltage = jsonDoc["voltage"];
     char* device = jsonDoc["deviceId"];
     if(deviceId != device){
        Serial.println("Device ID does not match");
        return;
      }

        if(voltage){
          setPercentage = voltage;
        }
        float percentage = jsonDoc["percentage"];

        // Print values for debugging
        Serial.print("Voltage: ");
        Serial.println(voltage);
        Serial.print("Percentage: ");
        Serial.println(percentage);

        // Control relay and LED based on percentage
        if (percentage <= setPercentage) {
          digitalWrite(RELAY_PIN, HIGH); // Turn off relay
        // Turn on LED
        } else {
          digitalWrite(RELAY_PIN, LOW);  // Turn on relay
          // Turn off LED
        }
      } else {
        Serial.println("Failed to parse JSON");
      }
    } else {
      Serial.println("HTTP GET request failed");
    }
    http.end();
  } else {
       digitalWrite(LED_PIN, HIGH); // Turn on LED
    Serial.println("Disconnected from WiFi");
  }

  delay(60000);  // Delay before next check (e.g., 1 minute)
}



#include <ESP8266WiFi.h>
#include <ESP8266WebServer.h>

ESP8266WebServer server(80);  // Web server running on port 80

void setup() {
  Serial.begin(115200);
  WiFi.softAP("ESP01_Hotspot", "12345678");

  // Start the server
  server.on("/", handleRoot);  // When accessing the root page
  server.begin();
  Serial.println("Web server started.");
}

void handleRoot() {
  server.send(200, "text/html", "<h1>Hello from ESP01!</h1>");
}

void loop() {
  server.handleClient();  // Handle web requests
}
