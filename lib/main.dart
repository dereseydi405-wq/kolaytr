import 'dart:convert';

import 'package:flutter/material.dart';
import 'life_events.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzData;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  await CloudService.init();
  await CloudGuideService.init();
  runApp(const KolayTRApp());
}

class KolayTRApp extends StatelessWidget {
  const KolayTRApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      title: 'KolayTR',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        scaffoldBackgroundColor: const Color(0xFFF7F7FC),
        useMaterial3: true,
      ),
      home: const MainShell(),
    );
  }
}

class Procedure {
  final String title;
  final String category;
  final String desc;
  final String place;
  final String link;
  final List<String> docs;
  final List<String> steps;
  final List<String> warnings;

  const Procedure({
    required this.title,
    required this.category,
    required this.desc,
    required this.place,
    required this.link,
    required this.docs,
    required this.steps,
    required this.warnings,
  });
}

class SavedDocument {
  final String id;
  final String title;
  final String category;
  final String note;
  final String createdAt;

  const SavedDocument({
    required this.id,
    required this.title,
    required this.category,
    required this.note,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'note': note,
      'createdAt': createdAt,
    };
  }

  factory SavedDocument.fromJson(Map<String, dynamic> json) {
    return SavedDocument(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      category: json['category']?.toString() ?? 'Diğer',
      note: json['note']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }
}

class SavedReminder {
  final String id;
  final String title;
  final String category;
  final String note;
  final DateTime date;

  const SavedReminder({
    required this.id,
    required this.title,
    required this.category,
    required this.note,
    required this.date,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'note': note,
      'date': date.toIso8601String(),
    };
  }

  factory SavedReminder.fromJson(Map<String, dynamic> json) {
    return SavedReminder(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      category: json['category']?.toString() ?? 'Diğer',
      note: json['note']?.toString() ?? '',
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class LocalStore {
  static const String documentsKey = 'kolaytr_documents_v1';
  static const String remindersKey = 'kolaytr_reminders_v1';
  static const String favoritesKey = 'kolaytr_favorites_v1';

  static Future<Set<String>> loadFavoritesDeviceOnly() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(favoritesKey) ?? []).toSet();
  }

  static Future<Set<String>> loadFavorites() async {
    final localFavorites = await loadFavoritesDeviceOnly();
    final cloudFavorites = await CloudFavoriteService.loadFavoritesFromCloud();

    if (cloudFavorites == null) {
      return localFavorites;
    }

    if (cloudFavorites.isEmpty && localFavorites.isNotEmpty) {
      await CloudFavoriteService.syncFavorites(localFavorites);

      final migratedFavorites =
          await CloudFavoriteService.loadFavoritesFromCloud();

      if (migratedFavorites != null) {
        await saveFavoritesDeviceOnly(migratedFavorites);
        return migratedFavorites;
      }
    }

    await saveFavoritesDeviceOnly(cloudFavorites);
    return cloudFavorites;
  }

  static Future<void> saveFavoritesDeviceOnly(Set<String> favorites) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(favoritesKey, favorites.toList());
  }

  static Future<void> saveFavorites(Set<String> favorites) async {
    await saveFavoritesDeviceOnly(favorites);
    await CloudFavoriteService.syncFavorites(favorites);
  }

  static Future<bool> toggleFavorite(String title) async {
    final favorites = await loadFavorites();

    if (favorites.contains(title)) {
      favorites.remove(title);
      await saveFavorites(favorites);
      return false;
    } else {
      favorites.add(title);
      await saveFavorites(favorites);
      return true;
    }
  }

  static Future<List<SavedDocument>> loadDocumentsDeviceOnly() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(documentsKey);

      if (raw == null || raw.isEmpty) {
        return [];
      }

      final decoded = jsonDecode(raw);

      if (decoded is! List) {
        return [];
      }

      return decoded
          .whereType<Map>()
          .map(
            (item) => SavedDocument.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<SavedDocument>> loadDocuments() async {
    final localDocuments = await loadDocumentsDeviceOnly();
    final cloudDocuments = await CloudDocumentService.loadDocumentsFromCloud();

    if (cloudDocuments == null) {
      return localDocuments;
    }

    if (cloudDocuments.isEmpty && localDocuments.isNotEmpty) {
      await CloudDocumentService.syncDocuments(localDocuments);

      final migratedDocuments =
          await CloudDocumentService.loadDocumentsFromCloud();

      if (migratedDocuments != null) {
        await saveDocumentsDeviceOnly(migratedDocuments);
        return migratedDocuments;
      }
    }

    await saveDocumentsDeviceOnly(cloudDocuments);
    return cloudDocuments;
  }

  static Future<void> saveDocumentsDeviceOnly(
    List<SavedDocument> documents,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    final encoded = jsonEncode(documents.map((item) => item.toJson()).toList());

    await prefs.setString(documentsKey, encoded);
  }

  static Future<void> saveDocuments(List<SavedDocument> documents) async {
    await saveDocumentsDeviceOnly(documents);
    await CloudDocumentService.syncDocuments(documents);
  }

  static Future<List<SavedReminder>> loadRemindersDeviceOnly() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(remindersKey);

      if (raw == null || raw.isEmpty) {
        return [];
      }

      final decoded = jsonDecode(raw);

      if (decoded is! List) {
        return [];
      }

      return decoded
          .whereType<Map>()
          .map(
            (item) => SavedReminder.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<SavedReminder>> loadReminders() async {
    final localReminders = await loadRemindersDeviceOnly();
    final cloudReminders = await CloudReminderService.loadRemindersFromCloud();

    if (cloudReminders == null) {
      return localReminders;
    }

    if (cloudReminders.isEmpty && localReminders.isNotEmpty) {
      await CloudReminderService.syncReminders(localReminders);

      final migratedReminders =
          await CloudReminderService.loadRemindersFromCloud();

      if (migratedReminders != null) {
        await saveRemindersDeviceOnly(migratedReminders);
        return migratedReminders;
      }
    }

    await saveRemindersDeviceOnly(cloudReminders);
    return cloudReminders;
  }

  static Future<void> saveRemindersDeviceOnly(
    List<SavedReminder> reminders,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    final encoded = jsonEncode(reminders.map((item) => item.toJson()).toList());

    await prefs.setString(remindersKey, encoded);
  }

  static Future<void> saveReminders(List<SavedReminder> reminders) async {
    await saveRemindersDeviceOnly(reminders);
    await CloudReminderService.syncReminders(reminders);
  }
}

class CloudService {
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  static bool initialized = false;
  static String? lastError;

  static SupabaseClient? get client {
    if (!initialized) return null;
    return Supabase.instance.client;
  }

  static String get statusText {
    if (initialized) {
      final user = client?.auth.currentUser;
      final shortId = user == null ? 'oturum yok' : user.id.substring(0, 8);
      return 'Supabase bağlı • Kullanıcı: $shortId';
    }

    if (supabaseUrl.isEmpty || publishableKey.isEmpty) {
      return 'Supabase secrets eksik.';
    }

    return 'Supabase bağlantısı hazır değil.';
  }

  static Future<void> init() async {
    if (supabaseUrl.isEmpty || publishableKey.isEmpty) {
      initialized = false;
      lastError = 'SUPABASE_URL veya SUPABASE_PUBLISHABLE_KEY eksik.';
      return;
    }

    try {
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: publishableKey,
      );

      initialized = true;
      lastError = null;

      final auth = Supabase.instance.client.auth;

      if (auth.currentSession == null) {
        await auth.signInAnonymously();
      }
    } catch (error) {
      initialized = false;
      lastError = error.toString();
    }
  }

  static Future<String> testConnection() async {
    if (!initialized || client == null) {
      return lastError == null
          ? 'Bulut bağlantısı hazır değil.'
          : 'Bulut bağlantısı hazır değil: $lastError';
    }

    try {
      await client!
          .from('app_config')
          .select('latest_app_version')
          .eq('id', 1)
          .maybeSingle();

      await client!.from('guide_procedures').select('id').limit(1);

      final user = client!.auth.currentUser;

      return user == null
          ? 'Supabase bağlı ama kullanıcı oturumu bulunamadı.'
          : 'Supabase bağlı. Anonim kullanıcı aktif.';
    } catch (error) {
      return 'Supabase test hatası: $error';
    }
  }
}

class CloudDocumentService {
  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static bool get available {
    final client = CloudService.client;
    return CloudService.initialized &&
        client != null &&
        client.auth.currentUser != null;
  }

  static bool _looksLikeUuid(String value) {
    return _uuidPattern.hasMatch(value);
  }

  static String _formatCreatedAt(dynamic value) {
    try {
      final date = DateTime.parse(value.toString()).toLocal();
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      return '$day.$month.${date.year}';
    } catch (_) {
      return '';
    }
  }

  static SavedDocument _fromRow(dynamic row) {
    final map = Map<String, dynamic>.from(row as Map);

    return SavedDocument(
      id: map['id'].toString(),
      title: (map['title'] ?? '').toString(),
      category: (map['category'] ?? 'Diğer').toString(),
      note: (map['note'] ?? '').toString(),
      createdAt: _formatCreatedAt(map['created_at']),
    );
  }

