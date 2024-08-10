#ifndef BATTERY_MONITOR_H
#define BATTERY_MONITOR_H


class BatteryMonitor{
    public:
    BatteryMonitor(int pin);
    float readVoltage();
    float  calculatePercentage();
};

#endif