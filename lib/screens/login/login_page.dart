import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_signin_button/flutter_signin_button.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final String baseUrl = "https://10.21.99.118:8000"; // 🔹 Replace with your server
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  static final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);
  final FlutterSecureStorage storage = const FlutterSecureStorage();

  final Dio dio = Dio();

  bool _isLoading = false;

  /// --- Login with mobile/password ---
  Future<void> _handleLogin(BuildContext context) async {
    final mobile = _mobileController.text.trim();
    final password = _passwordController.text.trim();

    final isNumeric = int.tryParse(mobile) != null;

    if (mobile.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter mobile & password")),
      );
      return;
    } else if (mobile.length != 10 || !isNumeric) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Please enter a valid 10-digit mobile number")),
      );
      return;
    } else if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Password must be at least 6 characters long")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await dio.post(
        '$baseUrl/core/api/token/', // Django endpoint for JWT login
        data: {
          "phone_number": mobile,
          "password": password,
        },
        options: Options(
          headers: {"Content-Type": "application/json"},
        ),
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        final accessToken = data['access'];
        final refreshToken = data['refresh'];

        if (accessToken != null && refreshToken != null) {
          await storage.write(key: 'access_token', value: accessToken);
          await storage.write(key: 'refresh_token', value: refreshToken);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Login successful!")),
          );

          Navigator.pushReplacementNamed(context, "/home");
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("Login successful, but tokens not received.")),
          );
        }
      } else {
        String errorMessage = "Invalid credentials or server error.";
        try {
          if (response.data is Map<String, dynamic>) {
            errorMessage = response.data['detail'] ??
                response.data['message'] ??
                "Invalid credentials.";
          }
        } catch (_) {}
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage)));
      }
    } on DioError catch (e) {
      String message = "Login failed. Please try again.";
      if (e.response != null) {
        message = e.response?.data['detail'] ??
            e.response?.data['message'] ??
            message;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("An error occurred: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// --- Google login ---
  Future<void> _handleGoogleSignUp(BuildContext context) async {
    setState(() => _isLoading = true);

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Google sign-in canceled")),
        );
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to get Google ID token")),
        );
        return;
      }

      final response = await dio.post(
        '$baseUrl/api/google-login/', // Django backend endpoint
        data: {"id_token": idToken},
        options: Options(
          headers: {"Content-Type": "application/json"},
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final accessToken = data['access'];
        final refreshToken = data['refresh'];

        if (accessToken != null && refreshToken != null) {
          await storage.write(key: 'access_token', value: accessToken);
          await storage.write(key: 'refresh_token', value: refreshToken);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Google login successful!")),
          );

          Navigator.pushReplacementNamed(context, "/home");
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Tokens not received from server")),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                "Google login failed: ${response.statusCode} ${response.statusMessage}"),
          ),
        );
      }
    } on DioError catch (e) {
      String message = "Google login failed. Please try again.";
      if (e.response != null) {
        message = e.response?.data['detail'] ??
            e.response?.data['message'] ??
            message;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("An error occurred: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: Image.asset('assets/CivicCare.png', fit: BoxFit.contain),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _mobileController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: InputDecoration(
                  labelText: "Mobile",
                  prefixIcon: const Icon(Icons.phone_android),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Password",
                  prefixIcon: const Icon(Icons.lock),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : () => _handleLogin(context),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: Colors.blue.shade700,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : const Text(
                          "Log In",
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                ),
              ),
              const SizedBox(height: 25),
              const Text("Or sign up with"),
              const SizedBox(height: 15),
              SignInButton(
                Buttons.Google,
                text: "Sign in with Google",
                onPressed: _isLoading ? null : () => _handleGoogleSignUp(context),
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account? "),
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, "/register");
                    },
                    child: const Text("Register"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
