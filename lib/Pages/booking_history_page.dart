import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BookingHistoryPage extends StatelessWidget {
  const BookingHistoryPage({super.key});

  String _formatDate(Timestamp? ts) {
    if (ts == null) return 'Date TBD';
    return DateFormat('EEE, d MMM yyyy').format(ts.toDate());
  }

  String _formatTime(String? value) {
    if (value == null || value.trim().isEmpty) return '--';
    return value;
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

  Future<void> _cancelBooking({
    required BuildContext context,
    required DocumentReference<Map<String, dynamic>> bookingRef,
    required String? tripId,
    required DateTime? travelDate,
    required String from,
    required String to,
    required String depart,
    required int seatsBooked,
  }) async {
    final confirmed = await _confirmCancellation(context);
    if (confirmed != true) return;
    try {
      final seatRef = _seatDocRef(
        tripId: tripId,
        travelDate: travelDate,
        from: from,
        to: to,
        depart: depart,
      );

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        if (seatRef != null) {
          final seatSnap = await transaction.get(seatRef);
          final currentAvailable =
              (seatSnap.data()?['availableSeats'] as num?)?.toInt() ?? 0;
          final newAvailable = currentAvailable + seatsBooked;

          final seatPayload = <String, dynamic>{
            'tripId': tripId,
            'serviceDate': travelDate != null
                ? Timestamp.fromDate(travelDate)
                : null,
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
        }

        transaction.update(bookingRef, {
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
        });
      });

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Booking cancelled.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Cancel failed: $e')));
      }
    }
  }

  Future<bool?> _confirmCancellation(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cancel booking?'),
          content: const Text(
            'Are you sure you want to cancel this ticket? Seats will be released.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('No'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Yes, cancel'),
            ),
          ],
        );
      },
    );
  }

  DateTime? _combineDateAndTime(DateTime? day, String? time) {
    if (day == null || time == null || time.trim().isEmpty) return null;
    try {
      final parsed = DateFormat.jm().parseLoose(time);
      return DateTime(day.year, day.month, day.day, parsed.hour, parsed.minute);
    } catch (_) {
      return null;
    }
  }

  String _resolveStatus(Map<String, dynamic> data) {
    final rawStatus = data['status']?.toString() ?? 'pending';
    final normalized = rawStatus.toLowerCase();
    if (normalized == 'cancelled' || normalized == 'canceled') {
      return 'cancelled';
    }

    final travelDate = (data['travelDate'] as Timestamp?)?.toDate();
    final depart = data['departureTime']?.toString();
    final arrive = data['arrivalTime']?.toString();

    final depDt = _combineDateAndTime(travelDate, depart);
    var arrDt = _combineDateAndTime(travelDate, arrive);
    if (depDt != null && arrDt != null && arrDt.isBefore(depDt)) {
      arrDt = arrDt.add(const Duration(days: 1));
    }
    if (depDt == null) return rawStatus;
    final endTime = arrDt ?? depDt;
    final now = DateTime.now();

    if (now.isAfter(endTime)) {
      return 'expired';
    }
    if (now.isBefore(depDt)) {
      return 'upcoming';
    }
    return 'ongoing';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Please log in to view bookings.'));
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text('My Bookings'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .where('userId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const _EmptyState();
          }

          final sortedDocs = docs.toList()
            ..sort((a, b) {
              final aTs = a.data()['createdAt'] as Timestamp?;
              final bTs = b.data()['createdAt'] as Timestamp?;
              final aMillis = aTs?.millisecondsSinceEpoch ?? 0;
              final bMillis = bTs?.millisecondsSinceEpoch ?? 0;
              return bMillis.compareTo(aMillis);
            });

          double totalSpent = 0;
          for (final doc in sortedDocs) {
            final data = doc.data();
            final seatsBooked = (data['seatsBooked'] as num?)?.toInt() ?? 1;
            final fare = (data['fare'] as num?)?.toDouble() ?? 0;
            totalSpent += fare * seatsBooked;
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: sortedDocs.length,
                  itemBuilder: (context, index) {
                    final data = sortedDocs[index].data();
                    final from = data['from']?.toString() ?? 'From';
                    final to = data['to']?.toString() ?? 'To';
                    final depart = _formatTime(
                      data['departureTime']?.toString(),
                    );
                    final arrive = _formatTime(data['arrivalTime']?.toString());
                    final seatsBooked =
                        (data['seatsBooked'] as num?)?.toInt() ?? 1;
                    final fare = (data['fare'] as num?)?.toDouble() ?? 0;
                    final totalPrice = fare * seatsBooked;
                    final status = _resolveStatus(data);
                    final busName = data['busName']?.toString() ?? 'Bus';
                    final travelDate = data['travelDate'] as Timestamp?;
                    final tripId = data['tripId']?.toString();
                    final bookingRef = sortedDocs[index].reference;
                    final isCancelled =
                        status.toLowerCase() == 'cancelled' ||
                        status.toLowerCase() == 'canceled';
                    final isExpired = status.toLowerCase() == 'expired';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                        boxShadow: const [
                          BoxShadow(color: Color(0x14000000), blurRadius: 6),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  busName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              _statusPill(status),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$from → $to',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_formatDate(travelDate)} · $depart - $arrive',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF4B5563),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                'Seats: $seatsBooked',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Price: Rs ${totalPrice.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: (isCancelled || isExpired)
                                      ? null
                                      : () {
                                          _cancelBooking(
                                            context: context,
                                            bookingRef: bookingRef,
                                            tripId: tripId,
                                            travelDate: travelDate?.toDate(),
                                            from: from,
                                            to: to,
                                            depart: depart,
                                            seatsBooked: seatsBooked,
                                          );
                                        },
                                  child: const Text('Cancel'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _statusPill(String status) {
    final normalized = status.toLowerCase();
    Color background;
    Color foreground;

    if (normalized == 'cancelled' || normalized == 'canceled') {
      background = const Color(0xFFFEE2E2);
      foreground = const Color(0xFFEF4444);
    } else if (normalized == 'expired') {
      background = const Color(0xFFFEE2E2);
      foreground = const Color(0xFFEF4444);
    } else if (normalized == 'ongoing') {
      background = const Color(0xFFE0F7EC);
      foreground = const Color(0xFF10B981);
    } else if (normalized == 'upcoming') {
      background = const Color(0xFFEFF6FF);
      foreground = const Color(0xFF2563EB);
    } else {
      background = const Color(0xFFEFF6FF);
      foreground = const Color(0xFF2563EB);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(
            Icons.confirmation_number_outlined,
            size: 52,
            color: Colors.grey,
          ),
          SizedBox(height: 12),
          Text(
            'No bookings yet',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 6),
          Text(
            'Your tickets will appear here after booking.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
