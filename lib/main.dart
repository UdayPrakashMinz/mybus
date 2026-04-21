import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:mybus/Service/auth_router.dart';
import 'package:mybus/Pages/edit_bus.dart';
import 'package:mybus/Pages/add_bus.dart';
import 'package:mybus/Pages/razorpay_payment_page.dart';
import 'package:mybus/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static const Color _primary = Color(0xFF137FEC);

  static const Color _bgLight = Color(0xFFF6F7F8);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MyBus',
      theme: ThemeData(useMaterial3: true),
      home: const AuthRouter(),
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/edit_bus':
            final args = settings.arguments as Map<String, dynamic>?;
            if (args != null) {
              return MaterialPageRoute(
                builder: (context) => EditBusPage(busData: args),
              );
            }
            return null;

          case '/add_bus':
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (context) => AddBus(busData: args),
            );

          case '/book_ticket_info':
            final args = settings.arguments as Map<String, dynamic>?;
            final DateTime safeDate;
            if (args?['date'] is DateTime) {
              safeDate = args!['date'] as DateTime;
            } else {
              safeDate =
                  DateTime.tryParse(args?['date']?.toString() ?? '') ??
                  DateTime.now();
            }

          case '/razorpay_payment':
            final args = settings.arguments as Map<String, dynamic>?;
            final amount = (args?['amount'] as num?)?.toDouble() ?? 0;
            final description =
                args?['description']?.toString() ?? 'Bus Ticket Payment';
            return MaterialPageRoute(
              builder: (context) =>
                  RazorpayPaymentPage(amount: amount, description: description),
            );

          default:
            return null;
        }
        return null;
      },
    );
  }
}
