#include <ESP8266WiFi.h>
#include <ESP8266HTTPClient.h>
#include <ArduinoJson.h>

int RELAY_PIN =2;  // GPIO1
int LED_PIN =0;    // GPIO0

String ssid = "ESP32_Battery_Monitor";  // Wi-Fi network SSID
String password = "";  // Wi-Fi password (set if needed)
String apSSID = "ESP01_Hotspot";  // Hotspot SSID
String apPassword = "12345678";  // Hotspot password (must be at least 8 characters)
String serverIP = "192.168.1.1";  // IP address of the ESP32
String deviceId = "myDeviceId";  // Device ID to query

float setPercentage = 50;  // Set this to your threshold percentage

WiFiClient client;  // Declare a WiFiClient object

void setup() {
  Serial.begin(115200);
  pinMode(RELAY_PIN, OUTPUT);
  pinMode(LED_PIN, OUTPUT);
    digitalWrite(LED_PIN, HIGH);
    digitalWrite(RELAY_PIN, HIGH);

  // Initialize Hotspot (SoftAP Mode)
  WiFi.softAP(apSSID, apPassword);
  Serial.println("Hotspot Started");
  Serial.print("IP address of Hotspot: ");
  Serial.println(WiFi.softAPIP());

  // Initialize WiFi (Station Mode)
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("Connected to WiFi");
  
  // Turn off LED and relay initially

//   digitalWrite(RELAY_PIN, HIGH);
}

void loop() {
  // Turn on LED to indicate the device is ON

  
  if (WiFi.status() == WL_CONNECTED) {
  digitalWrite(LED_PIN, LOW);
  // digitalWrite(LED_PIN, LOW);


    HTTPClient http;
    String url = String("http://") + serverIP + "/getVoltageById?deviceId=" + deviceId;

    // Use the updated API for http.begin, pass the WiFiClient object and the URL
    http.begin(client, url);

    int httpCode = http.GET();
    if (httpCode > 0) {
      String payload = http.getString();
      Serial.println(payload);

      // Parse JSON response
      StaticJsonDocument<200> jsonDoc;
      DeserializationError error = deserializeJson(jsonDoc, payload);
      if (!error) {
        float voltage = jsonDoc["voltage"];
        String device = jsonDoc["deviceId"];
        if (deviceId != device) {
          Serial.println("Device ID does not match");
          return;
        }

        if (voltage) {
          setPercentage = voltage;
        }
        float currentPercentage = jsonDoc["percentage"];

        // Print values for debugging
        Serial.print("Voltage: ");
        Serial.println(voltage);
        Serial.print("Percentage: ");
        Serial.println( currentPercentage);

        // Control relay and LED based on percentage
        if ( currentPercentage <= setPercentage) {
          digitalWrite(RELAY_PIN, HIGH);  // Turn off relay
          // digitalWrite(LED_PIN, HIGH);    // Turn on LED
        } else {
          digitalWrite(RELAY_PIN, LOW);   // Turn on relay
          // digitalWrite(LED_PIN, LOW);     // Turn off LED
        }
      } else {
        Serial.println("Failed to parse JSON");
      }
    } else {
      Serial.println("HTTP GET request failed");
    }
    http.end();
  } else {
          digitalWrite(RELAY_PIN, HIGH);  // Turn off relay

    digitalWrite(LED_PIN, HIGH);  // Turn on LED
    Serial.println("Disconnected from WiFi");
  }

  delay(60000);  // Delay before next check (1 second)
}
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          