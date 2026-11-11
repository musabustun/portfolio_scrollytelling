import 'package:flutter/painting.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Köşe yarıçapları (AGENTS.md §10.5): pill 999, panel ve kart 24.
abstract final class AppRadii {
  static const BorderRadius pill = BorderRadius.all(Radius.circular(999));

  static BorderRadius get panel => BorderRadius.circular(24.r);
}
