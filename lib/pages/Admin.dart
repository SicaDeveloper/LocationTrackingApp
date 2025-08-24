import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:locationtrackingapp/main.dart';
import 'package:locationtrackingapp/pages/Login.dart';
import 'package:locationtrackingapp/pages/Profile.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeProvider extends ChangeNotifier {
  bool sendingLocation = false;

  void setSendingLocation(bool value) {
    sendingLocation = value;
    notifyListeners();
  }

  Position? currentPosition;

  void setCurrentPosition(Position value) {
    currentPosition = value;
    notifyListeners();
  }
}

// Dedicated Map Widget ========================================================
class LocationMap extends StatefulWidget {
  final Position currentPosition;
  final MapController mapController;
  const LocationMap({super.key, required this.currentPosition, required this.mapController});

  @override
  State<LocationMap> createState() => LocationMapState();
}

class LocationMapState extends State<LocationMap> {
  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: widget.mapController,
      options: MapOptions(
        center: LatLng(widget.currentPosition.latitude, widget.currentPosition.longitude),
        zoom: 13.0,
        maxZoom: 22.0,
        minZoom: 3.0,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.thunderforest.com/atlas/{z}/{x}/{y}.png?apikey=8f601b1030a94a4398f9bad10ef3d40e',
          maxZoom: 22,
          userAgentPackageName: 'com.locationtrackingapp.myapp',
        ),
        RichAttributionWidget(
          attributions: [
            TextSourceAttribution(
              'Maps: © Thunderforest | Data: © OpenStreetMap contributors',
              onTap: () => launchUrl(Uri.parse('https://www.thunderforest.com')),
            ),
          ],
        ),
        MarkerLayer(
          markers: [
            Marker(
              width: 80.0,
              height: 80.0,
              point: LatLng(widget.currentPosition.latitude, widget.currentPosition.longitude),
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
    );
  }
}

// Main Admin Page with Sidebar ================================================
class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  Position? _currentPosition;
  final MapController _mapController = MapController();
  StreamSubscription<Position>? _positionStream;
  int _selectedIndex = 0; // For sidebar navigation
  bool state = false;

  // Sidebar menu items
  static const List<Widget> _menuOptions = <Widget>[
    Text('Dashboard'),
    Text('Location Tracking'),
    Text('Users'),
    Text('Settings'),
  ];

  @override
  void initState() {
    super.initState();
    _fetchCurrentLocation().then((_) {
      _listenToLocationUpdates();
    });
  }

  void moveToCurrentLocation() {
    if (_currentPosition != null) {
      _mapController.move(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        13.0,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Current location is not available.')),
      );
    }
  }

  Future<void> sendLocationToApi() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.supabaseClient.auth.currentUser;
    state = !state;

    final locationData = {
      'user_id': user?.id,
      'latitude': _currentPosition?.latitude,
      'longitude': _currentPosition?.longitude,
      'created_at': _currentPosition?.timestamp.toIso8601String()
    };

    if (state) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location Being sent to Server')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stopped sending Location to Server')),
      );
    }

    while (state) {
      await Future.delayed(const Duration(minutes: 5));
      try {
        await authProvider.supabaseClient
            .from('locations')
            .upsert(locationData, onConflict: 'user_id');
      } catch (e) {
        if (kDebugMode) {
          print(e);
        }
      }
    }
  }

  void _listenToLocationUpdates() {
    const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 20
    );

    _positionStream = Geolocator.getPositionStream(
        locationSettings: locationSettings).listen(
          (Position position) {
        if (mounted) {
          setState(() {
            _currentPosition = position;
          });
        }
      },
    );
  }

  Future<void> _fetchCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied.')),
          );
        }
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are permanently denied.')),
        );
      }
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

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

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.blueGrey[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: moveToCurrentLocation,
          ),
          IconButton(
            icon: Icon(state ? Icons.location_on : Icons.location_off),
            onPressed: sendLocationToApi,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => GoogleSignInPageState().signOut(),
          )
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blueGrey[800],
              ),
              child: const Text(
                'Admin Panel',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Dashboard'),
              selected: _selectedIndex == 0,
              onTap: () {
                _onItemTapped(0);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.location_on),
              title: const Text('Location Tracking'),
              selected: _selectedIndex == 1,
              onTap: () {
                _onItemTapped(1);
                Navigator.pop(context);
              },
            ),
            ExpansionTile(
              leading: const Icon(Icons.group),
              title: const Text('Team Management'),
              children: <Widget>[
                ListTile(
                  title: const Text('View All Teams'),
                  onTap: () {
                    // Navigate to a screen to view all teams
                  },
                ),
                ListTile(
                  title: const Text('Create New Team'),
                  onTap: () {
                    // Navigate to a screen to create a new team
                  },
                ),
                ListTile(
                  title: const Text('Manage Team Members'),
                  onTap: () {
                    // Navigate to a screen to manage members for a selected team
                  },
                ),
              ],
            ),
            ExpansionTile(
              leading: const Icon(Icons.person),
              title: const Text('User Management'),
              children: <Widget>[
                ListTile(
                  title: const Text('View All Users'),
                  onTap: () {
                    // Handle 'View All Users' action
                  },
                ),
                ListTile(
                  title: const Text('Add New User'),
                  onTap: () {
                    // Handle 'Add New User' action
                  },
                ),
                ListTile(
                  title: const Text('Edit User Roles'),
                  onTap: () {
                    // Handle 'Edit User Roles' action
                  },
                ),
              ],
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              selected: _selectedIndex == 3,
              onTap: () {
                _onItemTapped(3);
                Navigator.pop(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfilePage()),
                );
              },
            ),
          ],
        ),
      ),
      body: Row(
        children: [
          // Main content area
          Expanded(
            child: _currentPosition == null
                ? const Center(child: CircularProgressIndicator())
                : LocationMap(currentPosition: _currentPosition!, mapController: _mapController),
          ),

          // Side panel for admin controls (optional)
          if (_selectedIndex == 1) // Show only for Location Tracking
            Container(
              width: 300,
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                border: Border(left: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Location Tracking',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Current Location'),
                            Text(
                              _currentPosition != null
                                  ? '${_currentPosition!.latitude.toStringAsFixed(6)}, ${_currentPosition!.longitude.toStringAsFixed(6)}'
                                  : 'Unknown',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Send Location to Server'),
                    value: state,
                    onChanged: (value) {
                      setState(() {
                        state = value;
                      });
                      if (value) {
                        sendLocationToApi();
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: moveToCurrentLocation,
                    icon: const Icon(Icons.my_location),
                    label: const Text('Center on My Location'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}