// lib/features/applications/application_detail_screen.dart

import 'package:flutter/material.dart';

class ApplicationDetailScreen extends StatelessWidget {
  final String caseId;
  const ApplicationDetailScreen({super.key, required this.caseId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text('Application Detail Screen Stub for case: $caseId'),
      ),
    );
  }
}
