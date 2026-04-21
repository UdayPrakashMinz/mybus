import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("About MyBus"), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              "MyBus",
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),

            Text(
              "MyBus – A Smart Travel Solution is a smart bus management and booking application Made by B. Tech (Computer Science & Engineering) Final Year Project Group - D (2026) at Black Diamond College of Engineering and Technology to simplify public transport for both passengers and bus operators. It provides real-time booking, trip management, and seat tracking.",
              style: TextStyle(fontSize: 16),
            ),

            SizedBox(height: 20),

            Text(
              "👨‍💻 Development Team",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),

            Text("Anugrahit Tirkey (2321309044)"),
            Text("Dulana Sing (2321309047)"),
            Text("Kapil Luhar (2321309048)"),
            Text("Sanjeev Choudhary (2321309049)"),
            Text("Sriyaa Sutar (2321309053)"),
            Text("Subham Mishra (2321309054)"),
            Text("Uday Prakash Minz (2321309057) - Leader & Main Developer"),

            SizedBox(height: 20),

            Text(
              "🎯 Purpose",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text("• Fast and convenient booking"),
            Text("• Real-time seat availability"),
            Text("• Efficient trip and route management"),
            Text("• Reduced manual errors"),

            SizedBox(height: 20),

            Text(
              "🚀 Features",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text("• Bus search and booking"),
            Text("• Route and city selection"),
            Text("• Live seat tracking"),
            Text("• Time-based scheduling"),
            Text("• Dynamic fare calculation"),
            Text("• Notifications and alerts"),
            Text("• User profile & trip history"),

            SizedBox(height: 20),

            Text(
              "📌 Objective",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              "To modernize transportation systems by making them digital, efficient, and user-friendly.",
            ),

            SizedBox(height: 30),

            Center(
              child: Text(
                "MyBus — A Smart Travel Solution",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
