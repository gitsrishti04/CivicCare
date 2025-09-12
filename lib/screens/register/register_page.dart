import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:civic_care/constants/api_constants.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // NOTE: no trailing slash to avoid double '//' when concatenating paths
  // final String baseUrl = "https://cca88b0175fe.ngrok-free.app";

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  final FlutterSecureStorage storage = const FlutterSecureStorage();
  final Dio dio = Dio();

  bool _isLoading = false;
  bool _isLocating = false;

  double? _latitude;
  double? _longitude;

  String _endpoint(String path) => "$baseUrl$path";

  // ---------------- Location + Reverse Geocoding ----------------

  Future<void> _getCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnack("Location services are disabled. Please enable and retry.");
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        _showSnack("Location permission denied. Please allow and try again.");
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _latitude = position.latitude;
      _longitude = position.longitude;

      final humanReadable = await _reverseGeocode(
        position.latitude,
        position.longitude,
      );
      setState(() {
        _addressController.text =
            humanReadable ??
            "Lat: ${position.latitude}, Lng: ${position.longitude}";
      });
    } catch (e) {
      _showSnack("Error fetching location: $e");
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  /// Reverse geocode with plugin on mobile/desktop; HTTP fallback on web.
  Future<String?> _reverseGeocode(double lat, double lng) async {
    try {
      if (!kIsWeb) {
        final placemarks = await placemarkFromCoordinates(lat, lng);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          return [
            p.street,
            p.subLocality,
            p.locality,
            p.administrativeArea,
            p.postalCode,
          ].where((e) => (e != null && e.trim().isNotEmpty)).join(", ");
        }
        return null;
      } else {
        // Web fallback via Nominatim (OpenStreetMap).
        // NOTE: On some hosts, CORS may block this. We handle failure gracefully.
        final res = await dio.get(
          "https://nominatim.openstreetmap.org/reverse",
          queryParameters: {
            "format": "jsonv2",
            "lat": lat.toString(),
            "lon": lng.toString(),
            "zoom": "18",
            "addressdetails": "1",
          },
          options: Options(
            headers: {
              "User-Agent": "civic-app/1.0 (contact: youremail@example.com)",
              "Accept": "application/json",
            },
          ),
        );
        if (res.statusCode == 200 &&
            res.data is Map &&
            res.data["display_name"] != null) {
          return res.data["display_name"] as String;
        }
        return null;
      }
    } catch (_) {
      // If reverse geocoding fails (e.g., CORS on web), return null so UI degrades nicely.
      return null;
    }
  }

  // ---------------- Registration + Auto Login ----------------

  Future<void> _handleRegister() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    final isNumeric = int.tryParse(phone) != null;
    final nameRegExp = RegExp(r"^[a-zA-Z\s]{3,}$");
    final emailRegExp = RegExp(
      r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$",
    );

    if (name.isEmpty ||
        email.isEmpty ||
        phone.isEmpty ||
        _latitude == null ||
        _longitude == null ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      _showSnack(
        "All fields are required (including location). Tap the location icon to autofill address.",
      );
      return;
    }
    if (!nameRegExp.hasMatch(name)) {
      _showSnack("Enter a valid name (min 3 letters).");
      return;
    }
    if (!emailRegExp.hasMatch(email)) {
      _showSnack("Enter a valid email.");
      return;
    }
    if (phone.length != 10 || !isNumeric) {
      _showSnack("Enter a valid 10-digit phone number.");
      return;
    }
    if (password.length < 6) {
      _showSnack("Password must be at least 6 characters long.");
      return;
    }
    if (password != confirmPassword) {
      _showSnack("Passwords do not match.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Registration
      final regResponse = await dio.post(
        "${baseUrl}/core/register/",
        data: {
          "name": name,
          "email": email,
          "phone_number": phone,
          "password": password,
          // Send only coordinates to backend (address is for display)
          "latitude": _latitude,
          "longitude": _longitude,
        },
        options: Options(headers: {"Content-Type": "application/json"}),
      );

      if (!mounted) return;

      if (regResponse.statusCode == 201) {
        // Auto-login
        final loginResponse = await dio.post(
          _endpoint("/core/api/token/"),
          data: {"phone_number": phone, "password": password},
          options: Options(headers: {"Content-Type": "application/json"}),
        );

        if (loginResponse.statusCode == 200 ||
            loginResponse.statusCode == 201) {
          final accessToken = loginResponse.data['access'];
          final refreshToken = loginResponse.data['refresh'];

          if (accessToken != null && refreshToken != null) {
            await storage.write(key: 'access_token', value: accessToken);
            await storage.write(key: 'refresh_token', value: refreshToken);
            _showSnack("Registration & Login successful!");
            Navigator.pushReplacementNamed(context, "/home");
          } else {
            _showSnack("Login failed: tokens missing.");
          }
        } else {
          _showSnack("Login failed: ${loginResponse.statusCode}.");
        }
      } else {
        _showSnack(
          "Registration failed: ${regResponse.statusCode} ${regResponse.data}",
        );
      }
    } on DioException catch (e) {
      String message = "Request failed. Please try again.";
      if (e.response?.data is Map) {
        final data = e.response?.data as Map;
        message =
            data['detail']?.toString() ??
            data['message']?.toString() ??
            message;
      } else if (e.message != null) {
        message = e.message!;
      }
      _showSnack(message);
    } catch (e) {
      _showSnack("An error occurred: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------------- UI ----------------

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
              // Use a placeholder if asset missing to avoid crashes on web
              SizedBox(
                width: double.infinity,
                height: 150,
                child: Image.asset(
                  'assets/register.png',
                  height: 150,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(Icons.app_registration, size: 72),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _nameController,
                decoration: buildInputDecoration(
                  "Full Name",
                  Icons.person_outline,
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: buildInputDecoration("Email", Icons.mail_outline),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: buildInputDecoration(
                  "Phone Number",
                  Icons.phone_android,
                ),
              ),
              const SizedBox(height: 15),

              // Address (human-readable) + locate button
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _addressController,
                      readOnly: true,
                      decoration: buildInputDecoration(
                        "Address (auto-fetched for display)",
                        Icons.location_city,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _isLocating ? null : _getCurrentLocation,
                    icon: _isLocating
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location),
                    label: Text(_isLocating ? "Locating..." : "Locate"),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 15),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: buildInputDecoration(
                  "Password",
                  Icons.lock_outline,
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: buildInputDecoration(
                  "Confirm Password",
                  Icons.lock,
                ),
              ),
              const SizedBox(height: 25),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleRegister,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: Colors.blue.shade700,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        )
                      : const Text(
                          "Register",
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                ),
              ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Already have an account? "),
                  TextButton(
                    onPressed: () =>
                        Navigator.pushReplacementNamed(context, "/login"),
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
