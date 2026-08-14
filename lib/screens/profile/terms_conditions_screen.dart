import 'package:flutter/material.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        automaticallyImplyLeading: false,
  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
  surfaceTintColor: Colors.transparent,
  scrolledUnderElevation: 0,
  elevation: 0,
        title: const Text("Terms & Conditions"),
      ),


      body: const SingleChildScrollView(

        padding: EdgeInsets.all(20),

        child: Column(

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [


            Text(
              "Terms & Conditions",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),


            SizedBox(height: 16),


            Text(
              """
Welcome to Arah.

By using Arah, you agree to follow these terms and conditions.

1. User Accounts

Users must provide accurate information and are responsible for their account activities.

2. Platform Usage

Arah provides a platform that connects buyers and sellers. Users should communicate and work responsibly.

3. Prohibited Activities

Users must not use the platform for illegal activities or misuse other users' information.

4. Transactions

Users are responsible for agreements and interactions made through the platform.

5. Updates

These terms may be updated in the future as Arah grows.

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