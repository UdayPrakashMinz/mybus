import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mybus/utils/odisha_cities.dart';

class CreateTripPage extends StatefulWidget {
  const CreateTripPage({super.key});

  @override
  State<CreateTripPage> createState() => _CreateTripPageState();
}

class TripSegment {
  final String id;
  String from;
  String to;
  TimeOfDay? departureTime;
  TimeOfDay? arrivalTime;
  DateTime? departureDate;
  int sequenceNo;
  double fare;
  int availableSeats;
  int waitTimeMinutes;
  int travelTimeMinutes;
  double distanceKm;
  late TextEditingController fareController;
  late TextEditingController waitTimeController;
  late TextEditingController distanceController;
  late TextEditingController fromController;
  late TextEditingController toController;

  TripSegment({
    required this.id,
    required this.from,
    required this.to,
    this.departureTime,
    this.arrivalTime,
    this.departureDate,
    required this.sequenceNo,
    this.fare = 100,
    this.availableSeats = 0,
    this.waitTimeMinutes = 20,
    this.travelTimeMinutes = 60,
    this.distanceKm = 0,
  }) {
    fareController = TextEditingController(text: fare.toString());
    waitTimeController = TextEditingController(
      text: waitTimeMinutes.toString(),
    );
    distanceController = TextEditingController(
      text: distanceKm.toStringAsFixed(1),
    );
    fromController = TextEditingController(text: from);
    toController = TextEditingController(text: to);
  }

  void dispose() {
    fareController.dispose();
    waitTimeController.dispose();
    distanceController.dispose();
    fromController.dispose();
    toController.dispose();
  }
}

class _CreateTripPageState extends State<CreateTripPage> {
  // ================= STATE =================
  Map<String, dynamic>? selectedBus;
  bool recurringTrip = false;
  bool returnTrip = false;
  TimeOfDay? returnDepartureTime;
  List<TripSegment> segments = [];
  List<TripSegment> returnSegments = [];
  DateTime? departureDate;

