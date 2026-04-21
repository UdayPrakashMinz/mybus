import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mybus/utils/time_utils.dart';
import 'edit_trip_page.dart';
import 'create_trip_page.dart';
import 'package:mybus/utils/bus_utils.dart';

class ManageTripsPage extends StatefulWidget {
  const ManageTripsPage({super.key});

  @override
  State<ManageTripsPage> createState() => _ManageTripsPageState();
}

class _ManageTripsPageState extends State<ManageTripsPage> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: AppBar(
        title: const Text("Manage Trips"),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (value) {
                        setState(() => _searchQuery = value.toLowerCase());
                      },
                      decoration: InputDecoration(
                        hintText: "Search by route or bus name",
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FloatingActionButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CreateTripPage(),
                        ),
                      ).then((created) {
                        if (created == true) {
                          setState(() {});
                        }
                      });
                    },
                    backgroundColor: const Color(0xFF137FEC),
                    child: const Icon(Icons.add, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Trips List
            Expanded(child: _buildTripsList()),
          ],
        ),
      ),
    );
  }

  Widget _buildTripsList() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text("Please login to manage trips"));
    }

    return FutureBuilder<bool>(
      future: _isUserAdmin(user.uid),
      builder: (context, adminSnapshot) {
        if (adminSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final isAdmin = adminSnapshot.data ?? false;
        // Build query based on admin status
        Query<Map<String, dynamic>> query = FirebaseFirestore.instance
            .collection('trips');

        if (!isAdmin) {
          query = query.where('ownerId', isEqualTo: user.uid);
        }
        return StreamBuilder<QuerySnapshot>(
          stream: query.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.schedule, size: 80, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text(
                      "No trips created yet",
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Create your first trip to get started",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              );
            }

            final trips = snapshot.data!.docs.toList()
              ..sort((a, b) {
                final aData = a.data() as Map<String, dynamic>;
                final bData = b.data() as Map<String, dynamic>;
                final aSortDate = _tripSortDate(aData);
                final bSortDate = _tripSortDate(bData);
                return bSortDate.compareTo(aSortDate);
              });

            // Filter trips based on search
            var filteredTrips = trips.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final busName = (data['busName'] ?? '').toString().toLowerCase();
              final segments = data['segments'] as List<dynamic>? ?? [];

              String route = '';
              if (segments.isNotEmpty) {
                final first = segments.first as Map<String, dynamic>;
                final last = segments.last as Map<String, dynamic>;
                route =
                    "${(first['from'] ?? '').toLowerCase()} ${(last['to'] ?? '').toLowerCase()}";
              }

              return busName.contains(_searchQuery) ||
                  route.contains(_searchQuery);
            }).toList();

            if (filteredTrips.isEmpty) {
              return Center(
                child: Text(
                  "No trips match your search",
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredTrips.length,
              itemBuilder: (context, index) {
                final tripDoc = filteredTrips[index];
                final trip = tripDoc.data() as Map<String, dynamic>;
                final tripId = tripDoc.id;

                return _buildTripCard(context, trip, tripId);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildTripCard(
    BuildContext context,
    Map<String, dynamic> trip,
    String tripId,
  ) {
    final rawName = trip['busName'] ?? 'Unknown Bus';
    final rawNumber = trip['busNumber'];
    final busName = formatBusLabel(name: rawName, number: rawNumber);
    final segments = trip['segments'] as List<dynamic>? ?? [];
    final returnSegments = trip['returnSegments'] as List<dynamic>? ?? [];
    final busId = trip['busId']?.toString();
    final rcNumber = trip['rcNumber'] ?? trip['rcNo'] ?? trip['rc'] ?? 'N/A';
    final busType = (trip['busType'] ?? 'Standard').toString();
    final typeLower = busType.toLowerCase();
    final isAc = typeLower.contains('ac') && !typeLower.contains('non');
    final isSleeper = trip['sleeper'] == true || typeLower.contains('sleeper');

    // Extract route info
    String fromTo = 'Unknown route';
    String? departureTime;
    String? arrivalTime;
    if (segments.isNotEmpty) {
      final first = segments.first as Map<String, dynamic>;
      final last = segments.last as Map<String, dynamic>;
      fromTo = "${first['from']} → ${last['to']}";
      departureTime = first['departureTime'] as String?;
      arrivalTime = last['arrivalTime'] as String?;
    }

    String? returnDepartureTime;
    if (returnSegments.isNotEmpty) {
      final firstReturn = returnSegments.first as Map<String, dynamic>;
      returnDepartureTime = firstReturn['departureTime'] as String?;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
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
                      busName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      fromTo,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditTripPage(tripId: tripId),
                      ),
                    ).then((updated) {
                      if (updated == true) {
                        setState(() {});
                      }
                    });
                  } else if (value == 'delete') {
                    _showDeleteDialog(tripId, rawName, rawNumber);
                  }
                },
                itemBuilder: (BuildContext context) => [
                  const PopupMenuItem<String>(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 20, color: Colors.black),
                        SizedBox(width: 12),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 20, color: Colors.red),
                        SizedBox(width: 12),
                        Text('Delete'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.access_time, size: 14, color: Colors.black54),
              const SizedBox(width: 6),
              Text(
                'Start: ${formatTime12h(departureTime)}',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.flag, size: 14, color: Colors.black54),
              const SizedBox(width: 6),
              Text(
                'Arrive: ${formatTime12h(arrivalTime)}',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
          if (returnDepartureTime != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.reply, size: 14, color: Colors.green),
                const SizedBox(width: 6),
                Text(
                  'Return start: ${formatTime12h(returnDepartureTime)}',
                  style: const TextStyle(fontSize: 12, color: Colors.green),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _tagPill(isAc ? 'AC' : 'Non-AC'),
              _tagPill(isSleeper ? 'Sleeper' : 'Seater'),
              _tagPill('RC: $rcNumber'),
              if (busId != null && busId.isNotEmpty) _busStatusPill(busId),
            ],
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(String tripId, String rawName, dynamic rawNumber) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Trip?"),
        content: Text(
          "Delete trip for ${formatBusLabel(name: rawName, number: rawNumber)}? This cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteTrip(tripId);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTrip(String tripId) async {
    try {
      await FirebaseFirestore.instance.collection('trips').doc(tripId).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Trip deleted successfully"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error deleting trip: $e")));
    }
  }

  Future<bool> _isUserAdmin(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final roles = doc.data()?['roles'] as Map<String, dynamic>? ?? {};
    return roles['admin'] == true;
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

  Widget _busStatusPill(String busId) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance.collection('buses').doc(busId).snapshots(),
      builder: (context, snapshot) {
        final isActive = snapshot.data?.data()?['isActive'] ?? true;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color:
                isActive ? Colors.green.shade100 : Colors.orange.shade100,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            isActive ? 'Active' : 'Inactive',
            style: TextStyle(
              color:
                  isActive ? Colors.green.shade700 : Colors.orange.shade700,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      },
    );
  }

  DateTime _tripSortDate(Map<String, dynamic> trip) {
    final departureDate = trip['departureDate'];
    if (departureDate is Timestamp) {
      return departureDate.toDate();
    }

    final createdAt = trip['createdAt'];
    if (createdAt is Timestamp) {
      return createdAt.toDate();
    }

    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
