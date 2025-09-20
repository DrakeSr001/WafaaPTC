import 'package:flutter/foundation.dart';

class PendingScan {
  /// Returns code from URL query (?code=...) on web, else null.
  static String? readFromUrl() {
    if (!kIsWeb) return null;
    final params = Uri.base.queryParameters;
    final c = params['code'];
    if (c == null) {
      // Fallback: support hashes like #/home?code=...
      final frag = Uri.base.fragment;
      final qIndex = frag.indexOf('?');
      if (qIndex != -1) {
        final fragQuery = Uri.splitQueryString(frag.substring(qIndex + 1));
        final inFrag = fragQuery['code'];
        if (inFrag != null) {
          return inFrag.trim().length >= 10 ? inFrag.trim() : null;
        }
      }
      return null;
    }
    // basic sanity
    return c.trim().length >= 10 ? c.trim() : null;
  }
}

