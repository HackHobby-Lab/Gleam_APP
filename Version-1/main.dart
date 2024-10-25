import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:permission_handler/permission_handler.dart'; // Import the permission_handler package

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BLE RGB Controller',
      theme: ThemeData(primarySwatch: Colors.yellow),
      home: BleConnectScreen(),
    );
  }
}

class BleConnectScreen extends StatefulWidget {
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
      // Optionally, show a dialog to inform the user about permission denial
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

  Widget buildButton(String label, List<int> command) {
    return ElevatedButton(
      onPressed: connectedDevices.isEmpty
          ? null // Disable the button if no devices are connected
          : () => sendCommandToAllDevices(command),
      child: Text(label),
    );
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
                    buildButton("Red ON",
                        [0x00, 0xFF, 0x00, 0x00]), // Full brightness Red
                    buildButton("Green ON",
                        [0x01, 0x00, 0xFF, 0x00]), // Full brightness Green
                    buildButton("Blue ON",
                        [0x02, 0x00, 0x00, 0xFF]), // Full brightness Blue
                    buildButton("Yellow  ON",
                        [0x03, 0xFF, 0XFF, 0x00]), // Turn Yellow on
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
