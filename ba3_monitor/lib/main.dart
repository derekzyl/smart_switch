// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const NeumorphicApp(
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



class ApplianceType {
  final String name;
  final IconData icon;

  ApplianceType(this.name, this.icon);
}

class Device {
  final String id;
  String name;
  int percentage;
  int? systemType;
  double? batteryPercentage;
  String applianceType;

  Device({
    required this.id,
    required this.name,
    required this.percentage,
    this.systemType,
    this.batteryPercentage,
    required this.applianceType,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'percentage': percentage,
    'systemType': systemType,
    'batteryPercentage': batteryPercentage,
    'applianceType': applianceType,
  };

  factory Device.fromJson(Map<String, dynamic> json) => Device(
    id: json['id'],
    name: json['name'],
    percentage: json['percentage'],
    systemType: json['systemType'],
    batteryPercentage: json['batteryPercentage'],
    applianceType: json['applianceType'],
  );
}


class Voltage {
    final String systemType;
    final double percentage;
    final double voltage;
    final double percentageOff;
    Voltage({
      required this.systemType,
      required this.percentage,
      required this.voltage,
      required this.percentageOff,
    });

  Voltage copyWith({
    String? systemType,
    double? percentage,
    double? voltage,
    double? percentageOff,
  }) {
    return Voltage(
      systemType: systemType ?? this.systemType,
      percentage: percentage ?? this.percentage,
      voltage: voltage ?? this.voltage,
      percentageOff: percentageOff ?? this.percentageOff,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'systemType': systemType,
      'percentage': percentage,
      'voltage': voltage,
      'percentageOff': percentageOff,
    };
  }

  factory Voltage.fromMap(Map<String, dynamic> map) {
    return Voltage(
      systemType: map['systemType'] as String,
      percentage: map['percentage'] as double,
      voltage: map['voltage'] as double,
      percentageOff: map['percentageOff'] as double,
    );
  }

  String toJson() => json.encode(toMap());

  factory Voltage.fromJson(String source) => Voltage.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'Voltage(systemType: $systemType, percentage: $percentage, voltage: $voltage, percentageOff: $percentageOff)';
  }

  @override
  bool operator ==(covariant Voltage other) {
    if (identical(this, other)) return true;
  
    return 
      other.systemType == systemType &&
      other.percentage == percentage &&
      other.voltage == voltage &&
      other.percentageOff == percentageOff;
  }

  @override
  int get hashCode {
    return systemType.hashCode ^
      percentage.hashCode ^
      voltage.hashCode ^
      percentageOff.hashCode;
  }
  }

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _formKey = GlobalKey<FormState>();
  List<Device> _devices = [];
  String _newDeviceId = '';
  String _newDeviceName = '';
  int _newDevicePercentage = 0;
  String _selectedApplianceType = 'Other';

  Voltage voltage = Voltage(
    systemType: 'N/A',
    percentage: 0,
    voltage: 0,
    percentageOff: 0,
  );

