// nearby_complaints_page.dart
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:civic_care/constants/api_service.dart';
import 'package:civic_care/constants/api_constants.dart';

class NearbyComplaintsPage extends StatefulWidget {
  const NearbyComplaintsPage({super.key});

  @override
  State<NearbyComplaintsPage> createState() => _NearbyComplaintsPageState();
}

class _NearbyComplaintsPageState extends State<NearbyComplaintsPage> {
  final Dio _dio = ApiClient().dio;

  bool _isLoading = false;
  String? _error;
  List<Complaint> _complaints = [];

  @override
  void initState() {
    super.initState();
    _fetchComplaints();
  }

  Future<void> _fetchComplaints() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _dio.get(
        "${baseUrl}core/complaint/",
        options: Options(headers: {"Accept": "application/json"}),
      );

      final data = response.data;
      List<Complaint> newComplaints = [];
      if (data is List) {
        newComplaints = data.map((e) => Complaint.fromJson(e)).toList();
      }

      setState(() {
        _complaints = newComplaints;
      });
    } on DioException catch (e) {
      String msg = "Failed to fetch complaints.";
      if (e.response != null) {
        msg = "Server: ${e.response?.statusCode} ${e.response?.statusMessage}";
      } else {
        msg = e.message ?? msg;
      }
      setState(() => _error = msg);
    } catch (e) {
      setState(() => _error = "Error: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _onRefresh() async {
    await _fetchComplaints();
  }

  Future<void> _toggleUpvote(Complaint complaint) async {
    try {
      await _dio.put(
        "${baseUrl}core/complaint/",
        data: {
          "id": complaint.id,
        },
        options: Options(headers: {"Accept": "application/json"}),
      );
      await _fetchComplaints();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to update. Try again.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Complaints Feed"),
        actions: [
          IconButton(
            tooltip: "Refresh complaints",
            onPressed: () async => await _fetchComplaints(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext ctx) {
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
          Center(
            child: ElevatedButton.icon(
              onPressed: () => _fetchComplaints(),
              icon: const Icon(Icons.refresh),
              label: const Text("Retry"),
            ),
          ),
        ],
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_complaints.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          Center(
            child: Text(
              "No complaints found.",
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      itemCount: _complaints.length,
      itemBuilder: (context, index) {
        return ComplaintCard(
          complaint: _complaints[index],
          onToggleUpvote: () => _toggleUpvote(_complaints[index]),
        );
      },
    );
  }
}

// ---------------- Complaint model ----------------

class Complaint {
  final String id;
  final String title;
  final String description;
  final String? imageUrl;
  final String? address;
  final DateTime createdAt;
  final bool upvoted;
  final int upvoteCount;

  Complaint({
    required this.id,
    required this.title,
    required this.description,
    this.imageUrl,
    this.address,
    required this.createdAt,
    required this.upvoted,
    required this.upvoteCount,
  });

  factory Complaint.fromJson(Map<String, dynamic> json) {
    DateTime created;
    try {
      created = DateTime.parse(
        json['created_at'] ??
            json['createdAt'] ??
            json['timestamp'] ??
            DateTime.now().toIso8601String(),
      );
    } catch (_) {
      created = DateTime.now();
    }

    return Complaint(
      id: (json['id'] ?? json['pk'] ?? "").toString(),
      title: (json['title'] ?? json['headline'] ?? "No title").toString(),
      description: (json['description'] ?? json['desc'] ?? "").toString(),
      imageUrl: json['image'],
      address: (json['address'] ?? json['location_text'])?.toString(),
      createdAt: created,
      upvoted: json['upvoted'] ?? false,
      upvoteCount: json['total_upvotes'] ?? 0,
    );
  }
}

// ---------------- UI Card ----------------

class ComplaintCard extends StatelessWidget {
  final Complaint complaint;
  final VoidCallback onToggleUpvote;
  const ComplaintCard({required this.complaint, required this.onToggleUpvote, super.key});

  String _formatDate(DateTime dt) {
    final date = DateFormat.yMMMd().format(dt);
    final time = DateFormat.Hm().format(dt);
    return "$date · $time";
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImage(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    complaint.title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    complaint.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                  if (complaint.address != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on,
                              size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              complaint.address!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.black54),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(complaint.createdAt),
                    style:
                        const TextStyle(fontSize: 11, color: Colors.black45),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        onPressed: onToggleUpvote,
                        icon: Icon(
                          complaint.upvoted
                              ? Icons.thumb_down
                              : Icons.thumb_up,
                          size: 16,
                        ),
                        label: Text(
                            complaint.upvoted ? "Downvote" : "Upvote"),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 3),
                          textStyle: const TextStyle(fontSize: 12),
                          backgroundColor: complaint.upvoted
                              ? Colors.red
                              : Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "${complaint.upvoteCount}",
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (complaint.imageUrl == null || complaint.imageUrl!.isEmpty) {
      return _fallbackImage();
    }

    final imageUrl = complaint.imageUrl!.startsWith("http")
        ? complaint.imageUrl!
        : "$baseUrl${complaint.imageUrl}";

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 110,
        height: 90,
        child: Image.network(
          imageUrl,
          headers: {
            "ngrok-skip-browser-warning": "69420",
          },
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _fallbackImage(),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _fallbackImage() {
    return Container(
      width: 110,
      height: 90,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(
        Icons.image_not_supported,
        color: Colors.white54,
        size: 40,
      ),
    );
  }
}