  static Map<String, dynamic> _toPayload(SavedDocument document) {
    final userId = CloudService.client?.auth.currentUser?.id;

    return {
      if (userId != null) 'user_id': userId,
      'title': document.title,
      'category': document.category,
      'note': document.note,
    };
  }

  static Future<List<SavedDocument>?> loadDocumentsFromCloud() async {
    if (!available) return null;

    try {
      final data = await CloudService.client!
          .from('user_documents')
          .select('id,title,category,note,created_at')
          .order('created_at', ascending: false);

      return (data as List).map<SavedDocument>(_fromRow).toList();
    } catch (error) {
      CloudService.lastError = error.toString();
      return null;
    }
  }

  static Future<void> syncDocuments(List<SavedDocument> documents) async {
    if (!available) return;

    try {
      final client = CloudService.client!;

      final cloudRows = await client.from('user_documents').select('id');

      final cloudIds = (cloudRows as List)
          .map((row) => Map<String, dynamic>.from(row as Map)['id'].toString())
          .toSet();

      final currentCloudIds =
          documents.map((item) => item.id).where(_looksLikeUuid).toSet();

      final deletedIds = cloudIds.difference(currentCloudIds);

      for (final id in deletedIds) {
        await client.from('user_documents').delete().eq('id', id);
      }

      for (final document in documents) {
        final payload = _toPayload(document);

        if (_looksLikeUuid(document.id) && cloudIds.contains(document.id)) {
          await client
              .from('user_documents')
              .update(payload)
              .eq('id', document.id);
        } else {
          await client.from('user_documents').insert(payload);
        }
      }

      final latest = await loadDocumentsFromCloud();

      if (latest != null) {
        await LocalStore.saveDocumentsDeviceOnly(latest);
      }
    } catch (error) {
      CloudService.lastError = error.toString();
    }
  }
}

class CloudReminderService {
  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static bool get available {
    final client = CloudService.client;
    return CloudService.initialized &&
        client != null &&
        client.auth.currentUser != null;
  }

  static bool _looksLikeUuid(String value) {
    return _uuidPattern.hasMatch(value);
  }

  static SavedReminder _fromRow(dynamic row) {
    final map = Map<String, dynamic>.from(row as Map);

    return SavedReminder(
      id: map['id'].toString(),
      title: (map['title'] ?? '').toString(),
      category: (map['category'] ?? 'Diğer').toString(),
      note: (map['note'] ?? '').toString(),
      date: DateTime.parse(map['reminder_at'].toString()).toLocal(),
    );
  }

  static Map<String, dynamic> _toPayload(SavedReminder reminder) {
    final userId = CloudService.client?.auth.currentUser?.id;

    return {
      if (userId != null) 'user_id': userId,
      'title': reminder.title,
      'category': reminder.category,
      'note': reminder.note,
      'reminder_at': reminder.date.toUtc().toIso8601String(),
    };
  }

  static Future<List<SavedReminder>?> loadRemindersFromCloud() async {
    if (!available) return null;

    try {
      final data = await CloudService.client!
          .from('user_reminders')
          .select('id,title,category,note,reminder_at')
          .order('reminder_at', ascending: true);

      return (data as List).map<SavedReminder>(_fromRow).toList();
    } catch (error) {
      CloudService.lastError = error.toString();
      return null;
    }
  }

  static Future<void> syncReminders(List<SavedReminder> reminders) async {
    if (!available) return;

    try {
      final client = CloudService.client!;

      final cloudRows = await client.from('user_reminders').select('id');

      final cloudIds = (cloudRows as List)
          .map((row) => Map<String, dynamic>.from(row as Map)['id'].toString())
          .toSet();

      final currentCloudIds =
          reminders.map((item) => item.id).where(_looksLikeUuid).toSet();

      final deletedIds = cloudIds.difference(currentCloudIds);

      for (final id in deletedIds) {
        await client.from('user_reminders').delete().eq('id', id);
      }

      for (final reminder in reminders) {
        final payload = _toPayload(reminder);

        if (_looksLikeUuid(reminder.id) && cloudIds.contains(reminder.id)) {
          await client
              .from('user_reminders')
              .update(payload)
              .eq('id', reminder.id);
        } else {
          await client.from('user_reminders').insert(payload);
        }
      }

      final latest = await loadRemindersFromCloud();

      if (latest != null) {
        await LocalStore.saveRemindersDeviceOnly(latest);
      }
    } catch (error) {
      CloudService.lastError = error.toString();
    }
  }
}

class CloudFavoriteService {
  static bool get available {
    final client = CloudService.client;
    return CloudService.initialized &&
        client != null &&
        client.auth.currentUser != null;
  }

