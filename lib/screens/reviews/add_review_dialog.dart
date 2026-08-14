import 'package:flutter/material.dart';
import '../../services/review_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/review_model.dart';
import '../../app/theme/app_theme.dart';
class AddReviewScreen extends StatefulWidget {
final String userId;
final String taskId;
const AddReviewScreen({
  super.key,
  required this.userId,
  required this.taskId,
});

  @override
  State<AddReviewScreen> createState() => _AddReviewScreenState();
}

class _AddReviewScreenState extends State<AddReviewScreen> {

  double rating = 0;
  final reviewController = TextEditingController();
  bool isLoading = false;

  @override
  void dispose() {
    reviewController.dispose();
    super.dispose();
  }


  Future<void> submitReview() async {

    if (rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select rating"),
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });


 final currentUserId = FirebaseAuth.instance.currentUser!.uid;

final review = ReviewModel(
  id: FirebaseFirestore.instance.collection('reviews').doc().id,
  fromUserId: currentUserId,
  toUserId: widget.userId,
  taskId: "task_id_here",
  rating: rating,
  review: reviewController.text.trim(),
  createdAt: DateTime.now(),
);

await ReviewService().addReview(review);

    if(!mounted) return;

    setState(() {
      isLoading = false;
    });


    Navigator.pop(context);

  }


  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
  automaticallyImplyLeading: false,
  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
  surfaceTintColor: Colors.transparent,
  scrolledUnderElevation: 0,
  elevation: 0,
        title: const Text("Add Review"),
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            const Text(
              "Rate your experience",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),


            const SizedBox(height:20),


            Row(
              children: List.generate(5, (index){

                return IconButton(
                  onPressed: (){
                    setState(() {
                      rating = index + 1.0;
                    });
                  },

                  icon: Icon(
                    Icons.star,
                    size: 35,
                    color: index < rating
                        ? AppTheme.warningAmber
                        : AppTheme.colorsOf(context).border,
                  ),

                );

              }),
            ),


            const SizedBox(height:30),


            TextField(
              controller: reviewController,

              maxLines: 5,

              decoration: const InputDecoration(
                hintText: "Write your review...",
                border: OutlineInputBorder(),
              ),
            ),


            const SizedBox(height:30),


            SizedBox(
              width: double.infinity,

              child: ElevatedButton(

                onPressed: isLoading
                    ? null
                    : submitReview,

                child: isLoading
                    ? const CircularProgressIndicator()
                    : const Text("Submit Review"),

              ),
            )

          ],
        ),
      ),
    );
  }
}