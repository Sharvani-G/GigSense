import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'playful_widgets.dart';

class FairnessMapScreen extends StatefulWidget {
  const FairnessMapScreen({super.key});

  @override
  State<FairnessMapScreen> createState() => _FairnessMapScreenState();
}

class _FairnessMapScreenState extends State<FairnessMapScreen> {
  String _timeFilter = 'all'; // 'all', 'morning', 'evening', 'latenight'

  final Map<String, LatLng> _zoneCoordinates = {
    'koramangala': const LatLng(12.9352, 77.6244),
    'indiranagar': const LatLng(12.9784, 77.6408),
    'hsr layout': const LatLng(12.9105, 77.6450),
    'whitefield': const LatLng(12.9698, 77.7499),
    'jayanagar': const LatLng(12.9308, 77.5802),
    'yelahanka': const LatLng(13.1008, 77.5963),
    'electronic city': const LatLng(12.8499, 77.6804),
    'malleshwaram': const LatLng(13.0031, 77.5697),
  };

  String? _getMatchedZone(String? areaHint) {
    if (areaHint == null || areaHint.trim().isEmpty) return null;
    final hint = areaHint.toLowerCase().trim();
    for (var zone in _zoneCoordinates.keys) {
      if (hint.contains(zone) || zone.contains(hint)) {
        return zone;
      }
    }
    return null;
  }

  void _showZoneDetailDialog(BuildContext context, String zone, List<Map<String, dynamic>> jobs, double underpaidRatio) {
    final totalJobs = jobs.length;
    final fairJobs = totalJobs - jobs.where((j) => j['is_underpaid'] == true).length;
    final fairRate = totalJobs > 0 ? (fairJobs / totalJobs) * 100 : 0.0;
    final isTrendingFair = underpaidRatio <= 0.35;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PlayfulColors.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: PlayfulColors.border, width: 2),
        ),
        title: Text(
          zone.toUpperCase(),
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isTrendingFair ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: PlayfulColors.border, width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isTrendingFair ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                    size: 16,
                    color: isTrendingFair ? PlayfulColors.quaternary : PlayfulColors.secondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isTrendingFair ? "Trending Fair" : "High Pay Risk",
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: PlayfulColors.foreground,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildDetailRow("Total Trips Scanned", "$totalJobs"),
            _buildDetailRow("Fairness Rate", "${fairRate.toStringAsFixed(0)}%"),
            _buildDetailRow("Confidence Level", totalJobs >= 5 ? "Highly Trusted" : "Developing"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              "CLOSE",
              style: GoogleFonts.plusJakartaSans(color: PlayfulColors.accent, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13, color: PlayfulColors.mutedForeground)),
          Text(value, style: GoogleFonts.shareTechMono(fontWeight: FontWeight.bold, fontSize: 14, color: PlayfulColors.foreground)),
        ],
      ),
    );
  }

  Widget _buildTimeChip(String label, String filterVal) {
    final isSelected = _timeFilter == filterVal;
    return GestureDetector(
      onTap: () {
        setState(() {
          _timeFilter = filterVal;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? PlayfulColors.accent : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: PlayfulColors.border, width: 2.0),
          boxShadow: [
            if (isSelected)
              const BoxShadow(
                color: PlayfulColors.accent,
                offset: Offset(2, 2),
                blurRadius: 0,
              )
            else
              const BoxShadow(
                color: PlayfulColors.border,
                offset: Offset(2, 2),
                blurRadius: 0,
              ),
          ],
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            fontSize: 11,
            color: isSelected ? Colors.white : PlayfulColors.foreground,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PlayfulColors.background,
      appBar: AppBar(
        title: Text(
          "FAIRNESS MAP",
          style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18, color: PlayfulColors.foreground),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: PlayfulColors.foreground),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Time of day filters row
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildTimeChip("All Day", "all"),
                    const SizedBox(width: 8),
                    _buildTimeChip("🌅 Morning", "morning"),
                    const SizedBox(width: 8),
                    _buildTimeChip("🌆 Evening", "evening"),
                    const SizedBox(width: 8),
                    _buildTimeChip("🌙 Late-Night", "latenight"),
                  ],
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('jobs').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: PlayfulColors.accent));
                  }

                  final docs = snapshot.data?.docs ?? [];
                  final Map<String, List<Map<String, dynamic>>> groupedJobs = {};

                  for (var doc in docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final area = _getMatchedZone(data['area_hint']);
                    if (area == null) continue;

                    // Filter by time of day if requested
                    if (_timeFilter != 'all') {
                      final ts = data['created_at'] ?? data['job_timestamp'];
                      if (ts != null) {
                        DateTime? dt;
                        if (ts is Timestamp) {
                          dt = ts.toDate();
                        } else if (ts is String) {
                          dt = DateTime.tryParse(ts);
                        }
                        if (dt != null) {
                          final hour = dt.hour;
                          final isMorning = hour >= 6 && hour < 12;
                          final isEvening = hour >= 16 && hour < 21;
                          final isLateNight = hour >= 21 || hour < 6;

                          if (_timeFilter == 'morning' && !isMorning) continue;
                          if (_timeFilter == 'evening' && !isEvening) continue;
                          if (_timeFilter == 'latenight' && !isLateNight) continue;
                        }
                      }
                    }

                    groupedJobs.putIfAbsent(area, () => []).add(data);
                  }

                  final List<CircleMarker> circles = [];
                  final List<Marker> markers = [];

                  groupedJobs.forEach((zone, jobs) {
                    final totalJobs = jobs.length;
                    if (totalJobs < 2) return; // Hard confidence threshold (minimum sample size of 2 for demo purposes)

                    final underpaidCount = jobs.where((j) => j['is_underpaid'] == true).length;
                    final underpaidRatio = underpaidCount / totalJobs;
                    final isTrendingUnderpaid = underpaidRatio > 0.35;

                    final coords = _zoneCoordinates[zone]!;
                    final color = isTrendingUnderpaid
                        ? PlayfulColors.secondary.withOpacity(0.35) // Pink warning for underpaid
                        : PlayfulColors.quaternary.withOpacity(0.35); // Mint for fair

                    final strokeColor = isTrendingUnderpaid ? PlayfulColors.secondary : PlayfulColors.quaternary;

                    circles.add(CircleMarker(
                      point: coords,
                      radius: 1200,
                      useRadiusInMeter: true,
                      color: color,
                      borderColor: strokeColor,
                      borderStrokeWidth: 3.0,
                    ));

                    markers.add(Marker(
                      point: coords,
                      width: 140,
                      height: 50,
                      child: Center(
                        child: GestureDetector(
                          onTap: () => _showZoneDetailDialog(context, zone, jobs, underpaidRatio),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: strokeColor, width: 2),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black12,
                                  offset: Offset(2, 2),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                            child: Text(
                              zone[0].toUpperCase() + zone.substring(1),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                                color: PlayfulColors.foreground,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ));
                  });

                  return Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: PlayfulColors.border, width: 2.0),
                      boxShadow: const [
                        BoxShadow(
                          color: PlayfulColors.border,
                          offset: Offset(4, 4),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: FlutterMap(
                        options: const MapOptions(
                          initialCenter: LatLng(12.9716, 77.5946),
                          initialZoom: 12.0,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.gigshield.app',
                          ),
                          CircleLayer(circles: circles),
                          MarkerLayer(markers: markers),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
