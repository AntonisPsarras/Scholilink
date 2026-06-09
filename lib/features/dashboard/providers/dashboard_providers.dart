import 'package:flutter_riverpod/flutter_riverpod.dart';

enum DashboardViewType { school, frontistirio }

final dashboardViewTypeProvider = StateProvider<DashboardViewType>(
  (ref) => DashboardViewType.school,
);
