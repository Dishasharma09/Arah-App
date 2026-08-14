import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/home/seller_home_screen.dart';
import '../../screens/orders/my_orders_screen.dart';
import '../../screens/chat/chat_list_screen.dart';
import '../../screens/profile/user_profile_screen.dart';

class ArahBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final bool isSeller;

  const ArahBottomNavBar({
    super.key,
    required this.currentIndex,
    this.isSeller = false,
  });

  void _navigate(int index, BuildContext context) {
    if (index == currentIndex) return;

    Widget screen;
    switch (index) {
      case 0:
        // Home — return to the root (pop all until first) or replace
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) =>
                isSeller ? const SellerHomeScreen() : const BuyerHomeScreen(),
          ),
          (route) => false,
        );
        return;
      case 1:
        screen = MyOrdersScreen(isSeller: isSeller);
        break;
      case 2:
        screen = ChatListScreen(isSeller: isSeller);
        break;
      case 3:
        screen = UserProfileScreen(isSeller: isSeller);
        break;
      default:
        return;
    }

    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    // Colors, elevation and label styles all come from
    // `bottomNavigationBarTheme` in AppTheme — nothing is hardcoded here.
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (index) => _navigate(index, context),
      items: const [
        BottomNavigationBarItem(
          icon: Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Icon(CupertinoIcons.house, size: 26),
          ),
          activeIcon: Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Icon(CupertinoIcons.house_fill, size: 26),
          ),
          label: "Home",
        ),
        BottomNavigationBarItem(
          icon: Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Icon(Icons.assignment_outlined, size: 26),
          ),
          activeIcon: Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Icon(Icons.assignment, size: 26),
          ),
          label: "Orders",
        ),
        BottomNavigationBarItem(
          icon: Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Icon(CupertinoIcons.chat_bubble, size: 26),
          ),
          activeIcon: Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Icon(CupertinoIcons.chat_bubble_fill, size: 26),
          ),
          label: "Chat",
        ),
        BottomNavigationBarItem(
          icon: Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Icon(CupertinoIcons.person, size: 26),
          ),
          activeIcon: Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Icon(CupertinoIcons.person_solid, size: 26),
          ),
          label: "Profile",
        ),
      ],
    );
  }
}
