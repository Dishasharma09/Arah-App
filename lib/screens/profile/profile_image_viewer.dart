import 'dart:io';
import 'package:flutter/material.dart';

class ProfileImageViewer extends StatelessWidget {
  final File? profileImage;
  final String? photoUrl;
  final VoidCallback onChangePhoto;

  const ProfileImageViewer({
    super.key,
    this.profileImage,
    this.photoUrl,
    required this.onChangePhoto,
  });

  @override
  Widget build(BuildContext context) {
    ImageProvider image;

    if (profileImage != null) {
      image = FileImage(profileImage!);
    } else {
      image = NetworkImage(photoUrl!);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Hero(
                tag: "profile_photo",
                child: Image(
                  image: image,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),

          Positioned(
            left: 20,
            right: 20,
            bottom: 30,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                onChangePhoto();
              },
              icon: const Icon(Icons.camera_alt),
              label: const Text("Change Photo"),
            ),
          ),
        ],
      ),
    );
  }
}