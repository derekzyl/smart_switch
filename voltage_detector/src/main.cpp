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

#define MAX_DEVICES 20
#define DEVICE_BLOCK_SIZE 20  // 16 bytes for device ID, 4 bytes for voltage
#define DEVICE_ID_SIZE 20
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

// Function prototypes
float getVoltage();
float detectBatteryType(float voltage);
float calculateBatteryPercentage(float voltage, float systemType);
void displayOnLCD(float voltage, float percentage);
void buttonToSetPercentageOff();
void setupWiFiServer();
int findDeviceBlock(String deviceId);
void storePercentageByDeviceId(String deviceId, int voltage);
int retrievePercentageByDeviceId(String deviceId);
String readDeviceIdFromEEPROM(int address);
void writeDeviceIdToEEPROM(int address, String deviceId);
int readPercentageFromEEPROM(int address);
void writePercentageToEEPROM(int address, int voltage);
bool deleteDeviceFromEEPROM(String deviceId);

void setup() {
  Serial.begin(115200);
  EEPROM.begin(512);
  lcd.init();
  lcd.backlight();
  // Pin configuration for buttons
  pinMode(MENU_PIN, INPUT_PULLUP);
  pinMode(UP_PIN, INPUT_PULLUP);
  pinMode(DOWN_PIN, INPUT_PULLUP);

  // Setup WiFi AP
  WiFi.softAP("ESP32_Battery_Monitor");
  WiFi.softAPConfig(IPAddress(192, 168, 1, 1), IPAddress(192, 168, 1, 1), IPAddress(255, 255, 255, 0));
Serial.println("IP Address: welcome to the server");

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
  float actualVoltage = (voltage / (R2 / (R1 + R2))) + 3;  // Adjust for voltage divider

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

  if (systemType > 29 && systemType < 58) {
    minusVoltage = 0.8;
  }

  if (systemType > 12 && systemType < 14.5) {
    minusVoltage = 0.2;
  }

  float newMaxVoltage = maxVoltage - minusVoltage;
  float c = ((voltage - minVoltage) / (newMaxVoltage - minVoltage)) * 100;
  if (voltage <= minVoltage) {
    c = 0;
  } else if (voltage >= newMaxVoltage) {
    c = 100;
  }
  percentage = c;
  EEPROM.write(percentageAddress, (int)c);
  EEPROM.commit();
  return c;
}

/**
 * The function `displayOnLCD` displays voltage and battery percentage on an LCD screen in a specific
 * format.
 * 
 * @param voltage The `displayOnLCD` function takes two parameters: `voltage` and `percentage`. The
 * `voltage` parameter is a float representing the voltage value, and the `percentage` parameter is a
 * float representing a percentage value. The function then displays these values on an LCD screen with
 * some additional
 * @param percentage The `percentage` parameter in the `displayOnLCD` function represents the battery
 * percentage level that you want to display on the LCD screen. It is a floating-point value that
 * indicates the current battery level as a percentage.
 */
