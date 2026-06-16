import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: mbBlue,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Text('Profil', style: MbTypography.h2(Colors.white)),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: Text(
              'Profil — à venir',
              style: MbTypography.body(mbInk2),
            ),
          ),
        ),
      ],
    );
  }
}
