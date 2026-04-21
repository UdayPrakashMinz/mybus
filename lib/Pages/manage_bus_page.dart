import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mybus/utils/bus_utils.dart';
import 'package:mybus/utils/price_utils.dart';

class ManageBusPage extends StatefulWidget {
  const ManageBusPage({super.key});

  @override
  State<ManageBusPage> createState() => _ManageBusPageState();
}

class _ManageBusPageState extends State<ManageBusPage> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  bool _rebuildingPrices = false;

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
        title: const Text("Manage Buses"),
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
                        hintText: "Search by bus name or RC number",
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
                  IconButton(
                    onPressed: _rebuildingPrices ? null : _rebuildPrices,
                    icon: _rebuildingPrices
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync),
                    tooltip: 'Rebuild prices',
                  ),
                  const SizedBox(width: 6),
                  FloatingActionButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/add_bus').then((_) {
                        setState(() {});
                      });
                    },
                    backgroundColor: const Color(0xFF137FEC),
                    child: const Icon(Icons.add, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Bus List
            Expanded(child: _buildBusList()),
          ],
        ),
      ),
    );
  }

  Widget _buildBusList() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text("Please login to manage buses"));
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
            .collection('buses');

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
                    Icon(
                      Icons.directions_bus_filled,
                      size: 80,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "No buses added yet",
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Add your first bus to get started",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              );
            }

            var buses = snapshot.data!.docs;

            // Filter buses based on search
            var filteredBuses = buses.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final busName = (data['busName'] ?? '').toString().toLowerCase();
              final rcNo = (data['rcNo'] ?? '').toString().toLowerCase();
              return busName.contains(_searchQuery) ||
                  rcNo.contains(_searchQuery);
            }).toList();

            if (filteredBuses.isEmpty) {
              return Center(
                child: Text(
                  "No buses match your search",
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: filteredBuses.length,
              itemBuilder: (context, index) {
                final doc = filteredBuses[index];
                final bus = doc.data() as Map<String, dynamic>;
                return _busCard(context, bus, doc.id);
              },
            );
          },
        );
      },
    );
  }

  Future<bool> _isUserAdmin(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      final roles = doc.data()?['roles'] as Map<String, dynamic>? ?? {};
      return roles['admin'] == true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _rebuildPrices() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to rebuild prices')),
      );
      return;
    }

    setState(() => _rebuildingPrices = true);
    try {
      final isAdmin = await _isUserAdmin(user.uid);
      final count = await PriceUtils.rebuildPricesForBuses(
        ownerId: isAdmin ? null : user.uid,
        isAdmin: isAdmin,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Prices updated for $count providers')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to rebuild prices')),
      );
    } finally {
      if (mounted) setState(() => _rebuildingPrices = false);
    }
  }

  Widget _busCard(
    BuildContext context,
    Map<String, dynamic> bus,
    String docId,
  ) {
    final busLabel = formatBusLabel(
      name: bus['busName']?.toString(),
      number: bus['busNumber'],
    );

    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, '/edit_bus', arguments: bus).then((_) {
          setState(() {});
        });
      },
      child: Container(
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
            // Bus Name and Status Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        busLabel,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        bus['rcNo'] ?? 'N/A',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: (bus['isActive'] ?? true)
                            ? Colors.green.shade100
                            : Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        (bus['isActive'] ?? true) ? 'Active' : 'Inactive',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: (bus['isActive'] ?? true)
                              ? Colors.green.shade700
                              : Colors.orange.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton(
                      icon: const Icon(Icons.more_vert, size: 20),
                      itemBuilder: (BuildContext context) => [
                        PopupMenuItem(
                          child: const Row(
                            children: [
                              Icon(Icons.edit, size: 18),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                          onTap: () =>
                              Navigator.pushNamed(
                                context,
                                '/edit_bus',
                                arguments: bus,
                              ).then((_) {
                                setState(() {});
                              }),
                        ),
                        PopupMenuItem(
                          child: const Row(
                            children: [
                              Icon(Icons.delete, size: 18, color: Colors.red),
                              SizedBox(width: 8),
                              Text(
                                'Delete',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                          onTap: () => _deleteWithConfirm(context, docId),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Bus Details Grid
            Row(
              children: [
                Expanded(child: _detailItem('Brand', bus['brand'] ?? 'N/A')),
                const SizedBox(width: 12),
                Expanded(child: _detailItem('Model', bus['model'] ?? 'N/A')),
                const SizedBox(width: 12),
                Expanded(
                  child: _detailItem('Seats', '${bus['totalSeats'] ?? 0}'),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _detailItem(
                    'Avg Speed',
                    '${bus['avgSpeedKmph'] ?? '--'} Km/h',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _detailItem(
                    'Price/Km',
                    '₹${bus['pricePerKm'] ?? '--'}',
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(child: SizedBox.shrink()),
              ],
            ),

            const SizedBox(height: 12),

            // Bus Type and Features
            Row(
              children: [
                _featureChip(bus['busType'] ?? 'N/A'),
                const SizedBox(width: 8),
                if (bus['isSleeper'] ?? false)
                  _featureChip(
                    'Sleeper',
                    backgroundColor: Colors.purple.shade100,
                  ),
              ],
            ),

            const SizedBox(height: 14),

            // Driver and Conductor Info
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.drive_eta,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Driver",
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                bus['driver']?['name'] ?? 'No driver',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.person,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Conductor",
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                bus['conductor']?['name'] ?? 'No conductor',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _featureChip(String label, {Color? backgroundColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor ?? const Color(0xFF137FEC).withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: backgroundColor == null
              ? const Color(0xFF137FEC)
              : Colors.purple,
        ),
      ),
    );
  }

  void _deleteWithConfirm(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Bus?"),
        content: const Text("This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteBus(docId);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteBus(String docId) async {
    try {
      await FirebaseFirestore.instance.collection('buses').doc(docId).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Bus deleted successfully"),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error deleting bus"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