  static Future<Set<String>?> loadFavoritesFromCloud() async {
    if (!available) return null;

    try {
      final data = await CloudService.client!
          .from('user_favorites')
          .select('procedure_title')
          .order('created_at', ascending: false);

      return (data as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .map((row) => (row['procedure_title'] ?? '').toString())
          .where((title) => title.trim().isNotEmpty)
          .toSet();
    } catch (error) {
      CloudService.lastError = error.toString();
      return null;
    }
  }

  static Future<void> syncFavorites(Set<String> favorites) async {
    if (!available) return;

    try {
      final client = CloudService.client!;
      final userId = client.auth.currentUser?.id;

      if (userId == null) return;

      final cloudRows =
          await client.from('user_favorites').select('procedure_title');

      final cloudTitles = (cloudRows as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .map((row) => (row['procedure_title'] ?? '').toString())
          .where((title) => title.trim().isNotEmpty)
          .toSet();

      final deletedTitles = cloudTitles.difference(favorites);
      final newTitles = favorites.difference(cloudTitles);

      for (final title in deletedTitles) {
        await client
            .from('user_favorites')
            .delete()
            .eq('procedure_title', title);
      }

      for (final title in newTitles) {
        await client.from('user_favorites').insert({
          'user_id': userId,
          'procedure_title': title,
        });
      }

      final latest = await loadFavoritesFromCloud();

      if (latest != null) {
        await LocalStore.saveFavoritesDeviceOnly(latest);
      }
    } catch (error) {
      CloudService.lastError = error.toString();
    }
  }
}

class CloudGuideService {
  static bool loadedFromCloud = false;
  static int loadedCount = 0;
  static String? lastError;

  static String get statusText {
    if (loadedFromCloud) {
      return 'Supabase rehber aktif • $loadedCount işlem';
    }

    if (lastError != null) {
      return 'Yerel rehber kullanılıyor • Bulut hatası var';
    }

    return 'Yerel rehber kullanılıyor';
  }

  static bool get available {
    final client = CloudService.client;
    return CloudService.initialized && client != null;
  }

  static String _readString(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static int _readInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _readDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static bool _readBool(dynamic value) {
    if (value is bool) return value;
    return value?.toString().toLowerCase() == 'true';
  }

  static List<String> _stringList(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    if (value is String) {
      final text = value.trim();

      if (text.isEmpty) return [];

      try {
        final decoded = jsonDecode(text);

        if (decoded is List) {
          return decoded
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toList();
        }
      } catch (_) {}

      return text
          .split('\n')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    return [];
  }

  static Procedure _fromRow(dynamic row) {
    final map = Map<String, dynamic>.from(row as Map);

    return Procedure(
      title: _readString(map['title']),
      category: _readString(map['category'], fallback: 'Genel'),
      desc: _readString(map['description']),
      place: _readString(map['institution']),
      link: _readString(map['official_url']),
      docs: _stringList(map['docs']),
      steps: _stringList(map['steps']),
      warnings: _stringList(map['warnings']),
    );
  }

  static Future<List<Procedure>?> loadProceduresFromCloud() async {
    if (!available) return null;

    try {
      final data = await CloudService.client!
          .from('guide_procedures')
          .select(
            'title,category,description,institution,required_documents,steps,warnings,official_url,is_active,sort_order',
          )
          .eq('is_active', true)
          .order('sort_order', ascending: true);

      final items = (data as List).map<Procedure>(_fromRow).toList();

      return items;
    } catch (error) {
      lastError = error.toString();
      CloudService.lastError = error.toString();
      return null;
    }
  }

  static Future<void> init() async {
    try {
      final items = await loadProceduresFromCloud().timeout(
        const Duration(seconds: 8),
        onTimeout: () => null,
      );

      if (items != null && items.isNotEmpty) {
        procedures = items;
        loadedFromCloud = true;
        loadedCount = items.length;
        lastError = null;
      }
    } catch (error) {
      loadedFromCloud = false;
      lastError = error.toString();
    }
  }
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tzData.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const settings = InitializationSettings(android: androidSettings);

    await plugin.initialize(settings: settings);

    final android = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
  }

  static String reminderNotificationKey(SavedReminder reminder) {
    return '${reminder.title}|${reminder.category}|${reminder.date.toIso8601String()}';
  }

  static int idFrom(String value) {
    int hash = 0;
    for (final unit in value.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }

  static Future<bool> ensureNotificationPermission() async {
    try {
      final androidPlugin = plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      final granted = await androidPlugin?.requestNotificationsPermission();

      return granted ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> scheduleReminder(SavedReminder reminder) async {
    final notificationAllowed = await ensureNotificationPermission();

    if (!notificationAllowed) {
      return;
    }

    final scheduledDate = tz.TZDateTime.from(reminder.date, tz.local);

    if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
      return;
    }

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'kolaytr_reminders',
        'KolayTR Hatırlatıcılar',
        channelDescription: 'KolayTR tarih ve saat hatırlatıcı bildirimleri',
        importance: Importance.max,
        priority: Priority.high,
      ),
    );

    Future<void> scheduleWith(AndroidScheduleMode mode) {
      return plugin.zonedSchedule(
        id: idFrom(reminderNotificationKey(reminder)),
        title: 'KolayTR Hatırlatıcı',
        body: '${reminder.title} zamanı geldi.',
        scheduledDate: scheduledDate,
        notificationDetails: details,
        androidScheduleMode: mode,
        payload: reminder.id,
      );
    }

    try {
      await scheduleWith(AndroidScheduleMode.inexactAllowWhileIdle);
    } catch (_) {
      await scheduleWith(AndroidScheduleMode.inexactAllowWhileIdle);
    }
  }

  static Future<void> cancelReminder(SavedReminder reminder) async {
    await plugin.cancel(id: idFrom(reminderNotificationKey(reminder)));
  }

  static Future<void> showTestNotification() async {
    final notificationAllowed = await ensureNotificationPermission();

    if (!notificationAllowed) {
      return;
    }

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'kolaytr_test',
        'KolayTR Test Bildirimi',
        channelDescription: 'KolayTR bildirim testi',
        importance: Importance.max,
        priority: Priority.high,
      ),
    );

    await plugin.show(
      id: 999001,
      title: 'KolayTR Test',
      body: 'Bildirim sistemi çalışıyor.',
      notificationDetails: details,
    );
  }
}

List<Procedure> procedures = [
  Procedure(
    title: 'Kimlik Yenileme',
    category: 'Kimlik',
    desc: 'Yeni kimlik kartı almak veya mevcut kimliği yenilemek için rehber.',
    place: 'Nüfus ve Vatandaşlık İşleri',
    link: 'https://www.nvi.gov.tr',
    docs: ['Mevcut kimlik', 'Biyometrik fotoğraf', 'Başvuru ücret bilgisi'],
    steps: [
      'Randevu al',
      'Belgeleri hazırla',
      'Nüfus müdürlüğüne git',
      'Başvuruyu tamamla',
    ],
    warnings: [
      'Ücret ve belge şartları değişebilir',
      'Resmi kaynağı kontrol et',
    ],
  ),
  Procedure(
    title: 'Ehliyet Yenileme',
    category: 'Araç',
    desc: 'Sürücü belgesi yenileme işlemi için gerekli adımlar.',
    place: 'Nüfus Müdürlükleri',
    link: 'https://www.nvi.gov.tr',
    docs: ['Eski ehliyet', 'Kimlik', 'Sağlık raporu', 'Biyometrik fotoğraf'],
    steps: [
      'Sağlık raporu al',
      'Randevu oluştur',
      'Belgeleri hazırla',
      'Başvurunu yap',
    ],
    warnings: ['Sağlık raporu süresine dikkat et'],
  ),
  Procedure(
    title: 'Pasaport Başvurusu',
    category: 'Seyahat',
    desc: 'Pasaport alma veya pasaport yenileme rehberi.',
    place: 'Nüfus Müdürlükleri',
    link: 'https://www.nvi.gov.tr',
    docs: [
      'Kimlik',
      'Biyometrik fotoğraf',
      'Harç ve defter bedeli bilgisi',
      'Varsa eski pasaport',
    ],
    steps: [
      'Pasaport süresini seç',
      'Ücreti kontrol et',
      'Randevu al',
      'Başvuruya git',
    ],
    warnings: ['Seyahat tarihinden önce yeterli süre bırak'],
  ),
  Procedure(
    title: 'Araç Muayene Takibi',
    category: 'Araç',
    desc: 'Araç muayene tarihi ve randevu sürecini takip etme rehberi.',
    place: 'TÜVTÜRK',
    link: 'https://www.tuvturk.com.tr',
    docs: ['Ruhsat', 'Kimlik', 'Trafik sigortası', 'Egzoz emisyon gerekebilir'],
    steps: [
      'Son tarihi kontrol et',
      'Randevu al',
      'Belgeleri hazırla',
      'Aracı istasyona götür',
    ],
    warnings: ['Gecikme cezası çıkabilir'],
  ),
  Procedure(
    title: 'SGK Hizmet Dökümü',
    category: 'SGK',
    desc: 'Sigorta prim ve çalışma geçmişini görüntüleme rehberi.',
    place: 'e-Devlet / SGK',
    link: 'https://www.turkiye.gov.tr',
    docs: ['e-Devlet girişi'],
    steps: [
      'e-Devlet’e gir',
      'SGK hizmet dökümü ara',
      'Belgeyi görüntüle veya indir',
    ],
    warnings: ['Kişisel bilgilerini paylaşırken dikkatli ol'],
  ),
  Procedure(
    title: 'İkametgah Belgesi',
    category: 'Belge',
    desc: 'Yerleşim yeri ve adres belgesi alma rehberi.',
    place: 'e-Devlet / Nüfus',
    link: 'https://www.turkiye.gov.tr',
    docs: ['e-Devlet girişi'],
    steps: [
      'e-Devlet’e gir',
      'Yerleşim Yeri Belgesi ara',
      'Belgeyi oluştur',
      'PDF indir',
    ],
    warnings: ['Barkodlu belge olduğundan emin ol'],
  ),
  Procedure(
    title: 'Tüketici Şikayeti',
    category: 'Haklar',
    desc:
        'Ayıplı ürün, iade, garanti ve hizmet sorunları için başvuru rehberi.',
    place: 'Tüketici Hakem Heyeti / e-Devlet',
    link: 'https://www.turkiye.gov.tr',
    docs: [
      'Fatura veya fiş',
      'Garanti belgesi',
      'Yazışmalar',
      'Fotoğraf veya kanıt',
    ],
    steps: [
      'Sorunu açık yaz',
      'Kanıtları hazırla',
      'e-Devlet üzerinden başvur',
    ],
    warnings: ['Kanıtları silme', 'Parasal limitler değişebilir'],
  ),
  Procedure(
    title: 'MHRS Randevusu',
    category: 'Sağlık',
    desc: 'Hastane veya aile hekimi randevusu alma rehberi.',
    place: 'MHRS',
    link: 'https://www.mhrs.gov.tr',
    docs: ['T.C. kimlik bilgisi', 'MHRS veya e-Devlet girişi'],
    steps: [
      'MHRS’ye gir',
      'İl, hastane ve poliklinik seç',
      'Tarih seç',
      'Randevuyu onayla',
    ],
    warnings: ['Gidemeyeceğin randevuyu iptal et'],
  ),
  Procedure(
    title: 'Elektrik Aboneliği',
    category: 'Ev',
    desc: 'Yeni eve taşınırken elektrik aboneliği açtırma rehberi.',
    place: 'Elektrik dağıtım veya tedarik şirketi',
    link: 'https://www.turkiye.gov.tr',
    docs: [
      'Kimlik',
      'Kira sözleşmesi veya tapu',
      'Sayaç veya tesisat numarası',
    ],
    steps: [
      'Sayaç bilgilerini hazırla',
      'Başvuru yap',
      'Güvence bedelini kontrol et',
    ],
    warnings: ['Eski abonelikleri kapatmayı unutma'],
  ),
  Procedure(
    title: 'Öğrenci Belgesi',
    category: 'Eğitim',
    desc: 'Okul veya üniversite öğrenci belgesi alma rehberi.',
    place: 'e-Devlet / YÖK / MEB',
    link: 'https://www.turkiye.gov.tr',
    docs: ['e-Devlet girişi'],
    steps: ['Öğrenci Belgesi ara', 'Belgeyi görüntüle', 'PDF olarak indir'],
    warnings: ['Belgenin güncel tarihli olduğundan emin ol'],
  ),
];

const List<String> quickCategories = [
  'Kimlik',
  'Araç',
  'Ev',
  'Sağlık',
  'Belge',
  'Haklar',
];

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;

  late final List<Widget> pages = const [
    HomePage(),
    GuidePage(),
    DocumentBagPage(),
    ReminderPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        height: 74,
        onDestinationSelected: (value) {
          setState(() {
            index = value;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Ana Sayfa',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: 'Rehber',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder),
            label: 'Belgeler',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: 'Hatırlatıcı',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Ayarlar',
          ),
        ],
      ),
    );
  }
}

class FavoriteProceduresSection extends StatefulWidget {
  const FavoriteProceduresSection({super.key});

