import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_provider.dart';
import 'ui/home_screen.dart';

class ReechyMonitorApp extends StatelessWidget {
  const ReechyMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: MaterialApp(
        title: 'Reachy Monitor',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF0D1117),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF58A6FF),
            secondary: Color(0xFF3FB950),
            surface: Color(0xFF161B22),
            error: Color(0xFFF85149),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF161B22),
            foregroundColor: Color(0xFFE6EDF3),
            elevation: 0,
          ),
          cardTheme: CardThemeData(
            color: const Color(0xFF161B22),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(
                color: Color(0xFF30363D),
                width: 1,
              ),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF58A6FF),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          textTheme: const TextTheme(
            bodyLarge: TextStyle(color: Color(0xFFE6EDF3)),
            bodyMedium: TextStyle(color: Color(0xFFE6EDF3)),
            bodySmall: TextStyle(color: Color(0xFF8B949E)),
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