Timer? _debounce ;
final String baseUrl ="http://192.168.1.1";
 static const Duration timeout = Duration(seconds: 5);
  

  final List<ApplianceType> _applianceTypes = [
    ApplianceType('Light', Icons.lightbulb),
    ApplianceType('Fan', Icons.air),
    ApplianceType('TV', Icons.tv),
    ApplianceType('Refrigerator', Icons.kitchen),
    ApplianceType('Other', Icons.devices_other),
  ];

  @override
  void initState()  {
    super.initState();
    _loadDevices();

// lets set interval fetch data from esp32

   Timer.periodic(const Duration(seconds: 5), (timer) async{
  await    _getGeneralDataFromESP32();
    });


  }

  Future<void> _loadDevices() async {
    final prefs = await SharedPreferences.getInstance();
    final devicesJson = prefs.getString('devices');
    final voltageJson = prefs.getString('voltage');
    if (devicesJson != null) {
      final devicesList = jsonDecode(devicesJson) as List;
      setState(() {
        _devices = devicesList.map((device) => Device.fromJson(device)).toList();
      });
    }
    if (voltageJson != null) {
      
      setState(() {
        voltage = Voltage.fromJson(voltageJson);
      });
    }
  }

  Future<void> _saveDevices() async {
    final prefs = await SharedPreferences.getInstance();
    final devicesJson = jsonEncode(_devices.map((device) => device.toJson()).toList());

    final voltageJson = voltage.toJson();
    await prefs.setString('voltage', voltageJson);
    await prefs.setString('devices', devicesJson);
  }

  void _addDevice() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      // check if the device ID already exists

      if (_devices.any((device) => device.id == _newDeviceId )) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Device ID already exists')),
        );
        return;
      }
      if(_devices.any((device) => device.name == _newDeviceName)){
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Device Name already exists')),
        );
        return;
      }

      setState(() {
        _devices.add(Device(
          id: _newDeviceId,
          name: _newDeviceName,
          percentage: _newDevicePercentage,
          applianceType: _selectedApplianceType,
        ));
        _newDeviceId = '';
        _newDeviceName = '';
        _newDevicePercentage = 0;
        _selectedApplianceType = 'Other';
      });
      _saveDevices();
    }
  }

  void _updateDevice(Device device) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String updatedName = device.name;
        int updatedPercentage = device.percentage;
        String updatedApplianceType = device.applianceType;

        return AlertDialog(
          title: const Text('Update Device'),
          content: Form(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: device.name,
                  decoration: const InputDecoration(labelText: 'Name'),
                  onChanged: (value) => updatedName = value,
                ),
                TextFormField(
                  initialValue: device.percentage.toString(),
                  decoration: const InputDecoration(labelText: 'Percentage'),
                  keyboardType: TextInputType.number,
                  onChanged: (value) => updatedPercentage = int.tryParse(value) ?? device.percentage,
                ),
                DropdownButtonFormField<String>(
                  value: device.applianceType,
                  items: _applianceTypes.map((type) {
                    return DropdownMenuItem(
                      value: type.name,
                      child: Row(
                        children: [
                          Icon(type.icon),
                          const SizedBox(width: 10),
                          Text(type.name),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) => updatedApplianceType = value!,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Update'),
              onPressed: () {
                setState(() {
                  device.name = updatedName;
                  device.percentage = updatedPercentage;
                  device.applianceType = updatedApplianceType;
                });
                _saveDevices();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _deleteDevice(Device device) async {
    bool confirmDelete = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: const Text('Are you sure you want to delete this device?'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Delete'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmDelete) {
      setState(() {
        _devices.remove(device);
      });
      _saveDevices();
      _deleteDeviceFromESP32(device.id);
    }
  }

  Future<void> _deleteDeviceFromESP32(String deviceId) async {
    final url = Uri.parse('http://192.168.1.1/deleteDevice');
    try {
      final response = await http.post(
        url,
        body: jsonEncode({'deviceId': deviceId}),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Device deleted from ESP32')),
        );
      } else {
        throw Exception('Failed to delete device from ESP32');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting device from ESP32: $e')),
      );
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
          const SnackBar(content: Text('Data sent successfully')),
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

Future<void> _setDefaultPercentage( int value) async {
    try {
      final url = Uri.parse('$baseUrl/setdefaultoff');  // Updated to match ESP32 endpoint
      final Map<String, dynamic> data = {'percentage': value};
      
      final response = await http.post(
        url,
        body: jsonEncode(data),
        headers: {'Content-Type': 'application/json'},
      ).timeout(timeout);

     

      if (response.statusCode == 200) {
        // Parse response to ensure it's valid
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
           _getGeneralDataFromESP32();
          if (context.mounted) {  // Check if context is still valid
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Default percentage set successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          throw Exception('Server returned error: ${responseData['message']}');
        }
      } else {
        throw Exception('Failed to set default percentage: ${response.statusCode}');
      }
    } on TimeoutException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connection timeout. Please check if ESP32 is reachable.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
      print('Error setting default percentage: $e');
    }
  }


  
  Future<Voltage?> _getGeneralDataFromESP32() async {
    try {
      final url = Uri.parse('$baseUrl/getvoltage');
      
      final response = await http.get(url).timeout(timeout);
      
      print('Response body: ${response.body}');
    

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Validate required fields exist
        if (!data.containsKey('systemType') || 
            !data.containsKey('percentage') || 
            !data.containsKey('voltage') || 
            !data.containsKey('setPercentageForOff')) {
          throw Exception('Invalid response format from server');
        }

        final voltage = Voltage(
          systemType:( data['systemType']).toString(),
          percentage: (data['percentage'] ?? 0).toDouble(),
          voltage: (data['voltage'] ?? 0).toDouble(),
          percentageOff: (data['setPercentageForOff'] ?? 0).toDouble(),  // Updated to match ESP32 response
        );

        
setState(() {
          this.voltage = voltage;
        });
         _saveDevices();  // Consider making this method static or moving it
        return voltage;
      } else {
        throw Exception('Failed to get data: ${response.statusCode}');
      }
    } on TimeoutException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connection timeout. Please check if ESP32 is reachable.'),
          ),
        );
      }
      return null;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor:          Colors.red[700],

          ),
        );
      }
      return null;
    }
  }
  
    Future<void> _getDataFromESP32(Device device) async {
    final url = Uri.parse('$baseUrl/getVoltageById?deviceId=${device.id}');
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

 Widget _buildLCDDisplay(String label, String value) {
    return Neumorphic(
      style: NeumorphicStyle(
        depth: -2,
        intensity: 0.8,
        color: Colors.blue[300],
        boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(8)),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                NeumorphicIcon(
                  Icons.battery_0_bar_sharp,
                  size: 20,
                  style: NeumorphicStyle(
                    color: Colors.grey[700],
                    intensity: 0.9,
                    depth: 2,
                    boxShape: const NeumorphicBoxShape.circle(),
                  ),
                ),
                const SizedBox(width: 2),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                color: Colors.grey[900],
                fontFamily: 'monospace',
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCalibrationMarks() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(11, (index) {
          final value = (index * 10).toString();
          return Column(
            children: [
              Text(
                value,
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 10,
                ),
              ),
              Container(
                height: 4,
                width: 1,
                color: Colors.grey[700],
              ),
            ],
          );
        }),
      ),
    );
  }

