import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const TavanYarApp());
}

class TavanYarApp extends StatelessWidget {
  const TavanYarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TavanYar P1',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Tahoma',
        useMaterial3: true,
      ),
      home: const MainScreen(),
      locale: const Locale('fa', 'IR'),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // آدرس دستگاه ESP8266 بعد از اتصال به وای‌فای TavanYar_P1
  static const String baseUrl = 'http://192.168.4.1';

  String titleText = 'نام سرویس درخواستی';
  String statusText = 'در حال بررسی ارتباط...';
  bool isConnected = false;
  bool isSettingsPage = false;
  bool isSending = false;

  final AudioPlayer _audioPlayer = AudioPlayer();
  Timer? _statusTimer;

  // ========== اندازه‌های دقیق طبق طراحی ==========
  // صفحه مرجع: ۷۲۰ × ۱۲۸۰ پیکسل
  // آیکون‌های اصلی: ۲۵۸ × ۲۵۸
  // آیکون زنگ: ۱۸۹ × ۱۸۹
  // آیکون تنظیمات: ۸۰ × ۸۰
  static const double designWidth = 720.0;
  static const double designHeight = 1280.0;
  static const double iconSize = 258.0;
  static const double bellSize = 189.0;
  static const double settingsSize = 80.0;

  @override
  void initState() {
    super.initState();
    _checkConnection();
    _statusTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _checkConnection();
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _checkConnection() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/status'))
          .timeout(const Duration(seconds: 2));
      if (response.statusCode == 200) {
        if (!isConnected) {
          setState(() {
            isConnected = true;
            statusText = 'ارتباط شما با دستگاه مرکزی برقرار است';
          });
        }
      } else {
        _setDisconnected();
      }
    } catch (_) {
      _setDisconnected();
    }
  }

  void _setDisconnected() {
    if (isConnected ||
        statusText !=
            'ارتباط قطع است – به وای‌فای TavanYar_P1 وصل شوید') {
      setState(() {
        isConnected = false;
        statusText = 'ارتباط قطع است – به وای‌فای TavanYar_P1 وصل شوید';
      });
    }
  }

  Future<void> _sendCommand(String cmd, String displayName) async {
    if (isSending) return;

    setState(() {
      isSending = true;
      titleText = displayName;
    });

    HapticFeedback.mediumImpact();

    try {
      final response = await http
          .get(Uri.parse('$baseUrl/cmd?c=$cmd'))
          .timeout(const Duration(seconds: 3));

      if (response.statusCode != 200) {
        _showSnack('خطا در ارسال فرمان');
      }
    } catch (e) {
      _showSnack('دستگاه در دسترس نیست');
      _setDisconnected();
    } finally {
      setState(() => isSending = false);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() => titleText = 'نام سرویس درخواستی');
        }
      });
    }
  }

  Future<void> _onAlarmPressed() async {
    setState(() => titleText = 'زنگ خطر');
    HapticFeedback.heavyImpact();

    // پخش صدای آژیر در صورت وجود فایل
    try {
      await _audioPlayer.play(AssetSource('siren.mp3'));
    } catch (_) {
      // فایل صدا موجود نباشد → فقط ویبره
    }

    await _sendCommand('alarm', 'زنگ خطر');

    Future.delayed(const Duration(seconds: 2), () {
      _audioPlayer.stop();
    });
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, textAlign: TextAlign.center),
        backgroundColor: Colors.red.shade800,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _toggleSettings() {
    setState(() {
      isSettingsPage = !isSettingsPage;
      if (!isSettingsPage) {
        titleText = 'نام سرویس درخواستی';
      } else {
        titleText = 'تنظیمات';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // مقیاس بر اساس عرض ۷۲۰ (طراحی اصلی صفحه)
    final scale = size.width / designWidth;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: isSettingsPage
            ? _buildSettingsPage(scale)
            : _buildMainPage(scale),
      ),
    );
  }

  Widget _buildMainPage(double scale) {
    final iconS = iconSize * scale;
    final bellS = bellSize * scale;
    final settingsS = settingsSize * scale;

    return Column(
      children: [
        // ========== کادر آبی بالا (طبق مشخصات: حاشیه ۴۰px، ارتفاع حدود ۱۰۰px) ==========
        Container(
          width: double.infinity,
          margin: EdgeInsets.fromLTRB(40 * scale, 20 * scale, 40 * scale, 0),
          height: 100 * scale,
          padding: EdgeInsets.symmetric(
            vertical: 12 * scale,
            horizontal: 16 * scale,
          ),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(12 * scale),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.4),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                titleText,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22 * scale,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 6 * scale),
              Text(
                statusText,
                style: TextStyle(
                  color: isConnected
                      ? const Color(0xFFB3E5FC)
                      : Colors.orangeAccent,
                  fontSize: 13 * scale,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),

        SizedBox(height: 20 * scale),

        // ========== ردیف زنگ خطر (۱۸۹×۱۸۹) و تنظیمات (۸۰×۸۰) ==========
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 40 * scale),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // دکمه زنگ خطر – اندازه دقیق ۱۸۹×۱۸۹
              GestureDetector(
                onTap: isSending ? null : _onAlarmPressed,
                child: Image.asset(
                  'assets/icons/icon_bell.png',
                  width: bellS,
                  height: bellS,
                  fit: BoxFit.contain,
                ),
              ),
              // دکمه تنظیمات – اندازه دقیق ۸۰×۸۰ از طرح
              GestureDetector(
                onTap: _toggleSettings,
                child: Image.asset(
                  'assets/icons/icon_settings.png',
                  width: settingsS,
                  height: settingsS,
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 16 * scale),

        // ========== دکمه‌های آبی (باز / بسته) – ۲۵۸×۲۵۸ ==========
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 36 * scale),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _IconButton(
                asset: 'assets/icons/icon_open.png',
                size: iconS,
                onTap: isSending
                    ? null
                    : () => _sendCommand('open', 'باز شدن درب آسانسور'),
              ),
              _IconButton(
                asset: 'assets/icons/icon_close.png',
                size: iconS,
                onTap: isSending
                    ? null
                    : () => _sendCommand('close', 'بسته شدن درب آسانسور'),
              ),
            ],
          ),
        ),

        SizedBox(height: 12 * scale),

        // ========== دکمه‌های سبز (بالا / پایین) – ۲۵۸×۲۵۸ ==========
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 36 * scale),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _IconButton(
                asset: 'assets/icons/icon_up.png',
                size: iconS,
                onTap: isSending
                    ? null
                    : () => _sendCommand('up', 'حرکت به سمت بالا'),
              ),
              _IconButton(
                asset: 'assets/icons/icon_down.png',
                size: iconS,
                onTap: isSending
                    ? null
                    : () => _sendCommand('down', 'حرکت به سمت پایین'),
              ),
            ],
          ),
        ),

        SizedBox(height: 12 * scale),

        // ========== دکمه درخواست سرویس (قرمز) – ۲۵۸×۲۵۸ ==========
        Center(
          child: _IconButton(
            asset: 'assets/icons/icon_service.png',
            size: iconS,
            onTap: isSending
                ? null
                : () => _sendCommand('service', 'درخواست سرویس'),
          ),
        ),

        const Spacer(),

        // ========== نام پروژه ==========
        Padding(
          padding: EdgeInsets.only(bottom: 16 * scale),
          child: Text(
            'TavanYar P1',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 16 * scale,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsPage(double scale) {
    final settingsS = settingsSize * scale;

    return Column(
      children: [
        // کادر آبی بالا
        Container(
          width: double.infinity,
          margin: EdgeInsets.fromLTRB(40 * scale, 20 * scale, 40 * scale, 0),
          height: 100 * scale,
          padding: EdgeInsets.symmetric(
            vertical: 12 * scale,
            horizontal: 16 * scale,
          ),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(12 * scale),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'تنظیمات',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22 * scale,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 6 * scale),
              Text(
                statusText,
                style: TextStyle(
                  color: isConnected
                      ? const Color(0xFFB3E5FC)
                      : Colors.orangeAccent,
                  fontSize: 13 * scale,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 28 * scale),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 28 * scale),
          child: Column(
            children: [
              _infoCard('نام دستگاه', 'TavanYar P1', scale),
              _infoCard('آدرس IP', '192.168.4.1', scale),
              _infoCard('SSID', 'TavanYar_P1 (مخفی)', scale),
              _infoCard('رمز عبور', 'TavanYar2024', scale),
              SizedBox(height: 20 * scale),
              Text(
                'برای اتصال:\n'
                '۱. وای‌فای موبایل را باز کنید\n'
                '۲. به شبکه TavanYar_P1 وصل شوید\n'
                '۳. رمز: TavanYar2024\n'
                '۴. به این برنامه برگردید',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14 * scale,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        // دکمه بازگشت با آیکون تنظیمات
        Padding(
          padding: EdgeInsets.only(bottom: 24 * scale),
          child: GestureDetector(
            onTap: _toggleSettings,
            child: Column(
              children: [
                Image.asset(
                  'assets/icons/icon_settings.png',
                  width: settingsS,
                  height: settingsS,
                  fit: BoxFit.contain,
                ),
                SizedBox(height: 8 * scale),
                Text(
                  'بازگشت به صفحه اصلی',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14 * scale,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoCard(String label, String value, double scale) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 10 * scale),
      padding: EdgeInsets.symmetric(
        vertical: 12 * scale,
        horizontal: 16 * scale,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(10 * scale),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white60,
              fontSize: 14 * scale,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14 * scale,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final String asset;
  final double size;
  final VoidCallback? onTap;

  const _IconButton({
    required this.asset,
    required this.size,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1.0,
        child: Image.asset(
          asset,
          width: size,
          height: size,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
