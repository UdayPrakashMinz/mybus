import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mybus/utils/price_utils.dart';

// Data for bus brands and models
const Map<String, List<Map<String, dynamic>>> busBrandModels = {
  'Tata': [
    {'name': '407', 'seats': 37},
    {'name': '709', 'seats': 37},
    {'name': '55AF', 'seats': 49},
    {'name': 'Starliner', 'seats': 54},
  ],
  'Ashok Leyland': [
    {'name': 'Oyster', 'seats': 50},
    {'name': 'Viking', 'seats': 52},
    {'name': 'Captain', 'seats': 54},
    {'name': 'Lynx', 'seats': 37},
  ],
  'Volvo': [
    {'name': 'B7R', 'seats': 49},
    {'name': 'B9R', 'seats': 49},
    {'name': 'B11R', 'seats': 52},
  ],
  'Scania': [
    {'name': 'K340', 'seats': 50},
    {'name': 'K360', 'seats': 56},
  ],
  'Bharat Benz': [
    {'name': '17', 'seats': 37},
    {'name': '18', 'seats': 49},
  ],
  'Mahindra': [
    {'name': 'E-Chess', 'seats': 47},
    {'name': 'HE-150', 'seats': 52},
  ],
  'Isuzu': [
    {'name': 'NJV', 'seats': 37},
    {'name': 'NMR', 'seats': 37},
  ],
};

class AddBus extends StatefulWidget {
  final Map<String, dynamic>? busData; // null = add, not null = edit

  const AddBus({super.key, this.busData});

  @override
  State<AddBus> createState() => _AddBusState();
}

class _AddBusState extends State<AddBus> {
  final _formKey = GlobalKey<FormState>();

  final _busNameCtrl = TextEditingController();
  final _busNumberCtrl = TextEditingController();
  final _rcNoCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _totalSeatsCtrl = TextEditingController();
  final _availableSeatsCtrl = TextEditingController();
  final _pricePerKmCtrl = TextEditingController();

  final _driverNameCtrl = TextEditingController();
  final _driverPhoneCtrl = TextEditingController();
  final _conductorNameCtrl = TextEditingController();
  final _conductorPhoneCtrl = TextEditingController();

  bool _isAC = true;
  bool _isSleeper = false;
  bool _isActive = false;
  bool _saving = false;

  String? _selectedBrand;
  String? _selectedModel;
  int? _avgSpeedKmph;
  List<String>? _previousBusNames;

  bool get isEdit => widget.busData != null;

  @override
  void initState() {
    super.initState();
    _loadPreviousBusNames();

    if (isEdit) {
      final b = widget.busData!;
      _busNameCtrl.text = b['busName'] ?? '';
      _busNumberCtrl.text = b['busNumber'] ?? '';
      _rcNoCtrl.text = b['rcNo'] ?? '';
      _selectedBrand = b['brand'];
      _selectedModel = b['model'];
      _modelCtrl.text = b['model'] ?? '';
      _totalSeatsCtrl.text = (b['totalSeats'] ?? '').toString();
      _availableSeatsCtrl.text = (b['availableSeats'] ?? '').toString();
      _pricePerKmCtrl.text = (b['pricePerKm'] ?? '').toString();

      _isAC = b['busType'] == "AC";
      _isSleeper = b['isSleeper'] ?? false;
      _isActive = b['isActive'] ?? true;
      _avgSpeedKmph = (b['avgSpeedKmph'] as num?)?.toInt();

      _driverNameCtrl.text = b['driver']?['name'] ?? '';
      _driverPhoneCtrl.text = b['driver']?['phone'] ?? '';
      _conductorNameCtrl.text = b['conductor']?['name'] ?? '';
      _conductorPhoneCtrl.text = b['conductor']?['phone'] ?? '';
    }
  }

  Future<void> _loadPreviousBusNames() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('buses')
          .where('ownerId', isEqualTo: user.uid)
          .get();

      final names = snapshot.docs
          .map((e) => (e['busName'] as String?)?.trim() ?? '')
          .toList();
      names.removeWhere((e) => e.isEmpty);

