// ─────────────────────────────────────────────────────────────
// ONYX API KEYS — Hardcoded Configuration
// ─────────────────────────────────────────────────────────────
// This eliminates all flutter_dotenv / asset-loading issues
// by keeping API keys as compile-time constants.
// ─────────────────────────────────────────────────────────────

class ApiKeys {
  ApiKeys._(); // Prevent instantiation

  // ── Gemini API Keys (Round-Robin Pool) ────────────────────
  static const List<String> geminiKeys = [
    'AIzaSyDP8FpjGx24bVt5oy8CLCfdXJKFJ9WZTPI',
    'AIzaSyDuNJ2NWx1f9JuEjY2wklgwQbvgSWD6kXc',
    'AIzaSyBMrxEt_j_jIbUGiUb6iuNWG-Bn4yGT8Zc',
    'AIzaSyCwQ3akH5Ljsr6CKrSkza1_SSI-SEttEaU',
    'AIzaSyBZBnbWwLJwSr0fY0GvMZUfEww9moSaDgk',
  ];

  // ── External Service Keys ─────────────────────────────────
  static const String openRouterApiKey =
      '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';

  static const String tavilyApiKey =
      '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';
}
