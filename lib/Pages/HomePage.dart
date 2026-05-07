import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mybus/Pages/find_trip.dart';
import 'package:mybus/Pages/profile_page.dart';
import 'package:mybus/utils/location_cache.dart';
import 'package:mybus/utils/price_utils.dart';

class ConsumerHomePage extends StatefulWidget {
  const ConsumerHomePage({super.key});

  @override
  State<ConsumerHomePage> createState() => _ConsumerHomePageState();
}

class _ConsumerHomePageState extends State<ConsumerHomePage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String? _selectedLocation;
  bool _userPickedLocation = false;

  Position? _currentPosition;
  String _locationStatus = 'Locating...';

  @override
  void initState() {
    super.initState();
    _restoreCachedLocation();
    _loadLocation(); // GPS
    _loadGeoLocations(); // from locations collection
  }

  Future<void> _restoreCachedLocation() async {
    await LocationCache.load();
    if (!mounted) return;
    setState(() {
      _selectedLocation = LocationCache.lastSelectedLocation;
      _userPickedLocation = LocationCache.userPicked;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _locationStatus = 'Location service off');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() => _locationStatus = 'Location permission denied');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      if (!mounted) return;

      setState(() {
        _currentPosition = position;
        _locationStatus = 'Using live location';
      });

      // ✅ TRY AUTO PICK HERE
      _maybeAutoPickLocation();
    } catch (_) {
      if (!mounted) return;
      setState(() => _locationStatus = 'Location unavailable');
    }
  }

  double? _readNum(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  List<String> _extractLocationNames(List<QueryDocumentSnapshot> docs) {
    final Set<String> names = {};

    for (final doc in docs) {
      final trip = doc.data() as Map<String, dynamic>;
      final segments = (trip['segments'] as List<dynamic>?) ?? [];

      for (final rawSeg in segments) {
        final seg = rawSeg as Map<String, dynamic>;

        final from = (seg['from'] ?? '').toString().trim();
        final to = (seg['to'] ?? '').toString().trim();

        if (from.isNotEmpty) names.add(from);
        if (to.isNotEmpty) names.add(to);
      }
    }

    final list = names.toList()..sort();
    return list;
  }

  void _maybeAutoPickLocation() {
    if (_userPickedLocation) return;

    //  MUST have both GPS + geo DB
    if (_geoLocations.isEmpty || _currentPosition == null) return;

    final lat = _currentPosition!.latitude;
    final lng = _currentPosition!.longitude;

    double bestDistance = double.infinity;
    String? bestMatch;

    for (final loc in _geoLocations) {
      if (loc.lat == null || loc.lng == null) continue;

      final distance = Geolocator.distanceBetween(lat, lng, loc.lat!, loc.lng!);

      if (distance < bestDistance) {
        bestDistance = distance;
        bestMatch = loc.name;
      }
    }

    if (bestMatch != null && bestMatch != _selectedLocation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        setState(() {
          _selectedLocation = bestMatch;
        });

        LocationCache.save(location: bestMatch, isUserPicked: false);
      });
    }
  }

  List<Map<String, dynamic>> _buildProviderCards(
    List<QueryDocumentSnapshot> docs,
  ) {
    final Map<String, Map<String, dynamic>> providers = {};

    for (final doc in docs) {
      final trip = doc.data() as Map<String, dynamic>;
      final busName = (trip['busName'] ?? 'Unknown').toString().trim();
      if (busName.isEmpty) continue;

      final segments = (trip['segments'] as List<dynamic>?) ?? [];
      if (segments.isEmpty) continue;

      if (providers.containsKey(busName)) continue;

      final firstSeg = segments.first as Map<String, dynamic>;
      final lastSeg = segments.last as Map<String, dynamic>;
      final destinations = <String>{};

      for (final rawSeg in segments) {
        final seg = rawSeg as Map<String, dynamic>;
        final to = (seg['to'] ?? '').toString().trim();
        if (to.isNotEmpty) destinations.add(to);
      }

      providers[busName] = {
        'busName': busName,
        'busId': trip['busId'],
        'busType': trip['busType'] ?? 'Standard',
        'sleeper': trip['sleeper'] ?? false,
        'from': (firstSeg['from'] ?? '').toString().trim(),
        'to': (lastSeg['to'] ?? '').toString().trim(),
        'destinations': destinations.toList()..sort(),
        'segments': segments,
      };
    }

    return providers.values.toList()..sort((a, b) {
      return (a['busName'] as String).toLowerCase().compareTo(
        (b['busName'] as String).toLowerCase(),
      );
    });
  }

  List<_LocationOption> _geoLocations = [];

  Future<void> _loadGeoLocations() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('locations')
          .doc('Odisha')
          .get();

      if (!doc.exists) return;

      final data = doc.data() as Map<String, dynamic>;

      final List<_LocationOption> loaded = [];

      data.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          loaded.add(
            _LocationOption(
              name: key,
              lat: (value['lat'] as num?)?.toDouble(),
              lng: (value['lng'] as num?)?.toDouble(),
            ),
          );
        }
      });

      if (!mounted) return;

      setState(() => _geoLocations = loaded);

      // ✅ TRY AUTO PICK HERE
      _maybeAutoPickLocation();
    } catch (e) {
      print("Geo load error: $e");
    }
  }

  bool _matchesDestination(Map<String, dynamic> provider) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;

    final destinations = (provider['destinations'] as List<dynamic>).map(
      (e) => e.toString().toLowerCase(),
    );
    return destinations.any((dest) => dest.contains(q));
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
                    _userHeader(),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _query = value),
                      decoration: InputDecoration(
                        hintText: 'Search provider by destination.',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _query = '');
                                },
                              ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    _locationBar(),
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
                  final locations = _extractLocationNames(docs);
                  _maybeAutoPickLocation();

                  final providers = _buildProviderCards(docs);
                  final visibleProviders = providers
                      .where(_matchesDestination)
                      .toList();

                  if (visibleProviders.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: _EmptyStateCard(),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    itemCount: visibleProviders.length,
                    itemBuilder: (context, index) {
                      final provider = visibleProviders[index];
                      return _providerCard(context, provider);
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _locationBar() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('trips')
          .where('status', isEqualTo: 'active')
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];

        final locations = _extractLocationNames(docs);

        // 🔥 ensure selected location exists in dropdown
        final Set<String> locationSet = {...locations};

        if (_selectedLocation != null && _selectedLocation!.isNotEmpty) {
          locationSet.add(_selectedLocation!);
        }

        final finalLocations = locationSet.toList()..sort();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.my_location, size: 16, color: Color(0xFF137FEC)),
              const SizedBox(width: 8),

              Expanded(
                child: Text(
                  _locationStatus,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),

              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedLocation,
                  hint: Text(_selectedLocation ?? "Select location"),
                  items: finalLocations.map((loc) {
                    return DropdownMenuItem(value: loc, child: Text(loc));
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedLocation = value;
                      _userPickedLocation = true;
                    });

                    LocationCache.save(location: value, isUserPicked: true);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _userHeader() {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: _loadUserDoc(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 40,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        final data = snapshot.data?.data() ?? {};
        final avatar = data['avatar'];
        final email = FirebaseAuth.instance.currentUser?.email ?? "";
        final name = (data['name'] as String?)?.trim();

        final displayName = (name != null && name.isNotEmpty) ? name : email;
        final roleLabel = "Consumer";

        return Row(
          children: [
            GestureDetector(
              onTap: () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const ProfilePage()));
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
                      fontSize: 20,
                    ),
                  ),
                  Text(
                    roleLabel,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _loadUserDoc() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return FirebaseFirestore.instance
          .collection('users')
          .doc('missing')
          .get();
    }
    return FirebaseFirestore.instance.collection('users').doc(user.uid).get();
  }

  Widget _providerCard(BuildContext context, Map<String, dynamic> provider) {
    return _withBusInfo(
      provider,
      builder: (busInfo) {
        final busType =
            (busInfo['busType'] ?? provider['busType'] ?? 'Standard')
                .toString();
        final typeLower = busType.toLowerCase();
        final isExpress = typeLower.contains('express');

        final destinations = (provider['destinations'] as List<dynamic>)
            .cast<String>();
        final destinationText = _formatDestinations(destinations);
        final from = provider['from']?.toString() ?? '';
        final to = provider['to']?.toString() ?? '';

        return _withPriceInfo(
          provider['busName']?.toString() ?? '',
          builder: (priceInfo) {
            final ac = _priceCategory(priceInfo, 'ac');
            final nonAc = _priceCategory(priceInfo, 'nonAc');
            final sleeper = _priceCategory(priceInfo, 'sleeper');

            final tags = <String>[];
            if (ac.count > 0) tags.add('AC');
            if (nonAc.count > 0) tags.add('Non-AC');
            if (sleeper.count > 0) tags.add('Sleeper');
            if (isExpress) tags.add('Express');
            if (tags.isEmpty) tags.add('Standard');

            return GestureDetector(
              onTap: () {
                final nextTo = _query.trim().isNotEmpty
                    ? _query.trim()
                    : (to.isNotEmpty ? to : destinations.firstOrNull ?? '');
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FindTripPage(
                      initialFrom: _selectedLocation ?? from,
                      initialTo: null,
                      initialDate: DateTime.now(),
                      initialBusName: provider['busName']?.toString(),
                    ),
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF3FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.directions_bus,
                            color: Color(0xFF137FEC),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                provider['busName']?.toString() ?? 'Provider',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                destinationText,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: tags.map(_tagPill).toList(),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _priceChip('AC', ac.avg),
                        _priceChip('Non-AC', nonAc.avg),
                        _priceChip('Sleeper', sleeper.avg),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (from.isNotEmpty || to.isNotEmpty)
                      Text(
                        'Route: ${from.isEmpty ? '--' : from} → '
                        '${to.isEmpty ? '--' : to}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if ((_selectedLocation ?? '').isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Starting from: ${_selectedLocation ?? ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatDestinations(List<String> destinations) {
    if (destinations.isEmpty) return 'Destinations not available';
    if (destinations.length <= 3) {
      return 'Goes to: ${destinations.join(', ')}';
    }
    final trimmed = destinations.take(3).join(', ');
    final remaining = destinations.length - 3;
    return 'Goes to: $trimmed +$remaining';
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

  Widget _priceChip(String label, double? value) {
    final text = value == null || value <= 0
        ? '$label: --/km'
        : '$label: Rs ${value.toStringAsFixed(1)}/km';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F5FA),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF3D4A5A),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  _PriceCategory _priceCategory(Map<String, dynamic> data, String key) {
    final raw = data[key] as Map<String, dynamic>? ?? const {};
    return _PriceCategory(
      avg: (raw['avg'] as num?)?.toDouble(),
      count: (raw['count'] as num?)?.toInt() ?? 0,
    );
  }

  Widget _withPriceInfo(
    String busName, {
    required Widget Function(Map<String, dynamic> priceInfo) builder,
  }) {
    final docId = PriceUtils.priceDocIdForBusName(busName);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('prices')
          .doc(docId)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? const <String, dynamic>{};
        return builder(data);
      },
    );
  }

  Widget _withBusInfo(
    Map<String, dynamic> provider, {
    required Widget Function(Map<String, dynamic> busInfo) builder,
  }) {
    final busId = provider['busId']?.toString();
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

class _LocationOption {
  final String name;
  final double? lat;
  final double? lng;

  const _LocationOption({required this.name, this.lat, this.lng});
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_bus, size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              'No providers found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Try a different destination or check again later.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceCategory {
  final double? avg;
  final int count;

  const _PriceCategory({required this.avg, required this.count});
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