bool _customExpansionTileIsExpanded = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeumorphicTheme.baseColor(context),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _sendDataToESP32, 
        backgroundColor: Colors.blue[100],
        label: 
                Row(
                    
                  children: [
                    const Text('Sync Data', style: TextStyle(
                      fontWeight: FontWeight.bold
                    ),),const SizedBox(width: 2,),  NeumorphicIcon(Icons.sync, style: NeumorphicStyle(
                      color: const HSLColor.fromAHSL(1, 180, 0.2, 0.5).toColor(),
                    ),)
                  ],
                ),
      ),
      appBar: NeumorphicAppBar(
        title: const Text('Battery Monitor', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold) ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            
                NeumorphicText("Quick Overview",style: NeumorphicStyle(
                  depth: 2,
                  intensity: 0.65,
                  surfaceIntensity: 0.15,color: Colors.grey[700],
                  boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(12)),
                ),),
                      
                     Neumorphic(
              style: NeumorphicStyle(
                depth: 3,
                intensity: 0.65,
                surfaceIntensity: 0.15,
                color: Colors.blue[500],
                boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(12)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildLCDDisplay("System Voltage", "${voltage.voltage.toInt()}V")),
                        const SizedBox(width: 4),
                        Expanded(child: _buildLCDDisplay("System %", "${voltage.percentage.toInt()}%")),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(child: _buildLCDDisplay("System Type", voltage.systemType.toString())),
                        const SizedBox(width: 4),
                        Expanded(child: _buildLCDDisplay("% Off", "${voltage.percentageOff.toInt()}%")),
                      ],
                    ),
                  ],
                ),
              ),
            ),       const SizedBox(height: 20),
            
             // Slider Section
            Text(
              'Set Default Percentage',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            
            const SizedBox(height: 8),
            
            _buildCalibrationMarks(),
            
            const SizedBox(height: 4),
            
            Neumorphic(
              style: NeumorphicStyle(
                depth: -2,
                intensity: 0.8,
                boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(12)),
              ),
              child: NeumorphicSlider(
                height: 15,
                value: voltage.percentageOff.toDouble(),
                min: 0,
                max: 100,
                onChanged: (value) {
                  setState(() {
                    voltage = voltage.copyWith(percentageOff: value);
                    
                    if (_debounce?.isActive ?? false) _debounce?.cancel();
                    _debounce = Timer(
                      const Duration(milliseconds: 500),
                      () {
                         _setDefaultPercentage(value.toInt());
                      },
                    );
                  });
                },
                style: const SliderStyle(
                  depth: 2,
                  accent: Colors.blueGrey,
                  variant: Colors.grey,
                ),
              ),
            ),
                const SizedBox(height: 20),
            
                
                Neumorphic(
                  style: NeumorphicStyle(
                    shape: NeumorphicShape.flat,depth: 3, intensity: 0.65, surfaceIntensity: 0.15, boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(12),) 
                  ),
                  child: ExpansionTile(
                    title: const Text("Add New device",style:TextStyle(fontWeight: FontWeight.w600)),
                    
                              onExpansionChanged: (bool expanded) {
                  setState(() {
                    _customExpansionTileIsExpanded = expanded;
                  });
                            },
                     trailing:NeumorphicButton(
                      
                      style: NeumorphicStyle(
                      shape: NeumorphicShape.concave,
                      intensity: 0.9,
                        depth: 2,
                        boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(16)),
                      ),
                      
                      child: _customExpansionTileIsExpanded ? NeumorphicIcon(Icons.arrow_upward,style: NeumorphicStyle(
                        color: const HSLColor.fromAHSL(1, 180, 0.2, 0.5).toColor(),
                      
                      ),): NeumorphicIcon(Icons.add, 
                     style:NeumorphicStyle(
                        color: const HSLColor.fromAHSL(1, 180, 0.2, 0.5).toColor(),
             
                      
                     )   ,) ),
                    children:[
                    
                     Form(
                      key: _formKey,
                      child: Neumorphic(
                        style:NeumorphicStyle(
                    shape: NeumorphicShape.flat,depth: 1, intensity: 0.65, surfaceIntensity: 0.15, boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(12),)
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            
                            children: [
                              NeumorphicTextField(
                                hint: 'Device ID',
                                onSaved: (value) => _newDeviceId = value!,
                                
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a device ID';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              NeumorphicTextField(
                                hint: 'Device Name',
                                onSaved: (value) => _newDeviceName = value!,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a device name';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              NeumorphicTextField(
                                hint: 'Percentage',
                                onSaved: (value) => _newDevicePercentage = int.parse(value!),
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
                              ),
                              const SizedBox(height: 16),
                              NeumorphicDropdown<String>(
                                value: _selectedApplianceType,
                                items: _applianceTypes.map((type) {
                                  return DropdownMenuItem(
                                    value: type.name,
                                    child: Row(
                                      children: [
                                        Icon(type.icon),
                                        const SizedBox(width: 10),
                                        Text(type.name),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedApplianceType = value!;
                                  });
                                },
                              ),
                              const SizedBox(height: 16),
                              NeumorphicButton(
                                onPressed: _addDevice,
                                style: NeumorphicStyle(
                                  shape: NeumorphicShape.flat,
                                  depth: 2,
                                  boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(12)),
                                ),
                                child: const Text('Add Device'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                             
                             
                             
                             ] ),
                ),
                const SizedBox(height: 20),
                  
                  
                Text('Devices', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[700])),
             _devices.isNotEmpty?
                SizedBox(
                  height: 400,
                  child: ListView.builder(
                    itemCount: _devices.length,
                    itemBuilder: (context, index) {
                      final device = _devices[index];
                      return Neumorphic(
                        margin: const EdgeInsets.only(bottom: 12),
                        style: NeumorphicStyle(
                          depth: 2,
                          intensity: 0.65,
                          surfaceIntensity: 0.15,
                          boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(12)),
                        ),
                        child: Column(
                  
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                children: [
                                             Icon(
                                              _applianceTypes.firstWhere((type) => type.name == device.applianceType).icon),
                               Text(device.name, style:TextStyle(
                                  fontWeight: FontWeight.bold, color: Colors.grey[900],  fontSize: 16
                               )),  ],
                              ),
                            ),Text('ID: ${device.id}\nSet: ${device.percentage}% | Battery: ${device.batteryPercentage?.toStringAsFixed(1) ?? "N/A"}% | System: ${device.systemType ?? "N/A"}V', style:TextStyle(
                              fontWeight:FontWeight.w600, color: Colors.grey[700],
                            )),
                             Padding(
                               padding: const EdgeInsets.all(8.0),
                               child: Row(
                                                       mainAxisSize: MainAxisSize.min,
                                                       children: [
                                NeumorphicButton(
                                  onPressed: () => _updateDevice(device),
                                  style: const NeumorphicStyle(
                                    boxShape: NeumorphicBoxShape.circle(),
                                  ),
                                  child: NeumorphicIcon(Icons.edit,  style: NeumorphicStyle(
                                                       
                                  color: const HSLColor.fromAHSL(1, 270,0.2, 0.5).toColor(),
                                  ),),
                                ),
                                const SizedBox(width: 8),
                                NeumorphicButton(
                                  onPressed: () => _deleteDevice(device),
                                  style: const NeumorphicStyle(
                                    boxShape: NeumorphicBoxShape.circle(),
                                  ),
                                  child: NeumorphicIcon(Icons.delete, 
                                  style: NeumorphicStyle(
                                                       
                                  color: const HSLColor.fromAHSL(1, 1, 0.2, 0.5).toColor(),
                                  ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                NeumorphicButton(
                                  onPressed: () => _getDataFromESP32(device),
                                  style: const NeumorphicStyle(
                                    boxShape: NeumorphicBoxShape.circle(),
                                  ),
                                  child: NeumorphicIcon(Icons.refresh,  style: NeumorphicStyle(
                               
                                  color:const HSLColor.fromAHSL(1, 180, 0.2, 0.5).toColor(),
                                  ),),
                                ),
                                                       ],
                                                     ),
                             ),
                        
                        
                        
                          ],
                          
                  
                        
                        ),
                      );
                    },
                  ),
                )
                :
                Center(child: Text('No devices added yet', style: TextStyle(color: Colors.grey[700]))),  
                
                const SizedBox(height: 16),
           
              ],
            ),
          ),
        ),
      ),
    );
  }

    @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

class NeumorphicTextField extends StatelessWidget {
  final String hint;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String?>? onSaved;
  final TextInputType? keyboardType;

  const NeumorphicTextField({
    super.key,
    required this.hint,
    this.validator,
    this.onSaved,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Neumorphic(
      style: NeumorphicStyle(
        depth: -2,
        intensity: 0.9,
        surfaceIntensity: 0.0,
        boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(12)),
      ),
      child: TextFormField(
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        validator: validator,
        onSaved: onSaved,
        keyboardType: keyboardType,
      ),
    );
  }
}

class NeumorphicDropdown<T> extends StatelessWidget {
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const NeumorphicDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Neumorphic(
      style: NeumorphicStyle(
        depth: -4,
        intensity: 0.8,
        surfaceIntensity: 0.2,
        boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(12)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            items: items,
            onChanged: onChanged,
            isExpanded: true,
          ),
        ),
      ),
    );
  }
}