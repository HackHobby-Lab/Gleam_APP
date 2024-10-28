import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:permission_handler/permission_handler.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Initial theme mode set to light
  ThemeMode _themeMode = ThemeMode.light;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BLE RGB Controller',
      theme: ThemeData(
        primarySwatch: Colors.yellow,
        brightness: Brightness.light, // Light theme
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.yellow,
        brightness: Brightness.dark, // Dark theme
      ),
      themeMode: _themeMode,
      home: BleConnectScreen(
        toggleTheme: () {
          setState(() {
            _themeMode = _themeMode == ThemeMode.light
                ? ThemeMode.dark
                : ThemeMode.light;
          });
        },
      ),
    );
  }
}

// LED state tracking
class Led {
  final String name;
  final List<int> onCommand;
  final List<int> offCommand;
  bool isOn;

  Led({
    required this.name,
    required this.onCommand,
    required this.offCommand,
    this.isOn = false,
  });
}

class BleConnectScreen extends StatefulWidget {
  final VoidCallback toggleTheme;

  BleConnectScreen({required this.toggleTheme});

  @override
  _BleConnectScreenState createState() => _BleConnectScreenState();
}

class _BleConnectScreenState extends State<BleConnectScreen> {
  final flutterReactiveBle = FlutterReactiveBle();
  List<DiscoveredDevice> connectedDevices = []; // List of connected devices
  final serviceUuid = Uuid.parse('00001523-1212-efde-1523-785feabcd123');
  final characteristicUuid = Uuid.parse('00001524-1212-efde-1523-785feabcd123');

  bool isScanning = false;
  List<DiscoveredDevice> devicesList = [];
  Color selectedColor = Colors.white; // Initial color for the color picker

  List<Led> leds = [
    Led(
      name: 'Red',
      onCommand: [0x00, 0xFF, 0x00, 0x00], // Command to turn Red ON
      offCommand: [0x00, 0x00, 0x00, 0x00], // Command to turn Red OFF
    ),
    Led(
      name: 'Green',
      onCommand: [0x01, 0x00, 0xFF, 0x00], // Command to turn Green ON
      offCommand: [0x01, 0x00, 0x00, 0x00], // Command to turn Green OFF
    ),
    Led(
      name: 'Blue',
      onCommand: [0x02, 0x00, 0x00, 0xFF], // Command to turn Blue ON
      offCommand: [0x02, 0x00, 0x00, 0x00], // Command to turn Blue OFF
    ),
    Led(
      name: 'Yellow',
      onCommand: [0x03, 0xFF, 0xFF, 0x00], // Command to turn Yellow ON
      offCommand: [0x03, 0x00, 0x00, 0x00], // Command to turn Yellow OFF
    ),
  ];

  @override
  void initState() {
    super.initState();
    requestPermissions(); // Request permissions when the screen initializes
    startScan();
  }

  Future<void> requestPermissions() async {
    // Request location permission (required for BLE)
    var locationStatus = await Permission.locationWhenInUse.request();
    if (locationStatus.isGranted) {
      print("Location permission granted.");
    } else {
      print("Location permission denied.");
    }

    // Request Bluetooth permission (for Android 12+)
    if (await Permission.bluetooth.request().isGranted) {
      print("Bluetooth permission granted.");
    } else {
      print("Bluetooth permission denied.");
    }

    // Request Bluetooth Connect permission (for Android 12+)
    if (await Permission.bluetoothConnect.request().isGranted) {
      print("Bluetooth connect permission granted.");
    }
  }

  void startScan() {
    setState(() {
      isScanning = true;
      devicesList.clear(); // Clear the device list before starting a new scan
    });

    flutterReactiveBle.scanForDevices(withServices: []).listen((device) {
      // Avoid duplicates
      if (!devicesList.any((d) => d.id == device.id)) {
        setState(() {
          devicesList.add(device);
        });
      }
    }).onDone(() {
      setState(() {
        isScanning = false;
      });
    });
  }

  void connectToDevice(DiscoveredDevice device) {
    setState(() {
      connectedDevices
          .add(device); // Add device to the list of connected devices
    });
    print('Connected to device: ${device.name}');
  }

  void sendCommandToAllDevices(List<int> value) async {
    if (connectedDevices.isNotEmpty) {
      for (var device in connectedDevices) {
        try {
          await flutterReactiveBle.writeCharacteristicWithResponse(
            QualifiedCharacteristic(
              serviceId: serviceUuid,
              characteristicId: characteristicUuid,
              deviceId: device.id,
            ),
            value: value,
          );
          print('Command sent to device ${device.name}: $value');
        } catch (e) {
          print('Failed to send command to device ${device.name}: $e');
        }
      }
    } else {
      print('No devices connected');
    }
  }

  void onColorChanged(Color color) {
    setState(() {
      selectedColor = color;
    });
    // Convert the color to RGB values
    List<int> rgbValue = [color.red, color.green, color.blue];
    sendCommandToAllDevices(rgbValue); // Send the RGB value to all devices
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('BLE RGB Controller'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed:
                isScanning ? null : startScan, // Disable button while scanning
          ),
          IconButton(
            icon: Icon(Icons.brightness_6),
            onPressed: widget.toggleTheme, // Toggle theme on press
          ),
        ],
      ),
      body: Column(
        children: [
          if (connectedDevices.isNotEmpty)
            Text('Connected devices: ${connectedDevices.length}'),
          isScanning
              ? LinearProgressIndicator()
              : ElevatedButton(
                  onPressed: startScan,
                  child: Text('Start Scan'),
                ),
          Expanded(
            child: ListView.builder(
              itemCount: devicesList.length,
              itemBuilder: (context, index) {
                final device = devicesList[index];
                return ListTile(
                  title: Text(
                      device.name.isNotEmpty ? device.name : 'Unknown device'),
                  subtitle: Text(device.id),
                  onTap: () => connectToDevice(device),
                );
              },
            ),
          ),
          connectedDevices.isNotEmpty
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var led in leds)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20.0), // Added padding for centering
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(led.name),
                            Switch(
                              value: led.isOn,
                              onChanged: (value) {
                                setState(() {
                                  led.isOn = value;
                                  // Send ON or OFF command based on switch state
                                  sendCommandToAllDevices(
                                      value ? led.onCommand : led.offCommand);
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    SizedBox(height: 20),
                    Text("Select a color:"),
                    ColorPicker(
                      pickerColor: selectedColor,
                      onColorChanged: onColorChanged,
                      showLabel: true,
                      pickerAreaHeightPercent: 0.8,
                    ),
                  ],
                )
              : Center(child: Text('No devices connected')),
        ],
      ),
    );
  }
}