      setState(() => _previousBusNames = names.toSet().toList());
    } catch (e) {
      debugPrint('Error loading bus names: $e');
    }
  }

  @override
  void dispose() {
    _busNameCtrl.dispose();
    _busNumberCtrl.dispose();
    _rcNoCtrl.dispose();
    _modelCtrl.dispose();
    _totalSeatsCtrl.dispose();
    _availableSeatsCtrl.dispose();
    _pricePerKmCtrl.dispose();
    _driverNameCtrl.dispose();
    _driverPhoneCtrl.dispose();
    _conductorNameCtrl.dispose();
    _conductorPhoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: AppBar(
        title: Text(isEdit ? "Manage Bus" : "Add New Bus"),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ---------------- BASIC INFO ----------------
              _sectionTitle("Basic Information"),

              // Bus Name with suggestions
              _busNameWithSuggestions(),

              // Bus Number with auto-increment
              Row(
                children: [
                  Expanded(
                    child: _input(
                      _busNumberCtrl,
                      "Bus Number (01-99)",
                      required: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12, top: 8),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        int current = int.tryParse(_busNumberCtrl.text) ?? 0;
                        if (current < 99) {
                          _busNumberCtrl.text = (current + 1)
                              .toString()
                              .padLeft(2, '0');
                        }
                      },
                      icon: const Icon(Icons.add),
                      label: const Text("++"),
                    ),
                  ),
                ],
              ),

              _rcNumberField(),

              const SizedBox(height: 12),

              // Brand Dropdown
              _brandDropdown(),

              // Model Dropdown
              _modelDropdown(),

              const SizedBox(height: 16),

              // ---------------- SEATS ----------------
              _sectionTitle("Specifications"),

              Row(
                children: [
                  Expanded(
                    child: _numberInput(
                      _totalSeatsCtrl,
                      "Total Seats",
                      required: true,
                      onChanged: (v) {
                        if (!isEdit) _availableSeatsCtrl.text = v;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _numberInput(
                      _availableSeatsCtrl,
                      "Available Seats",
                      required: true,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              _busTypeSelector(),

              SwitchListTile(
                value: _isSleeper,
                onChanged: (v) => setState(() => _isSleeper = v),
                title: const Text("Sleeper Bus"),
              ),

              const SizedBox(height: 8),

              _avgSpeedDropdown(),

              _numberInput(
                _pricePerKmCtrl,
                "Price per Km (₹1~3)",
                required: true,
              ),

              const SizedBox(height: 16),

              // ---------------- STAFF ----------------
              _sectionTitle("Staff Details"),

              _input(_driverNameCtrl, "Driver Name", required: true),
              _phoneNumberField(
                _driverPhoneCtrl,
                "Driver Phone",
                required: true,
              ),
              _input(_conductorNameCtrl, "Conductor Name"),
              _phoneNumberField(_conductorPhoneCtrl, "Conductor Phone"),

              const SizedBox(height: 16),

              // ---------------- STATUS ----------------
              _sectionTitle("Status"),

              SwitchListTile(
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
                title: const Text("Bus Active"),
              ),

              const SizedBox(height: 32),

              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _saving ? null : _saveBus,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF137FEC),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _saving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          isEdit ? "Update Bus" : "Save Bus",
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
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

  // ---------------- UI HELPERS ----------------

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _busNameWithSuggestions() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Autocomplete<String>(
        initialValue: TextEditingValue(text: _busNameCtrl.text),
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text.isEmpty) {
            return const [];
          }
          return (_previousBusNames ?? [])
              .where(
                (name) => name.toLowerCase().contains(
                  textEditingValue.text.toLowerCase(),
                ),
              )
              .toList();
        },
        onSelected: (String selection) {
          _busNameCtrl.text = selection;
        },
        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
          return TextFormField(
            controller: controller,
            focusNode: focusNode,
            validator: (v) => v == null || v.isEmpty ? "Required" : null,
            decoration: _decoration("Bus Name"),
            onChanged: (v) {
              _busNameCtrl.text = v;
            },
          );
        },
      ),
    );
  }

  Widget _rcNumberField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: _rcNoCtrl,
        enabled: !isEdit,
        textCapitalization: TextCapitalization.characters,
        inputFormatters: [],
        onChanged: (value) {
          // Desired format: OD23 AA 1234 or OD16 A 1234
          String cleaned = value.replaceAll(' ', '').toUpperCase();
          String state = '';
          String district = '';
          String series = '';
          String numbers = '';

          if (cleaned.isNotEmpty && _isAlpha(cleaned[0])) state += cleaned[0];
          if (cleaned.length >= 2 && _isAlpha(cleaned[1])) state += cleaned[1];
          if (cleaned.length >= 3 && _isDigit(cleaned[2])) {
            district += cleaned[2];
          }
          if (cleaned.length >= 4 && _isDigit(cleaned[3])) {
            district += cleaned[3];
          }

          int idx = 4;
          while (idx < cleaned.length &&
              _isAlpha(cleaned[idx]) &&
              series.length < 2) {
            series += cleaned[idx];
            idx++;
          }
          while (idx < cleaned.length &&
              _isDigit(cleaned[idx]) &&
              numbers.length < 4) {
            numbers += cleaned[idx];
            idx++;
          }

          String formatted = '';
          if (state.isNotEmpty) formatted += state;
          if (district.isNotEmpty) formatted += district;
          if (series.isNotEmpty) formatted += ' $series';
          if (numbers.isNotEmpty) formatted += ' $numbers';

          if (formatted != value) {
            _rcNoCtrl.value = TextEditingValue(
              text: formatted,
              selection: TextSelection.collapsed(offset: formatted.length),
            );
          }

          // auto-next when we have full 4-digit suffix
          if (numbers.length == 4) {
            FocusScope.of(context).nextFocus();
          }
        },
        validator: (v) {
          if (v == null || v.isEmpty) return "Required";
          String cleaned = v.replaceAll(' ', '');
          if (cleaned.length < 9) return "Invalid RC";
          if (!_isAlpha(cleaned[0]) || !_isAlpha(cleaned[1])) {
            return "Invalid state code";
          }
          if (!_isDigit(cleaned[2]) || !_isDigit(cleaned[3])) {
            return "Invalid district code";
          }
          int pos = 4;
          int letters = 0;
          while (pos < cleaned.length &&
              _isAlpha(cleaned[pos]) &&
              letters < 2) {
            letters++;
            pos++;
          }
          if (letters < 1) return "Missing series letters";
          int digits = 0;
          while (pos < cleaned.length && _isDigit(cleaned[pos]) && digits < 4) {
            digits++;
            pos++;
          }
          if (digits != 4) return "Need 4 digits at end";
          return null;
        },

        decoration: _decoration("RC Number (OD16 C 8464)"),
      ),
    );
  }

  Widget _brandDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: _selectedBrand,
        isExpanded: true,
        items: busBrandModels.keys.map((brand) {
          return DropdownMenuItem(value: brand, child: Text(brand));
        }).toList(),
        onChanged: (value) {
          setState(() {
            _selectedBrand = value;
            _selectedModel = null;
            _modelCtrl.clear();
            _totalSeatsCtrl.clear();
          });
          FocusScope.of(context).nextFocus();
        },
        validator: (v) => v == null ? "Select a brand" : null,
        decoration: _decoration("Bus Brand"),
      ),
    );
  }

  Widget _modelDropdown() {
    final models = _selectedBrand != null
        ? busBrandModels[_selectedBrand]!
        : [];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: _selectedModel,
        isExpanded: true,
        disabledHint: const Text("Select a brand first"),
        items: models.map<DropdownMenuItem<String>>((model) {
          return DropdownMenuItem<String>(
            value: model['name'] as String,
            child: Text('${model['name']} (${model['seats']} seats)'),
          );
        }).toList(),
        onChanged: _selectedBrand != null
            ? (value) {
                setState(() {
                  _selectedModel = value;
                  _modelCtrl.text = value ?? '';
                  // Auto-fill total seats
                  if (value != null) {
                    final model = models.firstWhere((m) => m['name'] == value);
                    _totalSeatsCtrl.text = model['seats'].toString();
                    if (!isEdit) {
                      _availableSeatsCtrl.text = model['seats'].toString();
                    }
                  }
                });
              }
            : null,
        validator: (v) => v == null ? "Select a model" : null,
        decoration: _decoration("Bus Model"),
      ),
    );
  }

  Widget _phoneNumberField(
    TextEditingController controller,
    String label, {
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.phone,
        maxLength: 10,
        onChanged: (value) {
          // Only allow digits
          final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
          if (digits != value) {
            controller.text = digits;
            controller.selection = TextSelection.collapsed(
              offset: digits.length,
            );
          }
        },
        validator: (v) {
          if (required && (v == null || v.isEmpty)) return "Required";
          if (v != null && v.isNotEmpty && v.length != 10) {
            return "Phone must be 10 digits";
          }
          if (v != null &&
              v.isNotEmpty &&
              !RegExp(r'^[6-9]\d{9}$').hasMatch(v)) {
            return "Invalid phone number";
          }
          return null;
        },
        decoration: _decoration(label),
      ),
    );
  }

  Widget _input(
    TextEditingController controller,
    String label, {
    bool required = false,
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        validator: required
            ? (v) => v == null || v.isEmpty ? "Required" : null
            : null,
        decoration: _decoration(label),
      ),
    );
  }

  Widget _numberInput(
    TextEditingController controller,
    String label, {
    bool required = false,
    void Function(String)? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        onChanged: onChanged,
        validator: required
            ? (v) => v == null || v.isEmpty ? "Required" : null
            : null,
        decoration: _decoration(label),
      ),
    );
  }

  Widget _busTypeSelector() {
    return Row(
      children: [
        _typeButton("AC", _isAC, () => setState(() => _isAC = true)),
        const SizedBox(width: 12),
        _typeButton("Non-AC", !_isAC, () => setState(() => _isAC = false)),
      ],
    );
  }

  Widget _avgSpeedDropdown() {
    const speeds = [55, 60, 65, 70];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<int>(
        initialValue: _avgSpeedKmph,
        isExpanded: true,
        items: speeds
            .map(
              (speed) =>
                  DropdownMenuItem(value: speed, child: Text('$speed Km/h')),
            )
            .toList(),
        onChanged: (value) => setState(() => _avgSpeedKmph = value),
        validator: (v) => v == null ? "Select average speed" : null,
        decoration: _decoration("Average Speed"),
      ),
    );
  }

  Widget _typeButton(String text, bool selected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF137FEC) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: selected ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    );
  }

  // Helper function for min value
  int min(int a, int b) => a < b ? a : b;

  bool _isDigit(String char) {
    return char.codeUnitAt(0) >= 48 && char.codeUnitAt(0) <= 57;
  }

  bool _isAlpha(String char) {
    int code = char.codeUnitAt(0);
    return (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
  }

  /// Ensure the bus number is unique for this owner and bus name.
  /// If the entered bus number already exists (or none entered), this
  /// picks the next available number (01..99) and updates the controller.
  Future<void> _ensureUniqueBusNumber(String ownerId) async {
    try {
      final name = _busNameCtrl.text.trim();
      if (name.isEmpty) return;

      final entered = _busNumberCtrl.text.trim();
      final enteredNum =
          int.tryParse(entered.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

      final snapshot = await FirebaseFirestore.instance
          .collection('buses')
          .where('ownerId', isEqualTo: ownerId)
          .where('busName', isEqualTo: name)
          .get();

      final existingNums = <int>[];
      for (final doc in snapshot.docs) {
        final bn = doc.data()['busNumber'];
        if (bn == null) continue;
        int n = 0;
        if (bn is int) n = bn;
        if (bn is String) {
          n = int.tryParse(bn.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        }
        if (n > 0) existingNums.add(n);
      }

      // If entered number exists, or no number entered, pick next available
      bool needPick = false;
      if (enteredNum > 0 && existingNums.contains(enteredNum)) needPick = true;
      if ((enteredNum == 0 || entered.isEmpty) && existingNums.isNotEmpty) {
        needPick = true;
      }

      if (!needPick) return;

      int next = 1;
      if (existingNums.isNotEmpty) {
        next = existingNums.reduce((a, b) => a > b ? a : b) + 1;
      } else if (enteredNum > 0) {
        next = enteredNum + 1;
      }

      if (next > 99) {
        // no available numbers
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No available bus numbers (01-99)')),
        );
        return;
      }

      final padded = next.toString().padLeft(2, '0');
      setState(() => _busNumberCtrl.text = padded);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bus number adjusted to $padded to avoid conflict'),
        ),
      );
    } catch (e) {
      debugPrint('Error ensuring unique bus number: $e');
    }
  }

  // ---------------- SAVE ----------------

  Future<void> _saveBus() async {
    if (!_formKey.currentState!.validate()) return;

    final totalSeats = int.tryParse(_totalSeatsCtrl.text) ?? 0;
    final availableSeats = int.tryParse(_availableSeatsCtrl.text) ?? 0;
    final pricePerKm = double.tryParse(_pricePerKmCtrl.text) ?? 0;

    if (availableSeats > totalSeats) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Available seats cannot exceed total seats"),
        ),
      );
      return;
    }
    if ((_avgSpeedKmph ?? 0) <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Select average speed")));
      return;
    }
    if (pricePerKm <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter a valid price per km")),
      );
      return;
    }

    try {
      setState(() => _saving = true);

      final user = FirebaseAuth.instance.currentUser!;
      final oldBus = widget.busData ?? {};

      // Ensure bus number is unique for this owner + bus name
      if (!isEdit) {
        await _ensureUniqueBusNumber(user.uid);
      }

      final busData = {
        "ownerId": user.uid,
        "busName": _busNameCtrl.text.trim(),
        "busNumber": _busNumberCtrl.text.trim(),
        "rcNo": _rcNoCtrl.text.trim(),
        "brand": _selectedBrand,
        "model": _selectedModel ?? _modelCtrl.text.trim(),
        "totalSeats": totalSeats,
        "availableSeats": availableSeats,
        "busType": _isAC ? "AC" : "Non-AC",
        "isSleeper": _isSleeper,
        "isActive": _isActive,
        "isAssigned": false,
        "avgSpeedKmph": _avgSpeedKmph,
        "pricePerKm": pricePerKm,
        "driver": {
          "name": _driverNameCtrl.text.trim(),
          "phone": _driverPhoneCtrl.text.trim(),
        },
        "conductor": {
          "name": _conductorNameCtrl.text.trim(),
          "phone": _conductorPhoneCtrl.text.trim(),
        },
        "updatedAt": FieldValue.serverTimestamp(),
      };

      final busRef = FirebaseFirestore.instance
          .collection("buses")
          .doc(_rcNoCtrl.text.trim());

      if (isEdit) {
        await busRef.update(busData);
      } else {
        await busRef.set({
          ...busData,
          "createdAt": FieldValue.serverTimestamp(),
        });
      }

      final busName = _busNameCtrl.text.trim();
      final isAc = _isAC;
      final isSleeper = _isSleeper;
      final price = pricePerKm;

      if (isEdit) {
        final oldName = (oldBus['busName'] ?? '').toString();
        final oldPrice = (oldBus['pricePerKm'] as num?)?.toDouble() ?? price;
        final oldIsAc = (oldBus['busType'] ?? '') == 'AC';
        final oldIsSleeper = oldBus['isSleeper'] == true;

        await PriceUtils.updateOnEdit(
          oldBusName: oldName,
          newBusName: busName,
          oldPricePerKm: oldPrice,
          newPricePerKm: price,
          oldIsAc: oldIsAc,
          newIsAc: isAc,
          oldIsSleeper: oldIsSleeper,
          newIsSleeper: isSleeper,
        );
      } else {
        await PriceUtils.updateOnAdd(
          busName: busName,
          pricePerKm: price,
          isAc: isAc,
          isSleeper: isSleeper,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEdit ? "Bus Updated" : "Bus Added"),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error saving bus"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