  @override
  State<FavoriteProceduresSection> createState() =>
      _FavoriteProceduresSectionState();
}

class _FavoriteProceduresSectionState extends State<FavoriteProceduresSection> {
  bool loading = true;
  List<Procedure> favorites = [];

  @override
  void initState() {
    super.initState();
    loadFavorites();
  }

  Future<void> loadFavorites() async {
    final titles = await LocalStore.loadFavorites();
    final items = procedures
        .where((item) => titles.contains(item.title))
        .take(4)
        .toList();

    if (!mounted) return;

    setState(() {
      favorites = items;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SizedBox.shrink();
    }

    if (favorites.isEmpty) {
      return const InfoBox(
        icon: Icons.star_border_outlined,
        title: 'Favori İşlemlerim',
        text:
            'Sık kullandığın işlemleri detay sayfasından favoriye ekleyebilirsin.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.star_rounded),
            SizedBox(width: 8),
            Text(
              'Favori İşlemlerim',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...favorites.map((item) => ProcedureCard(procedure: item)),
      ],
    );
  }
}

class FavoriteButton extends StatefulWidget {
  final Procedure procedure;

  const FavoriteButton({super.key, required this.procedure});

  @override
  State<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<FavoriteButton> {
  bool loading = true;
  bool favorite = false;

  @override
  void initState() {
    super.initState();
    loadFavorite();
  }

  Future<void> loadFavorite() async {
    final favorites = await LocalStore.loadFavorites();

    if (!mounted) return;

    setState(() {
      favorite = favorites.contains(widget.procedure.title);
      loading = false;
    });
  }

  Future<void> toggle() async {
    final result = await LocalStore.toggleFavorite(widget.procedure.title);

    if (!mounted) return;

    setState(() {
      favorite = result;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result ? 'Favorilere eklendi.' : 'Favorilerden çıkarıldı.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SizedBox.shrink();
    }

    return OutlinedButton.icon(
      onPressed: toggle,
      icon: Icon(favorite ? Icons.star_rounded : Icons.star_border_rounded),
      label: Text(favorite ? 'Favorilerden Çıkar' : 'Favorilere Ekle'),
    );
  }
}

const String kolayTrRecentProceduresKey = 'kolaytr_recent_procedure_titles_v1';

final ValueNotifier<List<String>> kolayTrRecentProcedureTitlesNotifier =
    ValueNotifier<List<String>>(<String>[]);

bool kolayTrRecentProcedureTitlesLoaded = false;

Future<void> kolayTrEnsureRecentProcedureTitlesLoaded() async {
  if (kolayTrRecentProcedureTitlesLoaded) return;

  final prefs = await SharedPreferences.getInstance();
  final titles = prefs.getStringList(kolayTrRecentProceduresKey) ?? <String>[];

  kolayTrRecentProcedureTitlesLoaded = true;
  kolayTrRecentProcedureTitlesNotifier.value = titles;
}

Future<void> kolayTrSaveRecentProcedure(Procedure procedure) async {
  final prefs = await SharedPreferences.getInstance();
  final current = prefs.getStringList(kolayTrRecentProceduresKey) ?? <String>[];

  final title = procedure.title.trim();
  if (title.isEmpty) return;

  final updated = <String>[
    title,
    ...current.where((item) => item.trim() != title),
  ].take(5).toList();

  await prefs.setStringList(kolayTrRecentProceduresKey, updated);
  kolayTrRecentProcedureTitlesLoaded = true;
  kolayTrRecentProcedureTitlesNotifier.value = updated;
}

IconData kolayTrHomeIconForCategory(String category) {
  switch (category) {
    case 'Kimlik':
      return Icons.badge_outlined;
    case 'Araç':
      return Icons.directions_car_outlined;
    case 'Ev':
      return Icons.home_work_outlined;
    case 'Sağlık':
      return Icons.local_hospital_outlined;
    case 'Belge':
      return Icons.description_outlined;
    case 'Haklar':
      return Icons.gavel_outlined;
    default:
      return Icons.apps_rounded;
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final popularTitles = <String>[
      'Kimlik Yenileme',
      'Pasaport Başvurusu',
      'Araç Muayene Tarihi',
      'Araç Muayene',
      'Hastane Tahlil Sonucu Görüntüleme',
      'Reçete Bilgisi Görüntüleme',
      'SGK Hizmet Dökümü',
      'Trafik Cezası',
      'Tapu Bilgileri Sorgulama',
      'Vergi Borcu',
      'Tüketici Hakem Heyeti Başvurusu',
      'Sosyal Yardım Başvurusu',
    ];

    final popularProcedures = [
      ...popularTitles.map((title) {
        final wanted = kolayTrNormalizeSearch(title);
        try {
          return procedures.firstWhere((item) {
            final itemTitle = kolayTrNormalizeSearch(item.title);
            return itemTitle.contains(wanted) || wanted.contains(itemTitle);
          });
        } catch (_) {
          return null;
        }
      }).whereType<Procedure>(),
      ...procedures,
    ];

    final uniquePopularProcedures = <Procedure>[];
    final seenPopularTitles = <String>{};

    for (final item in popularProcedures) {
      final key = kolayTrNormalizeSearch(item.title);
      if (seenPopularTitles.add(key)) {
        uniquePopularProcedures.add(item);
      }
      if (uniquePopularProcedures.length >= 8) break;
    }

    return PageWrap(
      children: [
        const Text(
          'KolayTR',
          style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
        ),
        Text(
          'Türkiye için pratik işlem rehberi',
          style: TextStyle(color: Colors.grey.shade700),
        ),
        const SizedBox(height: 16),
        const HeroBox(),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: StatCard(
                icon: Icons.list_alt_outlined,
                title: '${procedures.length}+',
                sub: 'İşlem rehberi',
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: StatCard(
                icon: Icons.security_outlined,
                title: 'Güvenli',
                sub: 'Cihaz içinde kayıt',
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        const LifeEventsHomeCard(),
        const SizedBox(height: 18),
        const UpcomingRemindersSection(),
        const SizedBox(height: 18),
        const FavoriteProceduresSection(),
        const SizedBox(height: 22),
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF3FF),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFDCE4FF)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFDDE6FF),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.verified_rounded,
                  color: Color(0xFF3158A4),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '220+ işlem rehberi aktif',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1F2330),
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Resmi kurumlara yönlendiren akıllı işlem rehberi.',
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF555A68),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Bugün ne yapmak istiyorsun?',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: quickCategories.map((category) {
            return QuickChip(category: category);
          }).toList(),
        ),
        const SizedBox(height: 22),
        FutureBuilder<void>(
          future: kolayTrEnsureRecentProcedureTitlesLoaded(),
          builder: (context, _) {
            return ValueListenableBuilder<List<String>>(
              valueListenable: kolayTrRecentProcedureTitlesNotifier,
              builder: (context, recentTitles, __) {
                final recentProcedures = <Procedure>[];

                for (final title in recentTitles) {
                  try {
                    final normalizedTitle = kolayTrNormalizeSearch(title);
                    final item = procedures.firstWhere(
                      (procedure) =>
                          kolayTrNormalizeSearch(procedure.title) ==
                          normalizedTitle,
                    );
                    recentProcedures.add(item);
                  } catch (_) {}
                }

                if (recentProcedures.isEmpty) {
                  return const SizedBox.shrink();
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Son Bakılan İşlemler',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1F2330),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...recentProcedures.map(
                      (item) => ProcedureCard(procedure: item),
                    ),
                    const SizedBox(height: 22),
                  ],
                );
              },
            );
          },
        ),
        const Text(
          'Kategori İşlem Sayıları',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1F2330),
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = (constraints.maxWidth - 12) / 2;

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <String>[
                'Kimlik',
                'Araç',
                'Ev',
                'Sağlık',
                'Belge',
                'Haklar',
              ].map((category) {
                final normalizedCategory = kolayTrNormalizeSearch(category);
                final count = procedures
                    .where(
                      (item) =>
                          kolayTrNormalizeSearch(item.category) ==
                          normalizedCategory,
                    )
                    .length;

                return SizedBox(
                  width: itemWidth,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GuidePage(initialCategory: category),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F7FB),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: const Color(0xFFE0E1E8)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE9EEFF),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              kolayTrHomeIconForCategory(category),
                              color: const Color(0xFF3158A4),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  category,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF1F2330),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$count işlem',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF666B78),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 28),
        const Text(
          'Popüler İşlemler',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        ...uniquePopularProcedures
            .take(8)
            .map((item) => ProcedureCard(procedure: item)),
        const InfoBox(
          icon: Icons.info_outline,
          title: 'Yasal Uyarı',
          text:
              'KolayTR resmi kurum değildir. Resmi kaynaklara yönlendiren yardımcı rehberdir.',
        ),
      ],
    );
  }
}

class UpcomingRemindersSection extends StatefulWidget {
  const UpcomingRemindersSection({super.key});

  @override
  State<UpcomingRemindersSection> createState() =>
      _UpcomingRemindersSectionState();
}

