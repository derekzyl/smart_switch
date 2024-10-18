#include <Arduino.h>
#include <WiFi.h>
#include <cmath>
#include <EEPROM.h>
#include <LiquidCrystal_I2C.h>
#include <ESPAsyncWebServer.h>
#include <ArduinoJson.h>

#define R1 100000.0 // Resistor R1 value in ohms
#define R2 5600.0   // Resistor R2 value in ohms
#define ADC_PIN 34  // ADC pin where the voltage divider is connected
#define MENU_PIN 18
#define UP_PIN 5
#define DOWN_PIN 19

#define MAX_DEVICES 10
#define DEVICE_BLOCK_SIZE 20  // 16 bytes for device ID, 4 bytes for voltage
#define DEVICE_ID_SIZE 16
#define VOLTAGE_SIZE 4

int setPercentageOffAddress = 2;
int systemTypeAddress = 0;
int percentageAddress = 1;
bool inVoltageSettingMode = false;  // Flag to track if we're in the setting mode

float percentage;
int setPercentageForOff;
float systemType;

// Create WiFi server
AsyncWebServer server(80);
LiquidCrystal_I2C lcd(0x27, 16, 2);  // Set the LCD address to 0x27 for a 16x2 display

void setup() {
  Serial.begin(115200);
  lcd.init();
  lcd.backlight();
    // Pin configuration for buttons
  pinMode(MENU_PIN, INPUT_PULLUP);
  pinMode(UP_PIN, INPUT_PULLUP);
  pinMode(DOWN_PIN, INPUT_PULLUP);

  // Setup WiFi AP
  WiFi.softAP("ESP32_Battery_Monitor");
  WiFi.softAPConfig(IPAddress(192, 168, 1, 1), IPAddress(192, 168, 1, 1), IPAddress(255, 255, 255, 0));

  EEPROM.begin(512);

  analogReadResolution(12);  // ESP32 ADC is 12-bit

  setupWiFiServer();  // Start WiFi server

  // Read percentage, setPercentageForOff, and systemType from EEPROM
  percentage = EEPROM.read(percentageAddress);
  percentage = (percentage < 0 || percentage > 100) ? 0 : percentage;  // Ensure valid percentage range

  setPercentageForOff = EEPROM.read(setPercentageOffAddress);
  setPercentageForOff = (setPercentageForOff < 0) ? 0 : setPercentageForOff;  // Fallback to 0 if invalid

  int storedSystemType = EEPROM.read(systemTypeAddress);
  systemType = (storedSystemType == 12 || storedSystemType == 24 || storedSystemType == 48) ? storedSystemType : 0.0;
}

void loop() {
  float voltage = getVoltage();
  float batteryType = detectBatteryType(voltage);
  float batteryPercentage = calculateBatteryPercentage(voltage, batteryType);

  // Display the voltage and battery percentage on the LCD
  displayOnLCD(voltage, batteryPercentage);

  // Handle button presses to adjust setPercentageForOff
  buttonToSetPercentageOff();
  delay(1000);
}

float getVoltage() {
  float adcValue = analogRead(ADC_PIN);
  
  // Convert ADC value to actual voltage considering voltage divider ratio
  float voltage = adcValue * (3.3 / 4095.0);  // Convert ADC value to voltage
  float actualVoltage = (voltage / (R2 / (R1 + R2))) +3;  // Adjust for voltage divider

  return actualVoltage;
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
  float minVoltage = systemType * 1;
  float maxVoltage = systemType * 1.2;
float minusVoltage = 0.4;

if(systemType >29 && systemType <58){
  minusVoltage = 0.8;
}
if(systemType >12 && systemType <14.5){
  minusVoltage = 0.2;
}




  float newMaxVoltage = maxVoltage-minusVoltage;
  // percentage = (voltage - minVoltage) / (maxVoltage - minVoltage) * 100;
  float c =( (voltage - minVoltage) / (newMaxVoltage - minVoltage)) * 100;
  if (voltage <= minVoltage) {
    c = 0;
  } else if (voltage >= newMaxVoltage) {
    c = 100;
  }
  // float c= map(voltage, minVoltage, maxVoltage, 0, 100);
  percentage = c;
  EEPROM.write(percentageAddress, (int)c);
  EEPROM.commit();
  // return constrain(c, 0, 100);
return c;


}

void displayOnLCD(float voltage, float percentage) {
      int roundedPercentage = static_cast<int>(ceil(percentage));
      int roundedVoltage = static_cast<int>(ceil(voltage));


  if(inVoltageSettingMode== false){
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Volt: ");
  lcd.print(roundedVoltage);
  lcd.print("V");
  lcd.setCursor(9, 0);
  lcd.print("Sys:");
  lcd.print(systemType);
  lcd.print("V");
  lcd.setCursor(0, 1);
  lcd.print("Bat:");
  lcd.print(roundedPercentage);

  lcd.print("%");
  lcd.setCursor(9, 1);
  lcd.print("Off:");
  lcd.print(setPercentageForOff);
  lcd.print("%");
  delay(1000);
  }
}
// void displayOnLCD(float voltage, float percentage) {
//   static int displayIndex = 0;  // Static variable to remember the current display state
//   static unsigned long previousMillis = 0;
//   unsigned long currentMillis = millis();
//   unsigned long interval = 5000;  // 5 seconds per display cycle

//   if (inVoltageSettingMode == false) {
//     if (currentMillis - previousMillis >= interval) {
//       previousMillis = currentMillis;
//       lcd.clear();  // Clear the screen for the new display

