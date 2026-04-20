// ─────────────────────────────────────────────────────────────
// ONYX API KEYS — Runtime Configuration Store
// ─────────────────────────────────────────────────────────────
// Keys are loaded at startup from the Git-ignored config file
// (assets/onyx_config.txt). NEVER hardcode secrets here.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ApiKeys {
  ApiKeys._();

  // ── Gemini API Keys (Round-Robin Pool) ────────────────────
  static List<String> geminiKeys = [];

  // ── External Service Keys ─────────────────────────────────
  static String openRouterApiKey = '';
  static String tavilyApiKey = '';

  /// Whether keys have been successfully loaded.
  static bool get isLoaded => geminiKeys.isNotEmpty;

  /// Loads all API keys from the bundled config file.
  /// Called once in main() before runApp().
  static Future<void> load() async {
    try {
      final raw = await rootBundle.loadString('assets/onyx_config.txt');
      final Map<String, String> parsed = {};

      for (final line in raw.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

        final eqIdx = trimmed.indexOf('=');
        if (eqIdx == -1) continue;

        final key = trimmed.substring(0, eqIdx).trim();
        var value = trimmed.substring(eqIdx + 1).trim();

        // Strip surrounding quotes if present
        if ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'"))) {
          value = value.substring(1, value.length - 1);
        }

        if (value.isNotEmpty) {
          parsed[key] = value;
        }
      }

      // Populate Gemini keys
      geminiKeys = [
        parsed['GEMINI_API_KEY_1'],
        parsed['GEMINI_API_KEY_2'],
        parsed['GEMINI_API_KEY_3'],
        parsed['GEMINI_API_KEY_4'],
        parsed['GEMINI_API_KEY_5'],
      ].whereType<String>().where((k) => k.isNotEmpty).toList();

      // Populate external keys
      openRouterApiKey = parsed['OPENROUTER_API_KEY'] ?? '';
      tavilyApiKey = parsed['TAVILY_API_KEY'] ?? '';

      debugPrint('🔐 ApiKeys: Loaded ${geminiKeys.length} Gemini keys, '
          'OpenRouter=${openRouterApiKey.isNotEmpty ? "✅" : "❌"}, '
          'Tavily=${tavilyApiKey.isNotEmpty ? "✅" : "❌"}');
    } catch (e) {
      debugPrint('🔐 ApiKeys: FAILED to load config — $e');
    }
  }
}
