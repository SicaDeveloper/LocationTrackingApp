import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:locationtrackingapp/pages/Home.dart';
import 'package:locationtrackingapp/pages/Login.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


// Your provider class to manage authentication state
class AuthProvider with ChangeNotifier {
  final SupabaseClient _supabaseClient = Supabase.instance.client;

  SupabaseClient get supabaseClient => _supabaseClient;
}

// A new widget to handle the asynchronous initialization
class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  // A state variable to track if Supabase is initialized
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    // Start the asynchronous initialization in initState
    _initializeSupabase();
  }

  Future<void> _initializeSupabase() async {
    try {
      // Supabase initialization call
      await Supabase.initialize(
        url: dotenv.env["SUPABASEBASEURL"]!,
        anonKey: dotenv.env["SUPABASEANONKEY"]!,
      );
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      // Handle initialization errors gracefully
      if (kDebugMode) {
        print('Error initializing Supabase: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitialized) {
      // If initialized, show the main app wrapped in the AuthProvider
      return ChangeNotifierProvider(
        create: (context) => AuthProvider(),
        child: const MyApp(),
      );
    } else {
      // If not initialized, show a loading indicator
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }
  }
}

Future<void> main() async {

  WidgetsFlutterBinding.ensureInitialized();
  // We no longer call Supabase.initialize here
  await dotenv.load(fileName: ".env");
  runApp(const AppInitializer());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: StreamBuilder<AuthState>(
        stream: authProvider.supabaseClient.auth.onAuthStateChange,
        builder: (context, snapshot) {
          // Show a loading indicator while waiting for the auth state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final session = snapshot.data?.session;
          if (session != null) {
            return const HomePage(); // User is logged in
          } else {
            return const LoginPage(); // User is not logged in
          }
        },
      ),
    );
  }
}
