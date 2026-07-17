// ============================================================
// main.dart  –  JavisAudit Entry Point
// ============================================================
// This is the very first file Flutter runs when the app starts.
// It initialises all required services (Hive, notifications,
// database) and then hands control to the MyApp widget.
// ============================================================

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Our own files — explained in each file's header comment
import 'database/database_helper.dart';
import 'providers/income_provider.dart';
import 'providers/expense_provider.dart';
import 'providers/sales_provider.dart';
import 'providers/vat_provider.dart';
import 'providers/profile_provider.dart';
import 'screens/splash_screen.dart';

// ── Global notification plugin instance ─────────────────────
// We create it here (globally) so it can be accessed from
// anywhere in the app — especially from within providers.
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// ── main() ──────────────────────────────────────────────────
// The async main function runs before any widgets are shown.
// We use it to set up the database and notification system.
Future<void> main() async {
  // WidgetsFlutterBinding.ensureInitialized() must be called
  // before any async work that uses Flutter's native channels
  // (like Hive, notifications, file system, etc.)
  WidgetsFlutterBinding.ensureInitialized();

  // ── Step 1: Initialise Hive ─────────────────────────────
  // Hive is a fast key-value store. We use it to:
  //   • Remember notification flags (notif_sent_70, etc.)
  //   • Cache the current year so we can reset flags on Jan 1
  // initFlutter() finds the correct directory on the device
  await Hive.initFlutter();

  // Open the 'settings' box — this is like a small dictionary
  // that persists between app launches
  await Hive.openBox('settings');

  // ── Step 2: Initialise the SQLite database ──────────────
  // This call creates the javisaudit.db file and all five
  // tables if they don't already exist (CREATE TABLE IF NOT EXISTS)
  await DatabaseHelper.instance.database;

  // ── Step 3: Set up local notifications ─────────────────
  // Android settings: the icon shown in the notification bar
  // '@mipmap/ic_launcher' is the default Flutter app icon
  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initSettings =
      InitializationSettings(android: androidSettings);

  // initialise() registers the app with the Android notification system
  await flutterLocalNotificationsPlugin.initialize(initSettings);

  // ── Step 4: Reset notification flags on a new year ─────
  // If the device is in a new calendar year, reset the flags
  // so threshold alerts can fire again (e.g., every Jan 1)
  _resetNotificationFlagsIfNewYear();

  // ── Step 5: Run the Flutter app ─────────────────────────
  // MultiProvider wraps the entire app so any widget can
  // listen to data changes via Provider.of<T>(context)
  runApp(
    MultiProvider(
      providers: [
        // ProfileProvider: manages business profile data
        ChangeNotifierProvider(create: (_) => ProfileProvider()),

        // IncomeProvider: manages all income records
        ChangeNotifierProvider(create: (_) => IncomeProvider()),

        // ExpenseProvider: manages all expense records
        ChangeNotifierProvider(create: (_) => ExpenseProvider()),

        // SalesProvider: manages all sales records
        ChangeNotifierProvider(create: (_) => SalesProvider()),

        // VatProvider: calculates annual turnover and fires
        // VAT threshold notifications
        ChangeNotifierProvider(create: (_) => VatProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

// ── Reset notification flags if it's a new year ─────────────
// Each threshold notification (70%, 90%, 100%) should only fire
// once per calendar year. We store the "last notified year" in
// Hive and reset all flags when the year changes.
void _resetNotificationFlagsIfNewYear() {
  final box = Hive.box('settings');
  final int currentYear = DateTime.now().year;

  // Read the year when we last checked — default 0 if never set
  final int lastCheckedYear = box.get('last_notif_year', defaultValue: 0);

  // If we're in a new year, clear all the "already sent" flags
  if (currentYear != lastCheckedYear) {
    box.put('notif_sent_70', false);
    box.put('notif_sent_90', false);
    box.put('notif_sent_100', false);
    box.put('last_notif_year', currentYear); // Remember this year
  }
}

// ── MyApp Widget ─────────────────────────────────────────────
// This is the root widget of the entire app.
// It defines the app's theme, name, and starting screen.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Name shown in the Android recent apps switcher
      title: 'JavisAudit',

      // debugShowCheckedModeBanner: false removes the red "Debug"
      // banner from the top-right corner during development
      debugShowCheckedModeBanner: false,

      // ── App Theme ──────────────────────────────────────
      // We define colours once here so the whole app is consistent.
      // GRA-inspired deep green is our primary brand colour.
      theme: ThemeData(
        useMaterial3: true,

        // Color scheme built from a seed colour
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F4C2A), // Deep GRA green
          brightness: Brightness.light,
        ),

        // AppBar style: green background, white text
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F4C2A),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),

        // Elevated button style: gold/amber colour
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A7A4A),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          ),
        ),

        // Input field decoration: rounded borders
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(
              color: Color(0xFF1A7A4A),
              width: 2,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
        ),
      ),

      // The app always starts at the SplashScreen, which then
      // decides whether to go to Onboarding or Dashboard
      home: const SplashScreen(),
    );
  }
}