void displayOnLCD(float voltage, float percentage) {
  int roundedPercentage = static_cast<int>(ceil(percentage));
  int roundedVoltage = static_cast<int>(ceil(voltage));

  if (inVoltageSettingMode == false) {
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



/**
 * The setupWiFiServer function sets up routes for handling HTTP POST and GET requests related to
 * storing, retrieving, and deleting device voltage data in JSON format.
 * 
 * @return The code snippet provided is setting up a WiFi server with various endpoints for handling
 * HTTP requests related to setting and retrieving voltage values for devices, as well as deleting
 * devices.
 */
void setupWiFiServer() {
  

#include <ArduinoJson.h>

// In the setupWiFiServer() function:
server.on("/setPercentageOffs", HTTP_POST, [](AsyncWebServerRequest *request) {}, NULL, [](AsyncWebServerRequest *request, uint8_t *data, size_t len, size_t index, size_t total) {
    // Create a JSON document object to store incoming data
    JsonDocument jsonDoc;
    DeserializationError error = deserializeJson(jsonDoc, (const char*)data);
    if (error) {
        request->send(400, "application/json", "{\"error\":\"Invalid JSON format\"}");
        return;
    }

    // ... rest of the function remains the same ...


    
    // Iterate over each key-value pair in the JSON document
    for (JsonPair kv : jsonDoc.as<JsonObject>()) {
      String deviceId = kv.key().c_str();
      int voltage = kv.value().as<int>();

      // Store voltage for that device dynamically
      storePercentageByDeviceId(deviceId, voltage);
    }
 EEPROM.commit(); 
    // Create a JSON response
   







    // Create a JSON response
    JsonDocument responseDoc;
    responseDoc["status"] = "success";

    String jsonResponse;
    serializeJson(responseDoc, jsonResponse);
    request->send(200, "application/json", jsonResponse);
});

server.on("/getVoltageById", HTTP_GET, [](AsyncWebServerRequest *request) {
    if (request->hasParam("deviceId")) {
        String deviceId = request->getParam("deviceId")->value();
        int voltage = retrievePercentageByDeviceId(deviceId);

        if (voltage == -1) {
            voltage = setPercentageForOff;
        }

        // Send response in JSON format
        JsonDocument jsonResponse;
        jsonResponse["deviceId"] = deviceId;
        jsonResponse["voltage"] = voltage;
        jsonResponse["systemType"] = systemType;
        jsonResponse["percentage"] = percentage;

        String response;
        serializeJson(jsonResponse, response);
        request->send(200, "application/json", response);
    } else {
        request->send(400, "application/json", "{\"error\":\"Missing deviceId parameter\"}");
    }
});

server.on("/deleteDevice", HTTP_POST, [](AsyncWebServerRequest *request) {}, NULL, [](AsyncWebServerRequest *request, uint8_t *data, size_t len, size_t index, size_t total) {
    JsonDocument jsonDoc;
    DeserializationError error = deserializeJson(jsonDoc, (const char*)data);
    
    if (error) {
        request->send(400, "application/json", "{\"error\":\"Invalid JSON format\"}");
        return;
    }

    String deviceId = jsonDoc["deviceId"].as<String>();
    bool deleted = deleteDeviceFromEEPROM(deviceId);

    if (deleted) {
        request->send(200, "application/json", "{\"status\":\"success\",\"message\":\"Device deleted\"}");
    } else {
        request->send(404, "application/json", "{\"error\":\"Device not found\"}");
    }
});

  server.begin();





}

/**
 * The function `buttonToSetPercentageOff` allows toggling between setting modes and adjusting a
 * percentage value based on button inputs.
 */
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
/**
 * The function `findDeviceBlock` searches for a device block in EEPROM based on the device ID and
 * returns the address of the block if found, otherwise returns -1.
 * 
 * @param deviceId The `deviceId` parameter is a string representing the unique identifier of a device
 * that we are searching for in the EEPROM memory. The function `findDeviceBlock` iterates through the
 * EEPROM memory blocks to find the block that stores the device with the specified `deviceId`.
 * 
 * @return The function `findDeviceBlock` returns the address of the device block if the device ID
 * matches with the stored device ID in the EEPROM. If the device is not found, it returns -1.
 */
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

/**
 * The function `storePercentageByDeviceId` stores or updates the percentage value associated with a
 * device ID in EEPROM memory.
 * 
 * @param deviceId The `deviceId` parameter is a string that represents the unique identifier of a
 * device for which you want to store or update the percentage value.
 * @param percentage The `percentage` parameter in the `storePercentageByDeviceId` function represents
 * the percentage value that you want to store for a specific device identified by its `deviceId`. This
 * function is responsible for storing or updating the percentage value associated with a device in the
 * EEPROM memory.
 */
void storePercentageByDeviceId(String deviceId, int percentage) {
  int deviceBlockAddress = findDeviceBlock(deviceId);

  if (deviceBlockAddress == -1) {
    // Device ID not found, find the first empty block
    for (int i = 0; i < MAX_DEVICES; i++) {
      int address = i * DEVICE_BLOCK_SIZE;

      // Read device ID from EEPROM
      String storedDeviceId = readDeviceIdFromEEPROM(address);

      // If the block is empty, use this block to store the device ID and percentage
      if (storedDeviceId == "") {
        writeDeviceIdToEEPROM(address, deviceId);
        writePercentageToEEPROM(address + DEVICE_ID_SIZE, percentage);
         Serial.println("New device stored: " + deviceId + " with percentage: " + String(percentage));
        break;
      }
    }
  } else {
    // Device ID found, update its percentage
    writePercentageToEEPROM(deviceBlockAddress + DEVICE_ID_SIZE, percentage);
      Serial.println("Updated device: " + deviceId + " with new percentage: " + String(percentage));
  }

  EEPROM.commit();  // Save changes to EEPROM
}



/**
 * This C++ function retrieves the percentage value associated with a device ID from EEPROM memory.
 * 
 * @param deviceId The `retrievePercentageByDeviceId` method takes a `deviceId` as a parameter. This
 * method is used to retrieve the percentage value associated with a specific device ID. The `deviceId`
 * is a unique identifier for a device stored in the system.
 * 
 * @return The method `retrievePercentageByDeviceId` returns an integer value representing the
 * percentage retrieved from the EEPROM based on the device ID. If the device ID is found, the
 * percentage value is returned. If the device ID is not found, the method returns -1 to indicate that
 * the device ID was not found.
 */
int retrievePercentageByDeviceId(String deviceId) {
  int deviceBlockAddress = findDeviceBlock(deviceId);

  if (deviceBlockAddress != -1) {
    return readPercentageFromEEPROM(deviceBlockAddress + DEVICE_ID_SIZE);
  }

  return -1;  // Device ID not found
}

/**
 * The function reads a device ID stored in EEPROM memory starting from a specified address and returns
 * it as a String.
 * 
 * @param address The `address` parameter in the `readDeviceIdFromEEPROM` function represents the
 * starting address in the EEPROM (Electrically Erasable Programmable Read-Only Memory) from which the
 * device ID will be read. The function reads characters from the EEPROM starting at the specified
 * address and continues until
 * 
 * @return The function `readDeviceIdFromEEPROM` returns a String containing the device ID read from
 * the EEPROM starting at the specified address.
 */
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

/**
 * The function writes a device ID string to EEPROM memory, padding with null characters if necessary.
 * 
 * @param address The `address` parameter is the starting address in the EEPROM (Electrically Erasable
 * Programmable Read-Only Memory) where the device ID will be written.
 * @param deviceId The `deviceId` parameter is a string that represents the unique identifier of a
 * device. It is used to store the device ID in the EEPROM memory starting at the specified address.
 */
void writeDeviceIdToEEPROM(int address, String deviceId) {
  for (int i = 0; i < DEVICE_ID_SIZE; i++) {
    if (i < deviceId.length()) {
      EEPROM.write(address + i, deviceId[i]);
    } else {
      EEPROM.write(address + i, 0);  // Write null character for unused bytes
    }
  }
}

/**
 * The function reads a percentage value from EEPROM at a specified address and prints the value and
 * address to the Serial monitor.
 * 
 * @param address The `address` parameter in the `readPercentageFromEEPROM` function is the memory
 * address in the EEPROM from which the percentage value needs to be read.
 * 
 * @return The function `readPercentageFromEEPROM` is returning the voltage value read from the EEPROM
 * at the specified address.
 */
int readPercentageFromEEPROM(int address) {
  int voltage = 0;
  EEPROM.get(address, voltage);
  Serial.println("Read percentage " + String(voltage) + " from address " + String(address));
  return voltage;
}

void writePercentageToEEPROM(int address, int voltage) {
  EEPROM.put(address, voltage);
  Serial.println("Writing percentage " + String(voltage) + " to address " + String(address));

}






/**
 * The function `deleteDeviceFromEEPROM` deletes a device block from EEPROM based on the device ID
 * provided.
 * 
 * @param deviceId The `deleteDeviceFromEEPROM` function takes a `String` parameter `deviceId`, which
 * represents the unique identifier of the device that needs to be deleted from the EEPROM memory. The
 * function searches for the device block in the EEPROM based on this `deviceId` and clears the block
 * if found, returning
 * 
 * @return The function `deleteDeviceFromEEPROM` returns a boolean value - `true` if the device block
 * was successfully cleared from EEPROM, and `false` if the device block was not found.
 */
bool deleteDeviceFromEEPROM(String deviceId) {
  int deviceBlockAddress = findDeviceBlock(deviceId);

  if (deviceBlockAddress != -1) {
    // Clear the device block in EEPROM
    for (int i = 0; i < DEVICE_BLOCK_SIZE; i++) {
      EEPROM.write(deviceBlockAddress + i, 0);
    }
    EEPROM.commit();
    return true;
  }

  return false;
}




// Route to set multiple voltages for devices based on JSON input
//   server.on("/setPercentageOffs", HTTP_POST, [](AsyncWebServerRequest *request) {}, NULL, [](AsyncWebServerRequest *request, uint8_t *data, size_t len, size_t index, size_t total) {
//     // Create a JSON document object to store incoming data
//     StaticJsonDocument<512> jsonDoc;

//     // Parse the incoming request body (assumed to be JSON)
//     DeserializationError error = deserializeJson(jsonDoc, (const char*)data);
//     if (error) {
//       request->send(400, "application/json", "{\"error\":\"Invalid JSON format\"}");
//       return;
//     }

//     // Iterate over each key-value pair in the JSON document
//     for (JsonPair kv : jsonDoc.as<JsonObject>()) {
//       String deviceId = kv.key().c_str();
//       int voltage = kv.value().as<int>();

//       // Store voltage for that device dynamically
//       storePercentageByDeviceId(deviceId, voltage);
//     }
//  EEPROM.commit(); 
//     // Create a JSON response
//     String jsonResponse;
//     StaticJsonDocument<256> responseDoc;
//     responseDoc["status"] = "success";

//     serializeJson(responseDoc, jsonResponse);
//     request->send(200, "application/json", jsonResponse);
//   });

//   server.on("/getVoltageById", HTTP_GET, [](AsyncWebServerRequest *request) {
//     if (request->hasParam("deviceId")) {
//       String deviceId = request->getParam("deviceId")->value();
//       int voltage = retrievePercentageByDeviceId(deviceId);

//       if (voltage == -1) {
//         // If deviceId is not found, use the globally set voltage from EEPROM
//         voltage = setPercentageForOff;
//       }

//       // Send response in JSON format
//       StaticJsonDocument<200> jsonResponse;
//       jsonResponse["deviceId"] = deviceId;
//       jsonResponse["voltage"] = voltage;
//       jsonResponse["systemType"] = systemType;
//       jsonResponse["percentage"] = percentage;

//       String response;
//       serializeJson(jsonResponse, response);
//       request->send(200, "application/json", response);
//     } else {
//       // If deviceId parameter is missing, return error
//       request->send(400, "application/json", "{\"error\":\"Missing deviceId parameter\"}");
//     }
//   });
// server.on("/deleteDevice", HTTP_POST, [](AsyncWebServerRequest *request) {}, NULL, [](AsyncWebServerRequest *request, uint8_t *data, size_t len, size_t index, size_t total) {
//     StaticJsonDocument<256> jsonDoc;
//     DeserializationError error = deserializeJson(jsonDoc, (const char*)data);
    
//     if (error) {
//       request->send(400, "application/json", "{\"error\":\"Invalid JSON format\"}");
//       return;
//     }

//     String deviceId = jsonDoc["deviceId"].as<String>();
//     bool deleted = deleteDeviceFromEEPROM(deviceId);

//     if (deleted) {
//       request->send(200, "application/json", "{\"status\":\"success\",\"message\":\"Device deleted\"}");
//     } else {
//       request->send(404, "application/json", "{\"error\":\"Device not found\"}");
//     }
//   });
