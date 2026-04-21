import 'package:cloud_firestore/cloud_firestore.dart';

class PriceUtils {
  static String priceDocIdForBusName(String busName) {
    final normalized = busName.trim().toLowerCase();
    if (normalized.isEmpty) return 'unknown';
    return normalized.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  }

  static Future<void> updateOnAdd({
    required String busName,
    required double pricePerKm,
    required bool isAc,
    required bool isSleeper,
  }) async {
    final category = _categoryKey(isAc: isAc, isSleeper: isSleeper);
    await _applyDelta(
      busName: busName,
      deltas: {category: _Delta(sum: pricePerKm, count: 1)},
    );
  }

  static Future<void> updateOnEdit({
    required String oldBusName,
    required String newBusName,
    required double oldPricePerKm,
    required double newPricePerKm,
    required bool oldIsAc,
    required bool newIsAc,
    required bool oldIsSleeper,
    required bool newIsSleeper,
  }) async {
    final oldCategory =
        _categoryKey(isAc: oldIsAc, isSleeper: oldIsSleeper);
    final newCategory =
        _categoryKey(isAc: newIsAc, isSleeper: newIsSleeper);

    if (oldBusName.trim().toLowerCase() != newBusName.trim().toLowerCase()) {
      await _applyDelta(
        busName: oldBusName,
        deltas: {oldCategory: _Delta(sum: -oldPricePerKm, count: -1)},
      );
      await _applyDelta(
        busName: newBusName,
        deltas: {newCategory: _Delta(sum: newPricePerKm, count: 1)},
      );
      return;
    }

    if (oldCategory == newCategory) {
      final delta = newPricePerKm - oldPricePerKm;
      if (delta != 0) {
        await _applyDelta(
          busName: newBusName,
          deltas: {newCategory: _Delta(sum: delta, count: 0)},
        );
      }
      return;
    }

    await _applyDelta(
      busName: newBusName,
      deltas: {
        oldCategory: _Delta(sum: -oldPricePerKm, count: -1),
        newCategory: _Delta(sum: newPricePerKm, count: 1),
      },
    );
  }

  static Future<void> updateOnDelete({
    required String busName,
    required double pricePerKm,
    required bool isAc,
    required bool isSleeper,
  }) async {
    final category = _categoryKey(isAc: isAc, isSleeper: isSleeper);
    await _applyDelta(
      busName: busName,
      deltas: {category: _Delta(sum: -pricePerKm, count: -1)},
    );
  }

  static Future<int> rebuildPricesForBuses({
    required String? ownerId,
    required bool isAdmin,
  }) async {
    Query<Map<String, dynamic>> query =
        FirebaseFirestore.instance.collection('buses');
    if (!isAdmin && ownerId != null && ownerId.isNotEmpty) {
      query = query.where('ownerId', isEqualTo: ownerId);
    }

    final snapshot = await query.get();
    final Map<String, _Agg> byProvider = {};

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final busName = (data['busName'] ?? '').toString().trim();
      if (busName.isEmpty) continue;

      final price = (data['pricePerKm'] as num?)?.toDouble() ?? 0;
      if (price <= 0) continue;

      final isSleeper = data['isSleeper'] == true;
      final isAc = (data['busType'] ?? '') == 'AC';
      final category = _categoryKey(isAc: isAc, isSleeper: isSleeper);

      byProvider.putIfAbsent(busName, () => _Agg(busName));
      byProvider[busName]!.add(category, price);
    }

    if (byProvider.isEmpty) return 0;

    final batches = <WriteBatch>[];
    WriteBatch batch = FirebaseFirestore.instance.batch();
    int ops = 0;

    void pushBatch() {
      batches.add(batch);
      batch = FirebaseFirestore.instance.batch();
      ops = 0;
    }

    for (final agg in byProvider.values) {
      final docId = priceDocIdForBusName(agg.busName);
      final docRef =
          FirebaseFirestore.instance.collection('prices').doc(docId);

      batch.set(docRef, agg.toDoc(), SetOptions(merge: false));
      ops++;
      if (ops >= 450) {
        pushBatch();
      }
    }
    if (ops > 0) pushBatch();

    for (final b in batches) {
      await b.commit();
    }

    return byProvider.length;
  }

  static String _categoryKey({required bool isAc, required bool isSleeper}) {
    if (isSleeper) return 'sleeper';
    return isAc ? 'ac' : 'nonAc';
  }

  static Future<void> _applyDelta({
    required String busName,
    required Map<String, _Delta> deltas,
  }) async {
    final safeName = busName.trim();
    if (safeName.isEmpty) return;

    final docId = priceDocIdForBusName(safeName);
    final docRef =
        FirebaseFirestore.instance.collection('prices').doc(docId);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      final data = snapshot.data() ?? <String, dynamic>{};

      final nextData = <String, dynamic>{
        'busName': safeName,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      for (final entry in deltas.entries) {
        final key = entry.key;
        final delta = entry.value;
        final current = (data[key] as Map<String, dynamic>?) ?? {};

        final currentSum = (current['sum'] as num?)?.toDouble() ?? 0;
        final currentCount = (current['count'] as num?)?.toInt() ?? 0;

        final nextSum = currentSum + delta.sum;
        final nextCount = currentCount + delta.count;

        final safeCount = nextCount < 0 ? 0 : nextCount;
        final safeSum = safeCount == 0 ? 0.0 : nextSum;
        final nextAvg = safeCount == 0 ? 0.0 : safeSum / safeCount;

        nextData[key] = {
          'sum': safeSum,
          'count': safeCount,
          'avg': nextAvg,
        };
      }

      transaction.set(docRef, nextData, SetOptions(merge: true));
    });
  }
}

class _Delta {
  final double sum;
  final int count;

  const _Delta({required this.sum, required this.count});
}

class _Agg {
  final String busName;
  final Map<String, _AggBucket> buckets = {
    'ac': _AggBucket(),
    'nonAc': _AggBucket(),
    'sleeper': _AggBucket(),
  };

  _Agg(this.busName);

  void add(String category, double price) {
    final bucket = buckets[category];
    if (bucket == null) return;
    bucket.sum += price;
    bucket.count += 1;
  }

  Map<String, dynamic> toDoc() {
    final data = <String, dynamic>{
      'busName': busName,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    for (final entry in buckets.entries) {
      final bucket = entry.value;
      final count = bucket.count;
      final sum = count == 0 ? 0.0 : bucket.sum;
      final avg = count == 0 ? 0.0 : sum / count;
      data[entry.key] = {
        'sum': sum,
        'count': count,
        'avg': avg,
      };
    }
    return data;
  }
}

class _AggBucket {
  double sum = 0;
  int count = 0;
}
