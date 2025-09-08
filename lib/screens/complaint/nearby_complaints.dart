// nearby_complaints_page.dart
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:civic_care/constants/api_service.dart';
import 'package:civic_care/constants/api_constants.dart';

class NearbyComplaintsPage extends StatefulWidget {
  const NearbyComplaintsPage({super.key});

  @override
  State<NearbyComplaintsPage> createState() => _NearbyComplaintsPageState();
}

class _NearbyComplaintsPageState extends State<NearbyComplaintsPage> {
  final Dio _dio = ApiClient().dio;
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;

  int _currentPage = 1;
  final int _pageSize = 10;
  bool _hasMore = true;

  List<Complaint> _complaints = [];

  @override
  void initState() {
    super.initState();
    _fetchComplaints();

    // listen for scroll to bottom
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_isLoadingMore &&
          _hasMore) {
        _loadMore();
      }
    });
  }

  Future<void> _fetchComplaints({bool reset = true}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _error = null;
        _currentPage = 1;
        _hasMore = true;
      });
    }

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
        if (reset) {
          _complaints = newComplaints;
        } else {
          _complaints.addAll(newComplaints);
        }

        _hasMore = newComplaints.length >= _pageSize;
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
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _onRefresh() async {
    await _fetchComplaints(reset: true);
  }

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    _currentPage++;
    await _fetchComplaints(reset: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Complaints Feed"),
        actions: [
          IconButton(
            tooltip: "Refresh complaints",
            onPressed: () async => await _fetchComplaints(reset: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(onRefresh: _onRefresh, child: _buildBody(context)),
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
          const SizedBox(height: 8),
          Center(
            child: ElevatedButton.icon(
              onPressed: () => _fetchComplaints(reset: true),
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
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      itemCount: _complaints.length + 1,
      itemBuilder: (context, index) {
        if (index < _complaints.length) {
          return ComplaintCard(complaint: _complaints[index]);
        } else {
          return _isLoadingMore
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
              : const SizedBox.shrink();
        }
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

  Complaint({
    required this.id,
    required this.title,
    required this.description,
    this.imageUrl,
    this.address,
    required this.createdAt,
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
      imageUrl: json['image_url'] ?? json['image'] ?? json['photo'],
      address: (json['address'] ?? json['location_text'])?.toString(),
      createdAt: created,
    );
  }
}

// ---------------- UI Card ----------------

class ComplaintCard extends StatelessWidget {
  final Complaint complaint;
  const ComplaintCard({required this.complaint, super.key});

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
            _buildImage(context),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    complaint.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    complaint.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  if (complaint.address != null)
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 14,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            complaint.address!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 6),
                  Text(
                    _formatDate(complaint.createdAt),
                    style: const TextStyle(fontSize: 11, color: Colors.black45),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(BuildContext context) {
    final imageUrl = complaint.imageUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 110,
        height: 90,
        child: imageUrl == null || imageUrl.isEmpty
            ? Container(
                color: Colors.grey[200],
                child: const Center(
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    size: 36,
                    color: Colors.grey,
                  ),
                ),
              )
            : CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: Colors.grey[200],
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: Colors.grey[200],
                  child: const Center(
                    child: Icon(
                      Icons.broken_image,
                      size: 36,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