class _UpcomingRemindersSectionState extends State<UpcomingRemindersSection> {
  bool loading = true;
  List<SavedReminder> reminders = [];

  @override
  void initState() {
    super.initState();
    loadReminders();
  }

  Future<void> loadReminders() async {
    final all = await LocalStore.loadReminders();
    final now = DateTime.now().subtract(const Duration(minutes: 1));

    final next = all.where((item) => item.date.isAfter(now)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    if (!mounted) return;

    setState(() {
      reminders = next.take(3).toList();
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Yaklaşan hatırlatıcılar yükleniyor...'),
            ],
          ),
        ),
      );
    }

    if (reminders.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.notifications_none_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Yaklaşan Hatırlatıcılar',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Henüz yaklaşan hatırlatıcın yok. Önemli işleri unutmamak için hatırlatıcı ekleyebilirsin.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.notifications_active_outlined),
            SizedBox(width: 8),
            Text(
              'Yaklaşan Hatırlatıcılar',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...reminders.map(
          (item) => Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.schedule_outlined)),
              title: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text('${formatDate(item.date)} • ${item.category}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => AddReminderPage(existingReminder: item),
                  ),
                );

                if (result == true) {
                  await loadReminders();
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}

String kolayTrNormalizeSearch(String value) {
  var s = value
      .replaceAll('İ', 'i')
      .replaceAll('I', 'i')
      .replaceAll('ı', 'i')
      .replaceAll('Ğ', 'g')
      .replaceAll('ğ', 'g')
      .replaceAll('Ü', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('Ş', 's')
      .replaceAll('ş', 's')
      .replaceAll('Ö', 'o')
      .replaceAll('ö', 'o')
      .replaceAll('Ç', 'c')
      .replaceAll('ç', 'c')
      .toLowerCase();

  s = s.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  return s;
}

List<String> kolayTrSmartSearchTerms(String value) {
  final q = kolayTrNormalizeSearch(value);
  if (q.isEmpty) return [];

  final terms = <String>{q};
  terms.addAll(q.split(' ').where((word) => word.trim().length > 1));

  void addWhen(List<String> triggers, List<String> additions) {
    final hit = triggers.any((trigger) {
      final normalizedTrigger = kolayTrNormalizeSearch(trigger);
      return q.contains(normalizedTrigger);
    });

    if (hit) {
      terms.addAll(additions.map(kolayTrNormalizeSearch));
    }
  }

  addWhen(
    ['araba', 'oto', 'otomobil', 'arac', 'araç', 'tasit', 'taşıt'],
    [
      'araç',
      'arac',
      'plaka',
      'trafik',
      'ruhsat',
      'hgs',
      'ogs',
      'mtv',
      'muayene',
      'tuvturk',
      'tüvtürk',
      'sigorta',
      'noter',
      'ehliyet',
      'surucu',
      'sürücü',
    ],
  );

  addWhen(
    ['ev', 'konut', 'daire', 'tasinma', 'taşınma', 'kira', 'tapu'],
    [
      'ev',
      'konut',
      'tapu',
      'kira',
      'dask',
      'dogalgaz',
      'doğalgaz',
      'elektrik',
      'su',
      'fatura',
      'abonelik',
      'rayic',
      'rayiç',
      'imar',
      'iskan',
      'iskân',
      'aidat',
      'belediye',
      'yapi',
      'yapı',
    ],
  );

  addWhen(
    ['doktor', 'hastane', 'muayene', 'saglik', 'sağlık', 'ilac', 'ilaç'],
    [
      'saglik',
      'sağlık',
      'mhrs',
      'hastane',
      'doktor',
      'randevu',
      'e nabiz',
      'e-nabız',
      'enabiz',
      'tahlil',
      'recete',
      'reçete',
      'ilac',
      'ilaç',
      'asi',
      'aşı',
      'rapor',
      'dis',
      'diş',
      'goz',
      'göz',
    ],
  );

  addWhen(
    [
      'sgk',
      'emekli',
      'emeklilik',
      'issizlik',
      'işsizlik',
      'hak',
      'yardim',
      'yardım',
    ],
    [
      'sgk',
      'hak',
      'haklar',
      'sosyal',
      'yardim',
      'yardım',
      'emekli',
      'emeklilik',
      'issizlik',
      'işsizlik',
      'is goremezlik',
      'iş göremezlik',
      'rapor parasi',
      'rapor parası',
      'engelli',
      'gazi',
      'sehit',
      'şehit',
      'yaslilik',
      'yaşlılık',
      'tuketici',
      'tüketici',
    ],
  );

  addWhen(
    [
      'okul',
      'ogrenci',
      'öğrenci',
      'egitim',
      'eğitim',
      'sinav',
      'sınav',
      'universite',
      'üniversite',
    ],
    [
      'egitim',
      'eğitim',
      'okul',
      'ogrenci',
      'öğrenci',
      'meb',
      'osym',
      'ösym',
      'yok',
      'yök',
      'diploma',
      'denklik',
      'transkript',
      'sinav',
      'sınav',
      'kyk',
      'burs',
      'yurt',
      'staj',
    ],
  );

  addWhen(
    ['belge', 'evrak', 'dokuman', 'döküman', 'diploma', 'barkod'],
    [
      'belge',
      'evrak',
      'barkod',
      'dogrulama',
      'doğrulama',
      'diploma',
      'transkript',
      'denklik',
      'sicil',
      'vergi levhasi',
      'vergi levhası',
      'ustalik',
      'ustalık',
      'kalfalik',
      'kalfalık',
      'src',
      'kep',
      'e imza',
      'elektronik imza',
      'tebligat',
    ],
  );

  addWhen(
    ['kimlik', 'nufus', 'nüfus', 'pasaport', 'ehliyet'],
    [
      'kimlik',
      'nufus',
      'nüfus',
      'pasaport',
      'ehliyet',
      'surucu belgesi',
      'sürücü belgesi',
      'dogum',
      'doğum',
      'olum',
      'ölüm',
      'evlilik',
      'bosanma',
      'boşanma',
      'soyadi',
      'soyadı',
      'adres',
    ],
  );

  addWhen(
    ['vergi', 'borc', 'borç', 'fatura', 'odeme', 'ödeme'],
    [
      'vergi',
      'gib',
      'borc',
      'borç',
      'fatura',
      'odeme',
      'ödeme',
      'mtv',
      'harc',
      'harç',
      'beyan',
      'e tebligat',
      'levha',
    ],
  );

  return terms.where((term) => term.trim().length > 1).toList();
}

class GuidePage extends StatefulWidget {
  final String initialCategory;

  const GuidePage({super.key, this.initialCategory = 'Tümü'});

  @override
  State<GuidePage> createState() => _GuidePageState();
}

class _GuidePageState extends State<GuidePage> {
  String query = '';
  late String selectedCategory;

  @override
  void initState() {
    super.initState();
    selectedCategory = widget.initialCategory;
  }

  List<String> get categories {
    final list = procedures.map((e) => e.category).toSet().toList();
    list.sort();
    return ['Tümü', ...list];
  }

  List<Procedure> get filtered {
    final q = kolayTrNormalizeSearch(query);
    final smartTerms = kolayTrSmartSearchTerms(query);

    int scoreProcedure(Procedure item) {
      if (q.isEmpty) return 0;

      final title = kolayTrNormalizeSearch(item.title);
      final category = kolayTrNormalizeSearch(item.category);
      final searchableText = kolayTrNormalizeSearch(
        '${item.title} ${item.category}',
      );
      final titleWords =
          title.split(' ').where((word) => word.isNotEmpty).toList();

      // 1) Başlık yazılan harf/kelimeyle başlıyorsa en üstte
      // Örn: a -> Araç, Acil, Adalet
      // Örn: k -> Kimlik, Kira, Kayıp
      if (title.startsWith(q)) return 0;

      // 2) Başlıktaki herhangi bir kelime yazılan değerle başlıyorsa
      // Örn: mu -> Araç Muayene
      if (titleWords.any((word) => word.startsWith(q))) return 1;

      // 3) Kategori yazılan değerle başlıyorsa
      // Örn: sa -> Sağlık
      if (category.startsWith(q)) return 2;

      // 4) 2 harften sonra başlık/kategori içinde geçenleri de getir
      // Örn: hli -> Ehliyet
      if (q.length >= 2) {
        if (title.contains(q)) return 3;
        if (category.contains(q)) return 4;
      }

      // 5) 3 harften sonra akıllı eş anlamlı arama
      // Örn: araba -> araç / plaka / muayene
      // Örn: doktor -> sağlık / mhrs / hastane
      if (q.length >= 3) {
        final smartHit = smartTerms.any((term) {
          if (term.length < 3) return false;
          return searchableText.contains(term);
        });

        if (smartHit) return 5;
      }

      return 999;
    }

    final selected = kolayTrNormalizeSearch(selectedCategory);
    final isAllCategory = selectedCategory == 'Tüm' ||
        selectedCategory == 'Tümü' ||
        selected == 'tum' ||
        selected == 'tumu';

    final items = procedures.where((item) {
      final itemCategory = kolayTrNormalizeSearch(item.category);
      final matchesCategory = isAllCategory || selected == itemCategory;

      if (!matchesCategory) return false;
      if (q.isEmpty) return true;

      return scoreProcedure(item) < 999;
    }).toList();

    items.sort((a, b) {
      final scoreA = scoreProcedure(a);
      final scoreB = scoreProcedure(b);

      if (scoreA != scoreB) return scoreA.compareTo(scoreB);

      final titleA = kolayTrNormalizeSearch(a.title);
      final titleB = kolayTrNormalizeSearch(b.title);

      return titleA.compareTo(titleB);
    });

    return items;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Text(
                'İşlem Rehberi',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Ehliyet, kimlik, SGK, ikametgah...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    query = value;
                  });
                },
              ),
            ),
            SizedBox(
              height: 52,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final category = categories[index];

                  return ChoiceChip(
                    label: Text(category),
                    selected: selectedCategory == category,
                    onSelected: (_) {
                      setState(() {
                        selectedCategory = category;
                      });
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Text(
                '${filtered.length} sonuç bulundu',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('Sonuç bulunamadı.'))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        return ProcedureCard(procedure: filtered[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class DetailPage extends StatelessWidget {
  const DetailPage({super.key, required this.procedure});

  final Procedure procedure;

  @override
  Widget build(BuildContext context) {
    Future.microtask(() => kolayTrSaveRecentProcedure(procedure));

    final hasOfficialLink = procedure.link.trim().isNotEmpty;
    final documents = procedure.docs;
    final steps = procedure.steps;
    final warnings = procedure.warnings;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FB),
      appBar: AppBar(
        title: const Text(
          'İşlem Detayı',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          FavoriteButton(procedure: procedure),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFEEF3FF), Color(0xFFFFFFFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFFDDE5FF)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDDE6FF),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.verified_user_outlined,
                          color: Color(0xFF3158A4),
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          procedure.category,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF3158A4),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    procedure.title,
                    style: const TextStyle(
                      fontSize: 30,
                      height: 1.08,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1F2330),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    procedure.desc,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF555A68),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const _KolayTrOfficialWarningCard(),
            const SizedBox(height: 18),
            _KolayTrInfoCard(
              icon: Icons.account_balance_outlined,
              title: 'Nereden yapılır?',
              child: Text(
                procedure.place,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.45,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF343844),
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (documents.isNotEmpty)
              _KolayTrInfoCard(
                icon: Icons.folder_copy_outlined,
                title: 'Gerekli belgeler',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...documents.map(
                      (item) => _KolayTrDocumentCheckTile(text: item),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => AddDocumentPage()),
                        );
                      },
                      icon: const Icon(Icons.add_rounded),
                      label: const Text(
                        'Belge çantasına ekle',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        side: const BorderSide(
                          color: Color(0xFF3158A4),
                          width: 1.4,
                        ),
                        foregroundColor: const Color(0xFF3158A4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (documents.isNotEmpty) const SizedBox(height: 18),
            if (steps.isNotEmpty)
              _KolayTrInfoCard(
                icon: Icons.route_outlined,
                title: 'Adımlar',
                child: Column(
                  children: [
                    for (int i = 0; i < steps.length; i++)
                      _KolayTrStepTile(
                        number: i + 1,
                        text: steps[i],
                        isLast: i == steps.length - 1,
                      ),
                  ],
                ),
              ),
            if (steps.isNotEmpty) const SizedBox(height: 18),
            if (warnings.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7E5),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFFFE0A6)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Color(0xFFB26A00),
                          size: 26,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Dikkat edilmesi gerekenler',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF5A3A00),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...warnings.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '• ',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFB26A00),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                item,
                                style: const TextStyle(
                                  fontSize: 15,
                                  height: 1.45,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF5A3A00),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (warnings.isNotEmpty) const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 58,
              child: FilledButton.icon(
                onPressed: hasOfficialLink
                    ? () => openExternalUrl(context, procedure.link)
                    : null,
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text(
                  'Resmi siteye git',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'KolayTR yalnızca rehberlik ve yönlendirme sağlar. Resmi işlem, ücret, belge ve randevu bilgileri için her zaman ilgili kurumun resmi sitesini kontrol et.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: Color(0xFF737887),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KolayTrOfficialWarningCard extends StatelessWidget {
  const _KolayTrOfficialWarningCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFEFFBF4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFCFEFDB)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_outlined, color: Color(0xFF167A3D), size: 28),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'KolayTR resmi kurum değildir. İşlemleri daha kolay anlaman için resmi kurumlara yönlendiren yardımcı rehberdir.',
              style: TextStyle(
                fontSize: 15,
                height: 1.45,
                fontWeight: FontWeight.w700,
                color: Color(0xFF185C35),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KolayTrInfoCard extends StatelessWidget {
  const _KolayTrInfoCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE4E5EC)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F4FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: const Color(0xFF3158A4), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1F2330),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _KolayTrDocumentCheckTile extends StatelessWidget {
  const _KolayTrDocumentCheckTile({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDDE5FF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF3158A4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 19,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 15.5,
                height: 1.4,
                fontWeight: FontWeight.w700,
                color: Color(0xFF343844),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KolayTrStepTile extends StatelessWidget {
  const _KolayTrStepTile({
    required this.number,
    required this.text,
    required this.isLast,
  });

  final int number;
  final String text;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF3158A4),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '$number',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    color: const Color(0xFFDDE5FF),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 15.5,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF343844),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DocumentBagPage extends StatefulWidget {
  const DocumentBagPage({super.key});

  @override
  State<DocumentBagPage> createState() => _DocumentBagPageState();
}

class _DocumentBagPageState extends State<DocumentBagPage> {
  bool loading = true;
  List<SavedDocument> documents = [];

  @override
  void initState() {
    super.initState();
    loadDocuments();
  }

  Future<void> loadDocuments() async {
    final items = await LocalStore.loadDocuments();

    if (!mounted) return;

    setState(() {
      documents = items;
      loading = false;
    });
  }

  Future<void> deleteDocument(SavedDocument item) async {
    final confirmed = await confirmDeleteAction(
      context,
      title: 'Belge silinsin mi?',
      message: '"${item.title}" silinecek. Bu işlem geri alınamaz.',
    );

    if (!confirmed) return;

    final updated = documents.where((doc) => doc.id != item.id).toList();
    await LocalStore.saveDocuments(updated);

    if (!mounted) return;

    setState(() {
      documents = updated;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Belge silindi.')));
  }

  Future<void> openAddDocument() async {
    final result = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const AddDocumentPage()));

    if (result == true) {
      await loadDocuments();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sampleDocuments = const [
      SimpleTile(
        icon: Icons.description_outlined,
        title: 'Kimlik Fotokopisi',
        subtitle: 'Örnek belge kaydı',
      ),
      SimpleTile(
        icon: Icons.description_outlined,
        title: 'Kira Sözleşmesi',
        subtitle: 'Örnek belge kaydı',
      ),
      SimpleTile(
        icon: Icons.description_outlined,
        title: 'Araç Ruhsatı',
        subtitle: 'Örnek belge kaydı',
      ),
    ];

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: openAddDocument,
        icon: const Icon(Icons.add),
        label: const Text('Belge Ekle'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 92),
          children: [
            const Text(
              'Belge Çantası',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            const InfoBox(
              icon: Icons.security_outlined,
              title: 'Belge Çantası',
              text:
                  'Kimlik, ruhsat, kira sözleşmesi, fatura ve garanti belgelerini düzenli tutma alanı. Eklediğin kayıtlar cihazda saklanır ve buluta yedeklenir.',
            ),
            if (loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (documents.isEmpty) ...[
              const InfoBox(
                icon: Icons.add_circle_outline,
                title: 'Henüz belge eklenmedi',
                text:
                    'Belge Ekle butonuna basarak kendi belge kayıtlarını oluşturabilirsin.',
              ),
              ...sampleDocuments,
            ] else ...[
              Text(
                '${documents.length} belge kaydı',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 10),
              ...documents.map((item) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: Icon(iconForDocument(item.category)),
                    title: Text(
                      item.title,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: Text(
                      item.note.trim().isEmpty
                          ? '${item.category} • ${item.createdAt}'
                          : '${item.category} • ${item.note}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => deleteDocument(item),
                    ),
                    onTap: () async {
                      final result = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) =>
                              AddDocumentPage(existingDocument: item),
                        ),
                      );

                      if (result == true) {
                        await loadDocuments();
                      }
                    },
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

class AddDocumentPage extends StatefulWidget {
  final SavedDocument? existingDocument;

  const AddDocumentPage({super.key, this.existingDocument});

  @override
  State<AddDocumentPage> createState() => _AddDocumentPageState();
}

class _AddDocumentPageState extends State<AddDocumentPage> {
  final titleController = TextEditingController();
  final noteController = TextEditingController();

  String category = 'Kimlik';

  final categories = const [
    'Kimlik',
    'Araç',
    'Ev',
    'Sağlık',
    'Eğitim',
    'Haklar',
    'Fatura',
    'Diğer',
  ];

  @override
  void initState() {
    super.initState();

    final existing = widget.existingDocument;

    if (existing != null) {
      titleController.text = existing.title;
      noteController.text = existing.note;
      category =
          categories.contains(existing.category) ? existing.category : 'Diğer';
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    noteController.dispose();
    super.dispose();
  }

  Future<void> saveDocument() async {
    final title = titleController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Belge adı boş olamaz.')));
      return;
    }

    final documents = await LocalStore.loadDocuments();

    final existing = widget.existingDocument;
    final now = DateTime.now();

    final item = SavedDocument(
      id: existing?.id ?? now.microsecondsSinceEpoch.toString(),
      title: title,
      category: category,
      note: noteController.text.trim(),
      createdAt: existing?.createdAt ??
          '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}',
    );

    if (existing == null) {
      documents.insert(0, item);
    } else {
      final index = documents.indexWhere((doc) => doc.id == existing.id);

      if (index == -1) {
        documents.insert(0, item);
      } else {
        documents[index] = item;
      }
    }

    await LocalStore.saveDocuments(documents);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          existing == null ? 'Belge kaydedildi.' : 'Belge güncellendi.',
        ),
      ),
    );

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existingDocument == null ? 'Belge Ekle' : 'Belgeyi Düzenle',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            widget.existingDocument == null
                ? 'Yeni Belge Kaydı'
                : 'Belgeyi Düzenle',
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            'Bu sürümde belge dosyası değil, belge takip kaydı eklenir. Gerçek dosya/fotoğraf ekleme sonraki sürümde gelecek.',
            style: TextStyle(color: Colors.grey.shade700, height: 1.35),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: titleController,
            decoration: const InputDecoration(
              labelText: 'Belge adı',
              hintText: 'Örnek: Kira sözleşmesi',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: category,
            decoration: const InputDecoration(
              labelText: 'Kategori',
              border: OutlineInputBorder(),
            ),
            items: categories.map((item) {
              return DropdownMenuItem(value: item, child: Text(item));
            }).toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                category = value;
              });
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: noteController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Not',
              hintText: 'Örnek: Ev klasöründe, 2026 yenilenecek',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: saveDocument,
            icon: const Icon(Icons.save_outlined),
            label: Text(
              widget.existingDocument == null ? 'Kaydet' : 'Güncelle',
            ),
          ),
        ],
      ),
    );
  }
}

class ReminderPage extends StatefulWidget {
  const ReminderPage({super.key});

  @override
  State<ReminderPage> createState() => _ReminderPageState();
}

class _ReminderPageState extends State<ReminderPage> {
  bool loading = true;
  List<SavedReminder> reminders = [];

  @override
  void initState() {
    super.initState();
    loadReminders();
  }

  Future<void> loadReminders() async {
    final items = await LocalStore.loadReminders();

    if (!mounted) return;

    setState(() {
      reminders = items;
      loading = false;
    });
  }

  Future<void> deleteReminder(SavedReminder item) async {
    final confirmed = await confirmDeleteAction(
      context,
      title: 'Hatırlatıcı silinsin mi?',
      message: '"${item.title}" silinecek ve bildirimi iptal edilecek.',
    );

    if (!confirmed) return;

    final updated =
        reminders.where((reminder) => reminder.id != item.id).toList();
    await LocalStore.saveReminders(updated);
    await NotificationService.cancelReminder(item);

    if (!mounted) return;

    setState(() {
      reminders = updated;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Hatırlatıcı silindi.')));
  }

  Future<void> openAddReminder() async {
    final result = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const AddReminderPage()));

    if (result == true) {
      await loadReminders();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sampleReminders = const [
      SimpleTile(
        icon: Icons.directions_car_outlined,
        title: 'Araç Muayene Tarihi',
        subtitle: 'Tarih eklenmedi',
      ),
      SimpleTile(
        icon: Icons.flight_takeoff_outlined,
        title: 'Pasaport Süresi',
        subtitle: 'Tarih eklenmedi',
      ),
      SimpleTile(
        icon: Icons.home_work_outlined,
        title: 'Kira Yenileme',
        subtitle: 'Tarih eklenmedi',
      ),
    ];

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: openAddReminder,
        icon: const Icon(Icons.add_alert_outlined),
        label: const Text('Ekle'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 92),
          children: [
            const Text(
              'Hatırlatıcılar',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            const InfoBox(
              icon: Icons.notifications_outlined,
              title: 'Hatırlatıcılar',
              text:
                  'Araç muayenesi, pasaport süresi, sigorta, kira ve önemli tarihleri takip etmek için tarih kaydı oluşturabilirsin.',
            ),
            if (loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (reminders.isEmpty) ...[
              const InfoBox(
                icon: Icons.add_alert_outlined,
                title: 'Henüz hatırlatıcı yok',
                text:
                    'Ekle butonuna basarak tarihli hatırlatıcı kaydı oluşturabilirsin.',
              ),
              ...sampleReminders,
            ] else ...[
              Text(
                '${reminders.length} hatırlatıcı',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 10),
              ...reminders.map((item) {
                final isPast = item.date.isBefore(
                  DateTime.now().subtract(const Duration(days: 1)),
                );

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: Icon(
                      iconForReminder(item.category),
                      color: isPast ? Colors.red.shade700 : null,
                    ),
                    title: Text(
                      item.title,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: Text(
                      item.note.trim().isEmpty
                          ? '${item.category} • ${formatDate(item.date)}'
                          : '${item.category} • ${formatDate(item.date)} • ${item.note}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => deleteReminder(item),
                    ),
                    onTap: () async {
                      final result = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) =>
                              AddReminderPage(existingReminder: item),
                        ),
                      );

                      if (result == true) {
                        await loadReminders();
                      }
                    },
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

class AddReminderPage extends StatefulWidget {
  final String? initialTitle;
  final String? initialCategory;
  final SavedReminder? existingReminder;

  const AddReminderPage({
    super.key,
    this.initialTitle,
    this.initialCategory,
    this.existingReminder,
  });

  @override
  State<AddReminderPage> createState() => _AddReminderPageState();
}

class _AddReminderPageState extends State<AddReminderPage> {
  late final TextEditingController titleController;
  final noteController = TextEditingController();

  late String category;
  DateTime? selectedDate;
  TimeOfDay? selectedTime;

  final categories = const [
    'Araç',
    'Seyahat',
    'Ev',
    'Sağlık',
    'Kimlik',
    'Fatura',
    'Diğer',
  ];

  @override
  void initState() {
    super.initState();

    final existing = widget.existingReminder;

    titleController = TextEditingController(
      text: existing?.title ?? widget.initialTitle ?? '',
    );

    noteController.text = existing?.note ?? '';

    category = existing?.category ?? widget.initialCategory ?? 'Araç';

    if (!categories.contains(category)) {
      category = 'Diğer';
    }

    if (existing != null) {
      selectedDate = DateTime(
        existing.date.year,
        existing.date.month,
        existing.date.day,
      );
      selectedTime = TimeOfDay.fromDateTime(existing.date);
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    noteController.dispose();
    super.dispose();
  }

  Future<void> pickDate() async {
    final now = DateTime.now();

    final result = await showDatePicker(
      context: context,
      locale: const Locale('tr', 'TR'),
      helpText: 'Tarih seç',
      cancelText: 'İptal',
      confirmText: 'Tamam',
      initialDate: selectedDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 15),
    );

    if (result == null) return;

    setState(() {
      selectedDate = result;
    });
  }

  Future<void> pickTime() async {
    final result = await showTimePicker(
      context: context,
      helpText: 'Saat seç',
      cancelText: 'İptal',
      confirmText: 'Tamam',
      initialTime: selectedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (result == null) return;

    setState(() {
      selectedTime = result;
    });
  }

  Future<void> saveReminder() async {
    final title = titleController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hatırlatıcı adı boş olamaz.')),
      );
      return;
    }

    if (selectedDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Lütfen tarih seç.')));
      return;
    }

    if (selectedTime == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Lütfen saat seç.')));
      return;
    }

    final scheduledAt = DateTime(
      selectedDate!.year,
      selectedDate!.month,
      selectedDate!.day,
      selectedTime!.hour,
      selectedTime!.minute,
    );

    if (scheduledAt.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geçmiş tarih veya saat seçilemez.')),
      );
      return;
    }

    final reminders = await LocalStore.loadReminders();
    final now = DateTime.now();
    final existing = widget.existingReminder;

    final item = SavedReminder(
      id: existing?.id ?? now.microsecondsSinceEpoch.toString(),
      title: title,
      category: category,
      note: noteController.text.trim(),
      date: scheduledAt,
    );

    if (existing == null) {
      reminders.add(item);
    } else {
      await NotificationService.cancelReminder(existing);

      final index = reminders.indexWhere(
        (reminder) => reminder.id == existing.id,
      );

      if (index == -1) {
        reminders.add(item);
      } else {
        reminders[index] = item;
      }
    }

    reminders.sort((a, b) => a.date.compareTo(b.date));

    await LocalStore.saveReminders(reminders);
    await NotificationService.scheduleReminder(item);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          existing == null
              ? 'Hatırlatıcı kaydedildi.'
              : 'Hatırlatıcı güncellendi.',
        ),
      ),
    );

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existingReminder == null
              ? 'Hatırlatıcı Ekle'
              : 'Hatırlatıcıyı Düzenle',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            widget.existingReminder == null
                ? 'Yeni Hatırlatıcı'
                : 'Hatırlatıcıyı Düzenle',
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            'Bildirim izni yalnızca Kaydet’e bastığında istenir. İzin verirsen seçtiğin tarih ve saatte telefon bildirimi planlanır.',
            style: TextStyle(color: Colors.grey.shade700, height: 1.35),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: titleController,
            decoration: const InputDecoration(
              labelText: 'Hatırlatıcı adı',
              hintText: 'Örnek: Araç muayenesi',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: category,
            decoration: const InputDecoration(
              labelText: 'Kategori',
              border: OutlineInputBorder(),
            ),
            items: categories.map((item) {
              return DropdownMenuItem(value: item, child: Text(item));
            }).toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                category = value;
              });
            },
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: pickDate,
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text(
              selectedDate == null
                  ? 'Tarih Seç'
                  : 'Seçilen Tarih: ${formatOnlyDate(selectedDate!)}',
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: pickTime,
            icon: const Icon(Icons.schedule_outlined),
            label: Text(
              selectedTime == null
                  ? 'Saat Seç'
                  : 'Seçilen Saat: ${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: noteController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Not',
              hintText: 'Örnek: Evrakları 1 hafta önce hazırla',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: saveReminder,
            icon: const Icon(Icons.save_outlined),
            label: Text(
              widget.existingReminder == null ? 'Kaydet' : 'Güncelle',
            ),
          ),
        ],
      ),
    );
  }
}

String formatOnlyDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
}

String formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');

  return '$day.$month.${date.year} $hour:$minute';
}

IconData iconForDocument(String category) {
  switch (category) {
    case 'Kimlik':
      return Icons.badge_outlined;
    case 'Araç':
      return Icons.directions_car_outlined;
    case 'Ev':
      return Icons.home_work_outlined;
    case 'Sağlık':
      return Icons.health_and_safety_outlined;
    case 'Eğitim':
      return Icons.school_outlined;
    case 'Haklar':
      return Icons.gavel_outlined;
    case 'Fatura':
      return Icons.receipt_long_outlined;
    default:
      return Icons.description_outlined;
  }
}

IconData iconForReminder(String category) {
  switch (category) {
    case 'Araç':
      return Icons.directions_car_outlined;
    case 'Seyahat':
      return Icons.flight_takeoff_outlined;
    case 'Ev':
      return Icons.home_work_outlined;
    case 'Sağlık':
      return Icons.health_and_safety_outlined;
    case 'Kimlik':
      return Icons.badge_outlined;
    case 'Fatura':
      return Icons.receipt_long_outlined;
    default:
      return Icons.notifications_outlined;
  }
}

Future<bool> confirmDeleteAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmText = 'Sil',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmText),
          ),
        ],
      );
    },
  );

  return result ?? false;
}

