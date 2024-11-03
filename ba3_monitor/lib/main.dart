import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';

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

class HomePage extends StatefulWidget {
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

  final List<ApplianceType> _applianceTypes = [
    ApplianceType('Light', Icons.lightbulb),
    ApplianceType('Fan', Icons.air),
    ApplianceType('TV', Icons.tv),
    ApplianceType('Refrigerator', Icons.kitchen),
    ApplianceType('Other', Icons.devices_other),
  ];

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

      // check if the device ID already exists

      if (_devices.any((device) => device.id == _newDeviceId )) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Device ID already exists')),
        );
        return;
      }
      if(_devices.any((device) => device.name == _newDeviceName)){
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Device Name already exists')),
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
          title: Text('Update Device'),
          content: Form(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: device.name,
                  decoration: InputDecoration(labelText: 'Name'),
                  onChanged: (value) => updatedName = value,
                ),
                TextFormField(
                  initialValue: device.percentage.toString(),
                  decoration: InputDecoration(labelText: 'Percentage'),
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
                          SizedBox(width: 10),
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
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('Update'),
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
          title: Text('Confirm Delete'),
          content: Text('Are you sure you want to delete this device?'),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: Text('Delete'),
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
          SnackBar(content: Text('Device deleted from ESP32')),
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



bool _customExpansionTileIsExpanded = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeumorphicTheme.baseColor(context),
      appBar: NeumorphicAppBar(
        title: Text('Battery Monitor', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold) ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

          
            Neumorphic(
              style: NeumorphicStyle(
                shape: NeumorphicShape.flat,depth: 3, intensity: 0.65, surfaceIntensity: 0.15, boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(12),) 
              ),
              child: ExpansionTile(
                title: Text("Add New device",style:TextStyle(fontWeight: FontWeight.w600)),
                
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
                    color: HSLColor.fromAHSL(1, 180, 0.2, 0.5).toColor(),

                  ),): NeumorphicIcon(Icons.add, 
                 style:NeumorphicStyle(
                    color: HSLColor.fromAHSL(1, 180, 0.2, 0.5).toColor(),
         

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
                          SizedBox(height: 16),
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
                          SizedBox(height: 16),
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
                          SizedBox(height: 16),
                          NeumorphicDropdown<String>(
                            value: _selectedApplianceType,
                            items: _applianceTypes.map((type) {
                              return DropdownMenuItem(
                                value: type.name,
                                child: Row(
                                  children: [
                                    Icon(type.icon),
                                    SizedBox(width: 10),
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
                          SizedBox(height: 16),
                          NeumorphicButton(
                            onPressed: _addDevice,
                            child: Text('Add Device'),
                            style: NeumorphicStyle(
                              shape: NeumorphicShape.flat,
                              depth: 2,
                              boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                         
                         
                         
                         ] ),
            ),
            SizedBox(height: 20),
              
              
            Text('Devices', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[700])),
         _devices.length>=1?
            Expanded(
              child: ListView.builder(
                itemCount: _devices.length,
                itemBuilder: (context, index) {
                  final device = _devices[index];
                  return Neumorphic(
                    margin: EdgeInsets.only(bottom: 12),
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
                              child: NeumorphicIcon(Icons.edit,  style: NeumorphicStyle(
                                                   
                              color: HSLColor.fromAHSL(1, 270,0.2, 0.5).toColor(),
                              ),),
                              style: NeumorphicStyle(
                                boxShape: NeumorphicBoxShape.circle(),
                              ),
                            ),
                            SizedBox(width: 8),
                            NeumorphicButton(
                              onPressed: () => _deleteDevice(device),
                              child: NeumorphicIcon(Icons.delete, 
                              style: NeumorphicStyle(
                                                   
                              color: HSLColor.fromAHSL(1, 1, 0.2, 0.5).toColor(),
                              ),
                              ),
                              style: NeumorphicStyle(
                                boxShape: NeumorphicBoxShape.circle(),
                              ),
                            ),
                            SizedBox(width: 8),
                            NeumorphicButton(
                              onPressed: () => _getDataFromESP32(device),
                              child: NeumorphicIcon(Icons.refresh,  style: NeumorphicStyle(
                           
                              color:HSLColor.fromAHSL(1, 180, 0.2, 0.5).toColor(),
                              ),),
                              style: NeumorphicStyle(
                                boxShape: NeumorphicBoxShape.circle(),
                              ),
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
            :Expanded(child: Center(child: Text('No devices added yet', style: TextStyle(color: Colors.grey[700])))),  
            
            SizedBox(height: 16),
        
            NeumorphicButton(

              onPressed: _sendDataToESP32,
              child: Row(
                mainAxisSize: MainAxisSize.min,

                children: [
                  Text('Sync Data', style: TextStyle(
                    fontWeight: FontWeight.bold
                  ),),SizedBox(width: 2,),  NeumorphicIcon(Icons.sync, style: NeumorphicStyle(
                    color: HSLColor.fromAHSL(1, 180, 0.2, 0.5).toColor(),
                  ),)
                ],
              ),
              style: NeumorphicStyle(
                shape: NeumorphicShape.flat,
                depth: 2,
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
  final String hint;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String?>? onSaved;
  final TextInputType? keyboardType;

  const NeumorphicTextField({
    Key? key,
    required this.hint,
    this.validator,
    this.onSaved,
    this.keyboardType,
  }) : super(key: key);

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
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
    Key? key,
    required this.value,
    required this.items,
    required this.onChanged,
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
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
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