
#include <Arduino.h>
#include <WiFi.h>
#include <EEPROM.h>
#include <LiquidCrystal_I2C.h>
#include <ESPAsyncWebServer.h>
#include <ArduinoJson.h>

#define R1 100000.0 // resistor R1 value in ohms
#define R2 10000.0  // resistor R2 value in ohms
#define ADC_PIN 34  // ADC pin where the voltage divider is connected
#define MENU_PIN 33
#define UP_PIN 32
#define DOWN_PIN 35

#define MAX_DEVICES 10
#define DEVICE_BLOCK_SIZE 20  // 16 bytes for device ID, 4 bytes for voltage
#define DEVICE_ID_SIZE 16
#define VOLTAGE_SIZE 4

int setVoltageAddress = 2;
int systemTypeAddress = 0;
int percentageAddress = 1;

// Read percentage, setVoltage, and systemType from EEPROM with fallback to 0
float percentage = EEPROM.read(percentageAddress);
percentage = (percentage < 0 || percentage > 100) ? 0 : percentage;  // Ensure valid percentage range

int setVoltage = EEPROM.read(setVoltageAddress);
setVoltage = (setVoltage < 0) ? 0 : setVoltage;  // Fallback to 0 if invalid

float systemType = EEPROM.read(systemTypeAddress);
systemType = (systemType != 12.0 && systemType != 24.0 && systemType != 48.0) ? 0.0 : systemType;  // Fallback to 0 if invalid

// Create WiFi server
AsyncWebServer server(80);

LiquidCrystal_I2C lcd(0x27, 16, 2);  // Set the LCD address to 0x27 for a 16x2 display

void setup() {
  Serial.begin(115200);
  lcd.init();
  lcd.backlight();
  WiFi.softAP("ESP32_Battery_Monitor");
  WiFi.softAPConfig(IPAddress(192, 168, 1, 1), IPAddress(192, 168, 1, 1), IPAddress(255, 255, 255, 0));
  EEPROM.begin(512);

  analogReadResolution(12);  // ESP32 ADC is 12-bit

  setupWiFiServer();  // Start WiFi server
}

void loop() {
  float voltage = getVoltage();
  float batteryType = detectBatteryType(voltage);
  float batteryPercentage = calculateBatteryPercentage(voltage, batteryType);

  // Display the voltage and battery percentage on the LCD
  displayOnLCD(voltage, batteryPercentage);

  // Handle button presses to adjust setVoltage
  buttonToSetVoltage();
}

float getVoltage() {
  int adcValue = analogRead(ADC_PIN);
  float voltage = adcValue * (3.3 / 4095.0);  // Convert ADC value to voltage
  return voltage;
}

float detectBatteryType(float voltage) {
  if (voltage <= 14.4) {
    EEPROM.write(systemTypeAddress, 12);
    systemType = 12.0;
    EEPROM.commit();
    return 12.0;
  } else if (voltage <= 28.8) {
    EEPROM.write(systemTypeAddress, 24);
    systemType = 24.0;
    EEPROM.commit();
    return 24.0;
  } else if (voltage <= 57.6) {
    EEPROM.write(systemTypeAddress, 48);
    systemType = 48.0;
    EEPROM.commit();
    return 48.0;
  } else {
    return 0.0;
  }
}

float calculateBatteryPercentage(float voltage, float systemType) {
  float minVoltage = systemType * 0.7;
  float maxVoltage = systemType * 0.9;
  percentage = (voltage - minVoltage) / (maxVoltage - minVoltage) * 100;
  EEPROM.write(percentageAddress, (int)percentage);
  EEPROM.commit();
  return constrain(percentage, 0, 100);
}

void displayOnLCD(float voltage, float percentage) {
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Voltage: ");
  lcd.print(voltage);
  lcd.print("V");
  lcd.setCursor(0, 1);
  lcd.print("Charge: ");
  lcd.print(percentage);
  lcd.print("%");
}

