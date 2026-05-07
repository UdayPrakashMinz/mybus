import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mybus/Pages/razorpay_payment_page.dart';
import 'package:mybus/utils/time_utils.dart';

enum BookingAction { bookOnly, razorpayCheckout }

class BusDetailsPage extends StatefulWidget {
  final Map<String, dynamic> bus;
  final String? tripId;
  final DateTime? travelDate;
  final Map<String, dynamic>? segment;

  const BusDetailsPage({
    super.key,
    required this.bus,
    this.tripId,
    this.travelDate,
    this.segment,
  });

  static const Color _primary = Color(0xFF137FEC);
  static const Color _bgLight = Color(0xFFF6F7F8);
  static const Color _razorpayBlue = Color(0xFF0F4FDB);

  static const String _razorpayPaymentMethod = 'razorpay';
  static const String _notificationType = 'booking_update';

  @override
  State<BusDetailsPage> createState() => _BusDetailsPageState();
}

class _BusDetailsPageState extends State<BusDetailsPage> {
  static const Color _primary = BusDetailsPage._primary;
  static const Color _bgLight = BusDetailsPage._bgLight;
  static const Color _razorpayBlue = BusDetailsPage._razorpayBlue;
  static const String _razorpayPaymentMethod =
      BusDetailsPage._razorpayPaymentMethod;
  static const String _notificationType = BusDetailsPage._notificationType;

  late final List<Map<String, dynamic>> _allSegments;
  late final List<String> _routePoints;
  late int _selectedFromIndex;
  late int _selectedToIndex;

  @override
  void initState() {
    super.initState();
    _allSegments = _normalizeSegments(
      widget.bus['allSegments'] ?? widget.segment?['allSegments'],
    );
    final effectiveSegment = widget.segment ?? widget.bus;
    final defaultFrom = effectiveSegment['from']?.toString() ?? 'From';
    final defaultTo = effectiveSegment['to']?.toString() ?? 'To';

    _routePoints = _deriveRoutePoints(
      allSegments: _allSegments,
      fallbackRoutePoints: (widget.bus['routePoints'] as List?)
          ?.map((e) => e.toString())
          .toList(),
      defaultFrom: defaultFrom,
      defaultTo: defaultTo,
    );
    final initialSelection = _initialSelectionIndices(
      routePoints: _routePoints,
      initialFrom: defaultFrom,
      initialTo: defaultTo,
    );
    _selectedFromIndex = initialSelection[0];
    _selectedToIndex = initialSelection[1];
  }

