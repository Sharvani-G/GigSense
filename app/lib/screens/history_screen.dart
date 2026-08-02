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
  bool _isFetchingMore = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;
  List<Map<String, dynamic>> _jobs = [];
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
    _fetchJobs(isRefresh: true);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && !_isFetchingMore && _hasMore) {
        _fetchJobs(isRefresh: false);
      }
    }
  }

  DateTime? _parseTimestamp(dynamic val) {
    if (val == null) return null;
    if (val is Timestamp) return val.toDate();
    if (val is String) return DateTime.tryParse(val);
    return null;
  }

  Future<void> _fetchJobs({required bool isRefresh}) async {
    if (isRefresh) {
      setState(() {
        _isLoading = true;
        _jobs.clear();
        _lastDocument = null;
        _hasMore = true;
      });
    } else {
      setState(() {
        _isFetchingMore = true;
      });
    }

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous_user';
      
      Query query = FirebaseFirestore.instance
          .collection('jobs')
          .where('user_id', isEqualTo: userId);

      if (_selectedPlatforms.isNotEmpty) {
        final platformFilter = _selectedPlatforms.map((p) => p.toLowerCase()).take(10).toList();
        query = query.where('platform', whereIn: platformFilter);
      }

      if (_selectedFairness == "Possibly Underpaid") {
        query = query.where('is_underpaid', isEqualTo: true);
      } else if (_selectedFairness == "Fair Pay") {
        query = query.where('is_underpaid', isEqualTo: false);
      }

      query = query.orderBy('job_timestamp', descending: true).limit(20);

      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final querySnapshot = await query.get();
      final docs = querySnapshot.docs;

      if (docs.length < 20) {
        _hasMore = false;
      }

      if (docs.isNotEmpty) {
        _lastDocument = docs.last;
      }

      final List<Map<String, dynamic>> loaded = docs
          .map((doc) => {...doc.data() as Map<String, dynamic>, 'id': doc.id})
          .toList();

      setState(() {
        if (isRefresh) {
          _jobs = loaded;
        } else {
          _jobs.addAll(loaded);
        }
        _isLoading = false;
        _isFetchingMore = false;
      });
    } catch (e) {
      debugPrint("Error fetching history: $e");
      setState(() {
        _isLoading = false;
        _isFetchingMore = false;
        _hasMore = false;
      });
    }
  }

  Color _getPlatformColor(String platform) {
    return getPlatformColor(platform);
  }

  String _formatDateTime(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final minuteStr = dt.minute.toString().padLeft(2, '0');
    return "${months[dt.month - 1]} ${dt.day}, ${dt.year} • $hour:$minuteStr $period";
  }

  void _showFilterBottomSheet() {
    final allPlatforms = [
      'zomato',
      'swiggy',
      'uber',
      'ola',
      'rapido',
      'dunzo',
      'blinkit',
      'zepto',
      'bigbasket',
      'amazon_flex',
      'urban_company',
      'porter',
      'housejoy',
      'other'
    ];

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
                            });
                            _fetchJobs(isRefresh: true);
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
                            _fetchJobs(isRefresh: true);
                            Navigator.pop(context);
                          },
                          backgroundColor: PlayfulColors.accent,
                          child: Text(StringsProvider.instance.t('btn_apply')),
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
    final visibleJobs = _jobs;

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
          : _jobs.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  itemCount: visibleJobs.length + (_hasMore ? 1 : 0),
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
                    final expectedFare = (job['expected_fare'] as num?)?.toDouble() ?? 0.0;
                    final isUnderpaid = job['is_underpaid'] == true;
                    double? pct;
                    if (expectedFare > 0.0) {
                      pct = (fare / expectedFare) * 100;
                    }
                    final rawTimestamp = job['job_timestamp'] ?? job['created_at'];
                    final parsedTime = _parseTimestamp(rawTimestamp);
                    final int? hour = parsedTime?.hour;
                    final bool showEveningPill = hour != null && hour >= 21 && hour < 23;
                    final bool showLateNightPill = hour != null && (hour >= 23 || hour < 6);
                    final dateStr = parsedTime != null
                        ? _formatDateTime(parsedTime)
                        : '';
                    final double? deduction = job['deduction_amount'] != null ? (job['deduction_amount'] as num).toDouble() : null;
                    final bool reasonStated = job['deduction_reason_stated'] ?? false;
                    final bool hasUndisclosedDeduction = deduction != null && deduction > 0 && !reasonStated;
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
                                    "₹${formatIndianCurrency(fare, decimals: 2)}",
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
                                  if (hasUndisclosedDeduction) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF1F2),
                                        borderRadius: BorderRadius.circular(9999),
                                        border: Border.all(color: PlayfulColors.secondary, width: 1.5),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.gavel, size: 10, color: PlayfulColors.secondary),
                                          const SizedBox(width: 4),
                                          Text(
                                            "Undisclosed Deduction",
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
                                  if (pct != null) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      "${pct.round()}%",
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                        color: pct >= 100
                                            ? PlayfulColors.quaternary
                                            : pct >= 85
                                                ? PlayfulColors.tertiary
                                                : PlayfulColors.secondary,
                                      ),
                                    ),
                                  ],
                                  if (showEveningPill) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFFBEB),
                                        borderRadius: BorderRadius.circular(9999),
                                        border: Border.all(color: PlayfulColors.tertiary, width: 1.5),
                                      ),
                                      child: Text(
                                        "🌆 Evening",
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFFD97706),
                                        ),
                                      ),
                                    ),
                                  ] else if (showLateNightPill) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFFBEB),
                                        borderRadius: BorderRadius.circular(9999),
                                        border: Border.all(color: PlayfulColors.tertiary, width: 1.5),
                                      ),
                                      child: Text(
                                        "🌙 Late-night",
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFFD97706),
                                        ),
                                      ),
                                    ),
                                  ],
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
