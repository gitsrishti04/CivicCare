import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import 'package:civic_care/constants/api_constants.dart';
import 'package:civic_care/constants/api_service.dart'; // ✅ ApiClient

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

  Map<String, dynamic>? _selectedComplaintCategory;
  List<Map<String, dynamic>> _complaintCategory = [];

  File? _selectedImage; // for mobile
  Uint8List? _selectedWebImage; // for web

  bool _isLoadingLocation = false;
  String _currentAddress = '';
  bool _isLoadingTypes = true;

  double? _latitude;
  double? _longitude;

  final Dio _dio = ApiClient().dio; // ✅ use ApiClient

  @override
  void initState() {
    super.initState();
    _fetchComplaintCategory();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _fetchComplaintCategory() async {
    try {
      final response = await _dio.get(
        "${baseUrl}core/dropdown/",
        queryParameters: {"uuid": uuid},
      );

      if (response.statusCode == 200) {
        List<dynamic> data = response.data;
        setState(() {
          _complaintCategory = data
              .map<Map<String, dynamic>>(
                (e) => {"id": e["id"], "label": e["label"]},
              )
              .toList();
          _isLoadingTypes = false;
        });
      } else {
        setState(() {
          _complaintCategory = [];
          _isLoadingTypes = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to fetch complaint types"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _complaintCategory = [];
        _isLoadingTypes = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error fetching complaint types: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _submitComplaint() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final title = _titleController.text.trim();
      final description = _descriptionController.text.trim();
      final address = _addressController.text.trim().isNotEmpty
          ? _addressController.text.trim()
          : _currentAddress;

      final formData = FormData.fromMap({
        "title": title,
        "description": description,
        "longitude": _longitude?.toString() ?? "",
        "latitude": _latitude?.toString() ?? "",
        "address": address,
        "category": _selectedComplaintCategory?["id"].toString() ?? "",
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
      Navigator.of(context).pop(); // close loader

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Complaint submitted successfully!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(); // go back
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
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _isLoadingLocation = false;
        _addressController.text = "Lat: $_latitude, Lon: $_longitude";
      });
    } catch (e) {
      setState(() => _isLoadingLocation = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to get location: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickImage() async {
  final ImagePicker picker = ImagePicker();

  showDialog(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text("Choose Image Source"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text("Gallery"),
              onTap: () async {
                Navigator.of(ctx).pop();
                final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);
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
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text("Camera"),
              onTap: () async {
                Navigator.of(ctx).pop();
                final XFile? pickedFile = await picker.pickImage(source: ImageSource.camera);
                if (pickedFile != null) {
                  setState(() {
                    _selectedImage = File(pickedFile.path);
                    _selectedWebImage = null; // no camera on web
                  });
                }
              },
            ),
          ],
        ),
      );
    },
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          "Register Complaint",
          style: TextStyle(color: Colors.black, fontSize: 18),
        ),
      ),
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
                    const SizedBox(height: 20),
                    _buildAddressSection(),
                    const SizedBox(height: 20),
                    _buildComplaintTypeDropdown(),
                    const SizedBox(height: 20),
                    _buildAttachmentSection(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Colors.orange),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        "Cancel",
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submitComplaint,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        "Submit",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            children: isRequired
                ? [
                    const TextSpan(
                      text: " *",
                      style: TextStyle(color: Colors.red),
                    ),
                  ]
                : [],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: isRequired
              ? (value) => (value == null || value.trim().isEmpty)
                    ? "$label is required"
                    : null
              : null,
          decoration: InputDecoration(
            fillColor: Colors.white,
            filled: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddressSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: _isLoadingLocation ? null : _getCurrentLocation,
          icon: _isLoadingLocation
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.my_location, color: Colors.blue),
          label: Text(
            _isLoadingLocation ? "Getting Location..." : "Use Current Location",
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _addressController,
          maxLines: 3,
          validator: (value) {
            if ((value == null || value.trim().isEmpty) &&
                _currentAddress.isEmpty) {
              return "Address is required";
            }
            return null;
          },
          decoration: InputDecoration(
            hintText: _currentAddress.isEmpty
                ? "Enter address"
                : _currentAddress,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Widget _buildComplaintTypeDropdown() {
    if (_isLoadingTypes) {
      return const Center(child: CircularProgressIndicator());
    }
    return DropdownButtonFormField<Map<String, dynamic>>(
      value: _selectedComplaintCategory,
      decoration: InputDecoration(
        labelText: "Complaint Category *",
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: Colors.white,
      ),
      items: _complaintCategory
          .map(
            (cat) => DropdownMenuItem<Map<String, dynamic>>(
              value: cat,
              child: Text(cat["label"]),
            ),
          )
          .toList(),
      onChanged: (value) => setState(() => _selectedComplaintCategory = value),
      validator: (value) =>
          value == null ? "Please select complaint category" : null,
    );
  }

  Widget _buildAttachmentSection() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        "Attach Photo",
        style: TextStyle(fontWeight: FontWeight.w500),
      ),
      const SizedBox(height: 8),
      GestureDetector(
        onTap: _pickImage,
        child: Container(
          width: double.infinity,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Center(
            child: _selectedImage != null
                ? Image.file(_selectedImage!, fit: BoxFit.cover)
                : _selectedWebImage != null
                    ? Image.memory(_selectedWebImage!, fit: BoxFit.cover)
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add, size: 40, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text(
                            "Upload Photo",
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
            ),
          ),
        ),
      ],
    );
  }
}
