import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/material.dart';

class AppIcons {
  // Social
  static const String google = 'assets/icons/ui/google.svg';
  static const String apple = 'assets/icons/ui/apple-logo.svg';
  static const String facebook = 'assets/icons/ui/facebook.png';

  // Auth
  static const String email = 'assets/icons/ui/envelope.svg';
  static const String lock = 'assets/icons/ui/lock.svg';
  static const String eye = 'assets/icons/ui/eye.svg';
  static const String eyeOff = 'assets/icons/ui/eye-crossed.svg';

  /// Universal SVG builder
  static Widget svg(String asset, {double size = 24, Color? color}) {
    return SvgPicture.asset(
      asset,
      height: size,
      width: size,
      colorFilter: color != null
          ? ColorFilter.mode(color, BlendMode.srcIn)
          : null,
    );
  }
}
