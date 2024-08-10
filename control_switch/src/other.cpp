#include <ESP8266WiFi.h>
#include <SevSeg.h>

// WiFi settings
const char* ssid = "ESP32_Hotspot";
const char* password = "password";

// Hardware connections
int relayPin = 2;         // GPIO2 for Relay
int buttonPin = 0;        // GPIO0 for Button
int tripPercentage = 50;  // Default trip percentage

// 7-Segment Display setup
SevSeg sevseg;
int displayPins[8] = {D1, D2, D3, D4, D5, D6, D7, D8}; // Change to your ESP8266 pin numbers

void setup() {
  // Set up relay pin
  pinMode(relayPin, OUTPUT);
  digitalWrite(relayPin, LOW);

  // Set up button pin
  pinMode(buttonPin, INPUT);

  // Initialize WiFi connection
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
  }

  // Set up 7-segment display
  byte numDigits = 2; 
  byte digitPins[] = {D0, D1}; // GPIO pins connected to digit control lines
  byte segmentPins[] = {D2, D3, D4, D5, D6, D7, D8}; // GPIO pins connected to segment control lines
  sevseg.begin(COMMON_ANODE, numDigits, digitPins, segmentPins);
  sevseg.setBrightness(90);
}

void loop() {
  // Check if the button is pressed to increase the trip percentage
  if (digitalRead(buttonPin) == HIGH) {
    tripPercentage += 5;
    if (tripPercentage > 100) {
      tripPercentage = 0; // Reset to 0% if it exceeds 100%
    }
    delay(300); // Debounce delay
  }

  // Show the trip percentage on the 7-segment display
  sevseg.setNumber(tripPercentage, 0);
  sevseg.refreshDisplay(); // Must be called repeatedly

  // Connect to the ESP32 server and read the battery percentage
  WiFiClient client;
  if (client.connect("192.168.4.1", 80)) { //IP of ESP32
    String percentage = client.readStringUntil('\n');
    int batteryPercentage = percentage.toInt();

    // Control the relay based on the battery percentage
    if (batteryPercentage > tripPercentage) {
      digitalWrite(relayPin, HIGH);
    } else {
      digitalWrite(relayPin, LOW);
    }
  }

  delay(1000); // Delay between updates
}
