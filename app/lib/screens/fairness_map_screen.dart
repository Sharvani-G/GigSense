import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'playful_widgets.dart';

// ---------------------------------------------------------------------------
// ZoneStats — Data Model representing aggregated metrics per zone
// ---------------------------------------------------------------------------
class ZoneStats {
  final String zone;
  final String platformsLabel;
  final double averagePercentage;
  final int totalTrips;
  final String confidenceTier;
  final Color statusColor;
  final String interpretation;

  ZoneStats({
    required this.zone,
    required this.platformsLabel,
    required this.averagePercentage,
    required this.totalTrips,
    required this.confidenceTier,
    required this.statusColor,
    required this.interpretation,
  });
}

// ---------------------------------------------------------------------------
// SearchSuggestion — Data Model for map search auto-completes
// ---------------------------------------------------------------------------
class SearchSuggestion {
  final String displayName;
  final double latitude;
  final double longitude;
  final bool isLocalZone;
  final String? zoneKey;

  SearchSuggestion({
    required this.displayName,
    required this.latitude,
    required this.longitude,
    required this.isLocalZone,
    this.zoneKey,
  });
}

class FairnessMapScreen extends StatefulWidget {
  const FairnessMapScreen({super.key});

  @override
  State<FairnessMapScreen> createState() => _FairnessMapScreenState();
}

class _FairnessMapScreenState extends State<FairnessMapScreen> {
  String _platformFilter = 'all'; // 'all', 'zomato', 'swiggy', 'uber', 'ola'
  String _timeFilter = 'all'; // 'all', 'morning', 'evening', 'latenight'
  String _activeView = 'map'; // 'map' or 'list'

  // Map & GPS State
  final MapController _mapController = MapController();
  LatLng? _userLocation;
  bool _isLocatingUser = false;

  // Search State
  final TextEditingController _searchController = TextEditingController();
  List<SearchSuggestion> _suggestions = [];
  bool _isOnlineSearching = false;
  Timer? _debounceTimer;
  final Map<String, List<SearchSuggestion>> _searchCache = {};

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

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

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

  List<ZoneStats> _computeZoneStats(List<DocumentSnapshot> docs) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final area = _getMatchedZone(data['area_hint']);
      if (area == null) continue;

      // Filter by platform
      final String platform = (data['platform'] as String?)?.toLowerCase() ?? 'other';
      if (_platformFilter != 'all' && platform != _platformFilter) continue;

      // Filter by time of day
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

