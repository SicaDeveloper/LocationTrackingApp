import 'package:flutter/material.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    // The Scaffold provides the basic visual layout structure of the app.
    return Scaffold(
      // The AppBar is the top bar of the screen.
      appBar: AppBar(
        title: const Text('Profile'),
        titleTextStyle:  const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        foregroundColor: Colors.white,
        backgroundColor: Colors.blueAccent,
        elevation: 0, // Removes the shadow under the app bar.
      ),
      // The body contains the main content of the screen.
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            // Center the content vertically within the column.
            mainAxisAlignment: MainAxisAlignment.center,
            // Stretch the widgets horizontally to fill the space.
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // A circular image for the user's profile picture.
              const CircleAvatar(
                radius: 60,
                backgroundColor: Colors.blueAccent,
                child: Icon(
                  Icons.person,
                  size: 72,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              // The user's name.
              const Text(
                'John Doe',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              // A brief description or bio.
              Text(
                'Software Developer & Flutter Enthusiast',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              // A button to edit the profile.
              ElevatedButton.icon(
                onPressed: () {
                  // TODO: Implement navigation to an edit profile page.
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Edit Profile Pressed')),
                  );
                },
                icon: const Icon(Icons.edit),
                label: const Text('Edit Profile'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(200, 50),
                ),
              ),
              const SizedBox(height: 10),
              // A button to log out.
              OutlinedButton.icon(
                onPressed: () {
                  // TODO: Implement logout functionality.
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Log Out Pressed')),
                  );
                },
                icon: const Icon(Icons.logout),
                label: const Text('Log Out'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(200, 50),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
