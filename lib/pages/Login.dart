import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Added import

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
      ),
      body: const Center(
        child: GoogleSignInPage()
      ),
    );
  }
}

class GoogleSignInPage extends StatefulWidget {
  const GoogleSignInPage({super.key});

  @override
  State createState() => GoogleSignInPageState();
}

class GoogleSignInPageState extends State<GoogleSignInPage> {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
    serverClientId: '540601564447-76guf1lu820nedop78npcm89avt7ic8v.apps.googleusercontent.com', // Or webClientId
  );

  GoogleSignInAccount? _currentUser;
  // Get a reference to the Supabase client
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) async {
      if (!mounted) return; // Check if the widget is still in the tree

      setState(() {
        _currentUser = account;
      });

      if (account != null) {
        // User signed in with Google, now sign in to Supabase
        try {
          final googleAuth = await account.authentication;
          final idToken = googleAuth.idToken;
          final accessToken = googleAuth.accessToken;

          if (idToken == null) {
            debugPrint('Google Sign-In: ID token is null. Supabase sign-in skipped.');
            // Sign out from Google to ensure a clean state if ID token is unexpectedly null
            await _googleSignIn.signOut();
            setState(() { _currentUser = null; });
            return;
          }

          // Sign in to Supabase with the Google ID token.
          // This will trigger onAuthStateChange in main.dart if successful.
          await supabase.auth.signInWithIdToken(
            provider: OAuthProvider.google,
            idToken: idToken,
            accessToken: accessToken, // Pass access token if available/needed
          );
          // Navigation to HomePage will be handled by main.dart's StreamBuilder
        } catch (e) {
          if (mounted) {
            debugPrint('Error signing into Supabase with Google: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error signing into Supabase: ${e.toString()}')),
            );
            // If Supabase sign-in fails, sign out from Google to allow a clean retry.
            await _googleSignIn.signOut();
            setState(() { _currentUser = null; });
          }
        }
      } else {
        // User signed out from Google.
        // The _handleSignOut method should ensure Supabase is also signed out.
        // This block primarily ensures UI reflects Google's signed-out state.
      }
    });
  }

  Future<void> _handleSignIn() async {
    try {
      // Initiates the Google Sign In flow.
      // The onCurrentUserChanged listener will then handle the Supabase sign-in part.
      await _googleSignIn.signIn();
    } catch (error) {
      if (mounted) {
        debugPrint('Error initiating Google Sign-In: $error');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google Sign-In failed: ${error.toString()}')),
        );
      }
    }
  }

  Future<void> _handleSignOut() async {
    try {
      // Sign out from Supabase first.
      await supabase.auth.signOut();
    } catch (e) {
      debugPrint('Error signing out from Supabase: $e');
      // Optionally show error to user, but still attempt Google sign out.
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error during Supabase sign-out: ${e.toString()}')),
        );
      }
    }
    try {
      // Then, sign out from Google.
      await _googleSignIn.signOut();
      // Using disconnect() is more thorough if you want to ensure the user
      // has to re-select their account next time.
      // await _googleSignIn.disconnect();
    } catch (e) {
      debugPrint('Error signing out from Google: $e');
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error during Google sign-out: ${e.toString()}')),
        );
      }
    }
    // The onCurrentUserChanged listener will set _currentUser to null, updating the UI.
  }

  Future<void> signOut() async {
    await _handleSignOut();
  }

  Future<void> silentSignIn() async {
    await _googleSignIn.signInSilently().catchError((error) {
      // It's normal for signInSilently to fail if there's no previous session.
      debugPrint("Google silent sign-in error (this can be normal): $error");
    });
  }

  @override
  Widget build(BuildContext context) {
    // The UI reflects the Google sign-in state.
    // Navigation is handled by Supabase auth state in main.dart.
    final GoogleSignInAccount? displayUser = _currentUser;

    if (displayUser != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          CircleAvatar(
            backgroundImage: displayUser.photoUrl != null
                ? NetworkImage(displayUser.photoUrl!)
                : null,
            radius: 50,
          ),
          const SizedBox(height: 16),
          Text('Welcome, ${displayUser.displayName ?? ''}!'),
          const SizedBox(height: 8),
          Text('Email: ${displayUser.email}'),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _handleSignOut,
            child: const Text('Sign Out'),
          ),
        ],
      );
    } else {
      return InkWell(
        onTap: _handleSignIn,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                spreadRadius: 1,
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Image.network( // Consider bundling this image or using a more robust solution
                'http://pngimg.com/uploads/google/google_PNG19635.png',
                height: 24,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 10.0),
              const Text(
                'Sign-in with Google',
                style: TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w500,
                  fontSize: 16.0,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
}
