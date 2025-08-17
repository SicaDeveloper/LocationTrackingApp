import 'package:flutter/material.dart';
import 'package:locationtrackingapp/pages/Home.dart';
import 'package:locationtrackingapp/pages/Login.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';

// ----------------------------------------------------
// 1. Declare GoogleSignIn as a top-level variable here.
//    This makes it accessible throughout the app.
//    Replace 'YOUR_GOOGLE_CLIENT_ID' with your actual ID.
// ----------------------------------------------------
final GoogleSignIn googleSignIn = GoogleSignIn(
  clientId: 'YOUR_GOOGLE_CLIENT_ID',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://oscapbqjirbscyhjmhjm.supabase.co',
    anonKey: 'sb_publishable_RGxXT9799AFwMCHJzxrvVg_Przqx5r5',
  );

  runApp(const MyApp());
}

final supabaseClient = Supabase.instance.client;

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // ----------------------------------------------------
    // 2. This is the new part! We call signInSilently() here.
    //    It only runs once when the app starts up.
    // ----------------------------------------------------
    googleSignIn.signInSilently().catchError((error) {
      debugPrint("Google silent sign-in error (this can be normal): $error");
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: StreamBuilder<AuthState>(
        stream: supabaseClient.auth.onAuthStateChange,
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
