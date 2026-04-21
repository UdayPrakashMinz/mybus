import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mybus/Pages/manage_bus_page.dart';
import 'package:mybus/Pages/profile_page.dart';
import 'package:mybus/utils/bus_utils.dart';
import 'create_trip_page.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  static DateTime _startOfToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static bool _isTripActive(Map<String, dynamic> tripData) {
    final rawStatus = tripData['status']?.toString().trim().toLowerCase() ?? '';
    if (rawStatus == 'active' ||
        rawStatus == 'scheduled' ||
        rawStatus == 'ongoing' ||
        rawStatus == 'running') {
      return true;
    }
    if (rawStatus == 'cancelled' ||
        rawStatus == 'canceled' ||
        rawStatus == 'completed' ||
        rawStatus == 'inactive' ||
        rawStatus == 'ended') {
      return false;
    }

    final departure = tripData['departureDate'];
    final departureDate = departure is Timestamp ? departure.toDate() : null;
    if (departureDate != null) {
      return !departureDate.isBefore(_startOfToday());
    }

    // If status/date is missing on older docs, don't hide potentially valid trips.
    return true;
  }

  static DateTime _extractDepartureDate(Map<String, dynamic> tripData) {
    final departure = tripData['departureDate'];
    if (departure is Timestamp) {
      return departure.toDate();
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),

      /// ---------------- APP BAR ----------------
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        toolbarHeight: 80,
        title: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: _loadUserDoc(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 40,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }

            if (snapshot.hasError) {
              return const Text("Error loading user");
            }

            final data = snapshot.data?.data() ?? {};
            final avatar = data['avatar'];
            final email = FirebaseAuth.instance.currentUser?.email ?? "";
            final name = (data['name'] as String?)?.trim();
            final roles = data['roles'] ?? {};
            final bool isAdmin = roles['admin'] == true;
            final bool isBusOwner = roles['busOwner'] == true;

            final displayName = (name != null && name.isNotEmpty)
                ? name
                : email;
            final roleLabel = isAdmin && isBusOwner
                ? "Admin / BusOwner"
                : isAdmin
                ? "Admin"
                : "BusOwner";

            return Row(
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ProfilePage()),
                    );
                  },
                  child: CircleAvatar(
                    radius: 24,
                    backgroundImage: avatar != null
                        ? AssetImage(avatar) as ImageProvider
                        : null,
                    child: avatar == null ? const Icon(Icons.person) : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Hi, $displayName",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      Text(
                        roleLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none, color: Colors.black),
          ),
          const SizedBox(width: 12),
        ],
      ),

      /// ---------------- BODY ----------------
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// OVERVIEW
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  "OVERVIEW",
                  style: TextStyle(
                    color: Colors.grey,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Chip(
                  label: Text("LIVE", style: TextStyle(color: Colors.blue)),
                  backgroundColor: Color(0xFFE6F0FF),
                ),
              ],
            ),

            const SizedBox(height: 16),

            /// STATS
            FutureBuilder<Map<String, String>>(
              future: _loadDashboardStats(),
              builder: (context, snapshot) {
                final stats =
                    snapshot.data ??
                    {
                      'totalFleet': '--',
                      'activeTrips': '--',
                      'bookedTicketsToday': '--',
                    };
                return Row(
                  children: [
                    _statCard(
                      icon: Icons.directions_bus,
                      title: "Total Buses",
                      value: stats['totalFleet'] ?? '--',
                    ),
                    const SizedBox(width: 12),
                    _statCard(
                      icon: Icons.route,
                      title: "Active Trips",
                      value: stats['activeTrips'] ?? '--',
                    ),
                    const SizedBox(width: 12),
                    _statCard(
                      icon: Icons.confirmation_num_outlined,
                      title: "Booked Tickets (Today)",
                      value: stats['bookedTicketsToday'] ?? '--',
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 12),

            /// ACTION BUTTONS
            Row(
              children: [
                _actionButton(
                  title: "Add New Bus",
                  icon: Icons.add,
                  color: Colors.blue,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ManageBusPage()),
                    );
                  },
                ),
                const SizedBox(width: 12),
                _actionButton(
                  title: "Create Trip",
                  icon: Icons.map,
                  color: Colors.black,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CreateTripPage()),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 32),

            /// CURRENT TRIPS
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  "Current Active Trips",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  "See All",
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            _activeTripsList(),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  /// ---------------- COMPONENTS ----------------

  static Widget _statCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Expanded(
      child: Container(
        height: 118,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.blue, size: 19),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _actionButton({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(height: 6),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _tripCard({
    required String busNo,
    required String route,
    required String seats,
    required String time,
    required String status,
    required Color statusColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              busNo,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  route,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.people, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        seats,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.access_time, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        time,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status,
              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _activeTripsList() {
    return FutureBuilder<bool>(
      future: _isCurrentUserAdmin(),
      builder: (context, adminSnapshot) {
        if (adminSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          return const Text(
            "Please login to view active trips",
            style: TextStyle(color: Colors.grey),
          );
        }

        Query<Map<String, dynamic>> query = FirebaseFirestore.instance
            .collection('trips');
        if (!(adminSnapshot.data ?? false)) {
          query = query.where('ownerId', isEqualTo: user.uid);
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: query.limit(80).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Text(
                "Unable to load active trips: ${snapshot.error}",
                style: const TextStyle(color: Colors.grey),
              );
            }

            final docs =
                (snapshot.data?.docs ?? [])
                    .where((doc) => _isTripActive(doc.data()))
                    .toList()
                  ..sort(
                    (a, b) => _extractDepartureDate(
                      b.data(),
                    ).compareTo(_extractDepartureDate(a.data())),
                  );
            final latestDocs = docs.take(5).toList();
            if (latestDocs.isEmpty) {
              return const Text(
                "No active trips found",
                style: TextStyle(color: Colors.grey),
              );
            }

            return Column(
              children: latestDocs.map((doc) {
                final trip = doc.data();
                final segments = trip['segments'] as List<dynamic>? ?? [];

                String route = 'Unknown route';
                String time = '--:--';
                String seats = '--';
                if (segments.isNotEmpty) {
                  final first = segments.first as Map<String, dynamic>;
                  final last = segments.last as Map<String, dynamic>;
                  route =
                      "${first['from'] ?? 'Unknown'} → ${last['to'] ?? 'Unknown'}";
                  time = (first['departureTime'] ?? '--:--').toString();
                  final availableSeats = first['availableSeats'];
                  seats = availableSeats != null
                      ? availableSeats.toString()
                      : '--';
                }

                final busNo = formatBusLabel(
                  name: trip['busName']?.toString(),
                  number: trip['busNumber'],
                );

                return _tripCard(
                  busNo: busNo,
                  route: route,
                  seats: seats,
                  time: time,
                  status: 'ACTIVE',
                  statusColor: Colors.green,
                );
              }).toList(),
            );
          },
        );
      },
    );
  }

  static Future<DocumentSnapshot<Map<String, dynamic>>> _loadUserDoc() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return FirebaseFirestore.instance.collection('users').doc('dummy').get();
    }
    return FirebaseFirestore.instance.collection('users').doc(user.uid).get();
  }

  static Future<Map<String, String>> _loadDashboardStats() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return {
          'totalFleet': '0',
          'activeTrips': '0',
          'bookedTicketsToday': '0',
        };
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final roles = userDoc.data()?['roles'] as Map<String, dynamic>? ?? {};
      final isAdmin = roles['admin'] == true;

      Query<Map<String, dynamic>> busesQuery = FirebaseFirestore.instance
          .collection('buses');
      Query<Map<String, dynamic>> tripsQuery = FirebaseFirestore.instance
          .collection('trips');

      if (!isAdmin) {
        busesQuery = busesQuery.where('ownerId', isEqualTo: user.uid);
        tripsQuery = tripsQuery.where('ownerId', isEqualTo: user.uid);
      }

      final results = await Future.wait([
        busesQuery.count().get(),
        tripsQuery.get(),
      ]);
      final busesCountSnapshot = results[0] as AggregateQuerySnapshot;
      final tripsDocs =
          (results[1] as QuerySnapshot<Map<String, dynamic>>).docs;
      final activeTripsCount = tripsDocs
          .where((doc) => _isTripActive(doc.data()))
          .length;
      final bookedToday = await _countBookedTicketsToday(
        isAdmin: isAdmin,
        userId: user.uid,
      );

      return {
        'totalFleet': busesCountSnapshot.count.toString(),
        'activeTrips': activeTripsCount.toString(),
        'bookedTicketsToday': bookedToday.toString(),
      };
    } catch (_) {
      return {'totalFleet': '0', 'activeTrips': '0', 'bookedTicketsToday': '0'};
    }
  }

  static Future<bool> _isCurrentUserAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final roles = userDoc.data()?['roles'] as Map<String, dynamic>? ?? {};
    return roles['admin'] == true;
  }

  static Future<int> _countBookedTicketsToday({
    required bool isAdmin,
    required String userId,
  }) async {
    const collections = ['bookings', 'tickets'];
    final todayStart = _startOfToday();
    final todayEnd = todayStart.add(const Duration(days: 1));
    final ownerTripIds = <String>{};

    if (!isAdmin) {
      final ownerTrips = await FirebaseFirestore.instance
          .collection('trips')
          .where('ownerId', isEqualTo: userId)
          .get();
      ownerTripIds.addAll(ownerTrips.docs.map((d) => d.id));
    }

    for (final collectionName in collections) {
      final docs = await _loadTodayDocsFromAnyDateField(
        collectionName: collectionName,
        todayStart: todayStart,
        todayEnd: todayEnd,
      );
      if (docs.isEmpty) continue;
      if (isAdmin) return docs.length;

      var count = 0;
      for (final doc in docs) {
        final data = doc.data();
        final ownerId = data['ownerId']?.toString();
        final busOwnerId = data['busOwnerId']?.toString();
        final operatorId = data['operatorId']?.toString();
        final tripId = data['tripId']?.toString();

        final belongsToUser =
            ownerId == userId ||
            busOwnerId == userId ||
            operatorId == userId ||
            (tripId != null && ownerTripIds.contains(tripId));
        if (belongsToUser) {
          count++;
        }
      }
      return count;
    }

    return 0;
  }

  static Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _loadTodayDocsFromAnyDateField({
    required String collectionName,
    required DateTime todayStart,
    required DateTime todayEnd,
  }) async {
    const candidateDateFields = [
      'bookingDate',
      'bookedAt',
      'createdAt',
      'timestamp',
      'travelDate',
      'departureDate',
    ];

    for (final field in candidateDateFields) {
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection(collectionName)
            .where(
              field,
              isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart),
            )
            .where(field, isLessThan: Timestamp.fromDate(todayEnd))
            .get();
        if (snapshot.docs.isNotEmpty) {
          return snapshot.docs;
        }
      } catch (_) {
        // Try the next probable date field.
      }
    }

    return <QueryDocumentSnapshot<Map<String, dynamic>>>[];
  }
}
