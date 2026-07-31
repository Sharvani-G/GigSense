import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'playful_widgets.dart';
import 'fairness_result_screen.dart';
import 'home_screen.dart'; // For EmptyStatePainter
import '../i18n/strings.dart';

class HistoryScreen extends StatefulWidget {
  final String? initialFairnessFilter;

  const HistoryScreen({
    super.key,
    this.initialFairnessFilter,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _jobs = [];
  List<Map<String, dynamic>> _filteredJobs = [];
  int _loadedLimit = 20;
  final ScrollController _scrollController = ScrollController();

  // Filter states
  List<String> _selectedPlatforms = [];
  String _selectedFairness = "All"; // "All", "Fair Pay", "Possibly Underpaid"

  @override
  void initState() {
    super.initState();
    if (widget.initialFairnessFilter != null) {
      _selectedFairness = widget.initialFairnessFilter!;
    }
    _fetchJobs();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (_loadedLimit < _filteredJobs.length) {
        setState(() {
          _loadedLimit += 20;
        });
      }
    }
  }

  DateTime? _parseTimestamp(dynamic val) {
    if (val == null) return null;
    if (val is Timestamp) return val.toDate();
    if (val is String) return DateTime.tryParse(val);
    return null;
  }

  Future<void> _fetchJobs() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous_user';
      final querySnapshot = await FirebaseFirestore.instance
          .collection('jobs')
          .where('user_id', isEqualTo: userId)
          .get();

      final List<Map<String, dynamic>> loaded = querySnapshot.docs
          .map((doc) => {...doc.data(), 'id': doc.id})
          .toList();

      loaded.sort((a, b) {
        final tsA = _parseTimestamp(a['job_timestamp']) ?? DateTime.fromMillisecondsSinceEpoch(0);
        final tsB = _parseTimestamp(b['job_timestamp']) ?? DateTime.fromMillisecondsSinceEpoch(0);
        return tsB.compareTo(tsA);
      });

      setState(() {
        _jobs = loaded;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching history: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    List<Map<String, dynamic>> temp = List.from(_jobs);

    // 1. Platform filter
    if (_selectedPlatforms.isNotEmpty) {
      temp = temp.where((job) {
        final platform = (job['platform'] as String?)?.toLowerCase() ?? 'other';
        return _selectedPlatforms.contains(platform);
      }).toList();
    }

    // 2. Fairness status filter
    if (_selectedFairness == "Possibly Underpaid") {
      temp = temp.where((job) => job['is_underpaid'] == true).toList();
    } else if (_selectedFairness == "Fair Pay") {
      temp = temp.where((job) => job['is_underpaid'] != true).toList();
    }

    setState(() {
      _filteredJobs = temp;
      _loadedLimit = 20; // reset pagination page
    });
  }

  Color _getPlatformColor(String platform) {
    final clean = platform.trim().toLowerCase();
    switch (clean) {
      case 'uber':
        return PlayfulColors.accent;
      case 'rapido':
        return PlayfulColors.secondary;
      case 'ola':
        return PlayfulColors.tertiary;
      case 'indrive':
        return PlayfulColors.quaternary;
      case 'zomato':
        return PlayfulColors.accent;
      case 'swiggy':
        return PlayfulColors.secondary;
      case 'dunzo':
        return PlayfulColors.tertiary;
      case 'blinkit':
        return PlayfulColors.quaternary;
      case 'zepto':
        return PlayfulColors.accent;
      case 'bigbasket':
        return PlayfulColors.secondary;
      case 'amazon_flex':
        return PlayfulColors.tertiary;
      case 'urban_company':
        return PlayfulColors.quaternary;
      case 'porter':
        return PlayfulColors.accent;
      case 'housejoy':
        return PlayfulColors.secondary;
      default:
        return PlayfulColors.mutedForeground;
    }
  }

  String _formatDateTime(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final minuteStr = dt.minute.toString().padLeft(2, '0');
    return "${months[dt.month - 1]} ${dt.day}, ${dt.year} • $hour:$minuteStr $period";
  }

  void _showFilterBottomSheet() {
    final allPlatforms = _jobs
        .map((j) => ((j['platform'] as String?) ?? 'other').toLowerCase())
        .toSet()
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateSheet) {
            return Container(
              padding: const EdgeInsets.only(top: 12, left: 24, right: 24, bottom: 24),
              decoration: const BoxDecoration(
                color: PlayfulColors.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                border: Border(
                  top: BorderSide(color: PlayfulColors.border, width: 2),
                  left: BorderSide(color: PlayfulColors.border, width: 2),
                  right: BorderSide(color: PlayfulColors.border, width: 2),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 6,
                      decoration: BoxDecoration(
                        color: PlayfulColors.border,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "FILTER HISTORY",
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: 2.0,
                      color: PlayfulColors.foreground,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Fairness Filter
                  Text(
                    "FAIRNESS STATUS",
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 1.5,
                      color: PlayfulColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: ["All", "Fair Pay", "Possibly Underpaid"].map((opt) {
                      final isSel = _selectedFairness == opt;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: GestureDetector(
                            onTap: () {
                              setStateSheet(() {
                                _selectedFairness = opt;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isSel ? PlayfulColors.accent : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: PlayfulColors.border, width: 2.0),
                              ),
                              child: Center(
                                child: Text(
                                  opt,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isSel ? Colors.white : PlayfulColors.foreground,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Platform Filter
                  if (allPlatforms.isNotEmpty) ...[
                    Text(
                      "PLATFORMS",
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        letterSpacing: 1.5,
                        color: PlayfulColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: allPlatforms.map((p) {
                        final isSel = _selectedPlatforms.contains(p);
                        final displayName = p.isNotEmpty ? p[0].toUpperCase() + p.substring(1) : 'Other';

                        return GestureDetector(
                          onTap: () {
                            setStateSheet(() {
                              if (isSel) {
                                _selectedPlatforms.remove(p);
                              } else {
                                _selectedPlatforms.add(p);
                              }
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSel ? PlayfulColors.accent : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: PlayfulColors.border, width: 2.0),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: _getPlatformColor(p),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  displayName,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isSel ? Colors.white : PlayfulColors.foreground,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 32),
                  ],

                  // Apply / Reset Buttons
                  Row(
                    children: [
                      Expanded(
                        child: PlayfulButton(
                          onPressed: () {
                            setStateSheet(() {
                              _selectedPlatforms.clear();
                              _selectedFairness = "All";
                            });
                            setState(() {
                              _selectedPlatforms.clear();
                              _selectedFairness = "All";
                              _applyFilters();
                            });
                            Navigator.pop(context);
                          },
                          backgroundColor: Colors.white,
                          child: Text(
                            "RESET",
                            style: TextStyle(color: PlayfulColors.foreground),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: PlayfulButton(
                          onPressed: () {
                            setState(() {
                              _applyFilters();
                            });
                            Navigator.pop(context);
                          },
                          backgroundColor: PlayfulColors.accent,
                          child: const Text("APPLY"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleJobs = _filteredJobs.take(_loadedLimit).toList();

    return Scaffold(
      backgroundColor: PlayfulColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: PlayfulColors.foreground),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Job History",
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: PlayfulColors.foreground,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, color: PlayfulColors.foreground),
            onPressed: _showFilterBottomSheet,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: PlayfulColors.accent,
              ),
            )
          : _filteredJobs.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  itemCount: visibleJobs.length + (_loadedLimit < _filteredJobs.length ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == visibleJobs.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(
                          child: CircularProgressIndicator(color: PlayfulColors.accent),
                        ),
                      );
                    }

                    final job = visibleJobs[index];
                    final platform = (job['platform'] as String?) ?? 'other';
                    final platformName = platform.isNotEmpty ? platform[0].toUpperCase() + platform.substring(1) : '';
                    final fare = (job['fare'] as num?)?.toDouble() ?? 0.0;
                    final isUnderpaid = job['is_underpaid'] == true;
                    final rawTimestamp = job['job_timestamp'];
                    final dateStr = rawTimestamp != null
                        ? _formatDateTime(_parseTimestamp(rawTimestamp)!)
                        : '';
                    final explanation = job['explanation'] ?? (isUnderpaid
                        ? "This came in noticeably below what's typical for this distance and platform."
                        : "This is about what's typical for a ${(job['distance_km'] as num?)?.toDouble()?.toStringAsFixed(1) ?? '0'}km $platformName trip.");

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FairnessResultScreen(
                                job: job,
                                isReadOnly: true,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: PlayfulColors.border, width: 2.0),
                            boxShadow: const [
                              BoxShadow(
                                color: PlayfulColors.border,
                                offset: Offset(4, 4),
                                blurRadius: 0,
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: _getPlatformColor(platform),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: PlayfulColors.border, width: 1),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        platformName,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                          color: PlayfulColors.foreground,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    "₹${fare.toStringAsFixed(2)}",
                                    style: GoogleFonts.outfit(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: PlayfulColors.foreground,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              if (dateStr.isNotEmpty)
                                Text(
                                  dateStr,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: PlayfulColors.mutedForeground,
                                  ),
                                ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isUnderpaid ? const Color(0xFFFEE2E2) : const Color(0xFFD1FAE5),
                                      borderRadius: BorderRadius.circular(9999),
                                      border: Border.all(color: PlayfulColors.border, width: 1.5),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isUnderpaid ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                                          size: 11,
                                          color: isUnderpaid ? PlayfulColors.secondary : PlayfulColors.quaternary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          isUnderpaid ? "Possibly Underpaid" : "Fair Pay",
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            color: PlayfulColors.foreground,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                explanation,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: PlayfulColors.mutedForeground,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: double.infinity,
            height: 140,
            child: CustomPaint(
              painter: EmptyStatePainter(),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "Nothing logged yet — your job history will show up here once you log your first trip.",
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: PlayfulColors.mutedForeground,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}