  List<Map<String, dynamic>> ownerBuses = [];
  Set<String> assignedBusIds = {};
  bool loadingBuses = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadOwnerBuses();
  }

  @override
  void dispose() {
    for (var segment in segments) {
      segment.dispose();
    }
    super.dispose();
  }

  // ================= FIREBASE =================
  Future<void> _loadOwnerBuses() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final isAdmin = await _isUserAdmin(uid);
      _isAdmin = isAdmin;

      Query<Map<String, dynamic>> busesQuery =
          FirebaseFirestore.instance.collection('buses');
      Query<Map<String, dynamic>> tripsQuery =
          FirebaseFirestore.instance.collection('trips').where(
                'status',
                isEqualTo: 'active',
              );

      if (!isAdmin) {
        busesQuery = busesQuery.where('ownerId', isEqualTo: uid);
        tripsQuery = tripsQuery.where('ownerId', isEqualTo: uid);
      }

      final busesFuture = busesQuery.get();
      final assignedTripsFuture = tripsQuery.get();

      final results = await Future.wait([busesFuture, assignedTripsFuture]);
      final busSnapshot = results[0];
      final assignedTripsSnapshot = results[1];

      final assignedIds = assignedTripsSnapshot.docs
          .map((doc) => (doc.data()['busId'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toSet();

      final buses = busSnapshot.docs.map((doc) {
        final name = doc['busName'] ?? 'Unknown';
        final number = doc['busNumber'] ?? '';
        final isAssigned = assignedIds.contains(doc.id);
        return {
          'id': doc.id,
          'name': name,
          'rcNo': doc['rcNo'] ?? '',
          'busNumber': number,
          'busType': doc['busType'],
          'isSleeper': doc['isSleeper'] ?? false,
          'totalSeats': doc['totalSeats'],
          'avgSpeedKmph': doc['avgSpeedKmph'],
          'pricePerKm': doc['pricePerKm'],
          'isActive': doc['isActive'] ?? true,
          'isAssigned': isAssigned,
        };
      }).toList();

      setState(() {
        ownerBuses = buses;
        assignedBusIds = assignedIds;
        if (selectedBus != null &&
            assignedBusIds.contains(selectedBus!['id'].toString())) {
          selectedBus = null;
        }
        loadingBuses = false;
      });
    } catch (e) {
      print('Error loading buses: $e');
      setState(() => loadingBuses = false);
    }
  }

  Future<bool> _isUserAdmin(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final roles = doc.data()?['roles'] as Map<String, dynamic>? ?? {};
      return roles['admin'] == true;
    } catch (_) {
      return false;
    }
  }

  bool get canCreateTrip {
    return selectedBus != null &&
        (recurringTrip || departureDate != null) &&
        segments.isNotEmpty &&
        // final stop only requires arrival, others need both times
        segments.asMap().entries.every((entry) {
          final idx = entry.key;
          final seg = entry.value;
          if (seg.from.isEmpty ||
              seg.to.isEmpty ||
              seg.arrivalTime == null ||
              seg.fare <= 0) {
            return false;
          }
          if (idx < segments.length - 1 && seg.departureTime == null) {
            return false;
          }
          return true;
        });
  }

  // ================= VALIDATION & HELPERS =================
  TimeOfDay _addMinutesToTime(TimeOfDay time, int minutes) {
    int hour = time.hour;
    int minute = time.minute + minutes;
    if (minute >= 60) {
      hour += minute ~/ 60;
      minute = minute % 60;
      if (hour >= 24) hour = hour % 24;
    }
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatTimeOfDay(TimeOfDay? time) {
    if (time == null) return '';
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  int _busSpeedKmph() {
    return (selectedBus?['avgSpeedKmph'] as num?)?.toInt() ?? 0;
  }

  double _busPricePerKm() {
    return (selectedBus?['pricePerKm'] as num?)?.toDouble() ?? 0;
  }

  int _calcTravelMinutes(double distanceKm) {
    final speed = _busSpeedKmph();
    if (speed <= 0 || distanceKm <= 0) return 0;
    return (distanceKm / speed * 60).round() + 5;
  }

  double _calcFare(double distanceKm) {
    final pricePerKm = _busPricePerKm();
    if (pricePerKm <= 0 || distanceKm <= 0) return 0;
    return distanceKm * pricePerKm;
  }

  void _recalculateSegmentValues(
    TripSegment seg, {
    bool updateDistanceText = true,
  }) {
    seg.travelTimeMinutes = _calcTravelMinutes(seg.distanceKm);
    seg.fare = _calcFare(seg.distanceKm);
    seg.fareController.text = seg.fare.toStringAsFixed(0);
    if (updateDistanceText) {
      seg.distanceController.text = seg.distanceKm.toStringAsFixed(1);
    }
    if (seg.departureTime != null) {
      seg.arrivalTime = _addMinutesToTime(
        seg.departureTime!,
        seg.travelTimeMinutes,
      );
    }
  }

  void _addSegment() {
    setState(() {
      final autoFrom = segments.isNotEmpty ? segments.last.to : '';
      final seats = (selectedBus?['totalSeats'] as num?)?.toInt() ?? 0;
      final newSeg = TripSegment(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        from: autoFrom,
        to: '',
        sequenceNo: segments.length + 1,
        availableSeats: seats,
        distanceKm: 0,
      );

      // If previous stop has arrival and wait time, auto-set this stop's departure
      if (segments.isNotEmpty && segments.last.arrivalTime != null) {
        newSeg.departureTime = _addMinutesToTime(
          segments.last.arrivalTime!,
          segments.last.waitTimeMinutes,
        );
      }

      _recalculateSegmentValues(newSeg);
      segments.add(newSeg);
      _generateReturnSegments();
    });
  }

  void _applyBusSeatDefaults(Map<String, dynamic> bus) {
    final seats = (bus['totalSeats'] as num?)?.toInt();
    if (seats == null || seats <= 0) return;
    for (final seg in segments) {
      seg.availableSeats = seats;
    }
    for (final seg in returnSegments) {
      seg.availableSeats = seats;
    }
  }

  void _recalculateAllSegments() {
    for (final seg in segments) {
      _recalculateSegmentValues(seg);
    }
    for (final seg in returnSegments) {
      _recalculateSegmentValues(seg);
    }
  }

  void _removeSegment(String segmentId) {
    final segment = segments.firstWhere(
      (s) => s.id == segmentId,
      orElse: () => TripSegment(id: '', from: '', to: '', sequenceNo: 0),
    );
    if (segment.id.isNotEmpty) {
      segment.dispose();
    }
    setState(() {
      segments.removeWhere((s) => s.id == segmentId);
      // Re-sequence
      for (int i = 0; i < segments.length; i++) {
        segments[i].sequenceNo = i + 1;
      }
      _generateReturnSegments();
    });
  }

  void _generateReturnSegments() {
    returnSegments.clear();
    if (!returnTrip || returnDepartureTime == null || segments.isEmpty) return;

    TimeOfDay? cur = returnDepartureTime;

    // Reverse order: process segments in reverse to create return segments
    final reversedSegs = segments.reversed.toList();

    for (int i = 0; i < reversedSegs.length; i++) {
      final seg = reversedSegs[i];
      final newSeg = TripSegment(
        id: DateTime.now().millisecondsSinceEpoch.toString() + i.toString(),
        from: seg.to,
        to: seg.from,
        sequenceNo: i + 1,
        travelTimeMinutes: seg.travelTimeMinutes,
        fare: seg.fare,
        waitTimeMinutes: seg.waitTimeMinutes,
        distanceKm: seg.distanceKm,
      );
      // Update controllers to show inherited values
      newSeg.fromController.text = seg.to;
      newSeg.toController.text = seg.from;
      newSeg.fareController.text = seg.fare.toStringAsFixed(0);
      newSeg.waitTimeController.text = seg.waitTimeMinutes.toString();
      newSeg.distanceController.text = seg.distanceKm.toStringAsFixed(1);

      if (cur != null) {
        newSeg.departureTime = cur;
        _recalculateSegmentValues(newSeg, updateDistanceText: false);
        cur = _addMinutesToTime(newSeg.arrivalTime!, seg.waitTimeMinutes);
      }
      returnSegments.add(newSeg);
    }
  }

  void _updateSegment(
    String segmentId,
    String from,
    String to,
    TimeOfDay? depTime,
    double distanceKm,
    int waitTime,
  ) {
    final index = segments.indexWhere((seg) => seg.id == segmentId);
    if (index != -1) {
      // Single setState for atomic update
      setState(() {
        segments[index].from = from;
        segments[index].to = to;
        segments[index].departureTime = depTime;
        segments[index].distanceKm = distanceKm;
        segments[index].waitTimeMinutes = waitTime;
        _recalculateSegmentValues(segments[index], updateDistanceText: false);

        // Auto-calc next segment departure if arrival is now set
        if (segments[index].arrivalTime != null &&
            index + 1 < segments.length) {
          final nextDep = _addMinutesToTime(
            segments[index].arrivalTime!,
            waitTime,
          );
          segments[index + 1].departureTime = nextDep;
        }
      });

      _generateReturnSegments();
    }
  }

  String _busLineLabel(Map<String, dynamic> bus) {
    final name = (bus['name'] ?? '').toString().trim();
    final number = (bus['busNumber'] ?? '').toString().trim();
    final rcNo = (bus['rcNo'] ?? '').toString().trim();
    final safeName = name.isEmpty ? 'Unknown Bus' : name;
    final safeNumber = number.isEmpty ? 'N/A' : number;
    final safeRc = rcNo.isEmpty ? 'N/A' : rcNo;
    return "$safeName #$safeNumber  RC:$safeRc";
  }

  Future<void> _openBusSearchPicker() async {
    String query = '';
    final searchCtrl = TextEditingController();

    await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final filtered = ownerBuses.where((bus) {
              if (query.trim().isEmpty) return true;
              final q = query.toLowerCase();
              final name = (bus['name'] ?? '').toString().toLowerCase();
              final number = (bus['busNumber'] ?? '').toString().toLowerCase();
              final rcNo = (bus['rcNo'] ?? '').toString().toLowerCase();
              return name.contains(q) || number.contains(q) || rcNo.contains(q);
            }).toList();

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 12,
                ),
                child: SizedBox(
                  height: MediaQuery.of(sheetContext).size.height * 0.7,
                  child: Column(
                    children: [
                      const Text(
                        "Select Bus",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: searchCtrl,
                        onChanged: (value) {
                          setSheetState(() => query = value);
                        },
                        decoration: InputDecoration(
                          hintText: "Search bus name, number, or RC",
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: filtered.isEmpty
                            ? const Center(child: Text("No buses found"))
                            : ListView.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final bus = filtered[index];
                                  final isAssigned = bus['isAssigned'] == true;

                                  return ListTile(
                                    enabled: !isAssigned,
                                    onTap: isAssigned
                                        ? null
                                        : () =>
                                              Navigator.pop(sheetContext, bus),
                                    title: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _busLineLabel(bus),
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: isAssigned
                                                  ? Colors.grey.shade500
                                                  : Colors.black,
                                            ),
                                          ),
                                        ),
                                        if (isAssigned)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              "Assigned",
                                              style: TextStyle(
                                                color: Colors.orange.shade800,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).then((bus) {
      if (bus != null && bus['isAssigned'] != true) {
        setState(() {
          selectedBus = bus;
          _applyBusSeatDefaults(bus);
          _recalculateAllSegments();
          _generateReturnSegments();
        });
      }
    });

    searchCtrl.dispose();
  }

  /// UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),

      /// APP BAR
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: const Text(
          "Create New Trip",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),

      /// BODY
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// RECURRING TRIP
            _card(
              child: SwitchListTile(
                title: const Text(
                  "Recurring Trip",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text("Repeat this schedule every week"),
                value: recurringTrip,
                onChanged: (value) {
                  setState(() {
                    recurringTrip = value;
                    if (recurringTrip) {
                      departureDate = null;
                    }
                  });
                },
              ),
            ),

            const SizedBox(height: 16),

            /// SCHEDULE (TOP)
            const Text(
              "SCHEDULE",
              style: TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),

            _card(
              child: recurringTrip
                  ? const Text(
                      "Departure date is not required for recurring trips.",
                      style: TextStyle(color: Colors.grey),
                    )
                  : _dateField("Departure Date", departureDate, () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setState(() => departureDate = picked);
                      }
                    }),
            ),

            const SizedBox(height: 16),

            /// SELECT BUS
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Select Bus",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  if (loadingBuses)
                    const Center(child: CircularProgressIndicator())
                  else if (ownerBuses.isEmpty)
                    const Text(
                      "No buses available. Create a bus first.",
                      style: TextStyle(color: Colors.grey),
                    )
                  else
                    InkWell(
                      onTap: _openBusSearchPicker,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F9FC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: selectedBus == null
                                  ? const Text(
                                      "Search and choose a bus",
                                      style: TextStyle(color: Colors.grey),
                                    )
                                  : Text(
                                      _busLineLabel(selectedBus!),
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_drop_down),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            /// BUS STOPS
            const Text(
              "BUS STOPS",
              style: TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
            const Text(
              "Add each bus stop with From → To, departure time, distance (km) & wait time",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 12),

            // List of outbound stops
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: segments.length,
              itemBuilder: (context, index) {
                final segment = segments[index];
                return _buildSegmentCard(segment, index);
              },
            ),
            if (returnTrip && returnSegments.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                "RETURN STOPS",
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: returnSegments.length,
                itemBuilder: (context, idx) {
                  final segment = returnSegments[idx];
                  return _buildSegmentCard(segment, idx);
                },
              ),
            ],

            const SizedBox(height: 12),

            // Add Segment Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _addSegment,
                icon: const Icon(Icons.add),
                label: const Text("Add Bus Stop"),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            _card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text(
                      "Return Trip",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    value: returnTrip,
                    onChanged: (val) {
                      setState(() {
                        returnTrip = val;
                        if (!returnTrip) {
                          returnSegments.clear();
                          returnDepartureTime = null;
                        } else {
                          _generateReturnSegments();
                        }
                      });
                    },
                  ),
                  if (returnTrip)
                    _timeField("Return Start", returnDepartureTime, () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (picked != null) {
                        setState(() {
                          returnDepartureTime = picked;
                          _generateReturnSegments();
                        });
                      }
                    }),
                ],
              ),
            ),

            const SizedBox(height: 100),
          ],
        ),
      ),

      /// CREATE TRIP BUTTON
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: canCreateTrip
                ? () {
                    _createTrip();
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: canCreateTrip
                  ? const Color(0xFF137FEC)
                  : Colors.grey.shade400,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              "Create Trip",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// BUILD BUS STOP CARD
  Widget _buildSegmentCard(TripSegment segment, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Bus Stop ${segment.sequenceNo}",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                onPressed: () => _removeSegment(segment.id),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          const SizedBox(height: 12),

          /// From & To
          Row(
            children: [
              Expanded(
                child: _textFieldSimple(
                  label: "From",
                  hint: "Starting point",
                  controller: segment.fromController,
                  onChanged: (value) => _updateSegment(
                    segment.id,
                    value,
                    segment.to,
                    segment.departureTime,
                    segment.distanceKm,
                    segment.waitTimeMinutes,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _textFieldSimple(
                  label: "To",
                  hint: "Destination",
                  controller: segment.toController,
                  onChanged: (value) {
                    _updateSegment(
                      segment.id,
                      segment.from,
                      value,
                      segment.departureTime,
                      segment.distanceKm,
                      segment.waitTimeMinutes,
                    );
                    // Auto-fill next bus stop's 'from' and its controller
                    final nextIndex = index + 1;
                    if (nextIndex < segments.length) {
                      final next = segments[nextIndex];
                      _updateSegment(
                        next.id,
                        value,
                        next.to,
                        next.departureTime,
                        next.distanceKm,
                        next.waitTimeMinutes,
                      );
                      // ensure next controller displays new value
                      next.fromController.text = value;
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          /// Departure & Arrival Times
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Departure",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (picked != null) {
                          _updateSegment(
                            segment.id,
                            segment.from,
                            segment.to,
                            picked,
                            segment.distanceKm,
                            segment.waitTimeMinutes,
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F9FC),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              segment.departureTime == null
                                  ? "-- : --"
                                  : segment.departureTime!.format(context),
                            ),
                            const Icon(Icons.access_time, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Arrival",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F9FC),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            segment.arrivalTime == null
                                ? "-- : --"
                                : segment.arrivalTime!.format(context),
                          ),
                          const Icon(Icons.access_time, size: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          /// Fare & Seats
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Fare (₹)",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: segment.fareController,
                      keyboardType: TextInputType.number,
                      enabled: false,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF7F9FC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Wait Time (min)",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: segment.waitTimeController,
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        if (value.isNotEmpty) {
                          final wait =
                              int.tryParse(value) ?? segment.waitTimeMinutes;
                          _updateSegment(
                            segment.id,
                            segment.from,
                            segment.to,
                            segment.departureTime,
                            segment.distanceKm,
                            wait,
                          );
                        }
                      },
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF7F9FC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          /// Distance
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Distance to Next Stop (km)",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: segment.distanceController,
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  if (value.isNotEmpty) {
                    final distance =
                        double.tryParse(value) ?? segment.distanceKm;
                    _updateSegment(
                      segment.id,
                      segment.from,
                      segment.to,
                      segment.departureTime,
                      distance,
                      segment.waitTimeMinutes,
                    );
                  }
                },
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF7F9FC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// ================= REUSABLE WIDGETS =================

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }

  Widget _textFieldSimple({
    required String label,
    required String hint,
    TextEditingController? controller,
    required Function(String) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
        const SizedBox(height: 6),
        Autocomplete<String>(
          initialValue: TextEditingValue(text: controller?.text ?? ''),
          optionsBuilder: (TextEditingValue textEditingValue) {
            final query = textEditingValue.text.trim().toLowerCase();
            if (query.isEmpty) return const Iterable<String>.empty();
            return odishaCities.where(
              (option) => option.toLowerCase().contains(query),
            );
          },
          onSelected: (selection) {
            if (controller != null) {
              controller.text = selection;
            }
            onChanged(selection);
          },
          fieldViewBuilder: (context, textCtrl, focusNode, onFieldSubmitted) {
            if (controller != null) {
              textCtrl.value = controller.value;
              textCtrl.addListener(() {
                if (controller.text != textCtrl.text) {
                  controller.value = textCtrl.value;
                  onChanged(textCtrl.text);
                }
              });
            }
            return TextField(
              controller: textCtrl,
              focusNode: focusNode,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: hint,
                filled: true,
                fillColor: const Color(0xFFF7F9FC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _timeField(String label, TimeOfDay? time, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F9FC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(time == null ? "-- : --" : time.format(context)),
                const Icon(Icons.access_time, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _dateField(String label, DateTime? date, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F9FC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  date == null
                      ? "mm/dd/yyyy"
                      : "${date.day}/${date.month}/${date.year}",
                ),
                const Icon(Icons.calendar_today, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ================= FIREBASE SAVE =================
  Future<void> _createTrip() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null || selectedBus == null) return;
      if (!recurringTrip && departureDate == null) return;
      if (assignedBusIds.contains(selectedBus!['id'].toString())) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("This bus is already assigned to an active trip."),
          ),
        );
        return;
      }

      // Convert segments to Firestore format
      final segmentsData = segments
          .map(
            (seg) => {
              'sequenceNo': seg.sequenceNo,
              'from': seg.from,
              'to': seg.to,
              'departureTime': _formatTimeOfDay(seg.departureTime),
              'arrivalTime': _formatTimeOfDay(seg.arrivalTime),
              'fare': seg.fare,
              'availableSeats': seg.availableSeats,
              'waitTimeMinutes': seg.waitTimeMinutes,
              'travelTimeMinutes': seg.travelTimeMinutes,
              'distanceKm': seg.distanceKm,
            },
          )
          .toList();

      // Convert return segments to Firestore format
      final returnSegmentsData = returnSegments
          .map(
            (seg) => {
              'sequenceNo': seg.sequenceNo,
              'from': seg.from,
              'to': seg.to,
              'departureTime': _formatTimeOfDay(seg.departureTime),
              'arrivalTime': _formatTimeOfDay(seg.arrivalTime),
              'fare': seg.fare,
              'availableSeats': seg.availableSeats,
              'waitTimeMinutes': seg.waitTimeMinutes,
              'travelTimeMinutes': seg.travelTimeMinutes,
              'distanceKm': seg.distanceKm,
            },
          )
          .toList();

      final tripData = {
        'busId': selectedBus!['id'],
        'busName': selectedBus!['name'],
        'busNumber': selectedBus!['busNumber'],
        'rcNo': selectedBus!['rcNo'],
        'busType': selectedBus!['busType'],
        'sleeper': selectedBus!['isSleeper'] ?? false,
        'totalSeats': selectedBus!['totalSeats'],
        'isAssigned': true,
        if (!recurringTrip && departureDate != null)
          'departureDate': Timestamp.fromDate(departureDate!),
        'segments': segmentsData,
        if (returnTrip) 'returnSegments': returnSegmentsData,
        'recurring': recurringTrip,
        'ownerId': uid,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('trips').add(tripData);

      await FirebaseFirestore.instance
          .collection('buses')
          .doc(selectedBus!['id'])
          .update({'isAssigned': true, 'isActive': true});

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Trip created successfully"),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }
}