Future<void> openExternalUrl(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);

  if (uri == null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Link açılamadı.')));
    return;
  }

  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

  if (!opened && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Resmi site açılamadı.')));
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PageWrap(
      children: [
        const Text(
          'Ayarlar',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 16),
        const SimpleTile(
          icon: Icons.apps,
          title: 'KolayTR',
          subtitle: 'Belgeler v2.6.5',
        ),
        const Divider(),
        SimpleTile(
          icon: Icons.menu_book_outlined,
          title: 'Rehber Kaynağı',
          subtitle: CloudGuideService.statusText,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(CloudGuideService.statusText)),
            );
          },
        ),
        SimpleTile(
          icon: Icons.cloud_done_outlined,
          title: 'Bulut Bağlantısı',
          subtitle: CloudService.statusText,
          onTap: () async {
            final result = await CloudService.testConnection();

            if (!context.mounted) return;

            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(result)));
          },
        ),
        SimpleTile(
          icon: Icons.notifications_active_outlined,
          title: 'Test Bildirimi Gönder',
          subtitle: 'Bildirim sistemi çalışıyor mu kontrol et.',
          onTap: () async {
            await NotificationService.showTestNotification();

            if (!context.mounted) return;

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Test bildirimi gönderildi.')),
            );
          },
        ),
        SimpleTile(
          icon: Icons.info_outline,
          title: 'Hakkında',
          subtitle: 'KolayTR ne işe yarar?',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const TextPage(
                  title: 'Hakkında',
                  text:
                      'KolayTR, Türkiye’de yaşayan kullanıcıların günlük resmi işlemlerini daha kolay anlamasına yardımcı olmak için tasarlanmış bir rehber uygulamasıdır. Kimlik, ehliyet, pasaport, araç, SGK, sağlık, eğitim, ev ve tüketici hakları gibi konularda gerekli belgeleri, adımları ve resmi yönlendirmeleri sade şekilde gösterir.',
                ),
              ),
            );
          },
        ),
        SimpleTile(
          icon: Icons.gavel_outlined,
          title: 'Yasal Uyarı',
          subtitle: 'Resmi kurum değildir açıklaması.',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const TextPage(
                  title: 'Yasal Uyarı',
                  text:
                      'KolayTR resmi kurum, devlet kurumu veya kamu hizmeti sağlayıcısı değildir. Uygulama yalnızca bilgilendirme ve yönlendirme amacı taşır. İşlem ücretleri, belge şartları, süreler ve başvuru kuralları zamanla değişebilir. Kullanıcılar işlem yapmadan önce mutlaka resmi kurum kaynaklarını kontrol etmelidir.',
                ),
              ),
            );
          },
        ),
        SimpleTile(
          icon: Icons.privacy_tip_outlined,
          title: 'Gizlilik Politikası',
          subtitle: 'Veri kullanımı ve güvenlik açıklaması.',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const TextPage(
                  title: 'Gizlilik Politikası',
                  text:
                      'KolayTR MVP 1.3 sürümünde belge ve hatırlatıcı kayıtları cihaz içinde saklanır. Kullanıcı hesabı, kimlik bilgisi veya gerçek belge dosyası sunucuya gönderilmez. Veriler uygulama kaldırıldığında cihazdan silinebilir.',
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class PageWrap extends StatelessWidget {
  final List<Widget> children;

  const PageWrap({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: children,
        ),
      ),
    );
  }
}

