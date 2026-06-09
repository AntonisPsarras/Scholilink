import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Manages the selected index of the bottom navigation bar / navigation rail.
final navigationProvider = StateProvider<int>((ref) => 0);

/// Holds an optional widget to display as a full-center-area overlay on desktop.
/// When set, the overlay replaces the tab content in the center column while
/// keeping the left and right sidebars visible. Setting to null hides the overlay.
final centerOverlayProvider = StateProvider<Widget?>((ref) => null);
