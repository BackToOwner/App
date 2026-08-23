import 'package:flutter/material.dart';
import '../models/report_item.dart';
import 'report_list_screen.dart';

class FoundScreen extends StatelessWidget {
  const FoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ReportListScreen(reportType: ReportType.found);
  }
}
