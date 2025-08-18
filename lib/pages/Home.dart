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

class HomeProvider extends ChangeNotifier{
  bool sendingLocation = false;

  void setSendingLocation(bool value){
    sendingLocation = value;
    notifyListeners();
  }

  Position? currentPosition;

  void setCurrentPosition(Position value){
    currentPosition = value;
    notifyListeners();
  }

}

// Dedicated Map Widget ========================================================
class LocationMap extends StatefulWidget{
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
              // Use widget.currentPosition here as well.
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

// Main Home Page ==============================================================
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Position? _currentPosition;
  final MapController _mapController = MapController();
  StreamSubscription<Position>? _positionStream;
  @override
  void initState() {
    super.initState();
    _fetchCurrentLocation().then((_) {
      _listenToLocationUpdates();
    });
  }

  bool state = false;

  void moveToCurrentLocation() {
    if (_currentPosition != null) {
      _mapController.move(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        13.0,
      );
    } else {
      // Optional: show a message to the user that the location is not available
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

    if(state){
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location Being sent to Server')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stopped sending Location to Server')),
      );
    }

    while(state) {
      await Future.delayed(const Duration(minutes: 5));
      try{
        await authProvider.supabaseClient
            .from('locations')
            .upsert(locationData, onConflict: 'user_id');
      }
      catch(e) {
        if (kDebugMode) {
          print(e);
        }
      }
    }
  }


  void _listenToLocationUpdates(){

    const locationSettings = LocationSettings(
      accuracy:LocationAccuracy.high,
      distanceFilter: 20
    );

    _positionStream = Geolocator.getPositionStream(
    locationSettings: locationSettings).listen(
      (Position position) {
        if(mounted) {
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
  void dispose() {
    _positionStream?.cancel(); // stop listening when page is disposed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: const Icon(Icons.home),
              onPressed: moveToCurrentLocation,
            ),
            IconButton(
              icon: const Icon(Icons.location_on),
              onPressed: moveToCurrentLocation,
            ),
            const SizedBox(width: 20),
            IconButton(
              icon: const Icon(Icons.share_location_outlined),
              onPressed: sendLocationToApi,
            ),
            IconButton(
              icon: const Icon(Icons.logout_outlined),
              onPressed: () => GoogleSignInPageState().signOut(),
            )
          ],
        ),
      ),
      floatingActionButton: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          ClipOval(
            child: Material(
              color: const Color(0xFF7861FF),
              elevation: 6,
              child: InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfilePage()),
                ),
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
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: state? Colors.green : Colors.red,
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
          : LocationMap(currentPosition: _currentPosition!, mapController: _mapController), // Using the new map widget
    );
  }
}

