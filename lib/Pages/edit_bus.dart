import 'package:cloud_firestore/cloud_firestore.dart';
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

class EditBusPage extends StatefulWidget {
  final Map<String, dynamic> busData;

  const EditBusPage({super.key, required this.busData});

  @override
  State<EditBusPage> createState() => _EditBusPageState();
}

class _EditBusPageState extends State<EditBusPage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _busNameCtrl;
  late TextEditingController _busNumberCtrl;
  late TextEditingController _rcNoCtrl;
  late TextEditingController _modelCtrl;
  late TextEditingController _totalSeatsCtrl;
  late TextEditingController _availableSeatsCtrl;
  late TextEditingController _pricePerKmCtrl;

  late TextEditingController _driverNameCtrl;
  late TextEditingController _driverPhoneCtrl;
  late TextEditingController _conductorNameCtrl;
  late TextEditingController _conductorPhoneCtrl;

  bool _isAC = true;
  bool _isSleeper = false;
  bool _isActive = true;
  bool _updating = false;

  String? _selectedBrand;
  String? _selectedModel;
  int? _avgSpeedKmph;

  @override
  void initState() {
    super.initState();
    final bus = widget.busData;

    _busNameCtrl = TextEditingController(text: bus['busName'] ?? '');
    _busNumberCtrl = TextEditingController(text: bus['busNumber'] ?? '');
    _rcNoCtrl = TextEditingController(text: bus['rcNo'] ?? '');
    _modelCtrl = TextEditingController(text: bus['model'] ?? '');
    _totalSeatsCtrl = TextEditingController(
      text: (bus['totalSeats'] ?? '').toString(),
    );
    _availableSeatsCtrl = TextEditingController(
      text: (bus['availableSeats'] ?? '').toString(),
    );
    _pricePerKmCtrl = TextEditingController(
      text: (bus['pricePerKm'] ?? '').toString(),
    );

    _driverNameCtrl = TextEditingController(text: bus['driver']?['name'] ?? '');
    _driverPhoneCtrl = TextEditingController(
      text: bus['driver']?['phone'] ?? '',
    );
    _conductorNameCtrl = TextEditingController(
      text: bus['conductor']?['name'] ?? '',
    );
    _conductorPhoneCtrl = TextEditingController(
      text: bus['conductor']?['phone'] ?? '',
    );

    _isAC = bus['busType'] == "AC";
    _isSleeper = bus['isSleeper'] ?? false;
    _isActive = bus['isActive'] ?? true;
    _selectedBrand = bus['brand'];
    _selectedModel = bus['model'];
    _avgSpeedKmph = (bus['avgSpeedKmph'] as num?)?.toInt();
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
      appBar: AppBar(title: const Text("Edit Bus"), centerTitle: true),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Basic Info
              _sectionTitle("Basic Information"),
              _busNameWithSuggestions(),
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

              // Brand & Model
              _brandDropdown(),
              _modelDropdown(),

              const SizedBox(height: 16),

              // Seats
              _sectionTitle("Specifications"),
              Row(
                children: [
                  Expanded(
                    child: _numberInput(
                      _totalSeatsCtrl,
                      "Total Seats",
                      required: true,
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

              // Staff
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

              // Status
              _sectionTitle("Status"),
              SwitchListTile(
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
                title: const Text("Bus Active"),
              ),

              const SizedBox(height: 32),

              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _updating ? null : _updateBus,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF137FEC),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _updating
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                "Update Bus",
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _updating
                          ? null
                          : () => _deleteBusWithConfirm(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        "Delete",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

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
      child: TextFormField(
        controller: _busNameCtrl,
        validator: (v) => v == null || v.isEmpty ? "Required" : null,
        decoration: _decoration("Bus Name"),
      ),
    );
  }

  Widget _rcNumberField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: _rcNoCtrl,
        enabled: false,
        decoration: _decoration("RC Number (Cannot edit)"),
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
                  if (value != null) {
                    final model = models.firstWhere((m) => m['name'] == value);
                    _totalSeatsCtrl.text = model['seats'].toString();
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
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
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

  Future<void> _updateBus() async {
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
      setState(() => _updating = true);

      final oldBus = widget.busData;
      final busData = {
        "busName": _busNameCtrl.text.trim(),
        "busNumber": _busNumberCtrl.text.trim(),
        "brand": _selectedBrand,
        "model": _selectedModel ?? _modelCtrl.text.trim(),
        "totalSeats": totalSeats,
        "availableSeats": availableSeats,
        "busType": _isAC ? "AC" : "Non-AC",
        "isSleeper": _isSleeper,
        "isActive": _isActive,
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

      final rcNo = widget.busData['rcNo'];
      await FirebaseFirestore.instance
          .collection("buses")
          .doc(rcNo)
          .update(busData);

      await PriceUtils.updateOnEdit(
        oldBusName: (oldBus['busName'] ?? '').toString(),
        newBusName: _busNameCtrl.text.trim(),
        oldPricePerKm: (oldBus['pricePerKm'] as num?)?.toDouble() ?? pricePerKm,
        newPricePerKm: pricePerKm,
        oldIsAc: (oldBus['busType'] ?? '') == 'AC',
        newIsAc: _isAC,
        oldIsSleeper: oldBus['isSleeper'] == true,
        newIsSleeper: _isSleeper,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Bus Updated"),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error updating bus"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  void _deleteBusWithConfirm(BuildContext context) {
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
              _deleteBus();
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteBus() async {
    try {
      setState(() => _updating = true);
      final rcNo = widget.busData['rcNo'];
      await FirebaseFirestore.instance.collection("buses").doc(rcNo).delete();

      await PriceUtils.updateOnDelete(
        busName: (widget.busData['busName'] ?? '').toString(),
        pricePerKm: (widget.busData['pricePerKm'] as num?)?.toDouble() ?? 0,
        isAc: (widget.busData['busType'] ?? '') == 'AC',
        isSleeper: widget.busData['isSleeper'] == true,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Bus deleted successfully"),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error deleting bus"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }
}
