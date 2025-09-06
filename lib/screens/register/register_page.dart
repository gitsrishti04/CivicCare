import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final String baseUrl = "https://cca88b0175fe.ngrok-free.app/"; // Replace with your server

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  final FlutterSecureStorage storage = const FlutterSecureStorage();
  final Dio dio = Dio();

  bool _isLoading = false;

  /// --- Register + Auto JWT Login ---
  Future<void> _handleRegister() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    final isNumeric = int.tryParse(phone) != null;
    final nameRegExp = RegExp(r"^[a-zA-Z\s]{3,}$");
    final emailRegExp = RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$");

    if (name.isEmpty ||
        email.isEmpty ||
        phone.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("All fields are required")),
      );
      return;
    } else if (!nameRegExp.hasMatch(name)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter a valid name (min 3 letters)")),
      );
      return;
    } else if (!emailRegExp.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter a valid email")),
      );
      return;
    } else if (phone.length != 10 || !isNumeric) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter a valid 10-digit phone number")),
      );
      return;
    } else if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password must be at least 6 characters long")),
      );
      return;
    } else if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwords do not match")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Registration API
      final regResponse = await dio.post(
        '$baseUrl/core/register/',
        data: {
          "name": name,
          "email": email,
          "phone_number": phone,
          "password": password,
        },
        options: Options(headers: {"Content-Type": "application/json"}),
      );

      if (!mounted) return;

      if (regResponse.statusCode == 201) {
        // Auto-login after registration
        final loginResponse = await dio.post(
          '$baseUrl/core/api/token/',
          data: {"phone_number": phone, "password": password},
          options: Options(headers: {"Content-Type": "application/json"}),
        );

        if (loginResponse.statusCode == 200 || loginResponse.statusCode == 201) {
          final accessToken = loginResponse.data['access'];
          final refreshToken = loginResponse.data['refresh'];

          if (accessToken != null && refreshToken != null) {
            await storage.write(key: 'access_token', value: accessToken);
            await storage.write(key: 'refresh_token', value: refreshToken);

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Registration & Login successful!")),
            );

            Navigator.pushReplacementNamed(context, "/home");
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Registration failed: ${regResponse.data}")),
        );
      }
    } on DioError catch (e) {
      String message = "Registration failed. Please try again.";
      if (e.response != null) {
        message = e.response?.data['detail'] ?? e.response?.data['message'] ?? message;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("An error occurred: $e")),
      );
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
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: Image.asset('assets/register.png', height: 150),
              ),
              const SizedBox(height: 20),
              TextField(controller: _nameController, decoration: buildInputDecoration("Full Name", Icons.person_outline)),
              const SizedBox(height: 15),
              TextField(controller: _emailController, keyboardType: TextInputType.emailAddress, decoration: buildInputDecoration("Email", Icons.mail_outline)),
              const SizedBox(height: 15),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                decoration: buildInputDecoration("Phone Number", Icons.phone_android),
              ),
              const SizedBox(height: 15),
              TextField(controller: _passwordController, obscureText: true, decoration: buildInputDecoration("Password", Icons.lock_outline)),
              const SizedBox(height: 15),
              TextField(controller: _confirmPasswordController, obscureText: true, decoration: buildInputDecoration("Confirm Password", Icons.lock)),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleRegister,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    backgroundColor: Colors.blue.shade700,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      : const Text("Register", style: TextStyle(fontSize: 16, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 20),
              // --- Row for existing users ---
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Already have an account? "),
                  TextButton(
                    onPressed: () => Navigator.pushReplacementNamed(context, "/login"),
                    child: const Text("Login"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration buildInputDecoration(String labelText, IconData icon) {
    return InputDecoration(
      labelText: labelText,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.grey[100],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }
}
