import 'package:flutter/material.dart';
import '../widgets/user_profile_sheet.dart';

void showUserProfile(BuildContext context, String userId) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => UserProfileSheet(userId: userId),
  );
}
