import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import 'package:civic_care/constants/api_constants.dart';
import 'package:civic_care/constants/api_service.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

class RegisterComplaintScreen extends StatefulWidget {
  const RegisterComplaintScreen({super.key});

  @override
  State<RegisterComplaintScreen> createState() =>
      _RegisterComplaintScreenState();
}

class _RegisterComplaintScreenState extends State<RegisterComplaintScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  List<Map<String, dynamic>> _complaintCategories = [];
  bool _isLoadingCategories = true;

  Map<String, dynamic>? _selectedCategory;
  Map<String, dynamic>? _selectedSubcategory;
  Set<Map<String, String>> _selectedItems = {};
  Map<String, int>? _selectedItemsId;

  File? _selectedImage;
  Uint8List? _selectedWebImage;

  bool _isLoadingLocation = false;
  double? _latitude;
  double? _longitude;

  final Dio _dio = ApiClient().dio;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _fetchComplaintCategories();
  }

  Future<void> _fetchComplaintCategories() async {
    try {
      final response = await _dio.get(
        "${baseUrl}core/dropdown/",
        queryParameters: {'uuid': uuid},
      );

      if (response.statusCode == 200) {
        // Parse the response into nested categories
        List<Map<String, dynamic>> categories = [];
        for (var category in response.data) {
          categories.add({
            'id': category['id'],
            'category': category['category'],
            'sub_category': List<Map<String, dynamic>>.from(
              category['sub_category'].map(
                (sub) => {
                  'id': sub['id'],
                  'category': sub['category'],
                  'sub_category': sub['sub_category'] != null
                      ? List<Map<String, dynamic>>.from(sub['sub_category'])
                      : [],
                },
              ),
            ),
          });
        }
        debugPrint("Fetched categories: $categories");
        setState(() {
          _complaintCategories = categories;
          _isLoadingCategories = false;
        });
      }
    } catch (e) {
      setState(() => _isLoadingCategories = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to load categories: $e")));
    }
  }

  Future<String> _getAddressFromLatLng(double lat, double lon) async {
    final url =
        "https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon";
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {"User-Agent": "civic_care_app"},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data["display_name"];
        return "($lat, $lon) - $address";
      }
    } catch (e) {
      return "($lat, $lon)";
    }
    return "($lat, $lon)";
  }

  Future<void> _submitComplaint() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select category and subcategory"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final title = _titleController.text.trim();
      final description = _descriptionController.text.trim();
      final address = _addressController.text.trim();
      debugPrint("Submitting complaint:$_selectedItems");

      final formData = FormData.fromMap({
        "title": title,
        "description": description,
        "longitude": _longitude?.toString() ?? "",
        "latitude": _latitude?.toString() ?? "",
        "address": address,
        "category": _selectedItemsId?['category'].toString(),
      });

      if (!kIsWeb && _selectedImage != null) {
        formData.files.add(
          MapEntry("image", await MultipartFile.fromFile(_selectedImage!.path)),
        );
      } else if (kIsWeb && _selectedWebImage != null) {
        formData.files.add(
          MapEntry(
            "image",
            MultipartFile.fromBytes(
              _selectedWebImage!,
              filename: "complaint.jpg",
            ),
          ),
        );
      }

      final response = await _dio.post(
        "${baseUrl}core/complaint/",
        data: formData,
      );

      if (!mounted) return;
      Navigator.of(context).pop();

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Complaint submitted successfully!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to submit complaint: ${response.data}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _latitude = position.latitude;
      _longitude = position.longitude;

      // reverse geocode
      final formattedAddress = await _getAddressFromLatLng(
        _latitude!,
        _longitude!,
      );

      setState(() {
        _isLoadingLocation = false;
        _addressController.text = formattedAddress;
      });

      // Move map
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(LatLng(_latitude!, _longitude!), 16);
      });
    } catch (e) {
      setState(() => _isLoadingLocation = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to get location: $e")));
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      if (kIsWeb) {
        Uint8List bytes = await pickedFile.readAsBytes();
        setState(() {
          _selectedWebImage = bytes;
          _selectedImage = null;
        });
      } else {
        setState(() {
          _selectedImage = File(pickedFile.path);
          _selectedWebImage = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Register Complaint")),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInputField(
                      label: "Complaint Title",
                      controller: _titleController,
                      isRequired: true,
                    ),
                    const SizedBox(height: 16),
                    _buildInputField(
                      label: "Complaint Description",
                      controller: _descriptionController,
                      maxLines: 4,
                      isRequired: true,
                    ),
                    const SizedBox(height: 16),

                    // ✅ Category + Subcategory
                    Text(
                      "Complaint Category",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _isLoadingCategories
                        ? const Center(child: CircularProgressIndicator())
                        : Column(
                            children: [
                              DropdownButtonFormField<Map<String, dynamic>>(
                                decoration: const InputDecoration(
                                  labelText: "Select Category",
                                  border: OutlineInputBorder(),
                                ),
                                value: _selectedCategory,
                                items: _complaintCategories.map((category) {
                                  return DropdownMenuItem(
                                    value: category,
                                    child: Text(category['category']),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedCategory = value;
                                    _selectedSubcategory = null;
                                  });
                                },
                              ),
                              const SizedBox(height: 12),
                              if (_selectedCategory != null)
                                DropdownButtonFormField<Map<String, dynamic>>(
                                  decoration: const InputDecoration(
                                    labelText: "Select Subcategory",
                                    border: OutlineInputBorder(),
                                  ),
                                  value: _selectedSubcategory,
                                  items:
                                      List<Map<String, dynamic>>.from(
                                        _selectedCategory?['sub_category'] ??
                                            [],
                                      ).map((subcat) {
                                        return DropdownMenuItem(
                                          value: subcat,
                                          child: Text(subcat['category']),
                                        );
                                      }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedSubcategory = value;
                                      _selectedItemsId = {
                                        "category":
                                            _selectedSubcategory?['id'] ?? 31,
                                      };
                                      _selectedItems = {
                                        {
                                          "category":
                                              _selectedCategory?['category'] ??
                                              "",
                                          "sub_category":
                                              _selectedSubcategory?['category'] ??
                                              "",
                                        },
                                      };
                                    });
                                  },
                                ),
                            ],
                          ),
                    if (_selectedItems.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.blueAccent),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _selectedItems
                              .map(
                                (e) =>
                                    "${e['category']} - ${e['sub_category']}",
                              )
                              .join(", "),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // ✅ Map
                    SizedBox(
                      height: 200,
                      child: FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: LatLng(
                            _latitude ?? 28.7041,
                            _longitude ?? 77.1025,
                          ),
                          initialZoom: _latitude != null ? 16 : 13,
                          interactionOptions: const InteractionOptions(
                            flags:
                                InteractiveFlag.pinchZoom |
                                InteractiveFlag.drag,
                          ),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                            subdomains: const ['a', 'b', 'c'],
                            userAgentPackageName: 'com.example.civic_care',
                          ),
                          if (_latitude != null && _longitude != null)
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: LatLng(_latitude!, _longitude!),
                                  width: 60,
                                  height: 60,
                                  child: const Icon(
                                    Icons.location_on,
                                    size: 40,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    OutlinedButton.icon(
                      onPressed: _isLoadingLocation
                          ? null
                          : _getCurrentLocation,
                      icon: const Icon(Icons.my_location),
                      label: Text(
                        _isLoadingLocation
                            ? "Getting location..."
                            : "Use Current Location",
                      ),
                    ),
                    const SizedBox(height: 8),

                    TextFormField(
                      controller: _addressController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: "Address",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildAttachmentSection(),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: _submitComplaint,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: const Text("Submit Complaint"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    int maxLines = 1,
    bool isRequired = false,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: isRequired
          ? (value) => (value == null || value.trim().isEmpty)
                ? "$label is required"
                : null
          : null,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _buildAttachmentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Attach Photo",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: _selectedImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(_selectedImage!, fit: BoxFit.cover),
                  )
                : _selectedWebImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(_selectedWebImage!, fit: BoxFit.cover),
                  )
                : const Center(child: Icon(Icons.add_a_photo, size: 40)),
          ),
        ),
      ],
    );
  }
}
