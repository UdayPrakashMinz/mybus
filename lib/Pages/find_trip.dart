import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mybus/Pages/bus_details.dart';
import 'package:mybus/utils/bus_utils.dart';
import 'package:mybus/utils/odisha_cities.dart';
import 'package:mybus/utils/time_utils.dart';

class FindTripPage extends StatefulWidget {
  final String? initialFrom;
  final String? initialTo;
  final DateTime? initialDate;
  final String? initialBusName;

  const FindTripPage({
    super.key,
    this.initialFrom,
    this.initialTo,
    this.initialDate,
    this.initialBusName,
  });

  @override
  State<FindTripPage> createState() => _FindTripPageState();
}

class _FindTripPageState extends State<FindTripPage> {
  final TextEditingController fromController = TextEditingController();
  final TextEditingController toController = TextEditingController();
  DateTime? selectedDate;
  bool _manualDate = false;
  bool _autoAdvanced = false;
  String? _busNameFilter;

  @override
  void initState() {
    super.initState();
    fromController.text = widget.initialFrom ?? '';
    toController.text = '';
    selectedDate = widget.initialDate ?? DateTime.now();
    _manualDate = widget.initialDate != null;
    _busNameFilter = widget.initialBusName?.trim();
  }

  @override
  void dispose() {
    fromController.dispose();
    toController.dispose();
    super.dispose();
  }