      grouped.putIfAbsent(area, () => []).add(data);
    }

    final List<ZoneStats> list = [];

    _zoneCoordinates.forEach((zone, coords) {
      final jobs = grouped[zone] ?? [];
      final totalTrips = jobs.length;

      if (totalTrips < 2) {
        list.add(ZoneStats(
          zone: zone,
          platformsLabel: _platformFilter == 'all' ? 'All Platforms' : _platformFilter[0].toUpperCase() + _platformFilter.substring(1),
          averagePercentage: 0.0,
          totalTrips: totalTrips,
          confidenceTier: "Estimated",
          statusColor: const Color(0xFF94A3B8), // Gray
          interpretation: "Not enough reported trips to calculate a locality baseline.",
        ));
        return;
      }

      final Set<String> platforms = jobs
          .map((j) => (j['platform'] as String?) ?? 'other')
          .map((p) => p.isNotEmpty ? p[0].toUpperCase() + p.substring(1) : '')
          .where((p) => p.isNotEmpty)
          .toSet();
      final platformsLabel = platforms.isEmpty ? 'Other' : platforms.join(', ');

      double totalPct = 0.0;
      int pctCount = 0;
      for (var j in jobs) {
        final fare = (j['fare'] as num?)?.toDouble() ?? 0.0;
        final expected = (j['expected_fare'] as num?)?.toDouble() ?? 0.0;
        if (expected > 0.0) {
          totalPct += (fare / expected) * 100;
          pctCount++;
        }
      }
      final double averagePercentage = pctCount > 0 ? (totalPct / pctCount) : 100.0;

      String confidenceTier = "Estimated";
      if (totalTrips >= 15 && totalTrips < 50) {
        confidenceTier = "Growing";
      } else if (totalTrips >= 50) {
        confidenceTier = "Well-established";
      }

      Color statusColor;
      String interpretation;
      if (averagePercentage >= 100.0) {
        statusColor = PlayfulColors.quaternary; // Mint
        interpretation = "Workers reporting trips here have generally been paid the full expected rate.";
      } else if (averagePercentage >= 85.0) {
        statusColor = PlayfulColors.tertiary; // Amber
        interpretation = "Workers reporting trips here have generally been paid close to the expected rate.";
      } else {
        statusColor = PlayfulColors.secondary; // Pink
        interpretation = "Workers reporting trips here have generally experienced significant underpayments.";
      }

      list.add(ZoneStats(
        zone: zone,
        platformsLabel: platformsLabel,
        averagePercentage: averagePercentage,
        totalTrips: totalTrips,
        confidenceTier: confidenceTier,
        statusColor: statusColor,
        interpretation: interpretation,
      ));
    });

    return list;
  }

  // Locating User (GPS centering)
  Future<void> _locateUser() async {
    setState(() {
      _isLocatingUser = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Location services are disabled.")),
        );
        setState(() => _isLocatingUser = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Location permissions are denied.")),
          );
          setState(() => _isLocatingUser = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Location permissions are permanently denied.")),
        );
        setState(() => _isLocatingUser = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
        _isLocatingUser = false;
      });

      _mapController.move(_userLocation!, 13.5);
    } catch (e) {
      debugPrint("Error getting user location: $e");
      setState(() => _isLocatingUser = false);
    }
  }

  void _onSearchChanged(String val) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _updateSuggestions(val);
    });
  }

  // Suggestion & autocomplete search mapping
  void _updateSuggestions(String val) {
    if (val.trim().isEmpty) {
      setState(() {
        _suggestions = [];
      });
      return;
    }

    final query = val.toLowerCase().trim();
    final List<SearchSuggestion> list = [];

    // Filter local zones
    _zoneCoordinates.forEach((zone, coords) {
      if (zone.contains(query)) {
        list.add(SearchSuggestion(
          displayName: "${zone[0].toUpperCase() + zone.substring(1)} (GigShield Zone)",
          latitude: coords.latitude,
          longitude: coords.longitude,
          isLocalZone: true,
          zoneKey: zone,
        ));
      }
    });

    setState(() {
      _suggestions = list;
    });
  }

  Future<void> _searchOnline(String query) async {
    if (query.trim().isEmpty) return;

    final cacheKey = query.toLowerCase().trim();
    if (_searchCache.containsKey(cacheKey)) {
      setState(() {
        _suggestions = _searchCache[cacheKey]!;
        _isOnlineSearching = false;
      });
      return;
    }

    setState(() {
      _isOnlineSearching = true;
      _suggestions = [];
    });

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=5&bounded=1&viewbox=77.3,12.7,77.9,13.2',
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': 'com.gigshield.app'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final List<SearchSuggestion> list = [];

        // Keep local matches
        _zoneCoordinates.forEach((zone, coords) {
          if (zone.contains(query.toLowerCase().trim())) {
            list.add(SearchSuggestion(
              displayName: "${zone[0].toUpperCase() + zone.substring(1)} (GigShield Zone)",
              latitude: coords.latitude,
              longitude: coords.longitude,
              isLocalZone: true,
              zoneKey: zone,
            ));
          }
        });

        for (var item in data) {
          final name = item['display_name'] as String;
          final lat = double.tryParse(item['lat'] ?? '');
          final lon = double.tryParse(item['lon'] ?? '');
          if (lat != null && lon != null) {
            list.add(SearchSuggestion(
              displayName: name,
              latitude: lat,
              longitude: lon,
              isLocalZone: false,
            ));
          }
        }

        _searchCache[cacheKey] = list;

        setState(() {
          _suggestions = list;
          _isOnlineSearching = false;
        });

        if (list.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No results found in Bengaluru region.")),
          );
        }
      } else {
        setState(() => _isOnlineSearching = false);
      }
    } catch (e) {
      debugPrint("Error searching online: $e");
      setState(() => _isOnlineSearching = false);
    }
  }

  ZoneStats? _getNearestZone(List<ZoneStats> stats) {
    if (_userLocation == null) return null;
    ZoneStats? nearest;
    double minDistance = double.infinity;

    for (var s in stats) {
      final coords = _zoneCoordinates[s.zone];
      if (coords == null) continue;

      final dist = Geolocator.distanceBetween(
        _userLocation!.latitude,
        _userLocation!.longitude,
        coords.latitude,
        coords.longitude,
      );

      if (dist < minDistance) {
        minDistance = dist;
        nearest = s;
      }
    }
    return nearest;
  }

  void _showZoneDetailBottomSheet(BuildContext context, ZoneStats stats) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFFFFFDF5),
            border: Border(
              top: BorderSide(color: PlayfulColors.border, width: 4),
            ),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    stats.zone.toUpperCase(),
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: PlayfulColors.foreground,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: stats.statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: stats.statusColor, width: 1.5),
                    ),
                    child: Text(
                      stats.totalTrips < 2
                          ? "NO DATA"
                          : stats.averagePercentage >= 100.0
                              ? "Trending Fair"
                              : stats.averagePercentage >= 85.0
                                  ? "Mixed Pay"
                                  : "Trending Underpaid",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: stats.statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(color: PlayfulColors.border, thickness: 2),
              const SizedBox(height: 12),

              _buildDetailRow("Platforms covered", stats.platformsLabel),
              _buildDetailRow("Average pay rate", stats.totalTrips >= 2 ? "${stats.averagePercentage.toStringAsFixed(0)}% of expected" : "N/A"),
              _buildDetailRow("Confidence tier", stats.confidenceTier),
              _buildDetailRow("Total reported trips", "${stats.totalTrips}"),

              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: PlayfulColors.border, width: 2),
                ),
                child: Text(
                  stats.interpretation,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: PlayfulColors.foreground,
                  ),
                ),
              ),

              const SizedBox(height: 20),
              PlayfulButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("GOT IT"),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13, color: PlayfulColors.mutedForeground)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: GoogleFonts.shareTechMono(fontWeight: FontWeight.bold, fontSize: 13, color: PlayfulColors.foreground),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeChip(String label, String filterVal) {
    final isSelected = _timeFilter == filterVal;
    return GestureDetector(
      onTap: () => setState(() => _timeFilter = filterVal),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? PlayfulColors.accent : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: PlayfulColors.border, width: 2.0),
          boxShadow: [
            BoxShadow(
              color: isSelected ? PlayfulColors.accent : PlayfulColors.border,
              offset: const Offset(2, 2),
              blurRadius: 0,
            )
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

  Widget _buildPlatformChip(String label, String filterVal) {
    final isSelected = _platformFilter == filterVal;
    return GestureDetector(
      onTap: () => setState(() => _platformFilter = filterVal),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? PlayfulColors.secondary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: PlayfulColors.border, width: 2.0),
          boxShadow: [
            BoxShadow(
              color: isSelected ? PlayfulColors.secondary : PlayfulColors.border,
              offset: const Offset(2, 2),
              blurRadius: 0,
            )
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

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: PlayfulColors.border, width: 1.5),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            fontSize: 9,
            color: PlayfulColors.foreground,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final String platformLabel = _platformFilter == 'all'
        ? 'All Platforms'
        : _platformFilter[0].toUpperCase() + _platformFilter.substring(1);

    final String timeLabel = _timeFilter == 'all'
        ? 'All Day'
        : _timeFilter == 'morning'
            ? 'Mornings'
            : _timeFilter == 'evening'
                ? 'Evenings'
                : 'Late-Nights';

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
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('jobs').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: PlayfulColors.accent));
            }

            final docs = snapshot.data?.docs ?? [];
            final zoneStats = _computeZoneStats(docs);

            // Filter zones that have actual trip entries
            final activeZones = zoneStats.where((z) => z.totalTrips >= 2).toList();

            // Sort by expected percentage descending
            activeZones.sort((a, b) => b.averagePercentage.compareTo(a.averagePercentage));

            // Dynamic Summary Text
            String summaryText = "Not enough comparative data yet. Log more jobs to see locality baselines.";
            if (activeZones.isNotEmpty) {
              final best = activeZones.first;
              final worst = activeZones.last;
              if (best.zone == worst.zone) {
                summaryText = "This week: ${best.zone[0].toUpperCase() + best.zone.substring(1)} average is ${best.averagePercentage.toStringAsFixed(0)}% of expected fare for $platformLabel trips.";
              } else {
                summaryText = "This week: ${best.zone[0].toUpperCase() + best.zone.substring(1)} pays best (${best.averagePercentage.toStringAsFixed(0)}% of expected fare on average). ${worst.zone[0].toUpperCase() + worst.zone.substring(1)} trends lowest (${worst.averagePercentage.toStringAsFixed(0)}%).";
              }
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Platform filters row
                Padding(
                  padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 8.0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildPlatformChip("All Platforms", "all"),
                        const SizedBox(width: 8),
                        _buildPlatformChip("Zomato", "zomato"),
                        const SizedBox(width: 8),
                        _buildPlatformChip("Swiggy", "swiggy"),
                        const SizedBox(width: 8),
                        _buildPlatformChip("Uber", "uber"),
                        const SizedBox(width: 8),
                        _buildPlatformChip("Ola", "ola"),
                      ],
                    ),
                  ),
                ),

                // Time of day filters row
                Padding(
                  padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 8.0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
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

                // Active Filter Context Label
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                  child: Text(
                    "Showing: $platformLabel · $timeLabel",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: PlayfulColors.mutedForeground,
                    ),
                  ),
                ),

                // Lead Summary Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
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
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.lightbulb_outline,
                          color: PlayfulColors.accent,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            summaryText,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: PlayfulColors.foreground,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // View Toggle Pill (Map / List)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(9999),
                      border: Border.all(color: PlayfulColors.border, width: 2.0),
                      boxShadow: const [
                        BoxShadow(
                          color: PlayfulColors.border,
                          offset: Offset(3, 3),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _activeView = "map"),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _activeView == "map" ? PlayfulColors.accent : Colors.transparent,
                                borderRadius: BorderRadius.circular(9999),
                              ),
                              child: Center(
                                child: Text(
                                  "Map View",
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: _activeView == "map" ? Colors.white : PlayfulColors.foreground,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _activeView = "list"),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _activeView == "list" ? PlayfulColors.accent : Colors.transparent,
                                borderRadius: BorderRadius.circular(9999),
                              ),
                              child: Center(
                                child: Text(
                                  "List View",
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: _activeView == "list" ? Colors.white : PlayfulColors.foreground,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Main Content View
                Expanded(
                  child: _activeView == "map"
                      ? _buildMapView(zoneStats)
                      : _buildListView(zoneStats),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMapView(List<ZoneStats> stats) {
    final List<CircleMarker> circles = [];
    final List<Marker> markers = [];

    // 1. Plot Zone Circles & Labels
    for (var s in stats) {
      if (s.totalTrips < 2) continue; // Only draw circles/markers with data

      final coords = _zoneCoordinates[s.zone]!;
      circles.add(CircleMarker(
        point: coords,
        radius: 1200,
        useRadiusInMeter: true,
        color: s.statusColor.withOpacity(0.35),
        borderColor: s.statusColor,
        borderStrokeWidth: 3.0,
      ));

      markers.add(Marker(
        point: coords,
        width: 140,
        height: 50,
        child: Center(
          child: GestureDetector(
            onTap: () => _showZoneDetailBottomSheet(context, s),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: s.statusColor, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    offset: Offset(2, 2),
                    blurRadius: 2,
                  ),
                ],
              ),
              child: Text(
                s.zone[0].toUpperCase() + s.zone.substring(1),
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
    }

    // 2. User Location Marker
    if (_userLocation != null) {
      markers.add(Marker(
        point: _userLocation!,
        width: 36,
        height: 36,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
            ),
            Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Colors.blueAccent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ));
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
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

            // Top Search Bar Layout Overlay
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Container(
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
                child: Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12.0),
                      child: Icon(Icons.search, color: PlayfulColors.foreground),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        onSubmitted: _searchOnline,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: PlayfulColors.foreground,
                        ),
                        decoration: InputDecoration(
                          hintText: "Search locality or address...",
                          hintStyle: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: PlayfulColors.mutedForeground,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear, color: PlayfulColors.mutedForeground, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _suggestions = [];
                          });
                        },
                      ),
                  ],
                ),
              ),
            ),

            // Suggestions List Overlay Dropdown
            if (_suggestions.isNotEmpty || _isOnlineSearching)
              Positioned(
                top: 72,
                left: 16,
                right: 16,
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 220),
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
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Material(
                      color: Colors.transparent,
                      child: _isOnlineSearching
                          ? const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Center(child: CircularProgressIndicator(color: PlayfulColors.accent)),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              itemCount: _suggestions.length + 1,
                              separatorBuilder: (context, i) => const Divider(color: PlayfulColors.border, height: 1, thickness: 1.5),
                              itemBuilder: (context, index) {
                                if (index == _suggestions.length) {
                                  return ListTile(
                                    dense: true,
                                    leading: const Icon(Icons.search_outlined, color: PlayfulColors.accent, size: 18),
                                    title: Text(
                                      "Search online for '${_searchController.text}'",
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: PlayfulColors.accent,
                                      ),
                                    ),
                                    onTap: () => _searchOnline(_searchController.text),
                                  );
                                }

                                final sugg = _suggestions[index];
                                return ListTile(
                                  dense: true,
                                  leading: Icon(
                                    sugg.isLocalZone ? Icons.star : Icons.location_on_outlined,
                                    color: sugg.isLocalZone ? PlayfulColors.tertiary : PlayfulColors.mutedForeground,
                                    size: 18,
                                  ),
                                  title: Text(
                                    sugg.displayName,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: PlayfulColors.foreground,
                                    ),
                                  ),
                                  onTap: () {
                                    final latLng = LatLng(sugg.latitude, sugg.longitude);
                                    _mapController.move(latLng, 13.5);

                                    if (sugg.isLocalZone && sugg.zoneKey != null) {
                                      final matched = stats.firstWhere((s) => s.zone == sugg.zoneKey);
                                      _showZoneDetailBottomSheet(context, matched);
                                    }

                                    setState(() {
                                      _suggestions = [];
                                      _searchController.text = sugg.isLocalZone
                                          ? sugg.zoneKey![0].toUpperCase() + sugg.zoneKey!.substring(1)
                                          : sugg.displayName.split(',').first;
                                    });
                                  },
                                );
                              },
                            ),
                    ),
                  ),
                ),
              ),

            // User GPS Locate Button (floating above the legend)
            Positioned(
              bottom: 135,
              right: 12,
              child: GestureDetector(
                onTap: _locateUser,
                child: Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: PlayfulColors.border, width: 2.0),
                    boxShadow: const [
                      BoxShadow(
                        color: PlayfulColors.border,
                        offset: Offset(3, 3),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: Center(
                    child: _isLocatingUser
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: PlayfulColors.accent, strokeWidth: 2),
                          )
                        : const Icon(
                            Icons.my_location,
                            color: PlayfulColors.foreground,
                            size: 20,
                          ),
                  ),
                ),
              ),
            ),

            // Dynamic Nearest Zone Card
            if (_userLocation != null)
              Builder(
                builder: (context) {
                  final nearest = _getNearestZone(stats);
                  if (nearest == null) return const SizedBox.shrink();

                  final coords = _zoneCoordinates[nearest.zone]!;
                  final double distMeters = Geolocator.distanceBetween(
                    _userLocation!.latitude,
                    _userLocation!.longitude,
                    coords.latitude,
                    coords.longitude,
                  );
                  final String distanceStr = distMeters >= 1000
                      ? "${(distMeters / 1000.0).toStringAsFixed(1)} km"
                      : "${distMeters.round()} m";

                  return Positioned(
                    bottom: 135,
                    left: 12,
                    right: 72,
                    child: GestureDetector(
                      onTap: () {
                        _mapController.move(coords, 13.5);
                        _showZoneDetailBottomSheet(context, nearest);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: PlayfulColors.border, width: 2.0),
                          boxShadow: const [
                            BoxShadow(
                              color: PlayfulColors.border,
                              offset: Offset(3, 3),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: nearest.statusColor,
                                shape: BoxShape.circle,
                                border: Border.all(color: PlayfulColors.border, width: 1),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "NEAREST ZONE",
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 9,
                                      color: PlayfulColors.mutedForeground,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  Text(
                                    "${nearest.zone[0].toUpperCase() + nearest.zone.substring(1)} ($distanceStr)",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      color: PlayfulColors.foreground,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.arrow_forward_ios,
                              size: 10,
                              color: PlayfulColors.mutedForeground,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),

            // Persistent Legend Overlay (Bottom area)
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: PlayfulColors.border, width: 2.0),
                  boxShadow: const [
                    BoxShadow(
                      color: PlayfulColors.border,
                      offset: Offset(2, 2),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      "PAY FAIRNESS HEALTH BY LOCALITY",
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                        color: PlayfulColors.foreground,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Tapping a zone shows expected rates & data confidence.",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: PlayfulColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        _buildLegendDot(PlayfulColors.quaternary, "Fair (>=100%)"),
                        _buildLegendDot(PlayfulColors.tertiary, "Mixed (85-99%)"),
                        _buildLegendDot(PlayfulColors.secondary, "Underpaid (<85%)"),
                        _buildLegendDot(const Color(0xFF94A3B8), "No Data"),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListView(List<ZoneStats> stats) {
    // Sort so zones with data are at top (by percentage descending), others at bottom
    final withData = stats.where((s) => s.totalTrips >= 2).toList();
    withData.sort((a, b) => b.averagePercentage.compareTo(a.averagePercentage));

    final noData = stats.where((s) => s.totalTrips < 2).toList();
    final sortedList = [...withData, ...noData];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedList.length,
      itemBuilder: (context, index) {
        final s = sortedList[index];
        final bool hasData = s.totalTrips >= 2;

        return GestureDetector(
          onTap: () => _showZoneDetailBottomSheet(context, s),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: PlayfulColors.border, width: 2.0),
              boxShadow: const [
                BoxShadow(
                  color: PlayfulColors.border,
                  offset: Offset(3, 3),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      s.zone.toUpperCase(),
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: PlayfulColors.foreground,
                      ),
                    ),
                    Text(
                      hasData
                          ? "${s.averagePercentage.toStringAsFixed(0)}% of expected"
                          : "No Data",
                      style: GoogleFonts.shareTechMono(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: hasData ? s.statusColor : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Scope: ${s.platformsLabel}",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: PlayfulColors.mutedForeground,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: s.statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: s.statusColor, width: 1.2),
                      ),
                      child: Text(
                        s.confidenceTier,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: s.statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
