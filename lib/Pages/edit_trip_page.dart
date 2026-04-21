import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mybus/utils/bus_utils.dart';
import 'package:mybus/utils/odisha_cities.dart';

class EditTripPage extends StatefulWidget {
  final String tripId;

  const EditTripPage({super.key, required this.tripId});

  @override
  State<EditTripPage> createState() => _EditTripPageState();
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

class _EditTripPageState extends State<EditTripPage> {
  // State
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
  bool loadingTrip = true;
  Map<String, dynamic>? tripData;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadOwnerBuses();
    _loadTrip();
  }

  @override
  void dispose() {
    for (var segment in segments) {
      segment.dispose();
    }
    for (var segment in returnSegments) {
      segment.dispose();
    }
    super.dispose();
  }

  Future<void> _loadOwnerBuses() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      _isAdmin = await _isUserAdmin(uid);

      Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection(
        'buses',
      );
      if (!_isAdmin) {
        query = query.where('ownerId', isEqualTo: uid);
      }

      Query<Map<String, dynamic>> tripsQuery = FirebaseFirestore.instance
          .collection('trips')
          .where('status', isEqualTo: 'active');
      if (!_isAdmin) {
        tripsQuery = tripsQuery.where('ownerId', isEqualTo: uid);
      }
      final assignedTripsSnapshot = await tripsQuery.get();
      final assignedIds = assignedTripsSnapshot.docs
          .where((doc) => doc.id != widget.tripId)
          .map((doc) => (doc.data()['busId'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toSet();

      final snapshot = await query.get();

      final buses = snapshot.docs.map((doc) {
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
          'displayName': formatBusLabel(name: name, number: number),
          'isActive': doc['isActive'] ?? true,
          'isAssigned': isAssigned,
        };
      }).toList();

      setState(() {
        ownerBuses = buses;
        assignedBusIds = assignedIds;
        loadingBuses = false;
      });
    } catch (e) {
      print('Error loading buses: $e');
      setState(() => loadingBuses = false);
    }
  }

  Future<void> _loadTrip() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('trips')
          .doc(widget.tripId)
          .get();

