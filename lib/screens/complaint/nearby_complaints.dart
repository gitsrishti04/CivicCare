// nearby_complaints_page.dart
// Replace your existing nearby_complaints_page.dart with this file.

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:civic_care/constants/api_service.dart';
import 'package:civic_care/constants/api_constants.dart';

class NearbyComplaintsPage extends StatefulWidget {
  const NearbyComplaintsPage({super.key});

  @override
  State<NearbyComplaintsPage> createState() => _NearbyComplaintsPageState();
}

class _NearbyComplaintsPageState extends State<NearbyComplaintsPage>
    with SingleTickerProviderStateMixin {
  final Dio _dio = ApiClient().dio;

  late TabController _tabController;

  List<Complaint> _nearby = [];
  List<Complaint> _city = [];
  List<Complaint> _yours = [];

  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
      List<Complaint> all = [];
      if (data is List) {
        all = data.map((e) => Complaint.fromJson(e)).toList();
      }

      // classification relies on backend flags if present
      final nearby = all.where((c) => c.isNearby).toList();
      final yours = all.where((c) => c.isMine).toList();

      // city contains everything (unique) but keep order from server
      final city = all.toList();

      setState(() {
        _nearby = nearby;
        _city = city;
        _yours = yours;
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleUpvote(Complaint complaint) async {
    // Optimistic UI update
    _optimisticToggle(complaint);

    try {
      // NOTE: adapt endpoint/data to your backend. This is a best-effort.
      await _dio.put(
        "${baseUrl}core/complaint/",
        data: {"id": complaint.id},
        options: Options(headers: {"Accept": "application/json"}),
      );
      // Optionally refresh to get authoritative counts
      await _fetchComplaints();
    } catch (e) {
      // revert optimistic change on error
      _optimisticToggle(complaint);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Failed to update vote")));
    }
  }

  void _optimisticToggle(Complaint complaint) {
    setState(() {
      for (final list in [_nearby, _city, _yours]) {
        final idx = list.indexWhere((c) => c.id == complaint.id);
        if (idx != -1) {
          final old = list[idx];
          final toggled = old.copyWith(
            upvoted: !old.upvoted,
            upvoteCount: old.upvoted
                ? old.upvoteCount - 1
                : old.upvoteCount + 1,
          );
          list[idx] = toggled;
        }
      }
    });
  }

  Future<void> _shareComplaint(Complaint c) async {
    final text =
        "Complaint: ${c.title}\n${c.address ?? ''}\n${c.description}\n";
    await Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Complaint copied to clipboard (share)')),
    );
  }

  Future<void> _openComplaintDetail(Complaint complaint) async {
    final result = await Navigator.push<Complaint?>(
      context,
      MaterialPageRoute(
        builder: (_) => ComplaintDetailPage(complaint: complaint, dio: _dio),
      ),
    );

    // If the detail returned an updated complaint, update local lists
    if (result != null) {
      setState(() {
        for (final list in [_nearby, _city, _yours]) {
          final idx = list.indexWhere((c) => c.id == result.id);
          if (idx != -1) list[idx] = result;
        }
        // if it's marked as mine but not present in _yours, add it
        if (result.isMine && !_yours.any((c) => c.id == result.id)) {
          _yours.insert(0, result);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('सभी शिकायतें देखें'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _fetchComplaints,
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'NEARBY'),
            Tab(text: 'CITY'),
            Tab(text: 'YOURS'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchComplaints,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              )
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildList(_nearby),
                  _buildList(_city),
                  _buildList(_yours),
                ],
              ),
      ),
    );
  }

  Widget _buildList(List<Complaint> items) {
    if (items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Center(child: Text('No complaints found')),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final c = items[index];
        return GestureDetector(
          onTap: () => _openComplaintDetail(c),
          child: ComplaintCard(
            complaint: c,
            onVote: () => _toggleUpvote(c),
            onComment: () async =>
                _openComplaintDetail(c), // open detail where comments are
            onShare: () => _shareComplaint(c),
          ),
        );
      },
    );
  }
}

// ---------------- Complaint Model ----------------

class Complaint {
  final String id;
  final String title;
  final String description;
  final String? image; // absolute url (or null)
  final String? address;
  final DateTime createdAt;
  final bool upvoted;
  final int upvoteCount;
  final int commentCount;
  final String? authorName;
  final String status; // e.g., Resolved, Assigned, New / Un-Assigned

  // flags for classification (backend ideally provides these)
  final bool isNearby;
  final bool isCity;
  final bool isMine;

  Complaint({
    required this.id,
    required this.title,
    required this.description,
    this.image,
    this.address,
    required this.createdAt,
    required this.upvoted,
    required this.upvoteCount,
    this.commentCount = 0,
    this.authorName,
    this.status = '',
    this.isNearby = false,
    this.isCity = true,
    this.isMine = false,
  });

