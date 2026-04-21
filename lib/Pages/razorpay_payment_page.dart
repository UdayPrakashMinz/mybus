import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // ✅ REQUIRED for kIsWeb
import 'package:razorpay_flutter/razorpay_flutter.dart';

class RazorpayPaymentResult {
  final String paymentId;
  final String? orderId;
  final String? signature;

  const RazorpayPaymentResult({
    required this.paymentId,
    this.orderId,
    this.signature,
  });
}

class RazorpayPaymentPage extends StatefulWidget {
  final double amount;
  final String description;
  final String? keyId;
  final String? orderId;
  final String? customerName;
  final String? prefillEmail;
  final String? prefillContact;

  const RazorpayPaymentPage({
    super.key,
    required this.amount,
    this.description = 'Bus Ticket Payment',
    this.keyId,
    this.orderId,
    this.customerName,
    this.prefillEmail,
    this.prefillContact,
  });

  @override
  State<RazorpayPaymentPage> createState() => _RazorpayPaymentPageState();
}

class _RazorpayPaymentPageState extends State<RazorpayPaymentPage> {
  static const Color _razorpayBlue = Color(0xFF0F4FDB);

  Razorpay? _razorpay; // ✅ FIXED (removed late)
  late final String _keyId;
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _keyId = "rzp_test_SYW7LgfD7Yk5b6";

    if (!kIsWeb) {
      _razorpay = Razorpay();

      _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
      _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
      _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    } else {
      debugPrint("Razorpay not supported on web");
    }
  }

  @override
  void dispose() {
    if (!kIsWeb) {
      _razorpay?.clear();
    }
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    if (!mounted) return;
    setState(() {
      _isProcessing = false;
      _errorMessage = null;
    });
    Navigator.pop(
      context,
      RazorpayPaymentResult(
        paymentId: response.paymentId ?? '',
        orderId: response.orderId,
        signature: response.signature,
      ),
    );
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (!mounted) return;
    setState(() {
      _isProcessing = false;
      _errorMessage =
          response.message ??
          'Payment failed. Please try again or use another method.';
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_errorMessage!)));
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    if (!mounted) return;
    setState(() {
      _isProcessing = false;
      _errorMessage = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('External wallet: ${response.walletName ?? ''}')),
    );
  }

  void _startPayment() {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Payments are only supported on mobile app"),
        ),
      );
      return;
    }

    if (_keyId.trim().isEmpty) {
      setState(() {
        _errorMessage =
            'Razorpay key missing. Provide RAZORPAY_KEY_ID at build time.';
      });
      return;
    }

    final amountInPaise = (widget.amount * 100).round();

    if (amountInPaise <= 0) {
      setState(() {
        _errorMessage = 'Invalid amount.';
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    final options = <String, Object?>{
      'key': _keyId,
      'amount': amountInPaise,
      'currency': 'INR',
      'name': widget.customerName ?? 'MyBus',
      'description': widget.description,
      'prefill': <String, String?>{
        'email': widget.prefillEmail,
        'contact': widget.prefillContact,
      },
      'theme': <String, String>{'color': '#0F4FDB'},
      'retry': <String, Object>{'enabled': true, 'max_count': 1},
    };

    if (widget.orderId != null && widget.orderId!.isNotEmpty) {
      options['order_id'] = widget.orderId!;
    }

    try {
      _razorpay!.open(options);
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Unable to open Razorpay: $e';
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errorMessage!)));
    }
  }

  void _cancel() {
    Navigator.pop(context, null);
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Optional: Completely block UI on web
    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(title: const Text('Payment')),
        body: const Center(
          child: Text(
            "Payments are available only on the mobile app.",
            style: TextStyle(fontSize: 16),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text('Razorpay Payment'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: const [
                BoxShadow(color: Color(0x14000000), blurRadius: 8),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.payment, color: _razorpayBlue),
                    SizedBox(width: 8),
                    Text(
                      'Razorpay Checkout',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  widget.description,
                  style: const TextStyle(color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Amount',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 6),
                Text(
                  'Rs ${widget.amount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isProcessing ? null : _cancel,
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _startPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _razorpayBlue,
                  ),
                  child: Text(
                    _isProcessing ? 'Processing...' : 'Pay Now',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
