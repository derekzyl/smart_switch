// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';

// void main() {
//   runApp(BatteryMonitorApp());
// }

// class BatteryMonitorApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Battery Monitor',
//       theme: ThemeData(
//         primarySwatch: Colors.blue,
//       ),
//       home: BatteryMonitorScreen(),
//     );
//   }
// }

// class BatteryMonitorScreen extends StatefulWidget {
//   @override
//   _BatteryMonitorScreenState createState() => _BatteryMonitorScreenState();
// }

// class _BatteryMonitorScreenState extends State<BatteryMonitorScreen> {
//   int batteryPercentage = 0;

//   @override
//   void initState() {
//     super.initState();
//     _fetchBatteryData();
//   }

//   Future<void> _fetchBatteryData() async {
//     try {
//       // Replace with the ESP32's IP address and endpoint
//       final response = await http.get(Uri.parse('http://192.168.4.1/battery'));
//       if (response.statusCode == 200) {
//         setState(() {
//           batteryPercentage = int.parse(response.body.trim());
//         });
//       } else {
//         throw Exception('Failed to load battery data');
//       }
//     } catch (e) {
//       print("Error fetching battery data: $e");
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Battery Monitor'),
//       ),
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: <Widget>[
//             Text(
//               'Battery Percentage:',
//               style: TextStyle(fontSize: 24),
//             ),
//             SizedBox(height: 20),
//             Text(
//               '$batteryPercentage%',
//               style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
//             ),
//             SizedBox(height: 40),
//             ElevatedButton(
//               onPressed: _fetchBatteryData,
//               child: Text('Refresh'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_neumorphic/flutter_neumorphic.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return NeumorphicApp(
      debugShowCheckedModeBanner: false,
      title: 'ESP32 Battery Monitor',
      themeMode: ThemeMode.light,
      theme: NeumorphicThemeData(
        baseColor: Color(0xFFE0E0E0),
        lightSource: LightSource.topLeft,
        depth: 10,
      ),
      home: HomePage(),
    );
  }
}

class Device {
  final String id;
  int percentage;
  int? systemType;
  double? batteryPercentage;

  Device({required this.id, required this.percentage, this.systemType, this.batteryPercentage});

  Map<String, dynamic> toJson() => {
    'id': id,
    'percentage': percentage,
    'systemType': systemType,
    'batteryPercentage': batteryPercentage,
  };

  factory Device.fromJson(Map<String, dynamic> json) => Device(
    id: json['id'],
    percentage: json['percentage'],
    systemType: json['systemType'],
    batteryPercentage: json['batteryPercentage'],
  );
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _formKey = GlobalKey<FormState>();
  List<Device> _devices = [];
  String _newDeviceId = '';
  int _newDevicePercentage = 0;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    final prefs = await SharedPreferences.getInstance();
    final devicesJson = prefs.getString('devices');
    if (devicesJson != null) {
      final devicesList = jsonDecode(devicesJson) as List;
      setState(() {
        _devices = devicesList.map((device) => Device.fromJson(device)).toList();
      });
    }
  }

  Future<void> _saveDevices() async {
    final prefs = await SharedPreferences.getInstance();
    final devicesJson = jsonEncode(_devices.map((device) => device.toJson()).toList());
    await prefs.setString('devices', devicesJson);
  }

  void _addDevice() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() {
        _devices.add(Device(id: _newDeviceId, percentage: _newDevicePercentage));
        _newDeviceId = '';
        _newDevicePercentage = 0;
      });
      _saveDevices();
    }
  }

  Future<void> _sendDataToESP32() async {
    final url = Uri.parse('http://192.168.1.1/setPercentageOffs');
    final deviceMap = {for (var device in _devices) device.id: device.percentage};
    try {
      final response = await http.post(
        url,
        body: jsonEncode(deviceMap),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Data sent successfully')),
        );
      } else {
        throw Exception('Failed to send data');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _getDataFromESP32(Device device) async {
    final url = Uri.parse('http://192.168.1.1/getVoltageById?deviceId=${device.id}');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          device.systemType = data['systemType'];
          device.batteryPercentage = data['percentage'].toDouble();
        });
        _saveDevices();
      } else {
        throw Exception('Failed to get data');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeumorphicTheme.baseColor(context),
      appBar: NeumorphicAppBar(
        title: Text('ESP32 Battery Monitor'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  NeumorphicTextField(
                    decoration: InputDecoration(labelText: 'Device ID'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a device ID';
                      }
                      return null;
                    },
                    onSaved: (value) => _newDeviceId = value!,
                  ),
                  SizedBox(height: 16),
                  NeumorphicTextField(
                    decoration: InputDecoration(labelText: 'Percentage'),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a percentage';
                      }
                      if (int.tryParse(value) == null) {
                        return 'Please enter a valid number';
                      }
                      return null;
                    },
                    onSaved: (value) => _newDevicePercentage = int.parse(value!),
                  ),
                  SizedBox(height: 16),
                  NeumorphicButton(
                    onPressed: _addDevice,
                    child: Text('Add Device'),
                    style: NeumorphicStyle(
                      shape: NeumorphicShape.flat,
                      boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            Text('Devices:', style: TextStyle(fontSize: 20)),
            Expanded(
              child: ListView.builder(
                itemCount: _devices.length,
                itemBuilder: (context, index) {
                  final device = _devices[index];
                  return Neumorphic(
                    margin: EdgeInsets.only(bottom: 12),
                    style: NeumorphicStyle(
                      depth: 8,
                      intensity: 0.65,
                      surfaceIntensity: 0.15,
                      boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(12)),
                    ),
                    child: ListTile(
                      title: Text(device.id),
                      subtitle: Text('Set: ${device.percentage}% | Battery: ${device.batteryPercentage?.toStringAsFixed(1) ?? "N/A"}% | System: ${device.systemType ?? "N/A"}V'),
                      trailing: NeumorphicButton(
                        onPressed: () => _getDataFromESP32(device),
                        child: Icon(Icons.refresh),
                        style: NeumorphicStyle(
                          boxShape: NeumorphicBoxShape.circle(),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 16),
            NeumorphicButton(
              onPressed: _sendDataToESP32,
              child: Text('Send Data to ESP32'),
              style: NeumorphicStyle(
                shape: NeumorphicShape.flat,
                boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NeumorphicTextField extends StatelessWidget {
  final InputDecoration decoration;
  final FormFieldValidator<String>? validator;
  final dynamic onSaved;
  final TextInputType? keyboardType;

  const NeumorphicTextField({
    Key? key,
    required this.decoration,
    this.validator,
    this.onSaved,
    this.keyboardType,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Neumorphic(
      style: NeumorphicStyle(
        depth: -4,
        intensity: 0.8,
        surfaceIntensity: 0.2,
        boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(12)),
      ),
      child: TextFormField(
        decoration: decoration.copyWith(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        validator: validator,
        onSaved: onSaved,
        keyboardType: keyboardType,
      ),
    );
  }
}