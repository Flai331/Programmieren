// ═══════════════════════════════════════════════════════════════
//  StorageService – lokale Datenpersistenz (shared_preferences)
//  lib/utils/storage_service.dart
// ═══════════════════════════════════════════════════════════════

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/volk.dart';
import '../models/standort.dart';
import '../models/inspektion.dart';
import '../models/ernte.dart';
import '../models/behandlung.dart';

class StorageService {
  static const _keyVoelker      = 'imkerei_voelker';
  static const _keyStandorte    = 'imkerei_standorte';
  static const _keyInspektionen = 'imkerei_inspektionen';
  static const _keyErnten       = 'imkerei_ernten';
  static const _keyBehandlungen = 'imkerei_behandlungen';

  // ── Standorte ───────────────────────────────────────────────
  static Future<List<Standort>> loadStandorte() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyStandorte);
    if (raw == null) return [];
    final List decoded = jsonDecode(raw);
    return decoded.map((e) => Standort.fromJson(e)).toList();
  }

  static Future<void> saveStandorte(List<Standort> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyStandorte, jsonEncode(list.map((e) => e.toJson()).toList()));
  }

  // ── Völker ───────────────────────────────────────────────────
  static Future<List<Volk>> loadVoelker() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyVoelker);
    if (raw == null) return [];
    final List decoded = jsonDecode(raw);
    return decoded.map((e) => Volk.fromJson(e)).toList();
  }

  static Future<void> saveVoelker(List<Volk> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyVoelker, jsonEncode(list.map((e) => e.toJson()).toList()));
  }

  // ── Inspektionen ─────────────────────────────────────────────
  static Future<List<Inspektion>> loadInspektionen() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyInspektionen);
    if (raw == null) return [];
    final List decoded = jsonDecode(raw);
    return decoded.map((e) => Inspektion.fromJson(e)).toList();
  }

  static Future<void> saveInspektionen(List<Inspektion> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyInspektionen, jsonEncode(list.map((e) => e.toJson()).toList()));
  }

  // ── Ernten ───────────────────────────────────────────────────
  static Future<List<Ernte>> loadErnten() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyErnten);
    if (raw == null) return [];
    final List decoded = jsonDecode(raw);
    return decoded.map((e) => Ernte.fromJson(e)).toList();
  }

  static Future<void> saveErnten(List<Ernte> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyErnten, jsonEncode(list.map((e) => e.toJson()).toList()));
  }

  // ── Behandlungen ─────────────────────────────────────────────
  static Future<List<Behandlung>> loadBehandlungen() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyBehandlungen);
    if (raw == null) return [];
    final List decoded = jsonDecode(raw);
    return decoded.map((e) => Behandlung.fromJson(e)).toList();
  }

  static Future<void> saveBehandlungen(List<Behandlung> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBehandlungen, jsonEncode(list.map((e) => e.toJson()).toList()));
  }
}
