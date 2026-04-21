import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mybus/Pages/bus_details.dart';
import 'package:mybus/utils/bus_utils.dart';
import 'package:mybus/utils/location_cache.dart';
import 'package:mybus/utils/odisha_cities.dart';
import 'package:mybus/utils/time_utils.dart';

class SearchPage extends StatefulWidget {
  final String? initialFrom;
  final String? initialTo;
  final DateTime? initialDate;

  const SearchPage({
    super.key,
    this.initialFrom,
    this.initialTo,
    this.initialDate,
  });

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController searchController = TextEditingController();
  final TextEditingController fromController = TextEditingController();
  final TextEditingController toController = TextEditingController();
  DateTime? selectedDate;
  bool _manualDate = false;
  bool _autoAdvanced = false;

  String selectedFilter = "All";

  @override
  void initState() {
    super.initState();
    final cachedFrom = LocationCache.lastSelectedLocation;
    fromController.text = widget.initialFrom ?? cachedFrom ?? '';
    toController.text = '';
    selectedDate = widget.initialDate ?? DateTime.now();
    _manualDate = widget.initialDate != null;
  }

  @override
  void dispose() {
    searchController.dispose();
    fromController.dispose();
    toController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
    );
    if (selected != null) {
      setState(() {
        selectedDate = selected;
        _manualDate = true;
        _autoAdvanced = false;
      });
    }
  }

  void _shiftDate(int days) {
    final now = _dayStart(DateTime.now());
    final base = selectedDate ?? now;
    final next = _dayStart(base.add(Duration(days: days)));
    if (next.isBefore(now)) return;
    setState(() {
      selectedDate = next;
      _manualDate = true;
      _autoAdvanced = false;
    });
  }

  DateTime _dayStart(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  DateTime? _parseDateAndTime(Timestamp? dateTs, String? time) {
    if (dateTs == null || time == null || time.trim().isEmpty) return null;
    try {
      final day = dateTs.toDate();
      final parsed = DateFormat.jm().parseLoose(time);
      return DateTime(day.year, day.month, day.day, parsed.hour, parsed.minute);
    } catch (_) {
      return null;
    }
  }

  bool _isPastDepartureToday(DateTime? departureDateTime) {
    if (departureDateTime == null) return false;
    final now = DateTime.now();
    if (selectedDate == null) return departureDateTime.isBefore(now);
    final selectedDay = _dayStart(selectedDate!);
    if (!_sameDay(selectedDay, _dayStart(now))) return false;
    return departureDateTime.isBefore(now);
  }

  List<Map<String, dynamic>> _buildTripCards(List<QueryDocumentSnapshot> docs) {
    final now = DateTime.now();
    final today = _dayStart(now);
    final listingEnd = today.add(const Duration(days: 14));
    final List<Map<String, dynamic>> result = [];

    for (final doc in docs) {
      final trip = doc.data() as Map<String, dynamic>;
      final isRecurring = trip['recurring'] == true;
      final tripDate = trip['departureDate'] as Timestamp?;
      final busName = trip['busName']?.toString() ?? 'Unknown';
      final busNumber = trip['busNumber']?.toString() ?? '';
      final busLabel = formatBusLabel(name: busName, number: busNumber);
      final rcNumber =
          trip['rcNumber']?.toString() ??
          trip['rcNo']?.toString() ??
          trip['rc']?.toString() ??
          'N/A';
      final List<dynamic> segments = (trip['segments'] as List<dynamic>?) ?? [];
      if (segments.isEmpty) continue;
      final List<dynamic> returnSegments =
          (trip['returnSegments'] as List<dynamic>?) ?? [];

      Iterable<DateTime> serviceDays;
      if (isRecurring) {
        serviceDays = List<DateTime>.generate(
          15,
          (index) => today.add(Duration(days: index)),
        );
      } else {
        if (tripDate == null) continue;
        final tripDay = _dayStart(tripDate.toDate());
        if (tripDay.isBefore(today) || tripDay.isAfter(listingEnd)) continue;
        serviceDays = [tripDay];
      }

      DateTime? serviceDay;
      if (selectedDate != null) {
        final selectedDay = _dayStart(selectedDate!);
        if (selectedDay.isBefore(today) || selectedDay.isAfter(listingEnd)) {
          continue;
        }
        if (isRecurring) {
          serviceDay = selectedDay;
        } else if (tripDate != null &&
            _sameDay(tripDate.toDate(), selectedDay)) {
          serviceDay = selectedDay;
        } else {
          continue;
        }
      } else {
        for (final day in serviceDays) {
          if (serviceDay == null || day.isBefore(serviceDay)) {
            serviceDay = day;
          }
        }
      }
      if (serviceDay == null) continue;

      final dayTs = Timestamp.fromDate(serviceDay);
      final List<Map<String, dynamic>> cardSegments = [];
      final List<Map<String, dynamic>> cardReturnSegments = [];

      for (final rawSeg in segments) {
        final seg = rawSeg as Map<String, dynamic>;
        final from = (seg['from'] ?? '').toString().trim();
        final to = (seg['to'] ?? '').toString().trim();
        if (from.isEmpty || to.isEmpty) continue;

        final depart = (seg['departureTime'] ?? '').toString();
        final arrive = (seg['arrivalTime'] ?? '').toString();
        final departureDateTime = _parseDateAndTime(dayTs, depart);
        if (_isPastDepartureToday(departureDateTime)) continue;

        cardSegments.add({
          'from': from,
          'to': to,
          'depart': depart,
          'arrive': arrive,
          'fare': (seg['fare'] as num?)?.toDouble() ?? 0,
          'availableSeats': seg['availableSeats'] ?? 0,
          'departureDate': dayTs,
          'departureDateTime': departureDateTime,
        });
      }

      for (final rawSeg in returnSegments) {
        final seg = rawSeg as Map<String, dynamic>;
        final from = (seg['from'] ?? '').toString().trim();
        final to = (seg['to'] ?? '').toString().trim();
        if (from.isEmpty || to.isEmpty) continue;

        final depart = (seg['departureTime'] ?? '').toString();
        final arrive = (seg['arrivalTime'] ?? '').toString();
        final departureDateTime = _parseDateAndTime(dayTs, depart);
        if (_isPastDepartureToday(departureDateTime)) continue;

        cardReturnSegments.add({
          'from': from,
          'to': to,
          'depart': depart,
          'arrive': arrive,
          'fare': (seg['fare'] as num?)?.toDouble() ?? 0,
          'availableSeats': seg['availableSeats'] ?? 0,
          'departureDate': dayTs,
          'departureDateTime': departureDateTime,
        });
      }

      if (cardSegments.isEmpty) continue;

      cardSegments.sort((a, b) {
        final aDt = a['departureDateTime'] as DateTime?;
        final bDt = b['departureDateTime'] as DateTime?;
        if (aDt == null && bDt == null) return 0;
        if (aDt == null) return 1;
        if (bDt == null) return -1;
        return aDt.compareTo(bDt);
      });

      cardReturnSegments.sort((a, b) {
        final aDt = a['departureDateTime'] as DateTime?;
        final bDt = b['departureDateTime'] as DateTime?;
        if (aDt == null && bDt == null) return 0;
        if (aDt == null) return 1;
        if (bDt == null) return -1;
        return aDt.compareTo(bDt);
      });

      result.add({
        'tripId': doc.id,
        'busId': trip['busId'],
        'busLabel': busLabel,
        'busName': busName,
        'busNumber': busNumber,
        'rcNumber': rcNumber,
        'busType': trip['busType'] ?? 'Standard',
        'sleeper': trip['sleeper'] ?? false,
        'serviceDay': dayTs,
        'segments': cardSegments,
        'returnSegments': cardReturnSegments,
      });
    }

    result.sort((a, b) {
      final aSeg = (a['segments'] as List).isEmpty
          ? null
          : (a['segments'] as List).first['departureDateTime'] as DateTime?;
      final bSeg = (b['segments'] as List).isEmpty
          ? null
          : (b['segments'] as List).first['departureDateTime'] as DateTime?;
      if (aSeg == null && bSeg == null) return 0;
      if (aSeg == null) return 1;
      if (bSeg == null) return -1;
      return aSeg.compareTo(bSeg);
    });

    return result;
  }

  bool _matchesTripQuery(Map<String, dynamic> trip, String q) {
    if (q.isEmpty) return true;
    final fields = [
      trip['busName'],
      trip['busNumber'],
      trip['rcNumber'],
      trip['busType'],
    ].map((e) => e.toString().toLowerCase());

    if (fields.any((field) => field.contains(q))) return true;

    final segments = trip['segments'] as List<dynamic>;
    return segments.any((seg) {
      return seg['from'].toString().toLowerCase().contains(q) ||
          seg['to'].toString().toLowerCase().contains(q);
    });
  }

  bool _segmentMatchesFilters(Map<String, dynamic> seg) {
    final fromText = fromController.text.trim().toLowerCase();
    final toText = toController.text.trim().toLowerCase();

    if (fromText.isNotEmpty &&
        !seg['from'].toString().toLowerCase().contains(fromText)) {
      return false;
    }
    if (toText.isNotEmpty &&
        !seg['to'].toString().toLowerCase().contains(toText)) {
      return false;
    }
    return true;
  }

  List<String> _routeStops(List<Map<String, dynamic>> segments) {
    if (segments.isEmpty) return [];
    final stops = <String>[];
    stops.add(segments.first['from'].toString());
    for (final seg in segments) {
      stops.add(seg['to'].toString());
    }
    return stops;
  }

  Map<String, dynamic>? _matchRouteSpan(
    List<Map<String, dynamic>> segments,
    String fromText,
    String toText,
  ) {
    if (segments.isEmpty) return null;
    final stops = _routeStops(segments);
    if (stops.isEmpty) return null;

    bool matchesStop(String stop, String query) {
      return stop.toLowerCase().contains(query);
    }

    int? fromIndex;
    int? toIndex;

    if (fromText.isEmpty && toText.isEmpty) {
      return {
        'segments': segments,
        'fromIndex': 0,
        'toIndex': stops.length - 1,
      };
    }

    if (fromText.isNotEmpty && toText.isNotEmpty) {
      for (int i = 0; i < stops.length; i++) {
        if (!matchesStop(stops[i], fromText)) continue;
        for (int j = i + 1; j < stops.length; j++) {
          if (matchesStop(stops[j], toText)) {
            fromIndex = i;
            toIndex = j;
            break;
          }
        }
        if (fromIndex != null) break;
      }
      if (fromIndex == null || toIndex == null) return null;
    } else if (fromText.isNotEmpty) {
      for (int i = 0; i < stops.length; i++) {
        if (matchesStop(stops[i], fromText)) {
          fromIndex = i;
          toIndex = stops.length - 1;
          break;
        }
      }
      if (fromIndex == null) return null;
    } else if (toText.isNotEmpty) {
      for (int j = 1; j < stops.length; j++) {
        if (matchesStop(stops[j], toText)) {
          fromIndex = 0;
          toIndex = j;
          break;
        }
      }
      if (toIndex == null) return null;
    }

    final segStart = fromIndex!;
    final segEnd = toIndex! - 1;
    if (segStart < 0 || segEnd >= segments.length || segStart > segEnd) {
      return null;
    }

    return {
      'segments': segments.sublist(segStart, segEnd + 1),
      'fromIndex': fromIndex,
      'toIndex': toIndex,
    };
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> trips) {
    final q = searchController.text.trim().toLowerCase();
    final hasRouteFilter =
        fromController.text.trim().isNotEmpty ||
        toController.text.trim().isNotEmpty;

    final List<Map<String, dynamic>> result = [];
    for (final trip in trips) {
      if (!_matchesTripQuery(trip, q)) continue;

      final serviceDay = trip['serviceDay'] as Timestamp?;
      if (selectedDate != null && serviceDay != null) {
        if (!_sameDay(serviceDay.toDate(), selectedDate!)) continue;
      }

      final segments = List<Map<String, dynamic>>.from(
        trip['segments'] as List,
      );
      final returnSegments = List<Map<String, dynamic>>.from(
        (trip['returnSegments'] as List?) ?? const [],
      );
      final fromText = fromController.text.trim().toLowerCase();
      final toText = toController.text.trim().toLowerCase();

      final routeMatch = _matchRouteSpan(segments, fromText, toText);
      final returnRouteMatch = _matchRouteSpan(
        returnSegments,
        fromText,
        toText,
      );
      if (hasRouteFilter && routeMatch == null && returnRouteMatch == null) {
        continue;
      }

      final filteredSegs = hasRouteFilter
          ? (routeMatch == null
                ? <Map<String, dynamic>>[]
                : (routeMatch['segments'] as List<Map<String, dynamic>>))
          : segments;
      final filteredReturnSegs = hasRouteFilter
          ? (returnRouteMatch == null
                ? <Map<String, dynamic>>[]
                : (returnRouteMatch['segments'] as List<Map<String, dynamic>>))
          : returnSegments;

      if (selectedFilter == "AC") {
        if (!trip['busType'].toString().toLowerCase().contains('ac')) {
          continue;
        }
      } else if (selectedFilter == "Non-AC") {
        if (trip['busType'].toString().toLowerCase().contains('ac')) {
          continue;
        }
      } else if (selectedFilter == "Sleeper") {
        if (trip['sleeper'] != true &&
            !trip['busType'].toString().toLowerCase().contains('sleeper')) {
          continue;
        }
      }

      result.add({
        ...trip,
        'visibleSegments': filteredSegs,
        'visibleReturnSegments': filteredReturnSegs,
      });
    }

    return result;
  }

  double _totalDistanceKm(List<dynamic> segments) {
    double total = 0;
    for (final rawSeg in segments) {
      final seg = rawSeg as Map<String, dynamic>;
      final value =
          (seg['distanceKm'] as num?) ??
          (seg['distance'] as num?) ??
          (seg['distance_km'] as num?);
      if (value != null) total += value.toDouble();
    }
    return total;
  }

  String _formatTripDate(Timestamp? ts) {
    if (ts == null) return 'Date TBD';
    return DateFormat('EEE, d MMM').format(ts.toDate());
  }

  Map<String, dynamic>? _bestPriceSummary(List<Map<String, dynamic>> trips) {
    double? bestFare;
    Map<String, dynamic>? bestTrip;
    Map<String, dynamic>? bestSeg;

    for (final trip in trips) {
      final segments = trip['visibleSegments'] as List<dynamic>;
      for (final rawSeg in segments) {
        final seg = rawSeg as Map<String, dynamic>;
        final fare = (seg['fare'] as num?)?.toDouble() ?? 0;
        if (fare <= 0) continue;
        if (bestFare == null || fare < bestFare) {
          bestFare = fare;
          bestTrip = trip;
          bestSeg = seg;
        }
      }
    }

    if (bestFare == null || bestTrip == null || bestSeg == null) return null;
    return {
      'fare': bestFare,
      'busLabel': bestTrip['busLabel'],
      'from': bestSeg['from'],
      'to': bestSeg['to'],
    };
  }

  String _busTitle(String busName, String busNumber, String rcNumber) {
    final parts = <String>[busName];
    if (busNumber.isNotEmpty) parts.add('#$busNumber');
    if (rcNumber.isNotEmpty && rcNumber != 'N/A') parts.add(rcNumber);
    return parts.join('  ');
  }

  Widget _compareCard(Map<String, dynamic> compare) {
    return _CompareCard(
      busLabel: compare['busLabel']?.toString() ?? '',
      from: compare['from']?.toString() ?? '',
      to: compare['to']?.toString() ?? '',
      fare: (compare['fare'] as num?)?.toDouble() ?? 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Search Trips',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Filter by route and date. Destination is optional.',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 16),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('trips')
                          .where('status', isEqualTo: 'active')
                          .snapshots(),
                      builder: (context, snapshot) {
                        final locations = _extractLocations(
                          snapshot.data?.docs ?? [],
                        );
                        return Row(
                          children: [
                            Expanded(
                              child: _locationField(
                                controller: fromController,
                                hintText: "From",
                                icon: Icons.trip_origin,
                                suggestions: locations,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _locationField(
                                controller: toController,
                                hintText: "To",
                                icon: Icons.place,
                                suggestions: locations,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: searchController,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              hintText: "Search bus/company",
                              prefixIcon: const Icon(Icons.search),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              suffixIcon: searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.close),
                                      onPressed: () {
                                        searchController.clear();
                                        setState(() {});
                                      },
                                    )
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _dateNavButton(
                          icon: Icons.chevron_left,
                          onTap: () => _shiftDate(-1),
                        ),
                        InkWell(
                          onTap: _pickDate,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today, size: 14),
                                const SizedBox(width: 6),
                                Text(
                                  selectedDate == null
                                      ? "Today"
                                      : "${selectedDate!.day}/${selectedDate!.month}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        _dateNavButton(
                          icon: Icons.chevron_right,
                          onTap: () => _shiftDate(1),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 56,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    _chip("All"),
                    _chip("AC"),
                    _chip("Non-AC"),
                    _chip("Sleeper"),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Divider(
                  height: 20,
                  thickness: 2,
                  color: Color.fromARGB(255, 206, 224, 248),
                ),
              ),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('trips')
                    .where('status', isEqualTo: 'active')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];
                  final allTrips = _buildTripCards(docs);
                  final visibleTrips = _applyFilters(allTrips);

                  if (visibleTrips.isEmpty) {
                    _autoAdjustDateIfNeeded();
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: _EmptyStateCard(),
                    );
                  }

                  final compare = _bestPriceSummary(visibleTrips);

                  return ListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (compare != null) _compareCard(compare),
                      ...visibleTrips.map((trip) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _tripCard(context, trip),
                        );
                      }),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String text) {
    final selected = selectedFilter == text;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: selected,
        label: Text(text),
        selectedColor: const Color(0xFF137FEC),
        labelStyle: TextStyle(
          color: selected ? Colors.white : Colors.black,
          fontWeight: FontWeight.w600,
        ),
        onSelected: (_) {
          setState(() => selectedFilter = text);
        },
      ),
    );
  }

  Widget _dateNavButton({required IconData icon, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF3FF),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFBFD9FF)),
          ),
          child: Icon(icon, color: const Color(0xFF137FEC)),
        ),
      ),
    );
  }

  void _autoAdjustDateIfNeeded() {
    if (_manualDate) return;
    if (fromController.text.trim().isEmpty) return;
    final now = DateTime.now();
    if (selectedDate == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          selectedDate = now;
          _autoAdvanced = false;
        });
      });
      return;
    }

    if (!_autoAdvanced && _sameDay(selectedDate!, now)) {
      final tomorrow = now.add(const Duration(days: 1));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          selectedDate = tomorrow;
          _autoAdvanced = true;
        });
      });
    }
  }

  Widget _tripCard(BuildContext context, Map<String, dynamic> trip) {
    return _withBusInfo(
      trip,
      builder: (busInfo) {
        if (busInfo['isActive'] == false) {
          return const SizedBox.shrink();
        }
        final busType = (busInfo['busType'] ?? trip['busType'] ?? 'Standard')
            .toString();
        final isSleeper =
            busInfo['isSleeper'] == true ||
            trip['sleeper'] == true ||
            busType.toLowerCase().contains('sleeper');
        final typeLower = busType.toLowerCase();
        final isAc = typeLower.contains('ac') && !typeLower.contains('non');
        final isExpress = typeLower.contains('express');
        final busNumber = trip['busNumber'].toString();
        final serviceDay = trip['serviceDay'] as Timestamp?;
        final segments = trip['visibleSegments'] as List<dynamic>;
        final returnSegments =
            trip['visibleReturnSegments'] as List<dynamic>? ?? [];
        final displaySegments = segments.isNotEmpty ? segments : returnSegments;
        final firstSeg = displaySegments.first as Map<String, dynamic>;
        final lastSeg = displaySegments.last as Map<String, dynamic>;
        final routeText = '${firstSeg['from']} → ${lastSeg['to']}';
        final timeText =
            '${formatTime12h(firstSeg['depart'] as String?)} - ${formatTime12h(lastSeg['arrive'] as String?)}';
        final totalSeats = _resolveTotalSeats(
          busInfo.isNotEmpty ? busInfo : trip,
        );
        final seatRef = _seatDocRef(
          tripId: trip['tripId']?.toString(),
          travelDate: serviceDay?.toDate(),
          from: firstSeg['from']?.toString() ?? '',
          to: lastSeg['to']?.toString() ?? '',
          depart: firstSeg['depart']?.toString() ?? '',
        );
        final totalFare = displaySegments.fold<double>(0, (sum, rawSeg) {
          final seg = rawSeg as Map<String, dynamic>;
          final fare = (seg['fare'] as num?)?.toDouble() ?? 0;
          return sum + fare;
        });

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF93C5FD)),
                      ),
                      child: const Icon(
                        Icons.directions_bus,
                        color: Color(0xFF1D4ED8),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _busTitle(
                              trip['busName'].toString(),
                              busNumber,
                              trip['rcNumber'],
                            ),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatTripDate(serviceDay),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF4B5563),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x332563EB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF93C5FD)),
                      ),
                      child: Text(
                        'Rs ${totalFare.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  routeText,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  timeText,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _tagPill(
                      isAc ? 'AC' : 'Non-AC',
                      background: const Color(0x332563EB),
                      foreground: Colors.black,
                    ),
                    _tagPill(
                      isSleeper ? 'Sleeper' : 'Seater',
                      background: const Color(0x332563EB),
                      foreground: Colors.black,
                    ),
                    if (isExpress)
                      _tagPill(
                        'Express',
                        background: const Color(0x332563EB),
                        foreground: Colors.black,
                      ),
                    _seatPill(
                      seatRef: seatRef,
                      totalSeats: totalSeats,
                      fallbackAvailable:
                          (firstSeg['availableSeats'] as num?)?.toInt() ?? 0,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Rs ${totalFare.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BusDetailsPage(
                              bus: {
                                'company': trip['busLabel'],
                                'type': busType,
                                'sleeper': isSleeper,
                                'price': 'Rs ${totalFare.toStringAsFixed(0)}',
                                'depart': firstSeg['depart'],
                                'arrive': lastSeg['arrive'],
                                'duration': '',
                                'seats': totalSeats ?? 0,
                                'from': firstSeg['from'],
                                'to': lastSeg['to'],
                                'amenities': const <String>[],
                                'routePoints': [
                                  firstSeg['from'],
                                  lastSeg['to'],
                                ],
                              },
                              tripId: trip['tripId']?.toString(),
                              travelDate: serviceDay?.toDate(),
                              segment: {
                                'from': firstSeg['from'],
                                'to': lastSeg['to'],
                                'depart': firstSeg['depart'],
                                'arrive': lastSeg['arrive'],
                                'fare': totalFare,
                                'distanceKm': _totalDistanceKm(displaySegments),
                              },
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF137FEC),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('View', style: TextStyle(fontSize: 11)),
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

  Widget _segmentList(
    BuildContext context, {
    required Map<String, dynamic> trip,
    required List<dynamic> segments,
    required bool isSleeper,
    required DateTime? travelDate,
  }) {
    return Column(
      children: segments.map((rawSeg) {
        final seg = rawSeg as Map<String, dynamic>;
        final seats = seg['availableSeats'] ?? 0;
        final fare = seg['fare'];
        final title = '${seg['from']} → ${seg['to']}';
        final timeText = '${seg['depart'] ?? '--'} - ${seg['arrive'] ?? '--'}';

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF7FAFF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE1ECFF)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeText,
                      style: const TextStyle(
                        color: Color(0xFF4B5563),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                fare != null ? 'Rs $fare' : 'Rs --',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BusDetailsPage(
                        bus: {
                          'company': trip['busLabel'],
                          'type': trip['busType'],
                          'sleeper': isSleeper,
                          'price': fare != null ? 'Rs $fare' : 'Rs --',
                          'depart': seg['depart'],
                          'arrive': seg['arrive'],
                          'duration': '',
                          'seats': seats,
                          'from': seg['from'],
                          'to': seg['to'],
                          'amenities': const <String>[],
                          'routePoints': [seg['from'], seg['to']],
                        },
                        tripId: trip['tripId']?.toString(),
                        travelDate: travelDate,
                        segment: {
                          'from': seg['from'],
                          'to': seg['to'],
                          'depart': seg['depart'],
                          'arrive': seg['arrive'],
                          'fare': seg['fare'],
                          'distanceKm': (seg['distanceKm'] as num?)?.toDouble(),
                        },
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF137FEC),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Book', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  int? _resolveTotalSeats(Map<String, dynamic> trip) {
    final candidates = [
      trip['totalSeats'],
      trip['seatCount'],
      trip['seatCapacity'],
      trip['capacity'],
    ];
    for (final value in candidates) {
      if (value is num && value > 0) return value.toInt();
    }
    return null;
  }

  Widget _tagPill(
    String text, {
    Color background = const Color(0xFFEAF3FF),
    Color foreground = const Color(0xFF0E5FB0),
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _safeKey(String value) {
    final key = value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    return key.replaceAll(RegExp(r'^_+|_+$'), '');
  }

  DocumentReference<Map<String, dynamic>>? _seatDocRef({
    required String? tripId,
    required DateTime? travelDate,
    required String from,
    required String to,
    required String depart,
  }) {
    if (tripId == null || tripId.isEmpty || travelDate == null) return null;
    final dateKey = DateFormat('yyyyMMdd').format(travelDate);
    final id = [
      tripId,
      dateKey,
      _safeKey(from),
      _safeKey(to),
      _safeKey(depart),
    ].join('_');
    return FirebaseFirestore.instance.collection('seat_availability').doc(id);
  }

  Widget _seatPill({
    required DocumentReference<Map<String, dynamic>>? seatRef,
    required int? totalSeats,
    required int fallbackAvailable,
  }) {
    if (seatRef == null) {
      final available = totalSeats ?? fallbackAvailable;
      final label = totalSeats == null
          ? 'Seats $available'
          : 'Seats $available/$totalSeats';
      return _tagPill(
        label,
        background: const Color(0x332563EB),
        foreground: Colors.black,
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: seatRef.snapshots(),
      builder: (context, snapshot) {
        final liveAvailable = (snapshot.data?.data()?['availableSeats'] as num?)
            ?.toInt();
        final available = liveAvailable ?? totalSeats ?? fallbackAvailable;
        final label = totalSeats == null
            ? 'Seats $available'
            : 'Seats $available/$totalSeats';
        return _tagPill(
          label,
          background: const Color(0x332563EB),
          foreground: Colors.black,
        );
      },
    );
  }

  Widget _locationField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    required List<String> suggestions,
  }) {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: controller.text),
      optionsBuilder: (TextEditingValue textEditingValue) {
        final query = textEditingValue.text.trim().toLowerCase();
        if (query.isEmpty) return const Iterable<String>.empty();
        return suggestions.where(
          (option) => option.toLowerCase().contains(query),
        );
      },
      onSelected: (selection) {
        controller.text = selection;
        setState(() {});
      },
      fieldViewBuilder: (context, textCtrl, focusNode, onFieldSubmitted) {
        textCtrl.value = controller.value;
        textCtrl.addListener(() {
          if (controller.text != textCtrl.text) {
            controller.value = textCtrl.value;
            setState(() {});
          }
        });
        return TextField(
          controller: textCtrl,
          focusNode: focusNode,
          onSubmitted: (_) => onFieldSubmitted(),
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: Icon(icon, size: 18),
            filled: true,
            fillColor: const Color(0xFFF2F5FA),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final optionList = options.toList(growable: false);
        const itemHeight = 48.0;
        const maxHeight = 240.0;
        final height = (optionList.length * itemHeight)
            .clamp(0, maxHeight)
            .toDouble();
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: height, maxWidth: 260),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: optionList.length,
                itemBuilder: (context, index) {
                  final option = optionList[index];
                  return ListTile(
                    dense: true,
                    title: Text(option),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  List<String> _extractLocations(List<QueryDocumentSnapshot> docs) {
    final map = <String, String>{
      for (final city in odishaCities) city.toLowerCase(): city,
    };
    for (final doc in docs) {
      final trip = doc.data() as Map<String, dynamic>;
      final segments = (trip['segments'] as List<dynamic>?) ?? [];
      for (final rawSeg in segments) {
        final seg = rawSeg as Map<String, dynamic>;
        final from = seg['from']?.toString().trim() ?? '';
        final to = seg['to']?.toString().trim() ?? '';
        if (from.isNotEmpty) {
          map[from.toLowerCase()] = from;
        }
        if (to.isNotEmpty) {
          map[to.toLowerCase()] = to;
        }
      }
    }
    final list = map.values.toList()..sort();
    return list;
  }

  Widget _withBusInfo(
    Map<String, dynamic> trip, {
    required Widget Function(Map<String, dynamic> busInfo) builder,
  }) {
    final busId = trip['busId']?.toString();
    if (busId == null || busId.isEmpty) {
      return builder(const {});
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('buses')
          .doc(busId)
          .snapshots(),
      builder: (context, snapshot) {
        final busInfo = snapshot.data?.data() ?? const <String, dynamic>{};
        return builder(busInfo);
      },
    );
  }
}

class _CompareCard extends StatelessWidget {
  final String busLabel;
  final String from;
  final String to;
  final double fare;

  const _CompareCard({
    required this.busLabel,
    required this.from,
    required this.to,
    required this.fare,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD7E9FF)),
      ),
      child: Row(
        children: [
          const Icon(Icons.insights, color: Color(0xFF137FEC)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Best price: Rs ${fare.toStringAsFixed(0)} · $from → $to · $busLabel',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 7, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'No trips found',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 6),
          Text(
            'Trips will appear here once agencies publish schedules.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          SizedBox(height: 12),
          Text(
            'Tip: try searching by bus name, number, or route.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