  DateTime _dayStart(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
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

  String _safeKey(String value) {
    final key = value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    return key.replaceAll(RegExp(r'^_+|_+$'), '');
  }

  String? _seatDocId({
    required String? tripId,
    required DateTime? travelDate,
    required String from,
    required String to,
    required String depart,
  }) {
    if (tripId == null || tripId.isEmpty || travelDate == null) return null;
    final dateKey = DateFormat('yyyyMMdd').format(travelDate);
    return [
      tripId,
      dateKey,
      _safeKey(from),
      _safeKey(to),
      _safeKey(depart),
    ].join('_');
  }

  DocumentReference<Map<String, dynamic>>? _seatDocRef({
    required String? tripId,
    required DateTime? travelDate,
    required String from,
    required String to,
    required String depart,
  }) {
    final id = _seatDocId(
      tripId: tripId,
      travelDate: travelDate,
      from: from,
      to: to,
      depart: depart,
    );
    if (id == null) return null;
    return FirebaseFirestore.instance.collection('seat_availability').doc(id);
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

      for (final rawSeg in segments) {
        final seg = rawSeg as Map<String, dynamic>;
        final from = (seg['from'] ?? '').toString().trim();
        final to = (seg['to'] ?? '').toString().trim();
        if (from.isEmpty || to.isEmpty) continue;

        final depart = (seg['departureTime'] ?? '').toString();
        final arrive = (seg['arrivalTime'] ?? '').toString();
        final departureDateTime = _parseDateAndTime(dayTs, depart);
        if (_isPastDepartureToday(departureDateTime)) {
          continue;
        }

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

      if (cardSegments.isEmpty) continue;

      cardSegments.sort((a, b) {
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
    final hasRouteFilter =
        fromController.text.trim().isNotEmpty ||
        toController.text.trim().isNotEmpty;

    final List<Map<String, dynamic>> result = [];
    final fromText = fromController.text.trim().toLowerCase();
    final toText = toController.text.trim().toLowerCase();

    final busNameFilter = _busNameFilter?.toLowerCase() ?? '';

    for (final trip in trips) {
      if (busNameFilter.isNotEmpty) {
        final tripName = (trip['busName'] ?? '').toString().toLowerCase();
        if (!tripName.contains(busNameFilter)) continue;
      }
      final serviceDay = trip['serviceDay'] as Timestamp?;
      if (selectedDate != null && serviceDay != null) {
        if (!_sameDay(serviceDay.toDate(), selectedDate!)) continue;
      }

      final segments = List<Map<String, dynamic>>.from(
        trip['segments'] as List,
      );

      final routeMatch = _matchRouteSpan(segments, fromText, toText);
      if (hasRouteFilter && routeMatch == null) continue;

      final filteredSegs = hasRouteFilter
          ? (routeMatch!['segments'] as List<Map<String, dynamic>>)
          : segments;

      result.add({...trip, 'visibleSegments': filteredSegs});
    }

    return result;
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

  String _formatTripDate(Timestamp? ts) {
    if (ts == null) return 'Date TBD';
    return DateFormat('EEE, d MMM').format(ts.toDate());
  }

  String _busTitle(String busName, String busNumber, String rcNumber) {
    final parts = <String>[busName];
    if (busNumber.isNotEmpty) parts.add('#$busNumber');
    if (rcNumber.isNotEmpty && rcNumber != 'N/A') parts.add(rcNumber);
    return parts.join('  ');
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
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Find Your Trip',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Choose your start point and date to see active trips.',
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

                  return ListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: visibleTrips.map((trip) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _tripCard(context, trip),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
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
        final busNumber = trip['busNumber'].toString();
        final serviceDay = trip['serviceDay'] as Timestamp?;
        final segments = trip['visibleSegments'] as List<dynamic>;
        final totalSeats = _resolveTotalSeats(
          busInfo.isNotEmpty ? busInfo : trip,
        );

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
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
                        isSleeper ? 'Sleeper' : 'Seater',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _tagPill(isAc ? 'AC' : 'Non-AC'),
                    _tagPill(isSleeper ? 'Sleeper' : 'Seater'),
                  ],
                ),
                const SizedBox(height: 12),
                _tripSummary(
                  context,
                  trip: trip,
                  segments: segments,
                  isSleeper: isSleeper,
                  travelDate: serviceDay?.toDate(),
                  totalSeats: totalSeats,
                  busType: busType,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _tripSummary(
    BuildContext context, {
    required Map<String, dynamic> trip,
    required List<dynamic> segments,
    required bool isSleeper,
    required DateTime? travelDate,
    required int? totalSeats,
    required String busType,
  }) {
    if (segments.isEmpty) return const SizedBox.shrink();
    final fromText = fromController.text.trim().toLowerCase();
    final toText = toController.text.trim().toLowerCase();
    final routeMatch = _matchRouteSpan(
      List<Map<String, dynamic>>.from(segments),
      fromText,
      toText,
    );
    final visibleSegments = routeMatch == null
        ? segments
        : (routeMatch['segments'] as List<Map<String, dynamic>>);

    if (visibleSegments.isEmpty) return const SizedBox.shrink();

    final firstSeg = visibleSegments.first as Map<String, dynamic>;
    final lastSeg = visibleSegments.last as Map<String, dynamic>;
    final seats = totalSeats ?? 0;
    final departKey = formatTime12h(firstSeg['depart'] as String?);
    final int? fallbackAvailable = visibleSegments
        .map((rawSeg) {
          final value = (rawSeg as Map<String, dynamic>)['availableSeats']
              ?.toString();
          return int.tryParse(value ?? '');
        })
        .where((value) => value != null)
        .map((value) => value!)
        .fold<int?>(null, (minValue, current) {
          if (minValue == null) return current;
          return current < minValue ? current : minValue;
        });
    final totalFare = visibleSegments.fold<double>(0, (sum, rawSeg) {
      final seg = rawSeg as Map<String, dynamic>;
      final fare = (seg['fare'] as num?)?.toDouble() ?? 0;
      return sum + fare;
    });
    final totalDistanceKm = _totalDistanceKm(visibleSegments);
    final title = '${firstSeg['from']} → ${lastSeg['to']}';
    final timeText =
        '${formatTime12h(firstSeg['depart'] as String?)} - ${formatTime12h(lastSeg['arrive'] as String?)}';
    final seatRef = _seatDocRef(
      tripId: trip['tripId']?.toString(),
      travelDate: travelDate,
      from: firstSeg['from']?.toString() ?? '',
      to: lastSeg['to']?.toString() ?? '',
      depart: departKey ?? '',
    );

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
                const SizedBox(height: 4),
                _seatAvailabilityText(
                  seatRef: seatRef,
                  fallback: fallbackAvailable ?? seats,
                ),
              ],
            ),
          ),
          Text(
            totalFare > 0 ? 'Rs ${totalFare.toStringAsFixed(0)}' : 'Rs --',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
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
                      'type': busType,
                      'sleeper': isSleeper,
                      'price': totalFare > 0
                          ? 'Rs ${totalFare.toStringAsFixed(0)}'
                          : 'Rs --',
                      'depart': firstSeg['depart'],
                      'arrive': lastSeg['arrive'],
                      'duration': '',
                      'seats': seats,
                      'from': firstSeg['from'],
                      'to': lastSeg['to'],
                      'amenities': const <String>[],
                      'routePoints': [firstSeg['from'], lastSeg['to']],
                    },
                    tripId: trip['tripId']?.toString(),
                    travelDate: travelDate,
                    segment: {
                      'from': firstSeg['from'],
                      'to': lastSeg['to'],
                      'depart': firstSeg['depart'],
                      'arrive': lastSeg['arrive'],
                      'fare': totalFare,
                      'distanceKm': totalDistanceKm,
                    },
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF137FEC),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('View', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _tagPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF0E5FB0),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
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

  Widget _seatAvailabilityText({
    required DocumentReference<Map<String, dynamic>>? seatRef,
    required dynamic fallback,
  }) {
    if (seatRef == null) {
      final seatsValue = (fallback is num) ? fallback.toInt() : 0;
      return Text(
        'Seats: $seatsValue',
        style: const TextStyle(
          color: Color(0xFF10B981),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: seatRef.snapshots(),
      builder: (context, snapshot) {
        final liveSeats = (snapshot.data?.data()?['availableSeats'] as num?)
            ?.toInt();
        final seatsValue =
            liveSeats ?? ((fallback is num) ? fallback.toInt() : 0);
        return Text(
          'Seats: $seatsValue',
          style: const TextStyle(
            color: Color(0xFF10B981),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        );
      },
    );
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

  int? _resolveTotalSeats(Map<String, dynamic> data) {
    final candidates = [
      data['totalSeats'],
      data['seatCount'],
      data['seatCapacity'],
      data['capacity'],
    ];
    for (final value in candidates) {
      if (value is num && value > 0) return value.toInt();
      final parsed = int.tryParse(value?.toString() ?? '');
      if (parsed != null && parsed > 0) return parsed;
    }
    return null;
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
            'Try changing the date or route.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