  List<Map<String, dynamic>> _normalizeSegments(dynamic raw) {
    if (raw is! List) return const [];
    final normalized = <Map<String, dynamic>>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final from = (item['from'] ?? '').toString().trim();
      final to = (item['to'] ?? '').toString().trim();
      if (from.isEmpty || to.isEmpty) continue;
      final depart = (item['depart'] ?? item['departureTime'] ?? '').toString();
      final arrive = (item['arrive'] ?? item['arrivalTime'] ?? '').toString();
      final fare = (item['fare'] as num?)?.toDouble() ?? 0;
      final distance =
          (item['distanceKm'] as num?)?.toDouble() ??
          (item['distance'] as num?)?.toDouble() ??
          (item['distance_km'] as num?)?.toDouble() ??
          0;
      normalized.add({
        ...item.cast<String, dynamic>(),
        'from': from,
        'to': to,
        'depart': depart,
        'arrive': arrive,
        'fare': fare,
        'distanceKm': distance,
      });
    }
    return normalized;
  }

  List<String> _deriveRoutePoints({
    required List<Map<String, dynamic>> allSegments,
    required List<String>? fallbackRoutePoints,
    required String defaultFrom,
    required String defaultTo,
  }) {
    if (allSegments.isNotEmpty) {
      final points = <String>[allSegments.first['from'].toString()];
      for (final seg in allSegments) {
        points.add(seg['to'].toString());
      }
      return points;
    }
    if (fallbackRoutePoints != null && fallbackRoutePoints.length > 1) {
      return fallbackRoutePoints;
    }
    return [defaultFrom, defaultTo];
  }

  List<int> _initialSelectionIndices({
    required List<String> routePoints,
    required String initialFrom,
    required String initialTo,
  }) {
    if (routePoints.length < 2) return [0, 1];
    final fromIndex = routePoints.indexWhere(
      (p) => p.toLowerCase() == initialFrom.toLowerCase(),
    );
    final toIndex = routePoints.indexWhere(
      (p) => p.toLowerCase() == initialTo.toLowerCase(),
    );
    final safeFrom = fromIndex >= 0 ? fromIndex : 0;
    var safeTo = toIndex >= 0 ? toIndex : routePoints.length - 1;
    if (safeTo <= safeFrom) safeTo = safeFrom + 1;
    if (safeTo >= routePoints.length) safeTo = routePoints.length - 1;
    return [safeFrom, safeTo];
  }

  List<Map<String, dynamic>> get _selectedSegments {
    if (_allSegments.isEmpty) return const [];
    final start = _selectedFromIndex.clamp(0, _allSegments.length - 1).toInt();
    final endExclusive = _selectedToIndex
        .clamp(start + 1, _allSegments.length)
        .toInt();
    return _allSegments.sublist(start, endExclusive);
  }

  String get _selectedFrom => _routePoints[_selectedFromIndex];

  String get _selectedTo => _routePoints[_selectedToIndex];

  String get _selectedDepart {
    final selected = _selectedSegments;
    if (selected.isEmpty) {
      return formatTime12h(
        (widget.segment ?? widget.bus)['depart']?.toString(),
      );
    }
    return formatTime12h(selected.first['depart']?.toString());
  }

  String get _selectedArrive {
    final selected = _selectedSegments;
    if (selected.isEmpty) {
      return formatTime12h(
        (widget.segment ?? widget.bus)['arrive']?.toString(),
      );
    }
    return formatTime12h(selected.last['arrive']?.toString());
  }

  double get _selectedFareValue {
    final selected = _selectedSegments;
    if (selected.isNotEmpty) {
      return selected.fold<double>(0, (sum, seg) {
        return sum + ((seg['fare'] as num?)?.toDouble() ?? 0);
      });
    }
    return _resolveFareValue(
      segmentFare: widget.segment?['fare'],
      busFare: widget.bus['fare'],
      priceText: widget.bus['price']?.toString() ?? 'Rs 0',
    );
  }

  double get _selectedDistanceKm {
    final selected = _selectedSegments;
    if (selected.isNotEmpty) {
      return selected.fold<double>(0, (sum, seg) {
        final value =
            (seg['distanceKm'] as num?)?.toDouble() ??
            (seg['distance'] as num?)?.toDouble() ??
            (seg['distance_km'] as num?)?.toDouble() ??
            0;
        return sum + value;
      });
    }
    return _resolveDistanceKm(widget.segment ?? widget.bus) ?? 0;
  }

  List<String> get _timelineTimes {
    if (_routePoints.isEmpty) return const [];
    final selected = _allSegments;
    return List<String>.generate(_routePoints.length, (index) {
      if (index == 0) {
        return selected.isNotEmpty
            ? formatTime12h(selected.first['depart']?.toString())
            : _selectedDepart;
      }
      if (selected.isNotEmpty && index - 1 < selected.length) {
        return formatTime12h(selected[index - 1]['arrive']?.toString());
      }
      if (index == _routePoints.length - 1) return _selectedArrive;
      return '--';
    });
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
    required String from,
    required String to,
    required String depart,
  }) {
    final id = _seatDocId(
      tripId: widget.tripId,
      travelDate: widget.travelDate,
      from: from,
      to: to,
      depart: depart,
    );
    if (id == null) return null;
    return FirebaseFirestore.instance.collection('seat_availability').doc(id);
  }

  @override
  Widget build(BuildContext context) {
    final String company = widget.bus["company"]?.toString() ?? "Bus";
    final String from = _selectedFrom;
    final String to = _selectedTo;
    final String depart = _selectedDepart;
    final String arrive = _selectedArrive;
    final String distanceText = _formatDistance(_selectedDistanceKm);
    final String price = _selectedFareValue > 0
        ? 'Rs ${_selectedFareValue.toStringAsFixed(0)}'
        : 'Rs --';
    final double fareValue = _selectedFareValue;
    final int seats = widget.bus["seats"] is num
        ? (widget.bus["seats"] as num).toInt()
        : int.tryParse(widget.bus["seats"]?.toString() ?? '') ?? 0;

    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'Bus Details',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.share_outlined), onPressed: () {}),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          _heroCard(company: company, from: from, to: to),
          const SizedBox(height: 16),
          _statsGrid(
            depart: depart,
            arrive: arrive,
            totalDistance: distanceText,
          ),
          const SizedBox(height: 16),

          _scheduleCard(
            points: _routePoints,
            times: _timelineTimes,
            selectedFromIndex: _selectedFromIndex,
            selectedToIndex: _selectedToIndex,
          ),
        ],
      ),
      bottomNavigationBar: _bookingBar(
        context,
        price: price,
        fareValue: fareValue,
        seats: seats,
        from: from,
        to: to,
        depart: depart,
        arrive: arrive,
      ),
    );
  }

  DateTime? _parseTimeOnDay(DateTime day, String time) {
    if (time.trim().isEmpty) return null;
    try {
      final parsed = DateFormat.jm().parseLoose(time);
      return DateTime(day.year, day.month, day.day, parsed.hour, parsed.minute);
    } catch (_) {
      try {
        final parsed24 = DateFormat('HH:mm').parse(time);
        return DateTime(
          day.year,
          day.month,
          day.day,
          parsed24.hour,
          parsed24.minute,
        );
      } catch (_) {
        return null;
      }
    }
  }

  String _formatDuration(String depart, String arrive) {
    final baseDay = widget.travelDate ?? DateTime.now();
    final depDt = _parseTimeOnDay(baseDay, depart);
    var arrDt = _parseTimeOnDay(baseDay, arrive);
    if (depDt == null || arrDt == null) return '--';
    if (arrDt.isBefore(depDt)) {
      arrDt = arrDt.add(const Duration(days: 1));
    }
    final diff = arrDt.difference(depDt);
    final hours = diff.inHours;
    final minutes = diff.inMinutes.remainder(60);
    if (hours <= 0 && minutes <= 0) return '--';
    if (hours == 0) return '${minutes}m';
    if (minutes == 0) return '${hours}h';
    return '${hours}h ${minutes}m';
  }

  double? _resolveDistanceKm(Map<String, dynamic> effectiveSegment) {
    final value =
        (effectiveSegment['distanceKm'] as num?) ??
        (effectiveSegment['distance'] as num?) ??
        (effectiveSegment['distance_km'] as num?) ??
        (widget.bus['distanceKm'] as num?) ??
        (widget.bus['distance'] as num?) ??
        (widget.bus['distance_km'] as num?);
    return value?.toDouble();
  }

  String _formatDistance(double? km) {
    if (km == null || km <= 0) return '--';
    if (km >= 100) return '${km.toStringAsFixed(0)} km';
    return '${km.toStringAsFixed(1)} km';
  }

  Widget _heroCard({
    required String company,
    required String from,
    required String to,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          SizedBox(
            height: 220,
            width: double.infinity,
            child: Image.network(
              'https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?auto=format&fit=crop&w=1200&q=80',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(color: Colors.grey.shade300);
              },
            ),
          ),
          Container(
            height: 220,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0xCC000000), Color(0x00000000)],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      company,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Route: $from → $to',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
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

  Widget _statsGrid({
    required String depart,
    required String arrive,
    required String totalDistance,
  }) {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            label: 'Departure',
            value: depart,
            subLabel: 'On Time',
            subColor: const Color(0xFF10B981),
            icon: Icons.check_circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            label: 'Arrival',
            value: arrive,
            subLabel: '+2 min',
            subColor: const Color(0xFFF59E0B),
            icon: Icons.schedule,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            label: 'Total Distance',
            value: totalDistance,
            subLabel: 'Route',
            subColor: _primary,
            icon: Icons.route,
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required String label,
    required String value,
    required String subLabel,
    required Color subColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(icon, size: 14, color: subColor),
              const SizedBox(width: 4),
              Text(
                subLabel,
                style: TextStyle(
                  color: subColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _scheduleCard({
    required List<String> points,
    required List<String> times,
    required int selectedFromIndex,
    required int selectedToIndex,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Journey Schedule',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              Text(
                'Track Live',
                style: TextStyle(
                  color: _primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            children: List.generate(points.length, (index) {
              final bool isCurrent = index == selectedFromIndex;
              final bool isInSelectedRange =
                  index >= selectedFromIndex && index <= selectedToIndex;
              final bool isDone = index < selectedFromIndex;
              final bool isLast = index == points.length - 1;
              return _timelineItem(
                index: index,
                title: points[index],
                time: times[index],
                isCurrent: isCurrent,
                isDone: isDone,
                isLast: isLast,
                isInSelectedRange: isInSelectedRange,
                isSelectedDestination: index == selectedToIndex,
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _timelineItem({
    required int index,
    required String title,
    required String time,
    required bool isCurrent,
    required bool isDone,
    required bool isLast,
    required bool isInSelectedRange,
    required bool isSelectedDestination,
  }) {
    final Color lineColor = isInSelectedRange
        ? _primary
        : const Color(0xFFE5E7EB);
    return GestureDetector(
      onTap: () {
        if (index > _selectedFromIndex) {
          setState(() {
            _selectedToIndex = index;
          });
        }
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? _primary.withOpacity(0.15)
                        : isSelectedDestination
                        ? const Color(0xFFE8F2FF)
                        : isDone
                        ? const Color(0xFFE5E7EB)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: isCurrent
                          ? _primary
                          : isSelectedDestination
                          ? _primary
                          : isDone
                          ? const Color(0xFFE5E7EB)
                          : const Color(0xFFD1D5DB),
                      width: 2,
                    ),
                  ),
                  child: isCurrent
                      ? Center(
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _primary,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        )
                      : isDone
                      ? const Icon(
                          Icons.check,
                          size: 14,
                          color: Color(0xFF6B7280),
                        )
                      : isSelectedDestination
                      ? const Icon(
                          Icons.flag,
                          size: 14,
                          color: Color(0xFF137FEC),
                        )
                      : isLast
                      ? const Icon(
                          Icons.location_on,
                          size: 14,
                          color: Color(0xFF9CA3AF),
                        )
                      : null,
                ),
                if (!isLast) Container(width: 2, height: 38, color: lineColor),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: isCurrent
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: isCurrent
                              ? const Color(0xFF111827)
                              : isInSelectedRange
                              ? const Color(0xFF1F2937)
                              : const Color(0xFF374151),
                        ),
                      ),
                      Text(
                        time,
                        style: TextStyle(
                          color: isInSelectedRange
                              ? _primary
                              : const Color(0xFF6B7280),
                          fontSize: 12,
                          fontWeight: isCurrent || isSelectedDestination
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isCurrent
                        ? 'Selected boarding'
                        : isSelectedDestination
                        ? 'Selected dropping'
                        : isDone
                        ? 'Departed'
                        : isLast
                        ? 'Destination'
                        : index > _selectedFromIndex
                        ? 'Tap to select dropping'
                        : 'Next stop',
                    style: TextStyle(
                      color: isCurrent || isSelectedDestination
                          ? _primary
                          : const Color(0xFF9CA3AF),
                      fontSize: 11,
                      fontWeight: isCurrent || isSelectedDestination
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static double _resolveFareValue({
    required dynamic segmentFare,
    required dynamic busFare,
    required String priceText,
  }) {
    if (segmentFare is num) return segmentFare.toDouble();
    if (busFare is num) return busFare.toDouble();
    final cleaned = priceText.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(cleaned) ?? 0;
  }

  Future<void> _sendBookingNotification(
    BuildContext context, {
    required String title,
    required String body,
    String? bookingId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('notifications').add({
          'userId': user.uid,
          'title': title,
          'body': body,
          'type': _notificationType,
          'bookingId': bookingId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$title · $body')));
  }

  Future<bool> _handleBooking(
    BuildContext context, {
    required String from,
    required String to,
    required String depart,
    required String arrive,
    required String price,
    required int seatsBooked,
    required int seatsAvailable,
    String? paymentMethod,
    String? paymentStatus,
    String? paymentId,
    String? paymentOrderId,
    String? paymentSignature,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to book a ticket')),
      );
      return false;
    }

    if (widget.tripId == null || widget.tripId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip info unavailable for booking')),
      );
      return false;
    }

    final fareValue = _selectedFareValue;
    final travelDay = widget.travelDate;
    String? createdBookingId;

    try {
      final bookingsRef = FirebaseFirestore.instance.collection('bookings');
      final seatRef = _seatDocRef(from: from, to: to, depart: depart);

      if (seatRef == null || travelDay == null) {
        final booking = {
          'userId': user.uid,
          'tripId': widget.tripId,
          'busName': widget.bus['company'],
          'from': from,
          'to': to,
          'departureTime': depart,
          'arrivalTime': arrive,
          'fare': fareValue,
          'seatsBooked': seatsBooked,
          'travelDate': travelDay != null
              ? Timestamp.fromDate(travelDay)
              : null,
          'status': 'pending',
          'paymentMethod': paymentMethod,
          'paymentStatus': paymentStatus,
          'paymentId': paymentId,
          'paymentOrderId': paymentOrderId,
          'paymentSignature': paymentSignature,
          'createdAt': FieldValue.serverTimestamp(),
        };
        final doc = await bookingsRef.add(booking);
        createdBookingId = doc.id;
      } else {
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final seatSnap = await transaction.get(seatRef);
          int available;
          if (seatSnap.exists) {
            available =
                (seatSnap.data()?['availableSeats'] as num?)?.toInt() ?? 0;
          } else {
            available = seatsAvailable;
          }

          if (available < seatsBooked) {
            throw Exception('Not enough seats available.');
          }

          final newAvailable = available - seatsBooked;

          final seatPayload = <String, dynamic>{
            'tripId': widget.tripId,
            'serviceDate': Timestamp.fromDate(travelDay),
            'from': from,
            'to': to,
            'depart': depart,
            'availableSeats': newAvailable,
            'updatedAt': FieldValue.serverTimestamp(),
          };
          if (!seatSnap.exists) {
            seatPayload['createdAt'] = FieldValue.serverTimestamp();
          }

          transaction.set(seatRef, seatPayload, SetOptions(merge: true));

          final bookingRef = bookingsRef.doc();
          createdBookingId = bookingRef.id;
          transaction.set(bookingRef, {
            'userId': user.uid,
            'tripId': widget.tripId,
            'busName': widget.bus['company'],
            'from': from,
            'to': to,
            'departureTime': depart,
            'arrivalTime': arrive,
            'fare': fareValue,
            'seatsBooked': seatsBooked,
            'travelDate': Timestamp.fromDate(travelDay),
            'status': 'pending',
            'paymentMethod': paymentMethod,
            'paymentStatus': paymentStatus,
            'paymentId': paymentId,
            'paymentOrderId': paymentOrderId,
            'paymentSignature': paymentSignature,
            'createdAt': FieldValue.serverTimestamp(),
          });
        });
      }
      if (context.mounted) {
        await _sendBookingNotification(
          context,
          title: 'Booking confirmed',
          body: '$seatsBooked seat(s) reserved.',
          bookingId: createdBookingId,
        );
      }
      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Booking failed: $e')));
      }
      return false;
    }
  }

  void _showBookingConfirmationSnack(
    BuildContext context, {
    required int seatsBooked,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Booking confirmed for $seatsBooked seat(s).')),
    );
  }

  Widget _bookingBar(
    BuildContext context, {
    required String price,
    required double fareValue,
    required int seats,
    required String from,
    required String to,
    required String depart,
    required String arrive,
  }) {
    final seatRef = _seatDocRef(from: from, to: to, depart: depart);
    if (seatRef != null) {
      return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: seatRef.snapshots(),
        builder: (context, snapshot) {
          final liveSeats = (snapshot.data?.data()?['availableSeats'] as num?)
              ?.toInt();
          return _bookingBarContent(
            context,
            price: price,
            fareValue: fareValue,
            seats: liveSeats ?? seats,
            from: from,
            to: to,
            depart: depart,
            arrive: arrive,
          );
        },
      );
    }

    return _bookingBarContent(
      context,
      price: price,
      fareValue: fareValue,
      seats: seats,
      from: from,
      to: to,
      depart: depart,
      arrive: arrive,
    );
  }

  Widget _bookingBarContent(
    BuildContext context, {
    required String price,
    required double fareValue,
    required int seats,
    required String from,
    required String to,
    required String depart,
    required String arrive,
  }) {
    final bool hasSeats = seats > 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          price,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          '/ seat',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$seats seats available',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF10B981),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: hasSeats
                        ? () async {
                            final selectedSeats = await _showSeatSelector(
                              context,
                              price: price,
                              seatsAvailable: seats,
                            );
                            if (selectedSeats == null) return;
                            final action = await _selectBookingAction(
                              context,
                              price: price,
                            );
                            if (action == null) return;
                            await _handleBookingAction(
                              context,
                              action: action,
                              price: price,
                              fareValue: fareValue,
                              seatsBooked: selectedSeats,
                              seatsAvailable: seats,
                              from: from,
                              to: to,
                              depart: depart,
                              arrive: arrive,
                            );
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 6,
                      shadowColor: _primary.withOpacity(0.3),
                    ),
                    child: const Text(
                      'Book Ticket',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFFF6F7F8),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<int?> _showSeatSelector(
    BuildContext context, {
    required String price,
    required int seatsAvailable,
  }) async {
    int selectedSeats = 1;
    return await showModalBottomSheet<int>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            final int maxSeats = seatsAvailable <= 0 ? 1 : seatsAvailable;
            if (selectedSeats > maxSeats) {
              selectedSeats = maxSeats;
            }

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select seats',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Available: $seatsAvailable',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      IconButton(
                        onPressed: selectedSeats > 1
                            ? () => setState(() => selectedSeats -= 1)
                            : null,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text(
                        '$selectedSeats',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      IconButton(
                        onPressed: selectedSeats < maxSeats
                            ? () => setState(() => selectedSeats += 1)
                            : null,
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                      const Spacer(),
                      Text(
                        '$price / seat',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: seatsAvailable <= 0
                          ? null
                          : () async {
                              Navigator.pop(sheetContext, selectedSeats);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 15,
                          color: Color(0xFFF6F7F8),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<BookingAction?> _selectBookingAction(
    BuildContext context, {
    required String price,
  }) {
    return showModalBottomSheet<BookingAction>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose booking option',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.confirmation_number_outlined),
                title: const Text('Book now'),
                subtitle: const Text('Reserve seats instantly.'),
                onTap: () =>
                    Navigator.pop(sheetContext, BookingAction.bookOnly),
              ),
              const Divider(height: 8),
              ListTile(
                leading: const Icon(Icons.payment, color: _razorpayBlue),
                title: const Text('Pay with Razorpay'),
                subtitle: Text('Proceed to payment processor · $price'),
                onTap: () =>
                    Navigator.pop(sheetContext, BookingAction.razorpayCheckout),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleBookingAction(
    BuildContext context, {
    required BookingAction action,
    required String price,
    required double fareValue,
    required int seatsBooked,
    required int seatsAvailable,
    required String from,
    required String to,
    required String depart,
    required String arrive,
  }) async {
    if (action == BookingAction.bookOnly) {
      final success = await _handleBooking(
        context,
        from: from,
        to: to,
        depart: depart,
        arrive: arrive,
        price: price,
        seatsBooked: seatsBooked,
        seatsAvailable: seatsAvailable,
        paymentMethod: 'manual',
        paymentStatus: 'not_required',
      );
      if (success && context.mounted) {
        _showBookingConfirmationSnack(context, seatsBooked: seatsBooked);
      }
      return;
    }

    final paymentResult = await _showRazorpayCheckout(
      context,
      amount: fareValue * seatsBooked,
      seatsBooked: seatsBooked,
    );
    if (paymentResult == null || paymentResult.paymentId.isEmpty) return;
    await _handleBooking(
      context,
      from: from,
      to: to,
      depart: depart,
      arrive: arrive,
      price: price,
      seatsBooked: seatsBooked,
      seatsAvailable: seatsAvailable,
      paymentMethod: _razorpayPaymentMethod,
      paymentStatus: 'paid',
      paymentId: paymentResult.paymentId,
      paymentOrderId: paymentResult.orderId,
      paymentSignature: paymentResult.signature,
    );
    if (context.mounted) {
      await _sendBookingNotification(
        context,
        title: 'Payment received',
        body: 'Razorpay checkout completed.',
      );
    }
  }

  Future<RazorpayPaymentResult?> _showRazorpayCheckout(
    BuildContext context, {
    required double amount,
    required int seatsBooked,
  }) async {
    return await Navigator.push<RazorpayPaymentResult>(
      context,
      MaterialPageRoute(
        builder: (_) => RazorpayPaymentPage(
          amount: amount,
          description: 'Seats: $seatsBooked',
        ),
      ),
    );
  }
}
