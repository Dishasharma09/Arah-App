import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show debugPrint;

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

Future<String> uploadProfilePicture(String uid, String filePath) async {
  final ref = FirebaseStorage.instance.ref("profile_pics/$uid.jpg");
  await ref.putFile(File(filePath));
  return await ref.getDownloadURL();
}









Future<String> uploadChatAttachment(
  String chatId,
  String filePath, {
  void Function(double progress)? onProgress,
}) async {
  try {
    final file = File(filePath);

    // If file_picker returned an invalid/non-existent path, fail early
    // with a clear message instead of letting Storage throw a confusing error.
    if (!await file.exists()) {
      throw Exception('File not found on device at path: $filePath');
    }

    // Prefix with a timestamp to avoid overwriting a file with the same name.
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';

    final ref =
        FirebaseStorage.instance.ref().child("chats/$chatId/$fileName");

    final task = ref.putFile(file);

    if (onProgress != null) {
      task.snapshotEvents.listen((snapshot) {
        if (snapshot.totalBytes > 0) {
          onProgress(snapshot.bytesTransferred / snapshot.totalBytes);
        }
      });
    }

    final uploadTask = await task;

    if (uploadTask.state != TaskState.success) {
      throw Exception('Upload did not complete successfully: ${uploadTask.state}');
    }

    // Use the ref from the finished snapshot to avoid any path mismatch.
    return await uploadTask.ref.getDownloadURL();
  } catch (e) {
    debugPrint("uploadChatAttachment error: $e");
    rethrow;
  }
}










  Future<String> uploadTaskAttachment(String taskId, String filePath) async {
    String fileName = filePath.split(RegExp(r'[/\\]')).last;
    Reference ref = _storage.ref().child('task_attachments/$taskId/$fileName');
    await ref.putFile(File(filePath));
    return await ref.getDownloadURL();
  }


}