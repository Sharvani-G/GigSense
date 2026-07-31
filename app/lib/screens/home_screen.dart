import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'playful_widgets.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onNavigateToLogJob;

  const HomeScreen({
    super.key,
    required this.onNavigateToLogJob,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  List<Map<String, dynamic>> _jobs = [];
  
  // Aggregated data
  double _totalEarnings = 0.0;
  double _totalHours = 0.0;
  int _flaggedCount = 0;
  List<MapEntry<String, double>> _chartData = [];
  List<PlatformBreakdown> _platformsBreakdown = [];

  @override
  void initState() {
    super.initState();
    _fetchAndProcessJobs();
  }

  // Parses various timestamp/date types safely
  DateTime? _parseTimestamp(dynamic val) {
    if (val == null) return null;
    if (val is Timestamp) {
      return val.toDate();
    }
    if (val is String) {
      return DateTime.tryParse(val);
    }
    return null;
  }

  // Custom weekday format label
  String _getWeekdayLabel(DateTime dt) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return weekdays[dt.weekday - 1];
  }

  Future<void> _fetchAndProcessJobs() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous_user';
      
      // Query jobs collection by user_id
      final querySnapshot = await FirebaseFirestore.instance
          .collection('jobs')
          .where('user_id', isEqualTo: userId)
          .get();

      final List<Map<String, dynamic>> allJobs = querySnapshot.docs
          .map((doc) => {...doc.data(), 'id': doc.id})
          .toList();

      final now = DateTime.now();
      final sevenDaysAgo = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7));

      // Filter jobs logged in the last 7 days
      final List<Map<String, dynamic>> weeklyJobs = allJobs.where((job) {
        final jobDate = _parseTimestamp(job['job_timestamp']);
        return jobDate != null && jobDate.isAfter(sevenDaysAgo);
      }).toList();

      // Aggregate calculations
      double totalEarnings = 0.0;
      double totalMinutes = 0.0;
      int flaggedCount = 0;

      for (var job in weeklyJobs) {
        totalEarnings += (job['fare'] as num?)?.toDouble() ?? 0.0;
        totalMinutes += (job['duration_min'] as num?)?.toDouble() ?? 0.0;
        if (job['is_underpaid'] == true) {
          flaggedCount++;
        }
      }

      // Generate daily earnings chart data (last 7 days)
      final List<MapEntry<String, double>> chartData = [];
      for (int i = 6; i >= 0; i--) {
        final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
        final dayLabel = _getWeekdayLabel(day);
        
        double dayEarnings = 0.0;
        for (var job in weeklyJobs) {
          final jobDate = _parseTimestamp(job['job_timestamp']);
          if (jobDate != null &&
              jobDate.year == day.year &&
              jobDate.month == day.month &&
              jobDate.day == day.day) {
            dayEarnings += (job['fare'] as num?)?.toDouble() ?? 0.0;
          }
        }
        chartData.add(MapEntry(dayLabel, dayEarnings));
      }

      // Platform breakdown calculation
      final Map<String, PlatformBreakdown> platformMap = {};
      for (var job in weeklyJobs) {
        final platformRaw = (job['platform'] as String?) ?? 'other';
        final platform = platformRaw.toLowerCase();
        final fare = (job['fare'] as num?)?.toDouble() ?? 0.0;

        if (platformMap.containsKey(platform)) {
          platformMap[platform]!.total += fare;
          platformMap[platform]!.count += 1;
        } else {
          platformMap[platform] = PlatformBreakdown(
            name: platformRaw,
            total: fare,
            count: 1,
          );
        }
      }

      setState(() {
        _jobs = allJobs;
        _totalEarnings = totalEarnings;
        _totalHours = double.parse((totalMinutes / 60.0).toStringAsFixed(1));
        _flaggedCount = flaggedCount;
        _chartData = chartData;
        _platformsBreakdown = platformMap.values.toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching jobs from Firestore: $e");
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Current week date range text
    final now = DateTime.now();
    final start = now.subtract(Duration(days: now.weekday - 1));
    final end = start.add(const Duration(days: 6));
    const months = ['Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
    // Note: Month index formatting
    final startMonth = months[(start.month + 4) % 12];
    final endMonth = months[(end.month + 4) % 12];
    final dateRange = "This week · ${start.day} $startMonth – ${end.day} $endMonth";

    return Scaffold(
      backgroundColor: PlayfulColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchAndProcessJobs,
          color: PlayfulColors.accent,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Error banner (non-blocking)
                if (_hasError)
                  Container(
                    color: PlayfulColors.secondary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.white),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Database sync issue. Using offline cache.",
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _fetchAndProcessJobs,
                          child: Text(
                            "RETRY",
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),
                      // Header
                      Text(
                        "HELLO RIDER!",
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w900,
                          fontSize: 28,
                          color: PlayfulColors.foreground,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateRange,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: PlayfulColors.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // AI Weekly Insight Placeholder
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: PlayfulColors.tertiary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: PlayfulColors.border, width: 2.0),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: PlayfulColors.tertiary,
                                    borderRadius: BorderRadius.circular(9999),
                                    border: Border.all(color: PlayfulColors.border, width: 2),
                                  ),
                                  child: Text(
                                    "AI INSIGHT",
                                    style: GoogleFonts.outfit(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: PlayfulColors.foreground,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "Your weekly insight will appear here once you've logged a few jobs.",
                              style: GoogleFonts.plusJakartaSans(
                                color: PlayfulColors.foreground,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Loader, Empty or Render View
                      if (_isLoading)
                        _buildLoadingState()
                      else if (_jobs.isEmpty)
                        _buildEmptyState()
                      else
                        _buildMainDashboard(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: widget.onNavigateToLogJob,
        backgroundColor: PlayfulColors.accent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: PlayfulColors.border, width: 2),
        ),
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      children: [
        Row(
          children: const [
            Expanded(child: PlayfulSkeleton(height: 100, width: double.infinity)),
            SizedBox(width: 12),
            Expanded(child: PlayfulSkeleton(height: 100, width: double.infinity)),
            SizedBox(width: 12),
            Expanded(child: PlayfulSkeleton(height: 100, width: double.infinity)),
          ],
        ),
        const SizedBox(height: 32),
        const PlayfulSkeleton(height: 200, width: double.infinity),
        const SizedBox(height: 32),
        Row(
          children: const [
            PlayfulSkeleton(height: 36, width: 120),
            SizedBox(width: 12),
            PlayfulSkeleton(height: 36, width: 120),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Column(
      children: [
        const SizedBox(height: 24),
        // Empty illustration using calm primitives
        SizedBox(
          width: double.infinity,
          height: 140,
          child: CustomPaint(
            painter: EmptyStatePainter(),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          "No jobs logged yet — tap below and let's check your first payout",
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
    );
  }

  Widget _buildMainDashboard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Stats Cards Row
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                label: "EARNINGS",
                value: "₹${_totalEarnings.toStringAsFixed(0)}",
                icon: Icons.currency_rupee,
                iconColor: PlayfulColors.accent,
                shadowColor: const Color(0xFFE2E8F0),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatCard(
                label: "HOURS",
                value: "${_totalHours}h",
                icon: Icons.access_time,
                iconColor: PlayfulColors.quaternary,
                shadowColor: const Color(0xFFE2E8F0),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatCard(
                label: "FLAGGED",
                value: "$_flaggedCount",
                icon: Icons.warning_amber_rounded,
                iconColor: PlayfulColors.secondary,
                shadowColor: PlayfulColors.secondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),

        // Chart Section
        Text(
          "DAILY EARNINGS",
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            fontSize: 12,
            letterSpacing: 1.0,
            color: PlayfulColors.foreground,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 200,
          padding: const EdgeInsets.only(right: 16, top: 16, bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: PlayfulColors.border, width: 2.0),
            boxShadow: const [
              BoxShadow(
                color: Color(0xFFE2E8F0),
                offset: Offset(4, 4),
                blurRadius: 0,
              ),
            ],
          ),
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: _getMaxEarningsValue() * 1.25,
              barTouchData: BarTouchData(enabled: true),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      final index = value.toInt();
                      if (index >= 0 && index < _chartData.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 6.0),
                          child: Text(
                            _chartData[index].key,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: PlayfulColors.foreground,
                            ),
                          ),
                        );
                      }
                      return const Text('');
                    },
                  ),
                ),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) => const FlLine(
                  color: Color(0xFFE2E8F0),
                  strokeWidth: 1.0,
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: List.generate(_chartData.length, (index) {
                final entry = _chartData[index];
                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: entry.value,
                      color: PlayfulColors.accent,
                      width: 14,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 32),

        // Platform Breakdown Section
        Text(
          "PLATFORM BREAKDOWN",
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            fontSize: 12,
            letterSpacing: 1.0,
            color: PlayfulColors.foreground,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: List.generate(_platformsBreakdown.length, (index) {
            final pb = _platformsBreakdown[index];
            final Color bg = _getPlatformColor(index);
            final Color textCol = _getPlatformTextColor(bg);
            final String nameCapitalized = pb.name.isNotEmpty
                ? pb.name[0].toUpperCase() + pb.name.substring(1)
                : '';

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(9999),
                border: Border.all(color: PlayfulColors.border, width: 2.0),
                boxShadow: const [
                  BoxShadow(
                    color: PlayfulColors.border,
                    offset: Offset(2, 2),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Text(
                "$nameCapitalized · ₹${pb.total.toStringAsFixed(0)} · ${pb.count} jobs",
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: textCol,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 48),
      ],
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color shadowColor,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.only(top: 24, bottom: 12, left: 8, right: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: PlayfulColors.border, width: 2.0),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                offset: const Offset(4, 4),
                blurRadius: 0,
              ),
            ],
          ),
          child: Column(
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: PlayfulColors.foreground,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: PlayfulColors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: -16,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconColor,
                shape: BoxShape.circle,
                border: Border.all(color: PlayfulColors.border, width: 2.0),
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  double _getMaxEarningsValue() {
    double maxVal = 100.0;
    for (var entry in _chartData) {
      if (entry.value > maxVal) {
        maxVal = entry.value;
      }
    }
    return maxVal;
  }

  Color _getPlatformColor(int index) {
    final List<Color> colors = [
      PlayfulColors.accent,      // Violet
      PlayfulColors.secondary,   // Pink
      PlayfulColors.tertiary,    // Amber
      PlayfulColors.quaternary,  // Mint
    ];
    return colors[index % colors.length];
  }

  Color _getPlatformTextColor(Color bg) {
    if (bg == PlayfulColors.tertiary) {
      return PlayfulColors.foreground;
    }
    return Colors.white;
  }
}

class PlatformBreakdown {
  final String name;
  double total;
  int count;

  PlatformBreakdown({
    required this.name,
    required this.total,
    required this.count,
  });
}

// Painter for empty state calm decorative line + shapes
class EmptyStatePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final path = Path();
    path.moveTo(size.width * 0.1, size.height * 0.7);
    path.quadraticBezierTo(
      size.width * 0.4,
      size.height * 0.1,
      size.width * 0.8,
      size.height * 0.6,
    );

    // Draw dashed path
    const double dashWidth = 6.0;
    const double dashSpace = 4.0;
    double distance = 0.0;
    final Path dashPath = Path();

    for (var metric in path.computeMetrics()) {
      while (distance < metric.length) {
        dashPath.addPath(
          metric.extractPath(distance, distance + dashWidth),
          Offset.zero,
        );
        distance += dashWidth + dashSpace;
      }
    }
    canvas.drawPath(dashPath, paint);

    // Draw calm circle
    final circlePaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.5), 24, circlePaint);

    final circleOutline = Paint()
      ..color = const Color(0xFF94A3B8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.5), 24, circleOutline);

    // Draw calm square
    final squarePaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(size.width * 0.2, size.height * 0.5),
        width: 24,
        height: 24,
      ),
      squarePaint,
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(size.width * 0.2, size.height * 0.5),
        width: 24,
        height: 24,
      ),
      circleOutline,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class PlayfulSkeleton extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const PlayfulSkeleton({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 16.0,
  });

  @override
  State<PlayfulSkeleton> createState() => _PlayfulSkeletonState();
}

class _PlayfulSkeletonState extends State<PlayfulSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: 0.4 + (_controller.value * 0.4),
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: Border.all(color: const Color(0xFFCBD5E1), width: 2.0),
            ),
          ),
        );
      },
    );
  }
}
