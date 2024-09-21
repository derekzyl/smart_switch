#include <ESP8266WiFi.h>
#include <ESP8266WebServer.h>

ESP8266WebServer server(80);  // Web server running on port 80

void setup() {
  Serial.begin(115200);
  WiFi.softAP("ESP01_Hotspot", "12345678");
    pinMode(0, OUTPUT);
 digitalWrite(0, HIGH);
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
