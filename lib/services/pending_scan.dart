import 'package:flutter/foundation.dart';

class PendingScan {
  /// Returns code from URL query (?code=...) on web, else null.
  static String? readFromUrl() {
    if (!kIsWeb) return null;
    final params = Uri.base.queryParameters;
    final c = params['code'];
    if (c == null) return null;
    // basic sanity
    return c.trim().length >= 10 ? c.trim() : null;
  }
}