  factory Complaint.fromJson(Map<String, dynamic> json) {
    // parse created_at which may be ISO or "dd-MMM-yyyy HH:mm:ss"
    DateTime created;
    final createdRaw =
        json['created_at'] ?? json['createdAt'] ?? json['timestamp'];
    if (createdRaw != null) {
      final s = createdRaw.toString();
      DateTime? parsed;
      // try ISO parse first
      try {
        parsed = DateTime.parse(s);
      } catch (_) {
        // try dd-MMM-yyyy HH:mm:ss (e.g. "13-Sep-2025 15:19:11")
        try {
          parsed = DateFormat('dd-MMM-yyyy HH:mm:ss').parse(s);
        } catch (_) {
          // fallback to now
          parsed = DateTime.now();
        }
      }
      created = parsed;
    } else {
      created = DateTime.now();
    }

    // normalize image: if full URL use as-is; if relative, prepend baseUrl; if empty/null -> null
    String? normalizedImage;
    final rawImage = json['image'];
    if (rawImage != null) {
      final s = rawImage.toString().trim();
      if (s.isNotEmpty) {
        if (s.startsWith('http')) {
          normalizedImage = s;
        } else {
          // ensure exactly one slash between baseUrl and path
          final base = baseUrl.endsWith('/')
              ? baseUrl.substring(0, baseUrl.length - 1)
              : baseUrl;
          final path = s.startsWith('/') ? s : '/$s';
          normalizedImage = '$base$path';
        }
      }
    }

    return Complaint(
      id: (json['id'] ?? json['pk'] ?? "").toString(),
      title: (json['title'] ?? json['headline'] ?? "No title").toString(),
      description: (json['description'] ?? json['desc'] ?? json['detail'] ?? "")
          .toString(),
      image: normalizedImage,
      address: (json['address'] ?? json['location_text'] ?? json['location'])
          ?.toString(),
      createdAt: created,
      upvoted: json['upvoted'] ?? json['is_upvoted'] ?? false,
      upvoteCount:
          (json['total_upvotes'] ??
                  json['total_upvote'] ??
                  json['upvote_count'] ??
                  json['upvotes'] ??
                  0)
              is int
          ? (json['total_upvotes'] ??
                json['total_upvote'] ??
                json['upvote_count'] ??
                json['upvotes'] ??
                0)
          : int.tryParse(
                  (json['total_upvotes'] ??
                          json['total_upvote'] ??
                          json['upvote_count'] ??
                          json['upvotes'] ??
                          0)
                      .toString(),
                ) ??
                0,
      commentCount:
          (json['comments_count'] ??
                  json['total_comments'] ??
                  json['comment_count'] ??
                  0)
              is int
          ? (json['comments_count'] ??
                json['total_comments'] ??
                json['comment_count'] ??
                0)
          : int.tryParse(
                  (json['comments_count'] ??
                          json['total_comments'] ??
                          json['comment_count'] ??
                          0)
                      .toString(),
                ) ??
                0,
      authorName:
          (json['author_name'] ??
                  json['name'] ??
                  json['reporter'] ??
                  json['user'])
              ?.toString(),
      status: (json['status'] ?? "").toString(),
      isNearby: json['is_nearby'] ?? json['nearby'] ?? false,
      isCity: json['is_city'] ?? true,
      isMine: json['is_mine'] ?? json['is_my_complaint'] ?? false,
    );
  }

  Complaint copyWith({
    String? id,
    String? title,
    String? description,
    String? image,
    String? address,
    DateTime? createdAt,
    bool? upvoted,
    int? upvoteCount,
    int? commentCount,
    String? authorName,
    String? status,
    bool? isNearby,
    bool? isCity,
    bool? isMine,
  }) {
    return Complaint(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      image: image ?? this.image,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
      upvoted: upvoted ?? this.upvoted,
      upvoteCount: upvoteCount ?? this.upvoteCount,
      commentCount: commentCount ?? this.commentCount,
      authorName: authorName ?? this.authorName,
      status: status ?? this.status,
      isNearby: isNearby ?? this.isNearby,
      isCity: isCity ?? this.isCity,
      isMine: isMine ?? this.isMine,
    );
  }
}

// ---------------- Complaint Card ----------------

class ComplaintCard extends StatelessWidget {
  final Complaint complaint;
  final VoidCallback onVote;
  final VoidCallback onComment;
  final VoidCallback onShare;

  const ComplaintCard({
    super.key,
    required this.complaint,
    required this.onVote,
    required this.onComment,
    required this.onShare,
  });

