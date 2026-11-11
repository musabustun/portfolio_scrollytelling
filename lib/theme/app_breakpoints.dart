import 'package:flutter/painting.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Tek breakpoint (720) ve iki tasarım boyutu (AGENTS.md §11.3); düzen kararı `isMobile` ile.
abstract final class AppBreakpoints {
  static const double mobileMaxWidth = 720;
  static const Size desktopDesignSize = Size(1440, 900);
  static const Size mobileDesignSize = Size(390, 844);

  static bool isMobileWidth(double width) => width < mobileMaxWidth;

  static Size designSizeFor(double width) =>
      isMobileWidth(width) ? mobileDesignSize : desktopDesignSize;

  /// Ekran mobil düzende mi. Yalnızca `ScreenUtilInit` altında çağrılır (ScreenUtil yapılandırılmış olmalı).
  static bool get isMobile => isMobileWidth(ScreenUtil().screenWidth);
}
