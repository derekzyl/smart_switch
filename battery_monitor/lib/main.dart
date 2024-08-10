import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(BatteryMonitorApp());
}

class BatteryMonitorApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Battery Monitor',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: BatteryMonitorScreen(),
    );
  }
}

class BatteryMonitorScreen extends StatefulWidget {
  @override
  _BatteryMonitorScreenState createState() => _BatteryMonitorScreenState();
}

class _BatteryMonitorScreenState extends State<BatteryMonitorScreen> {
  int batteryPercentage = 0;

  @override
  void initState() {
    super.initState();
    _fetchBatteryData();
  }

  Future<void> _fetchBatteryData() async {
    try {
      // Replace with the ESP32's IP address and endpoint
      final response = await http.get(Uri.parse('http://192.168.4.1/battery'));
      if (response.statusCode == 200) {
        setState(() {
          batteryPercentage = int.parse(response.body.trim());
        });
      } else {
        throw Exception('Failed to load battery data');
      }
    } catch (e) {
      print("Error fetching battery data: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Battery Monitor'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'Battery Percentage:',
              style: TextStyle(fontSize: 24),
            ),
            SizedBox(height: 20),
            Text(
              '$batteryPercentage%',
              style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 40),
            ElevatedButton(
              onPressed: _fetchBatteryData,
              child: Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }
}
