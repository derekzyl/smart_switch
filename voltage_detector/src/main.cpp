#include <Arduino.h>
#include <WiFi.h>
#include <LiquidCrystal_I2C.h>

#define R1 100000.0 // resistor R1 value in ohms
#define R2 10000.0 // resistor R2 value in ohms
#define ADC_PIN 34 // ADC pin where the voltage divider is connected

LiquidCrystal_I2C lcd(0x27, 16, 2); // Set the LCD address to 0x27 for a 16x2 display

void setup() {
  Serial.begin(115200);
  lcd.begin();
  lcd.backlight();
  WiFi.softAP("ESP32_Battery_Monitor");

  analogReadResolution(12); // ESP32 ADC is 12-bit
}

void loop() {
  float adcValue = analogRead(ADC_PIN);
  float voltage = adcValue * (3.3 / 4095.0) * ((R1 + R2) / R2); // Convert ADC reading to voltage

  // Determine battery system type
  String systemType = "Unknown";
  float percentage = 0.0;

  if (voltage <= 14.4) {
    systemType = "12V";
    percentage = (voltage - 10.5) / (14.4 - 10.5) * 100;
  } else if (voltage <= 28.8) {
    systemType = "24V";
    percentage = (voltage - 21.0) / (28.8 - 21.0) * 100;
  } else if (voltage <= 57.6) {
    systemType = "48V";
    percentage = (voltage - 42.0) / (57.6 - 42.0) * 100;
  }

  // Clamp percentage between 0% and 100%
  percentage = constrain(percentage, 0, 100);

  // Display on LCD
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Voltage: ");
  lcd.print(voltage);
  lcd.setCursor(0, 1);
  lcd.print("Charge: ");
  lcd.print(percentage);
  lcd.print("%");

  // Send data over Wi-Fi (simple HTTP server)
  WiFiClient client = WiFi.softAPgetStationNum();
  if (client) {
    String response = "Battery Voltage: " + String(voltage) + "V\n";
    response += "Battery Percentage: " + String(percentage) + "%";
    client.print(response);
    delay(1000);
  }

  delay(5000); // Adjust delay as needed
}
