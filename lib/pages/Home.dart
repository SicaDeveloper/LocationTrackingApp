import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:locationtrackingapp/pages/Login.dart';
import 'package:locationtrackingapp/pages/Profile.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:locationtrackingapp/pages/Login.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // A variable to store the current position. It's nullable because it might not be available yet.
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _fetchCurrentLocation();
  }

  Future<void> sendLocationToApi() async {
    try {
      final url = Uri.parse('https://your-api-endpoint.com/location');
      final response = await http.post(
        url,
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, dynamic>{
          'latitude': _currentPosition?.latitude,
          'longitude': _currentPosition?.longitude,
          'timestamp': _currentPosition?.timestamp.toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        if (kDebugMode) {
          print('Location sent successfully!');
          print('Failed to send location. Status code: ${response.statusCode}');
          print('Response body: ${response.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error: $e');
      }
    }
  }
  /// Determine the current position of the device.
  ///
  /// This function handles permission checks and service availability.
  Future<void> _fetchCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled, so we can't continue.
      // In a real app, you might want to show a dialog to the user here.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled.')),
        );
      }
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied, so we can't continue.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied.')),
          );
        }
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are permanently denied.')),
        );
      }
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    // Permissions are granted, get the position.
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(accuracy: LocationAccuracy.high)
      );
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to get location: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: BottomAppBar(
        shape : CircularNotchedRectangle(),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: const Icon(Icons.home),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const HomePage()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.location_on),
              onPressed: () {
                // Manually refresh location on button press
                _fetchCurrentLocation();
              },
            ),
            SizedBox( width: 20,),
            IconButton(
              icon: const Icon(Icons.share_location_outlined),
              onPressed: (){
                sendLocationToApi();
              }
            ),
            IconButton(
              icon: const Icon(Icons.logout_outlined),
              onPressed: (){
                  GoogleSignInPageState().signOut();
              },
            )
          ],
        ),
      ),
      floatingActionButton: Stack(
        // The clipBehavior property prevents the badge from overflowing
        // if it's placed outside the bounds of the FAB.
        clipBehavior: Clip.none,
        children: <Widget>[
          // This is the original floating action button.
          ClipOval(
            child: Material(
              color: const Color(0xFF7861FF),
              elevation: 6,
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProfilePage()),
                  );
                },
                child: const SizedBox(
                  width: 55,
                  height: 55,
                  child: Icon(
                    Icons.person,
                    size: 28,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          // This is the badge, positioned at the top right of the button.
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
        ],
      ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      body: _currentPosition == null
          ? const Center(child: CircularProgressIndicator())
          : FlutterMap(
        options: MapOptions(
          center: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          zoom: 13.0,
          maxZoom: 22.0,
          minZoom: 3.0
        ),
        children: [
          // OpenStreetMap Tile Layer
          TileLayer(
            urlTemplate: 'https://tile.thunderforest.com/atlas/{z}/{x}/{y}.png?apikey=8f601b1030a94a4398f9bad10ef3d40e',
            maxZoom: 22,
            userAgentPackageName: 'com.example.app', // Replace with your app name
          ),
        RichAttributionWidget(
          attributions: [
            TextSourceAttribution(
              'Maps: © Thunderforest | Data: © OpenStreetMap contributors',
              onTap: () => launchUrl(Uri.parse('https://www.thunderforest.com')),
            ),
          ],
        ),
          // Add a marker for the current location
          MarkerLayer(
            markers: [
              Marker(
                width: 80.0,
                height: 80.0,
                point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                // The builder property is used here to define the marker widget.
                builder: (BuildContext context) {
                  return const Icon(
                    Icons.location_on,
                    color: Colors.red,
                    size: 40.0,
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