  String _formatDate(DateTime dt) {
    final date = DateFormat('dd-MMM-yyyy').format(dt);
    final time = DateFormat('h:mm a').format(dt);
    return "$date $time";
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // image
          if (complaint.image != null && complaint.image!.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              child: Image.network(
                complaint.image!,
                headers: {"ngrok-skip-browser-warning": "69420"},
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Container(height: 160, color: Colors.grey[300]),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return SizedBox(
                    height: 160,
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                  (loadingProgress.expectedTotalBytes ?? 1)
                            : null,
                      ),
                    ),
                  );
                },
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.grey[200],
                      child: Text(
                        complaint.authorName != null &&
                                complaint.authorName!.isNotEmpty
                            ? complaint.authorName!
                                  .split(' ')
                                  .map((s) => s.isNotEmpty ? s[0] : '')
                                  .take(2)
                                  .join()
                            : 'U',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        complaint.authorName ?? 'Anonymous',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (complaint.status.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _statusColor(complaint.status),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          complaint.status,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 8),
                Text(
                  complaint.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
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
                        size: 16,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          complaint.address!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatDate(complaint.createdAt),
                      style: const TextStyle(
                        color: Colors.black45,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // votes / comments quick counts
                Row(
                  children: [
                    Icon(
                      complaint.upvoted
                          ? Icons.thumb_up
                          : Icons.thumb_up_off_alt,
                      size: 18,
                      color: complaint.upvoted ? Colors.blue : Colors.grey,
                    ),
                    const SizedBox(width: 6),
                    Text('${complaint.upvoteCount}'),
                    const SizedBox(width: 16),
                    const Icon(
                      Icons.chat_bubble_outline,
                      size: 18,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 6),
                    Text('${complaint.commentCount}'),
                  ],
                ),

                const SizedBox(height: 12),

                const Divider(),

                // action row: Vote up, Comment, Share
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    TextButton.icon(
                      onPressed: onVote,
                      icon: Icon(
                        Icons.thumb_up,
                        color: complaint.upvoted ? Colors.blue : Colors.black54,
                      ),
                      label: Text(
                        'Vote up',
                        style: TextStyle(
                          color: complaint.upvoted
                              ? Colors.blue
                              : Colors.black87,
                        ),
                      ),
                    ),

                    TextButton.icon(
                      onPressed: onComment,
                      icon: const Icon(
                        Icons.comment_outlined,
                        color: Colors.black54,
                      ),
                      label: Text(
                        'Comment',
                        style: const TextStyle(color: Colors.black87),
                      ),
                    ),

                    TextButton.icon(
                      onPressed: onShare,
                      icon: const Icon(
                        Icons.share_outlined,
                        color: Colors.black54,
                      ),
                      label: const Text(
                        'Share',
                        style: TextStyle(color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('resolved') || s.contains('closed')) return Colors.green;
    if (s.contains('assigned')) return Colors.blue;
    if (s.contains('new') ||
        s.contains('un-assigned') ||
        s.contains('unassigned'))
      return Colors.orange;
    return Colors.grey;
  }
}

// ---------------- Complaint Detail Page (Votes + Comments) ----------------

class ComplaintDetailPage extends StatefulWidget {
  final Complaint complaint;
  final Dio dio;

  const ComplaintDetailPage({
    super.key,
    required this.complaint,
    required this.dio,
  });

  @override
  State<ComplaintDetailPage> createState() => _ComplaintDetailPageState();
}

class _ComplaintDetailPageState extends State<ComplaintDetailPage>
    with SingleTickerProviderStateMixin {
  late Complaint _complaint;
  late TabController _tabController;

  List<CommentItem> _comments = [];
  bool _loadingComments = false;
  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _complaint = widget.complaint;
    _tabController = TabController(length: 2, vsync: this);
    _fetchComments();
  }

  Future<void> _fetchComments() async {
    setState(() => _loadingComments = true);
    try {
      final resp = await widget.dio.get(
        '${baseUrl}core/complaint/${_complaint.id}/comments/',
        options: Options(headers: {"Accept": "application/json"}),
      );
      final data = resp.data;
      if (data is List) {
        setState(() {
          _comments = data.map((e) => CommentItem.fromJson(e)).toList();
        });
      }
    } catch (e) {
      // ignore
    } finally {
      setState(() => _loadingComments = false);
    }
  }

  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    final temp = CommentItem.fake(text);
    setState(() {
      _comments.insert(0, temp);
      _complaint = _complaint.copyWith(
        commentCount: _complaint.commentCount + 1,
        isMine: true,
      );
      _commentController.clear();
    });

    try {
      await widget.dio.post(
        '${baseUrl}core/complaint/${_complaint.id}/comment/',
        data: {"text": text},
      );
    } catch (e) {
      // on error, show snackbar but keep optimistic UI
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to post comment')));
    }
  }

  Future<void> _toggleVote() async {
    // optimistic
    setState(() {
      final voted = _complaint.upvoted;
      _complaint = _complaint.copyWith(
        upvoted: !voted,
        upvoteCount: voted
            ? _complaint.upvoteCount - 1
            : _complaint.upvoteCount + 1,
      );
    });
    try {
      await widget.dio.put(
        '${baseUrl}core/complaint/',
        data: {"id": _complaint.id},
      );
    } catch (e) {
      // revert
      setState(() {
        final voted = _complaint.upvoted;
        _complaint = _complaint.copyWith(
          upvoted: !voted,
          upvoteCount: voted
              ? _complaint.upvoteCount - 1
              : _complaint.upvoteCount + 1,
        );
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to update vote')));
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // pass back updated complaint
        Navigator.of(context).pop(_complaint);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Complaint Detail')),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_complaint.image != null && _complaint.image!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    _complaint.image!,
                    width: double.infinity,
                    height: 220,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Container(height: 220, color: Colors.grey[300]),
                  ),
                ),

              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.grey[200],
                          child: Text(
                            (_complaint.authorName ?? 'U').substring(0, 1),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _complaint.authorName ?? 'Anonymous',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (_complaint.status.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _complaint.status,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    Text(
                      _complaint.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(_complaint.description),
                    const SizedBox(height: 12),
                    if (_complaint.address != null)
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 16),
                          const SizedBox(width: 6),
                          Expanded(child: Text(_complaint.address!)),
                        ],
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          DateFormat(
                            'dd-MMM-yyyy h:mm a',
                          ).format(_complaint.createdAt),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Votes / Comments tabs
                    TabBar(
                      controller: _tabController,
                      labelColor: Theme.of(context).colorScheme.primary,
                      tabs: [
                        Tab(text: 'VOTES (${_complaint.upvoteCount})'),
                        Tab(text: 'COMMENTS (${_complaint.commentCount})'),
                      ],
                    ),

                    SizedBox(
                      height: 300,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          // Votes view (simple)
                          Center(
                            child: Text(
                              'Total votes: ${_complaint.upvoteCount}',
                            ),
                          ),

                          // Comments view
                          _loadingComments
                              ? const Center(child: CircularProgressIndicator())
                              : Column(
                                  children: [
                                    Expanded(
                                      child: _comments.isEmpty
                                          ? const Center(
                                              child: Text('No comments yet'),
                                            )
                                          : ListView.separated(
                                              padding: const EdgeInsets.only(
                                                top: 8,
                                              ),
                                              itemBuilder: (ctx, i) => ListTile(
                                                leading: CircleAvatar(
                                                  backgroundColor:
                                                      Colors.grey[200],
                                                  child: Text(
                                                    _comments[i].authorInitials,
                                                  ),
                                                ),
                                                title: Text(
                                                  _comments[i].authorName ??
                                                      'User',
                                                ),
                                                subtitle: Text(
                                                  _comments[i].text,
                                                ),
                                              ),
                                              separatorBuilder: (_, __) =>
                                                  const Divider(height: 1),
                                              itemCount: _comments.length,
                                            ),
                                    ),

                                    // add comment box
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8.0,
                                        vertical: 6,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: TextField(
                                              controller: _commentController,
                                              decoration: const InputDecoration(
                                                hintText: 'Write a comment...',
                                                border: OutlineInputBorder(),
                                                isDense: true,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          ElevatedButton(
                                            onPressed: _postComment,
                                            child: const Text('Send'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _toggleVote,
                          icon: Icon(
                            _complaint.upvoted
                                ? Icons.thumb_up
                                : Icons.thumb_up_outlined,
                          ),
                          label: Text(_complaint.upvoted ? 'Voted' : 'Vote'),
                        ),

                        ElevatedButton.icon(
                          onPressed: () => Clipboard.setData(
                            ClipboardData(
                              text:
                                  '${_complaint.title}\n${_complaint.address ?? ''}',
                            ),
                          ),
                          icon: const Icon(Icons.share),
                          label: const Text('Share'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- Comment item ----------------

class CommentItem {
  final String id;
  final String text;
  final String? authorName;

  CommentItem({required this.id, required this.text, this.authorName});

  factory CommentItem.fromJson(Map<String, dynamic> json) {
    return CommentItem(
      id: (json['id'] ?? json['pk'] ?? '').toString(),
      text: (json['text'] ?? json['comment'] ?? '').toString(),
      authorName: (json['author_name'] ?? json['name'])?.toString(),
    );
  }

  factory CommentItem.fake(String text) => CommentItem(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    text: text,
    authorName: 'You',
  );

  String get authorInitials {
    if (authorName == null || authorName!.isEmpty) return 'U';
    final parts = authorName!.split(' ');
    return parts.map((p) => p.isNotEmpty ? p[0] : '').take(2).join();
  }
}