class HeroBox extends StatelessWidget {
  const HeroBox({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF0F766E)],
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_user_outlined, color: Colors.white, size: 42),
          SizedBox(height: 16),
          Text(
            'İşini kolayca çöz.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Resmi işlemler, belgeler, hatırlatıcılar ve günlük hayat rehberi tek yerde.',
            style: TextStyle(color: Colors.white, fontSize: 16, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class QuickChip extends StatelessWidget {
  final String category;

  const QuickChip({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(iconFor(category), size: 20),
      label: Text(category),
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => GuidePage(initialCategory: category),
          ),
        );
      },
    );
  }
}

class ProcedureCard extends StatelessWidget {
  final Procedure procedure;

  const ProcedureCard({super.key, required this.procedure});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFE8ECFF),
          child: Icon(
            iconFor(procedure.category),
            color: const Color(0xFF1E3A8A),
          ),
        ),
        title: Text(
          procedure.title,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(procedure.desc),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => DetailPage(procedure: procedure)),
          );
        },
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;

  const StatCard({
    super.key,
    required this.icon,
    required this.title,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
            ),
            Text(sub),
          ],
        ),
      ),
    );
  }
}

class InfoBox extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const InfoBox({
    super.key,
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEDEFFF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(text, style: const TextStyle(height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SectionBox extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<String> items;

  const SectionBox({
    super.key,
    required this.title,
    required this.icon,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...items.asMap().entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 12,
                      child: Text(
                        '${entry.key + 1}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(entry.value)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class SimpleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const SimpleTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: onTap == null ? null : const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class TextPage extends StatelessWidget {
  final String title;
  final String text;

  const TextPage({super.key, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          Text(text, style: const TextStyle(fontSize: 16, height: 1.5)),
        ],
      ),
    );
  }
}

IconData iconFor(String category) {
  switch (category) {
    case 'Kimlik':
      return Icons.badge_outlined;
    case 'Araç':
      return Icons.directions_car_outlined;
    case 'Seyahat':
      return Icons.flight_takeoff_outlined;
    case 'SGK':
      return Icons.health_and_safety_outlined;
    case 'Belge':
      return Icons.description_outlined;
    case 'Haklar':
      return Icons.gavel_outlined;
    case 'Eğitim':
      return Icons.school_outlined;
    case 'Sağlık':
      return Icons.local_hospital_outlined;
    case 'Ev':
      return Icons.home_work_outlined;
    default:
      return Icons.check_circle_outline;
  }
}