//       // Cycle through the display options
//       switch (displayIndex) {
//         case 0:
//           // Display "Voltage" and its value
//           lcd.setCursor(0, 0);
//           lcd.print("Voltage:");
//           lcd.setCursor(0, 1);
//           lcd.print(voltage);
//           lcd.print("V");
//           break;
//         case 1:
//           // Display "Battery %" and its value
//           lcd.setCursor(0, 0);
//           lcd.print("Battery %:");
//           lcd.setCursor(0, 1);
//           lcd.print(percentage);
//           lcd.print("%");
//           break;
//         case 2:
//           // Display "Off %" and its value
//           lcd.setCursor(0, 0);
//           lcd.print("turn of %:");
//           lcd.setCursor(0, 1);
//           lcd.print(setPercentageForOff);
//           lcd.print("%");
//           break;
//       }

//       // Move to the next display item
//       displayIndex++;
//       if (displayIndex > 2) {
//         displayIndex = 0;  // Reset after the last display option
//       }
//     }
//   }
// }


void setupWiFiServer() {
  // Route to set multiple voltages for devices based on JSON input
  server.on("/setPercentageOffs", HTTP_POST, [](AsyncWebServerRequest *request) {}, NULL, [](AsyncWebServerRequest *request, uint8_t *data, size_t len, size_t index, size_t total) {
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
      storePercentageByDeviceId(deviceId, voltage);
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
      int voltage = retrievePercentageByDeviceId(deviceId);

      if (voltage == -1) {
        // If deviceId is not found, use the globally set voltage from EEPROM
        voltage = setPercentageForOff;
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

void buttonToSetPercentageOff() {
  // Check if the menu button is pressed to toggle between modes
  if (digitalRead(MENU_PIN) == LOW) {  // Button press is LOW due to pull-up
    delay(200);  // Debounce delay to prevent multiple toggles
    inVoltageSettingMode = !inVoltageSettingMode;  // Toggle mode
    lcd.clear();
    
    if (inVoltageSettingMode) {
      lcd.setCursor(0, 0);
      lcd.print("Set Mode Active");
      lcd.setCursor(0, 1);
      lcd.print("Set Percentage: ");
    } else {
      lcd.setCursor(0, 0);
      lcd.print("Exiting Mode");
    }

    delay(500);  // Additional delay to avoid immediate toggling
  }

  // Only adjust voltage if in the setting mode
  if (inVoltageSettingMode) {
    // Display the set voltage on the LCD
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("Set Percentage: ");
    lcd.setCursor(0, 1);
    lcd.print(setPercentageForOff);
    lcd.print("%");

    // Check if the up button is pressed to increase voltage
    if (digitalRead(UP_PIN) == LOW) {  // Button press is LOW due to pull-up
      if (setPercentageForOff < 100) {
        setPercentageForOff++;
        delay(200);  // Add a short delay to prevent rapid incrementing
      }
    }

    // Check if the down button is pressed to decrease voltage
    if (digitalRead(DOWN_PIN) == LOW) {  // Button press is LOW due to pull-up
      if (setPercentageForOff > 0) {
        setPercentageForOff--;
        delay(200);  // Add a short delay to prevent rapid decrementing
      }
    }

    // Save the new set voltage to EEPROM
    EEPROM.write(setPercentageOffAddress, setPercentageForOff);
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

void storePercentageByDeviceId(String deviceId, int voltage) {
  int deviceBlockAddress = findDeviceBlock(deviceId);

  if (deviceBlockAddress == -1) {
    // Device ID not found, find the first empty block
    for (int i = 0; i < MAX_DEVICES; i++) {
      int address = i * DEVICE_BLOCK_SIZE;

      // Read device ID from EEPROM
      String storedDeviceId = readDeviceIdFromEEPROM(address);

      // If the block is empty, use this block to store the device ID and voltage
      if (storedDeviceId == "") {
        writeDeviceIdToEEPROM(address, deviceId);
        writePercentageToEEPROM(address + DEVICE_ID_SIZE, voltage);
        break;
      }
    }
  } else {
    // Device ID found, update its voltage
    writePercentageToEEPROM(deviceBlockAddress + DEVICE_ID_SIZE, voltage);
  }

  EEPROM.commit();  // Save changes to EEPROM
}

int retrievePercentageByDeviceId(String deviceId) {
  int deviceBlockAddress = findDeviceBlock(deviceId);

  if (deviceBlockAddress != -1) {
    return readPercentageFromEEPROM(deviceBlockAddress + DEVICE_ID_SIZE);
  }

  return -1;  // Device ID not found
}

String readDeviceIdFromEEPROM(int address) {
  String deviceId = "";
  for (int i = 0; i < DEVICE_ID_SIZE; i++) {
    char c = EEPROM.read(address + i);
    if (c == 0) {
      break;  // Stop if null character is encountered
    }
    deviceId += c;
  }
  return deviceId;
}

void writeDeviceIdToEEPROM(int address, String deviceId) {
  for (int i = 0; i < DEVICE_ID_SIZE; i++) {
    if (i < deviceId.length()) {
      EEPROM.write(address + i, deviceId[i]);
    } else {
      EEPROM.write(address + i, 0);  // Write null character for unused bytes
    }
  }
}

int readPercentageFromEEPROM(int address) {
  int voltage = 0;
  EEPROM.get(address, voltage);
  return voltage;
}

void writePercentageToEEPROM(int address, int voltage) {
  EEPROM.put(address, voltage);
}