      if (!doc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Trip not found")));
          Navigator.pop(context);
        }
        return;
      }

      final data = doc.data() as Map<String, dynamic>;
      tripData = data;

      // Load bus
      final busId = data['busId'];
      final busList = ownerBuses.isEmpty ? await _getBusList() : ownerBuses;
      selectedBus = busList.firstWhere(
        (b) => b['id'] == busId,
        orElse: () => {},
      );

      // Load date
      final depDate = data['departureDate'] as Timestamp?;
      departureDate = depDate?.toDate();

      // Load segments
      final segsData = data['segments'] as List<dynamic>? ?? [];
      segments = segsData.map((seg) {
        final s = seg as Map<String, dynamic>;
        final travelMinutes = (s['travelTimeMinutes'] as num?)?.toInt() ?? 0;
        final speed = _busSpeedKmph();
        final distance =
            (s['distanceKm'] as num?)?.toDouble() ??
            (speed > 0 ? (travelMinutes * speed) / 60.0 : 0);
        final pricePerKm = _busPricePerKm();
        final fare = pricePerKm > 0
            ? distance * pricePerKm
            : (s['fare'] as num?)?.toDouble() ?? 100;
        return TripSegment(
          id: s['sequenceNo'].toString(),
          from: s['from'] ?? '',
          to: s['to'] ?? '',
          sequenceNo: s['sequenceNo'] ?? 0,
          fare: fare,
          waitTimeMinutes: s['waitTimeMinutes'] ?? 20,
          travelTimeMinutes: speed > 0
              ? _calcTravelMinutes(distance)
              : (s['travelTimeMinutes'] as num?)?.toInt() ?? 60,
          departureTime: _parseTimeOfDay(s['departureTime']),
          arrivalTime: _parseTimeOfDay(s['arrivalTime']),
          availableSeats:
              (s['availableSeats'] as num?)?.toInt() ?? _defaultSeats(),
          distanceKm: distance,
        );
      }).toList();

      // Load return segments if available
      final returnSegsData = data['returnSegments'] as List<dynamic>? ?? [];
      if (returnSegsData.isNotEmpty) {
        returnTrip = true;
        // Extract return departure time from first return segment
        if (returnSegsData.isNotEmpty) {
          final firstReturnSeg = returnSegsData.first as Map<String, dynamic>;
          returnDepartureTime = _parseTimeOfDay(
            firstReturnSeg['departureTime'],
          );
        }
        returnSegments = returnSegsData.map((seg) {
          final s = seg as Map<String, dynamic>;
          final travelMinutes = (s['travelTimeMinutes'] as num?)?.toInt() ?? 0;
          final speed = _busSpeedKmph();
          final distance =
              (s['distanceKm'] as num?)?.toDouble() ??
              (speed > 0 ? (travelMinutes * speed) / 60.0 : 0);
          final pricePerKm = _busPricePerKm();
          final fare = pricePerKm > 0
              ? distance * pricePerKm
              : (s['fare'] as num?)?.toDouble() ?? 100;
          return TripSegment(
            id: s['sequenceNo'].toString(),
            from: s['from'] ?? '',
            to: s['to'] ?? '',
            sequenceNo: s['sequenceNo'] ?? 0,
            fare: fare,
            waitTimeMinutes: s['waitTimeMinutes'] ?? 20,
            travelTimeMinutes: speed > 0
                ? _calcTravelMinutes(distance)
                : (s['travelTimeMinutes'] as num?)?.toInt() ?? 60,
            departureTime: _parseTimeOfDay(s['departureTime']),
            arrivalTime: _parseTimeOfDay(s['arrivalTime']),
            availableSeats:
                (s['availableSeats'] as num?)?.toInt() ?? _defaultSeats(),
            distanceKm: distance,
          );
        }).toList();
      }

      recurringTrip = data['recurring'] ?? false;

      setState(() {
        loadingTrip = false;
      });
    } catch (e) {
      print('Error loading trip: $e');
      setState(() => loadingTrip = false);
    }
  }

  Future<List<Map<String, dynamic>>> _getBusList() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];

    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection(
      'buses',
    );
    if (!_isAdmin) {
      query = query.where('ownerId', isEqualTo: uid);
    }
    final snapshot = await query.get();

    return snapshot.docs
        .map(
          (doc) => {
            'id': doc.id,
            'name': doc['busName'] ?? 'Unknown',
            'rcNo': doc['rcNo'] ?? '',
            'busNumber': doc['busNumber'] ?? '',
            'busType': doc['busType'],
            'isSleeper': doc['isSleeper'] ?? false,
            'totalSeats': doc['totalSeats'],
            'avgSpeedKmph': doc['avgSpeedKmph'],
            'pricePerKm': doc['pricePerKm'],
            'isActive': doc['isActive'] ?? true,
          },
        )
        .toList();
  }

  TimeOfDay? _parseTimeOfDay(dynamic timeStr) {
    if (timeStr == null || timeStr.toString().isEmpty) return null;
    try {
      final raw = timeStr.toString().trim().replaceAll(
        RegExp(r'[\u00A0\u202F]'),
        ' ',
      );
      final amPmMatch = RegExp(
        r'^(\d{1,2}):(\d{2})\s*([AaPp][Mm])$',
      ).firstMatch(raw);
      if (amPmMatch != null) {
        var hour = int.parse(amPmMatch.group(1)!);
        final minute = int.parse(amPmMatch.group(2)!);
        final period = amPmMatch.group(3)!.toUpperCase();
        if (hour == 12) {
          hour = period == 'AM' ? 0 : 12;
        } else if (period == 'PM') {
          hour += 12;
        }
        return TimeOfDay(hour: hour, minute: minute);
      }

      final parts = raw.split(':');
      if (parts.length == 2) {
        return TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }
    } catch (e) {
      print('Error parsing time: $e');
    }
    return null;
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

  double _busPricePerKm() {
    return (selectedBus?['pricePerKm'] as num?)?.toDouble() ?? 0;
  }

  int _calcTravelMinutes(double distanceKm) {
    final speed = _busSpeedKmph();
    if (speed <= 0 || distanceKm <= 0) return 0;
    return (distanceKm / speed * 60).round();
  }

  double _calcFare(double distanceKm) {
    final pricePerKm = _busPricePerKm();
    if (pricePerKm <= 0 || distanceKm <= 0) return 0;
    return distanceKm * pricePerKm;
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
                                  final isSelected =
                                      selectedBus?['id'] == bus['id'];

                                  return ListTile(
                                    enabled: !isAssigned || isSelected,
                                    onTap: isAssigned && !isSelected
                                        ? null
                                        : () =>
                                              Navigator.pop(sheetContext, bus),
                                    title: Text(
                                      _busLineLabel(bus),
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isAssigned && !isSelected
                                            ? Colors.grey.shade500
                                            : Colors.black,
                                      ),
                                    ),
                                    trailing: isAssigned && !isSelected
                                        ? Container(
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
                                          )
                                        : null,
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
      if (bus != null) {
        setState(() {
          selectedBus = bus;
          _recalculateAllSegments();
          _generateReturnSegments();
        });
      }
    });

    searchCtrl.dispose();
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

  bool get canCreateTrip {
    return selectedBus != null &&
        (recurringTrip || departureDate != null) &&
        segments.isNotEmpty &&
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

  int _defaultSeats() {
    final seatsFromBus = (selectedBus?['totalSeats'] as num?)?.toInt();
    if (seatsFromBus != null && seatsFromBus > 0) return seatsFromBus;
    final seatsFromTrip = (tripData?['totalSeats'] as num?)?.toInt();
    if (seatsFromTrip != null && seatsFromTrip > 0) return seatsFromTrip;
    return 0;
  }

  void _recalculateAllSegments() {
    for (final seg in segments) {
      _recalculateSegmentValues(seg);
    }
    for (final seg in returnSegments) {
      _recalculateSegmentValues(seg);
    }
  }

  void _addSegment() {
    setState(() {
      final autoFrom = segments.isNotEmpty ? segments.last.to : '';
      final newSeg = TripSegment(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        from: autoFrom,
        to: '',
        sequenceNo: segments.length + 1,
        availableSeats: _defaultSeats(),
        distanceKm: 0,
      );

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
        availableSeats: _defaultSeats(),
        distanceKm: seg.distanceKm,
      );
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
      setState(() {
        segments[index].from = from;
        segments[index].to = to;
        segments[index].departureTime = depTime;
        segments[index].distanceKm = distanceKm;
        segments[index].waitTimeMinutes = waitTime;
        _recalculateSegmentValues(segments[index], updateDistanceText: false);

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

  Future<void> _updateTrip() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null || selectedBus == null) return;
      if (!recurringTrip && departureDate == null) return;

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
        if (!recurringTrip && departureDate != null)
          'departureDate': Timestamp.fromDate(departureDate!)
        else
          'departureDate': FieldValue.delete(),
        'segments': segmentsData,
        if (returnTrip) 'returnSegments': returnSegmentsData,
        'recurring': recurringTrip,
        'ownerId': uid,
        'status': 'active',
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final oldBusId = tripData['busId']?.toString();
      final newBusId = selectedBus!['id']?.toString();

      await FirebaseFirestore.instance
          .collection('trips')
          .doc(widget.tripId)
          .update(tripData);

      if (newBusId != null && newBusId.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('buses')
            .doc(newBusId)
            .update({'isAssigned': true, 'isActive': true});
      }

      if (oldBusId != null && oldBusId.isNotEmpty && oldBusId != newBusId) {
        await FirebaseFirestore.instance
            .collection('buses')
            .doc(oldBusId)
            .update({'isAssigned': false, 'isActive': false});
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Trip updated successfully"),
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

  Future<void> _deleteTrip() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Trip?"),
        content: const Text("This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final oldBusId = tripData?['busId']?.toString();
                await FirebaseFirestore.instance
                    .collection('trips')
                    .doc(widget.tripId)
                    .delete();
                if (oldBusId != null && oldBusId.isNotEmpty) {
                  await FirebaseFirestore.instance
                      .collection('buses')
                      .doc(oldBusId)
                      .update({'isAssigned': false, 'isActive': false});
                }
                if (!mounted) return;
                Navigator.pop(context, true);
              } catch (e) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text("Error: $e")));
              }
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loadingTrip || loadingBuses) {
      return Scaffold(
        backgroundColor: const Color(0xFFF7F9FC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: const BackButton(color: Colors.black),
          title: const Text(
            "Edit Trip",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: const Text(
          "Edit Trip",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
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

            /// SCHEDULE
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
                        initialDate: departureDate ?? DateTime.now(),
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
                      "No buses available",
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
            const SizedBox(height: 12),

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
                        initialTime: returnDepartureTime ?? TimeOfDay.now(),
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
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: canCreateTrip
                    ? () {
                        _updateTrip();
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
                  "Save Changes",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: _deleteTrip,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text(
                  "Delete Trip",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
                          initialTime: segment.departureTime ?? TimeOfDay.now(),
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

          /// Fare & Wait Time
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
}
