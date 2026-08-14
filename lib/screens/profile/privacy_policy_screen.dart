import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        automaticallyImplyLeading: false,
  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
  surfaceTintColor: Colors.transparent,
  scrolledUnderElevation: 0,
  elevation: 0,
        title: const Text("Privacy Policy"),
      ),

      body: const SingleChildScrollView(

        padding: EdgeInsets.all(20),

        child: Column(

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            Text(
              "Privacy Policy",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            SizedBox(height: 16),


            Text(
              """
Arah respects your privacy and is committed to protecting your personal information.

1. Information We Collect

We collect information you provide when creating an account, completing your profile, posting tasks, communicating with other users, and using our services.

2. How We Use Information

Your information is used to provide and improve Arah services, connect buyers and sellers, and maintain a secure platform.

3. Data Security

We take reasonable measures to protect your information and keep your data secure.

4. User Responsibility

Users are responsible for keeping their account information accurate and secure.

5. Changes To This Policy

This Privacy Policy may be updated from time to time. Users will be informed of important changes.

Version 1.0
              """,

              style: TextStyle(
                fontSize: 15,
                height: 1.6,
              ),

            ),

          ],

        ),

      ),

    );

  }
}