void setupWiFiServer() {
  // Route to set multiple voltages for devices based on JSON input
  server.on("/setVoltages", HTTP_POST, [](AsyncWebServerRequest *request) {}, NULL, [](AsyncWebServerRequest *request, uint8_t *data, size_t len, size_t index, size_t total) {
    // Create a JSON document object to store incoming data
    StaticJsonDocument<512> jsonDoc;

    // Parse the incoming request body (assumed to be JSON)
    DeserializationError error = deserializeJson(jsonDoc, (const char*)data);
    if (error) {
      request->send(400, "application/json", "{\"error\":\"Invalid JSON format\"}");
      return;
    }

    // Iterate over each key-value pair in the JSON document
    for (JsonPair kv : jsonDoc.as<JsonObject>()) {
      String deviceId = kv.key().c_str();
      int voltage = kv.value().as<int>();

      // Store voltage for that device dynamically
      storeVoltage(deviceId, voltage);
    }

    // Create a JSON response
    String jsonResponse;
    StaticJsonDocument<256> responseDoc;
    responseDoc["status"] = "success";

    serializeJson(responseDoc, jsonResponse);
    request->send(200, "application/json", jsonResponse);
  });

  server.on("/getVoltageById", HTTP_GET, [](AsyncWebServerRequest *request) {
    if (request->hasParam("deviceId")) {
      String deviceId = request->getParam("deviceId")->value();
      int voltage = retrieveVoltage(deviceId);

      if (voltage == -1) {
        // If deviceId is not found, use the globally set voltage from EEPROM
        voltage = setVoltage;
      }

      // Send response in JSON format
      StaticJsonDocument<200> jsonResponse;
      jsonResponse["deviceId"] = deviceId;
      jsonResponse["voltage"] = voltage;
      jsonResponse["systemType"] = systemType;
      jsonResponse["percentage"] = percentage;

      String response;
      serializeJson(jsonResponse, response);
      request->send(200, "application/json", response);
    } else {
      // If deviceId parameter is missing, return error
      request->send(400, "application/json", "{\"error\":\"Missing deviceId parameter\"}");
    }
  });

  server.begin();
}

void buttonToSetVoltage() {
  // Check if the menu button is pressed to enter voltage setting mode
  if (digitalRead(MENU_PIN) == HIGH) {
    // Display the set voltage on the LCD
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("Set Voltage: ");
    lcd.print(setVoltage);
    lcd.print("%");

    // Check if the up button is pressed to increase voltage
    if (digitalRead(UP_PIN) == HIGH) {
      if (setVoltage < 100) {
        setVoltage++;
        delay(200);  // Add a short delay to prevent rapid incrementing
      }
    }

    // Check if the down button is pressed to decrease voltage
    if (digitalRead(DOWN_PIN) == HIGH) {
      if (setVoltage > 0) {
        setVoltage--;
        delay(200);  // Add a short delay to prevent rapid decrementing
      }
    }
    EEPROM.write(setVoltageAddress, setVoltage);
    EEPROM.commit();
  }
}

// Function to find the EEPROM block for a given device ID
int findDeviceBlock(String deviceId) {
  for (int i = 0; i < MAX_DEVICES; i++) {
    int address = i * DEVICE_BLOCK_SIZE;

    // Read device ID from EEPROM
    String storedDeviceId = readDeviceIdFromEEPROM(address);

    if (storedDeviceId == deviceId) {
      return address;  // Found the device's block
    }
  }
  return -1;  // Device not found
}

// Function to assign a new block if the device ID is not already stored
int assignNewDeviceBlock(String deviceId) {
  for (int i = 0; i < MAX_DEVICES; i++) {
    int address = i * DEVICE_BLOCK_SIZE;

    // Check if the block is empty (no device stored)
    String storedDeviceId = readDeviceIdFromEEPROM(address);

    if (storedDeviceId.length() == 0) {
      // Empty block found, store the new device ID
      writeDeviceIdToEEPROM(address, deviceId);
      return address;
    }
  }
  return -1;  // No available block
}

// Function to read the device ID from EEPROM
String readDeviceIdFromEEPROM(int address) {
  char deviceId[DEVICE_ID_SIZE];
  for (int i = 0; i < DEVICE_ID_SIZE; i++) {
    deviceId[i] = EEPROM.read(address + i);
  }
  return String(deviceId);
}

// Function to write the device ID to EEPROM
void writeDeviceIdToEEPROM(int address, String deviceId) {
  for (int i = 0; i < DEVICE_ID_SIZE; i++) {
    EEPROM.write(address + i, deviceId[i]);
  }
  EEPROM.commit();
}

// Function to store the voltage for a given device
void storeVoltage(String deviceId, int voltage) {
  int deviceAddress = findDeviceBlock(deviceId);

  if (deviceAddress == -1) {
    // Device not found, assign a new block
    deviceAddress = assignNewDeviceBlock(deviceId);

    if (deviceAddress == -1) {
      Serial.println("Error: No available space for new device.");
      return;
    }
  }

  // Store voltage in the block
  EEPROM.put(deviceAddress + DEVICE_ID_SIZE, voltage);  // Store voltage after device ID
  EEPROM.commit();
  Serial.println("Stored voltage " + String(voltage) + " for device " + deviceId);
}

// Function to retrieve the voltage for a given device
int retrieveVoltage(String deviceId) {
  int deviceAddress = findDeviceBlock(deviceId);

  if (deviceAddress != -1) {
    int voltage;
    EEPROM.get(deviceAddress + DEVICE_ID_SIZE, voltage);  // Get voltage after device ID
    return voltage;
  }

  return -1;  // Device not found
}
