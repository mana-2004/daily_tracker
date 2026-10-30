import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DailyTrackerApp());
}

// ============================================================================
// 1. CORE LAYER: الثوابت اللغوية، الأدوات المساعدة، ونظام التصميم (Design System)
// ============================================================================

/// النصوص والثوابت اللغوية المدققة إملائياً ونحوياً
abstract final class AppStrings {
  static const String appTitle = 'رفيق الورد اليومي ولوحة الإنجاز الشهري';

  // التبويبات
  static const String dailyTab = 'وِرد اليوم';
  static const String monthlyTab = 'إحصائيات الشهر';

  // الآية القرآنية والترويسة
  static const String quranVerse =
      '﴿ وَاتَّقُوا يَوْمًا تُرْجَعُونَ فِيهِ إِلَى اللَّهِ ثُمَّ تُوَفَّىٰ كُلُّ نَفْسٍ مَّا كَسَبَتْ وَهُمْ لَا يُظْلَمُونَ ﴾';
  static const String quranReference = 'سورة البقرة · الآية ٢٨١';

  // أيام الأسبوع (يبدأ الأسبوع يوم السبت)
  static const List<String> weekDaysFull = [
    'السبت',
    'الأحد',
    'الإثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
  ];

  // اختصارات ذكية للهواتف ذات الشاشات الصغيرة جداً لمنع التداخل
  static const List<String> weekDaysCompact = [
    'سبت',
    'أحد',
    'إثنين',
    'ثلاثاء',
    'أربعاء',
    'خميس',
    'جمعة',
  ];

  static const List<String> monthsAr = [
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];

  static const List<Map<String, String>> hadithCollection = [
    {
      'title': 'فضل المداومة على العمل الصالح',
      'text':
          'قال رسول الله ﷺ: «أَحَبُّ الأَعْمَالِ إِلَى اللَّهِ أَدْوَمُهَا وَإِنْ قَلَّ».',
      'source': 'متفق عليه',
    },
    {
      'title': 'فضل الذكر والتقرب إلى الله',
      'text':
          'قال رسول الله ﷺ: «يَقُولُ اللَّهُ تَعَالَى: أَنَا عِنْدَ ظَنِّ عَبْدِي بِي، وَأَنَا مَعَهُ إِذَا ذَكَرَنِي، فَإِنْ ذَكَرَنِي فِي نَفْسِهِ ذَكَرْتُهُ فِي نَفْسِي، وَإِنْ ذَكَرَنِي فِي مَلَإٍ ذَكَرْتُهُ فِي مَلَإٍ خَيْرٍ مِنْهُمْ، وَإِنْ تَقَرَّبَ إِلَيَّ بِشِبْرٍ تَقَرَّبْتُ إِلَيْهِ ذِرَاعًا، وَإِنْ تَقَرَّبَ إِلَيَّ ذِرَاعًا تَقَرَّبْتُ إِلَيْهِ بَاعًا، وَإِنْ أَتَانِي يَمْشِي أَتَيْتُهُ هَرْوَلَةً».',
      'source': 'رواه البخاري ومسلم',
    },
  ];

  static String getMotivationMessage(int percentage, bool hasTasks) {
    if (!hasTasks) return 'أضف أعمالك اليومية للبدء في احتساب درجاتك';
    if (percentage == 100) return 'ما شاء الله! أتممت ورد اليوم كاملاً بهمة عالية';
    if (percentage >= 75) return 'همة مباركة، بقي القليل على إتمام الورد';
    if (percentage >= 40) return 'تقدم طيب، واصل الثبات والهمة';
    if (percentage > 0) return 'بداية طيبة، بارك الله في سعيك وعملك';
    return 'ابدأ يومك بذكر الله والاستعانة به';
  }
}

/// أدوات التعامل مع التواريخ وحسابات الأسبوع العربي (السبت -> الجمعة)
abstract final class AppDateUtils {
  static DateTime stripTime(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static String toDateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// ترتيب اليوم في الأسبوع بحيث يبدأ من السبت (0 = السبت ... 6 = الجمعة)
  static int getSaturdayBasedWeekdayIndex(DateTime date) =>
      (date.weekday + 1) % 7;

  static List<DateTime> getWeekDates(DateTime referenceDate) {
    final satOffset = getSaturdayBasedWeekdayIndex(referenceDate);
    final saturday = DateTime(
      referenceDate.year,
      referenceDate.month,
      referenceDate.day - satOffset,
    );
    return List.generate(
      7,
      (i) => DateTime(saturday.year, saturday.month, saturday.day + i),
    );
  }

  static int getDaysInMonth(int year, int month) =>
      DateTime(year, month + 1, 0).day;

  static String formatFullDate(DateTime date) =>
      '${date.day} ${AppStrings.monthsAr[date.month - 1]} ${date.year}';

  static String formatWeekRange(List<DateTime> weekDates) {
    final first = weekDates.first;
    final last = weekDates.last;
    return 'من السبت ${first.day} ${AppStrings.monthsAr[first.month - 1]} إلى الجمعة ${last.day} ${AppStrings.monthsAr[last.month - 1]} ${last.year}';
  }
}

/// ألوان الهوية البصرية الفاخرة (Royal Emerald & Champagne Gold)
abstract final class AppPalette {
  // الهوية الزمردية والذهبية
  static const Color primary = Color(0xFF1E6F65);
  static const Color primaryDark = Color(0xFF0F3D37);
  static const Color primaryDeeper = Color(0xFF082420);
  static const Color neonMint = Color(0xFF00E6A8);
  static const Color neonMintGlow = Color(0xFF47F5C8);
  static const Color goldAccent = Color(0xFFD97706);
  static const Color goldSoft = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFDC2626);

  // الوضع النهاري (Alabaster & Soft Sage)
  static const Color lightBg = Color(0xFFF2F6F5);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceAlt = Color(0xFFF7FBFA);
  static const Color lightBorder = Color(0xFFD5E3E0);
  static const Color lightText = Color(0xFF122624);
  static const Color lightMuted = Color(0xFF5C7471);

  // الوضع الليلي (Obsidian Emerald)
  static const Color darkBg = Color(0xFF071311);
  static const Color darkSurface = Color(0xFF0F221F);
  static const Color darkSurfaceAlt = Color(0xFF152E2A);
  static const Color darkBorder = Color(0xFF214640);
  static const Color darkText = Color(0xFFECF7F5);
  static const Color darkMuted = Color(0xFF8AB5AE);
}

/// خصائص التصميم المتجاوب حسب حجم الشاشة (Responsive Helper)
class ResponsiveLayout {
  final double width;
  const ResponsiveLayout(this.width);

  factory ResponsiveLayout.of(BuildContext context) =>
      ResponsiveLayout(MediaQuery.of(context).size.width);

  bool get isCompactPhone => width < 360;
  bool get isStandardPhone => width >= 360 && width < 600;
  bool get isTabletOrDesktop => width >= 600;

  double get horizontalPadding => isCompactPhone ? 10.0 : 16.0;
  double get cardPadding => isCompactPhone ? 12.0 : 16.0;
  double get titleFontSize => isCompactPhone ? 14.5 : 16.5;
  double get bodyFontSize => isCompactPhone ? 12.5 : 13.8;
}

/// بناء الثيم الموحد للتطبيق
abstract final class AppThemeBuilder {
  static ThemeData buildLight() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppPalette.lightBg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppPalette.primary,
        brightness: Brightness.light,
        primary: AppPalette.primary,
        surface: AppPalette.lightSurface,
      ),
      cardColor: AppPalette.lightSurface,
      dividerColor: AppPalette.lightBorder,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
    );
  }

  static ThemeData buildDark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppPalette.darkBg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppPalette.neonMint,
        brightness: Brightness.dark,
        primary: AppPalette.neonMint,
        surface: AppPalette.darkSurface,
      ),
      cardColor: AppPalette.darkSurface,
      dividerColor: AppPalette.darkBorder,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
    );
  }
}

// ============================================================================
// 2. DOMAIN LAYER: الكيانات (Entities)، خدمات الحسابات، وعقود المستودعات
// ============================================================================

/// تصنيف بصري ذكي للمهمة لمنح كل مهمة أيقونة ولوناً مميزاً دون تغيير هيكل البيانات
enum TaskVisualCategory { prayer, dhikr, quran, charity, general }

/// كيان المهمة اليومية (يحافظ على نفس مفاتيح JSON للتوافق الكامل)
class TaskItem {
  final int id;
  String title;
  int score;

  TaskItem({
    required this.id,
    required this.title,
    required this.score,
  });

  TaskItem copyWith({int? id, String? title, int? score}) {
    return TaskItem(
      id: id ?? this.id,
      title: title ?? this.title,
      score: score ?? this.score,
    );
  }

  /// استنتاج التصنيف البصري للمهمة تلقائياً من عنوانها لإثراء الواجهة الفنية
  TaskVisualCategory get visualCategory {
    if (title.contains('صلاة') && !title.contains('النبي')) {
      return TaskVisualCategory.prayer;
    }
    if (title.contains('قرآن') || title.contains('ورد') || title.contains('سورة')) {
      return TaskVisualCategory.quran;
    }
    if (title.contains('أذكار') ||
        title.contains('الاستغفار') ||
        title.contains('الصلاة على النبي')) {
      return TaskVisualCategory.dhikr;
    }
    if (title.contains('خير') || title.contains('صدقة')) {
      return TaskVisualCategory.charity;
    }
    return TaskVisualCategory.general;
  }

  IconData get categoryIcon {
    switch (visualCategory) {
      case TaskVisualCategory.prayer:
        return Icons.mosque_rounded;
      case TaskVisualCategory.quran:
        return Icons.menu_book_rounded;
      case TaskVisualCategory.dhikr:
        return Icons.auto_awesome_rounded;
      case TaskVisualCategory.charity:
        return Icons.volunteer_activism_rounded;
      case TaskVisualCategory.general:
        return Icons.task_alt_rounded;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'score': score,
      };

  factory TaskItem.fromJson(Map<String, dynamic> json) => TaskItem(
        id: json['id'] as int,
        title: json['title'] as String,
        score: (json['score'] ?? json['duration'] ?? 10) as int,
      );

  static List<TaskItem> defaultTasks() => [
        TaskItem(id: 0, title: 'صلاة الفجر: جماعة في المسجد', score: 15),
        TaskItem(id: 1, title: 'صلاة الفجر: أذكار بعد الصلاة', score: 7),
        TaskItem(id: 2, title: 'أذكار الصباح', score: 20),
        TaskItem(id: 3, title: 'صلاة الظهر: جماعة في المسجد', score: 20),
        TaskItem(id: 4, title: 'صلاة الظهر: أذكار بعد الصلاة', score: 7),
        TaskItem(id: 5, title: 'صلاة العصر: جماعة في المسجد', score: 15),
        TaskItem(id: 6, title: 'صلاة العصر: أذكار بعد الصلاة', score: 7),
        TaskItem(id: 7, title: 'أذكار المساء', score: 10),
        TaskItem(id: 8, title: 'صلاة المغرب: جماعة في المسجد', score: 15),
        TaskItem(id: 9, title: 'صلاة المغرب: أذكار بعد الصلاة', score: 7),
        TaskItem(id: 10, title: 'صلاة العشاء: جماعة في المسجد', score: 15),
        TaskItem(id: 11, title: 'صلاة العشاء: أذكار بعد الصلاة', score: 7),
        TaskItem(id: 12, title: 'ورد القرآن الكريم', score: 30),
        TaskItem(id: 13, title: 'الاستغفار', score: 10),
        TaskItem(id: 14, title: 'الصلاة على النبي ﷺ', score: 10),
        TaskItem(id: 15, title: 'فينا خير (بر وإحسان)', score: 10),
      ];
}

/// إحصائيات اليوم الواحد
class DayStats {
  final int earnedPoints;
  final int maxPoints;
  final int completedCount;
  final int totalTasksCount;
  final int percentage;

  const DayStats({
    required this.earnedPoints,
    required this.maxPoints,
    required this.completedCount,
    required this.totalTasksCount,
    required this.percentage,
  });
}

/// إحصائيات الأسبوع (7 أيام من السبت إلى الجمعة)
class WeekStats {
  final int earnedPoints;
  final int maxPoints;
  final int completedCount;
  final int percentage;
  final List<DateTime> weekDates;

  const WeekStats({
    required this.earnedPoints,
    required this.maxPoints,
    required this.completedCount,
    required this.percentage,
    required this.weekDates,
  });
}

/// أداء المهمة الواحدة خلال الشهر
class TaskMonthlyPerformance {
  final TaskItem task;
  final int completedDays;
  final int totalDaysInMonth;
  final int earnedScore;
  final int percentage;

  const TaskMonthlyPerformance({
    required this.task,
    required this.completedDays,
    required this.totalDaysInMonth,
    required this.earnedScore,
    required this.percentage,
  });
}

/// إحصائيات الشهر الكاملة للداشبورد
class MonthDashboardStats {
  final int year;
  final int month;
  final int daysInMonth;
  final int earnedPoints;
  final int maxPoints;
  final int completedTasksCount;
  final int activeDaysCount;
  final int bestDayPercentage;
  final int maxStreak;
  final int overallPercentage;
  final List<int> dailyPercentages;
  final List<TaskMonthlyPerformance> taskPerformances;

  const MonthDashboardStats({
    required this.year,
    required this.month,
    required this.daysInMonth,
    required this.earnedPoints,
    required this.maxPoints,
    required this.completedTasksCount,
    required this.activeDaysCount,
    required this.bestDayPercentage,
    required this.maxStreak,
    required this.overallPercentage,
    required this.dailyPercentages,
    required this.taskPerformances,
  });
}

/// عقد المستودع (Repository Interface - Dependency Inversion Principle)
abstract class ITrackerRepository {
  Future<bool> loadDarkMode();
  Future<void> saveDarkMode(bool isDark);

  Future<List<TaskItem>> loadTasks();
  Future<void> saveTasks(List<TaskItem> tasks);

  Future<Map<String, Map<int, bool>>> loadRecordsByDate();
  Future<void> saveRecordsByDate(Map<String, Map<int, bool>> records);

  Future<String> loadUserName();
  Future<void> saveUserName(String userName);
}

/// خدمة الحسابات والتحليلات المنطقية (Pure Domain Service)
class TrackerAnalyticsService {
  const TrackerAnalyticsService();

  int calculateMaxDailyScore(List<TaskItem> tasks) =>
      tasks.fold<int>(0, (sum, item) => sum + item.score);

  bool isTaskDone(
    Map<String, Map<int, bool>> recordsByDate,
    String dateKey,
    int taskId,
  ) {
    return recordsByDate[dateKey]?[taskId] == true;
  }

  DayStats calculateDayStats({
    required List<TaskItem> tasks,
    required Map<String, Map<int, bool>> recordsByDate,
    required String dateKey,
  }) {
    int earned = 0;
    int count = 0;
    for (final task in tasks) {
      if (isTaskDone(recordsByDate, dateKey, task.id)) {
        earned += task.score;
        count++;
      }
    }
    final maxPts = calculateMaxDailyScore(tasks);
    final perc = maxPts > 0 ? ((earned / maxPts) * 100).round() : 0;
    return DayStats(
      earnedPoints: earned,
      maxPoints: maxPts,
      completedCount: count,
      totalTasksCount: tasks.length,
      percentage: perc,
    );
  }

  WeekStats calculateWeekStats({
    required List<TaskItem> tasks,
    required Map<String, Map<int, bool>> recordsByDate,
    required DateTime referenceDate,
  }) {
    final weekDates = AppDateUtils.getWeekDates(referenceDate);
    int weekEarned = 0;
    int weekCount = 0;
    for (final d in weekDates) {
      final st = calculateDayStats(
        tasks: tasks,
        recordsByDate: recordsByDate,
        dateKey: AppDateUtils.toDateKey(d),
      );
      weekEarned += st.earnedPoints;
      weekCount += st.completedCount;
    }
    final maxWeek = calculateMaxDailyScore(tasks) * 7;
    final weekPerc = maxWeek > 0 ? ((weekEarned / maxWeek) * 100).round() : 0;
    return WeekStats(
      earnedPoints: weekEarned,
      maxPoints: maxWeek,
      completedCount: weekCount,
      percentage: weekPerc,
      weekDates: weekDates,
    );
  }

  MonthDashboardStats calculateMonthStats({
    required List<TaskItem> tasks,
    required Map<String, Map<int, bool>> recordsByDate,
    required int year,
    required int month,
  }) {
    final daysInMonth = AppDateUtils.getDaysInMonth(year, month);
    final maxDaily = calculateMaxDailyScore(tasks);

    int monthEarnedPoints = 0;
    int monthCompletedTasks = 0;
    int activeDaysCount = 0;
    int bestDayPerc = 0;
    int currentStreak = 0;
    int maxStreak = 0;

    final List<int> dailyPercentages = [];
    final Map<int, int> taskMonthlyCounts = {
      for (final t in tasks) t.id: 0,
    };

    for (int day = 1; day <= daysInMonth; day++) {
      final dObj = DateTime(year, month, day);
      final dKey = AppDateUtils.toDateKey(dObj);
      final st = calculateDayStats(
        tasks: tasks,
        recordsByDate: recordsByDate,
        dateKey: dKey,
      );

      dailyPercentages.add(st.percentage);
      monthEarnedPoints += st.earnedPoints;
      monthCompletedTasks += st.completedCount;

      if (st.completedCount > 0) activeDaysCount++;
      if (st.percentage > bestDayPerc) bestDayPerc = st.percentage;

      if (st.percentage >= 50) {
        currentStreak++;
        if (currentStreak > maxStreak) maxStreak = currentStreak;
      } else {
        currentStreak = 0;
      }

      for (final t in tasks) {
        if (isTaskDone(recordsByDate, dKey, t.id)) {
          taskMonthlyCounts[t.id] = (taskMonthlyCounts[t.id] ?? 0) + 1;
        }
      }
    }

    final maxMonthPoints = daysInMonth * maxDaily;
    final monthOverallPerc = maxMonthPoints > 0
        ? ((monthEarnedPoints / maxMonthPoints) * 100).round()
        : 0;

    final performances = tasks.map((t) {
      final doneDays = taskMonthlyCounts[t.id] ?? 0;
      final taskPerc =
          daysInMonth > 0 ? ((doneDays / daysInMonth) * 100).round() : 0;
      return TaskMonthlyPerformance(
        task: t,
        completedDays: doneDays,
        totalDaysInMonth: daysInMonth,
        earnedScore: doneDays * t.score,
        percentage: taskPerc,
      );
    }).toList();

    return MonthDashboardStats(
      year: year,
      month: month,
      daysInMonth: daysInMonth,
      earnedPoints: monthEarnedPoints,
      maxPoints: maxMonthPoints,
      completedTasksCount: monthCompletedTasks,
      activeDaysCount: activeDaysCount,
      bestDayPercentage: bestDayPerc,
      maxStreak: maxStreak,
      overallPercentage: monthOverallPerc,
      dailyPercentages: dailyPercentages,
      taskPerformances: performances,
    );
  }
}

// ============================================================================
// 3. DATA LAYER: تطبيق المستودع المحلي (SharedPreferences Implementation)
// ============================================================================

class SharedPrefsTrackerRepository implements ITrackerRepository {
  // الحفاظ على نفس المفاتيح الأصلية لضمان عدم ضياع بيانات المستخدمين الحاليين
  static const String _keyDarkMode = 'tracker_dark_mode';
  static const String _keyCustomTasks = 'tracker_custom_tasks_v1';
  static const String _keyRecordsByDate = 'tracker_records_by_date_v2';
  static const String _keyUserName = 'tracker_user_name';

  @override
  Future<bool> loadDarkMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyDarkMode) ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> saveDarkMode(bool isDark) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyDarkMode, isDark);
    } catch (_) {}
  }

  @override
  Future<List<TaskItem>> loadTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tasksJsonStr = prefs.getString(_keyCustomTasks);
      if (tasksJsonStr != null && tasksJsonStr.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(tasksJsonStr);
        return decoded
            .map((item) => TaskItem.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      }
    } catch (_) {}
    return TaskItem.defaultTasks();
  }

  @override
  Future<void> saveTasks(List<TaskItem> tasks) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(tasks.map((t) => t.toJson()).toList());
      await prefs.setString(_keyCustomTasks, encoded);
    } catch (_) {}
  }

  @override
  Future<Map<String, Map<int, bool>>> loadRecordsByDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recordsJsonStr = prefs.getString(_keyRecordsByDate);
      if (recordsJsonStr != null && recordsJsonStr.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(recordsJsonStr);
        final Map<String, Map<int, bool>> parsedRecords = {};
        decoded.forEach((dateKey, dayMap) {
          if (dayMap is Map) {
            final Map<int, bool> taskMap = {};
            dayMap.forEach((k, v) {
              final taskId = int.tryParse(k.toString());
              if (taskId != null && v == true) {
                taskMap[taskId] = true;
              }
            });
            parsedRecords[dateKey] = taskMap;
          }
        });
        return parsedRecords;
      }
    } catch (_) {}
    return {};
  }

  @override
  Future<void> saveRecordsByDate(Map<String, Map<int, bool>> records) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, Map<String, bool>> serializable = {};
      records.forEach((dateKey, taskMap) {
        serializable[dateKey] =
            taskMap.map((key, value) => MapEntry(key.toString(), value));
      });
      await prefs.setString(_keyRecordsByDate, jsonEncode(serializable));
    } catch (_) {}
  }

  @override
  Future<String> loadUserName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyUserName) ?? '';
    } catch (_) {
      return '';
    }
  }

  @override
  Future<void> saveUserName(String userName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyUserName, userName);
    } catch (_) {}
  }
}

// ============================================================================
// 4. PRESENTATION STATE LAYER: المتحكم المركزي بالحالة (TrackerController)
// ============================================================================

class TrackerController extends ChangeNotifier {
  final ITrackerRepository _repository;
  final TrackerAnalyticsService _analytics;

  TrackerController({
    required ITrackerRepository repository,
    TrackerAnalyticsService analytics = const TrackerAnalyticsService(),
  })  : _repository = repository,
        _analytics = analytics {
    final now = DateTime.now();
    _systemToday = AppDateUtils.stripTime(now);
    _selectedDate = _systemToday;
    _dashboardMonthDate = DateTime(now.year, now.month, 1);
  }

  bool _isLoading = true;
  bool _isDarkMode = false;
  int _currentTabIndex = 0; // 0 = جدول اليوم، 1 = إحصائيات الشهر
  late DateTime _systemToday;
  late DateTime _selectedDate;
  late DateTime _dashboardMonthDate;

  List<TaskItem> _tasks = [];
  Map<String, Map<int, bool>> _recordsByDate = {};
  String _userName = '';

  // Getters
  bool get isLoading => _isLoading;
  bool get isDarkMode => _isDarkMode;
  int get currentTabIndex => _currentTabIndex;
  DateTime get systemToday => _systemToday;
  DateTime get selectedDate => _selectedDate;
  DateTime get dashboardMonthDate => _dashboardMonthDate;
  List<TaskItem> get tasks => List.unmodifiable(_tasks);
  String get userName => _userName;

  String get selectedDateKey => AppDateUtils.toDateKey(_selectedDate);
  String get todayDateKey => AppDateUtils.toDateKey(_systemToday);
  bool get isSelectedDateToday => selectedDateKey == todayDateKey;

  int get selectedWeekdayIndex =>
      AppDateUtils.getSaturdayBasedWeekdayIndex(_selectedDate);
  String get selectedDayName => AppStrings.weekDaysFull[selectedWeekdayIndex];

  int get maxDailyScore => _analytics.calculateMaxDailyScore(_tasks);
  int get maxWeeklyScore => maxDailyScore * 7;

  DayStats get selectedDayStats => getDayStatsForKey(selectedDateKey);

  WeekStats get selectedWeekStats => _analytics.calculateWeekStats(
        tasks: _tasks,
        recordsByDate: _recordsByDate,
        referenceDate: _selectedDate,
      );

  MonthDashboardStats get currentMonthDashboardStats =>
      _analytics.calculateMonthStats(
        tasks: _tasks,
        recordsByDate: _recordsByDate,
        year: _dashboardMonthDate.year,
        month: _dashboardMonthDate.month,
      );

  DayStats getDayStatsForKey(String dateKey) => _analytics.calculateDayStats(
        tasks: _tasks,
        recordsByDate: _recordsByDate,
        dateKey: dateKey,
      );

  bool isTaskDone(String dateKey, int taskId) =>
      _analytics.isTaskDone(_recordsByDate, dateKey, taskId);

  // Initialization
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    _isDarkMode = await _repository.loadDarkMode();
    _tasks = await _repository.loadTasks();
    _recordsByDate = await _repository.loadRecordsByDate();
    _userName = await _repository.loadUserName();

    _isLoading = false;
    notifyListeners();
  }

  // Actions
  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
    await _repository.saveDarkMode(_isDarkMode);
  }

  void setTabIndex(int index) {
    if (_currentTabIndex == index) return;
    HapticFeedback.selectionClick();
    _currentTabIndex = index;
    notifyListeners();
  }

  void selectDate(DateTime date) {
    HapticFeedback.selectionClick();
    _selectedDate = AppDateUtils.stripTime(date);
    notifyListeners();
  }

  void stepSelectedDay(int deltaDays) {
    selectDate(DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day + deltaDays,
    ));
  }

  void jumpToToday() {
    final now = DateTime.now();
    _systemToday = AppDateUtils.stripTime(now);
    selectDate(_systemToday);
  }

  void stepDashboardMonth(int deltaMonths) {
    HapticFeedback.selectionClick();
    _dashboardMonthDate = DateTime(
      _dashboardMonthDate.year,
      _dashboardMonthDate.month + deltaMonths,
      1,
    );
    notifyListeners();
  }

  void openDayFromMonthlyDashboard(int year, int month, int day) {
    HapticFeedback.mediumImpact();
    _selectedDate = DateTime(year, month, day);
    _currentTabIndex = 0;
    notifyListeners();
  }

  Future<void> toggleTaskForDate(String dateKey, int taskId) async {
    HapticFeedback.lightImpact();
    final dayRecord = _recordsByDate.putIfAbsent(dateKey, () => {});
    final current = dayRecord[taskId] ?? false;
    dayRecord[taskId] = !current;
    notifyListeners();
    await _repository.saveRecordsByDate(_recordsByDate);
  }

  Future<void> addOrUpdateTask({
    TaskItem? existingTask,
    required String title,
    required int score,
  }) async {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty || score <= 0) return;

    if (existingTask != null) {
      final idx = _tasks.indexWhere((t) => t.id == existingTask.id);
      if (idx != -1) {
        _tasks[idx].title = cleanTitle;
        _tasks[idx].score = score;
      }
    } else {
      final nextId = _tasks.isEmpty
          ? 0
          : (_tasks.map((t) => t.id).reduce(math.max) + 1);
      _tasks.add(TaskItem(id: nextId, title: cleanTitle, score: score));
    }
    notifyListeners();
    await _repository.saveTasks(_tasks);
  }

  Future<void> deleteTask(int taskId) async {
    _tasks.removeWhere((t) => t.id == taskId);
    notifyListeners();
    await _repository.saveTasks(_tasks);
  }

  Future<void> restoreDefaultTasks() async {
    _tasks = TaskItem.defaultTasks();
    notifyListeners();
    await _repository.saveTasks(_tasks);
  }

  Future<void> resetCurrentWeek() async {
    final weekDates = AppDateUtils.getWeekDates(_selectedDate);
    for (final d in weekDates) {
      _recordsByDate.remove(AppDateUtils.toDateKey(d));
    }
    notifyListeners();
    await _repository.saveRecordsByDate(_recordsByDate);
  }

  Future<void> updateUserName(String value) async {
    _userName = value;
    await _repository.saveUserName(value);
  }
}

// ============================================================================
// 5. PRESENTATION UI LAYER: التطبيق الرئيسي والشاشات والمكونات القابلة لإعادة الاستخدام
// ============================================================================

class DailyTrackerApp extends StatefulWidget {
  const DailyTrackerApp({super.key});

  @override
  State<DailyTrackerApp> createState() => _DailyTrackerAppState();
}

class _DailyTrackerAppState extends State<DailyTrackerApp> {
  late final TrackerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TrackerController(
      repository: SharedPrefsTrackerRepository(),
    )..initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return MaterialApp(
          title: AppStrings.appTitle,
          debugShowCheckedModeBanner: false,
          themeMode: _controller.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          theme: AppThemeBuilder.buildLight(),
          darkTheme: AppThemeBuilder.buildDark(),
          builder: (context, child) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: child!,
            );
          },
          home: HomeScreen(controller: _controller),
        );
      },
    );
  }
}

/// الشاشة الرئيسية للتطبيق
class HomeScreen extends StatefulWidget {
  final TrackerController controller;

  const HomeScreen({
    super.key,
    required this.controller,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final TextEditingController _userNameTextCtrl;

  TrackerController get _ctrl => widget.controller;

  @override
  void initState() {
    super.initState();
    _userNameTextCtrl = TextEditingController(text: _ctrl.userName);
    _ctrl.addListener(_syncUserNameField);
  }

  void _syncUserNameField() {
    if (_userNameTextCtrl.text != _ctrl.userName && !_ctrl.isLoading) {
      _userNameTextCtrl.text = _ctrl.userName;
    }
  }

  @override
  void dispose() {
    _ctrl.removeListener(_syncUserNameField);
    _userNameTextCtrl.dispose();
    super.dispose();
  }

  // -------------------- النوافذ المنبثقة والحوارية --------------------

  Future<void> _openTaskEditor({TaskItem? existingTask}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TaskEditorSheet(
        existingTask: existingTask,
        onSave: (title, score) => _ctrl.addOrUpdateTask(
          existingTask: existingTask,
          title: title,
          score: score,
        ),
        onDelete: existingTask != null
            ? () => _confirmDeleteTask(existingTask)
            : null,
      ),
    );
  }

  Future<void> _confirmDeleteTask(TaskItem task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppConfirmationDialog(
        title: 'حذف المهمة اليومية',
        message:
            'هل أنت متأكد من حذف «${task.title}» (${task.score} د)؟ سيتم إعادة احتساب النسب والدرجات تلقائياً.',
        confirmLabel: 'حذف المهمة',
        isDestructive: true,
      ),
    );
    if (confirmed == true) {
      await _ctrl.deleteTask(task.id);
    }
  }

  Future<void> _confirmRestoreDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => const AppConfirmationDialog(
        title: 'استعادة الأوراد الافتراضية',
        message:
            'هل ترغب في استعادة قائمة الأعمال اليومية الافتراضية (16 عملاً بإجمالي 205 درجات)؟',
        confirmLabel: 'استعادة القائمة',
        isDestructive: false,
      ),
    );
    if (confirmed == true) {
      await _ctrl.restoreDefaultTasks();
    }
  }

  Future<void> _confirmResetWeek() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => const AppConfirmationDialog(
        title: 'بدء أسبوع جديد',
        message:
            'هل أنت متأكد من مسح علامات الإنجاز لهذا الأسبوع فقط للبدء من جديد؟ (لن يتأثر اسمك أو سجلات الأسابيع الأخرى أو مهامك المخصصة).',
        confirmLabel: 'نعم، مسح الأسبوع',
        isDestructive: true,
      ),
    );
    if (confirmed == true) {
      await _ctrl.resetCurrentWeek();
    }
  }

  void _openWeeklyMatrixSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => WeeklyMatrixSheet(controller: _ctrl),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_ctrl.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final responsive = ResponsiveLayout.of(context);
    final isDark = _ctrl.isDarkMode;

    return Scaffold(
      floatingActionButton: _ctrl.currentTabIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () => _openTaskEditor(),
              backgroundColor: AppPalette.primary,
              foregroundColor: Colors.white,
              elevation: 4,
              icon: const Icon(Icons.add_task_rounded, size: 20),
              label: const Text(
                'إضافة عمل',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
              ),
            )
          : null,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    responsive.horizontalPadding,
                    12,
                    responsive.horizontalPadding,
                    96,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // 1. شريط التبويبات العلوي وزر الوضع الليلي
                      TopNavigationHeader(
                        currentTabIndex: _ctrl.currentTabIndex,
                        isDarkMode: isDark,
                        onSelectTab: _ctrl.setTabIndex,
                        onToggleTheme: _ctrl.toggleTheme,
                      ),
                      const SizedBox(height: 12),

                      // 2. لافتة الآية القرآنية بتصميم زخرفي أنيق
                      QuranicVerseBanner(
                        maxDailyScore: _ctrl.maxDailyScore,
                        tasksCount: _ctrl.tasks.length,
                        isDarkMode: isDark,
                      ),
                      const SizedBox(height: 14),

                      // 3. المحتوى المتغير (وِرد اليوم / إحصائيات الشهر)
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 280),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: _ctrl.currentTabIndex == 0
                            ? _DailyTrackerTabView(
                                key: const ValueKey('daily_tab_view'),
                                controller: _ctrl,
                                onAddTask: () => _openTaskEditor(),
                                onEditTask: (task) =>
                                    _openTaskEditor(existingTask: task),
                                onRestoreDefaults: _confirmRestoreDefaults,
                                onOpenWeeklySheet: _openWeeklyMatrixSheet,
                                onResetWeek: _confirmResetWeek,
                              )
                            : _MonthlyDashboardTabView(
                                key: const ValueKey('monthly_tab_view'),
                                controller: _ctrl,
                              ),
                      ),
                      const SizedBox(height: 16),

                      // 4. بطاقة توقيع الاسم السفلية
                      UserProfileFooterCard(
                        controller: _userNameTextCtrl,
                        isDarkMode: isDark,
                        onChanged: _ctrl.updateUserName,
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 6. القسم الأول: واجهة وِرد اليوم (Daily Tracker View)
// ============================================================================

class _DailyTrackerTabView extends StatelessWidget {
  final TrackerController controller;
  final VoidCallback onAddTask;
  final ValueChanged<TaskItem> onEditTask;
  final VoidCallback onRestoreDefaults;
  final VoidCallback onOpenWeeklySheet;
  final VoidCallback onResetWeek;

  const _DailyTrackerTabView({
    super.key,
    required this.controller,
    required this.onAddTask,
    required this.onEditTask,
    required this.onRestoreDefaults,
    required this.onOpenWeeklySheet,
    required this.onResetWeek,
  });

  @override
  Widget build(BuildContext context) {
    final dayStats = controller.selectedDayStats;
    final weekStats = controller.selectedWeekStats;
    final dateKey = controller.selectedDateKey;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. بطاقة مستوى التقدم اليومي الفاخرة مع حلقة الإنجاز الدائرية
        HeroProgressBanner(
          title: 'مستوى الإنجاز اليومي',
          subtitleBadge:
              '${dayStats.completedCount} من ${dayStats.totalTasksCount} أعمال',
          earnedScore: dayStats.earnedPoints,
          maxScore: dayStats.maxPoints,
          percentage: dayStats.percentage,
          footerRightText:
              'إنجاز الأسبوع: ${weekStats.earnedPoints} / ${weekStats.maxPoints} د (${weekStats.percentage}%)',
          footerLeftText: AppStrings.getMotivationMessage(
            dayStats.percentage,
            controller.tasks.isNotEmpty,
          ),
        ),
        const SizedBox(height: 12),

        // 2. شريط التنقل بالتاريخ اليومي (متجاوب ضد التداخل)
        ResponsiveDateNavigator(
          dayName: controller.selectedDayName,
          formattedDate: AppDateUtils.formatFullDate(controller.selectedDate),
          isToday: controller.isSelectedDateToday,
          isDarkMode: controller.isDarkMode,
          onPrevious: () => controller.stepSelectedDay(-1),
          onNext: () => controller.stepSelectedDay(1),
          onJumpToToday: controller.jumpToToday,
        ),
        const SizedBox(height: 10),

        // 3. شريط أيام الأسبوع السبعة المتجاوب (Responsive Week Strip)
        ResponsiveWeekStrip(
          controller: controller,
          weekDates: weekStats.weekDates,
        ),
        const SizedBox(height: 16),

        // 4. شريط أدوات قائمة المهام
        TasksSectionHeader(
          tasksCount: controller.tasks.length,
          isDarkMode: controller.isDarkMode,
          onAddTask: onAddTask,
          onRestoreDefaults: onRestoreDefaults,
        ),
        const SizedBox(height: 8),

        // 5. بطاقات المهام اليومية (بديل فني متجاوب للجدول الضيق يمنع تداخل النصوص تماماً)
        if (controller.tasks.isEmpty)
          EmptyTasksPlaceholder(
            isDarkMode: controller.isDarkMode,
            onAddTask: onAddTask,
            onRestoreDefaults: onRestoreDefaults,
          )
        else
          ...controller.tasks.map((task) {
            final isDone = controller.isTaskDone(dateKey, task.id);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InteractiveTaskCard(
                task: task,
                isDone: isDone,
                isDarkMode: controller.isDarkMode,
                onToggle: () => controller.toggleTaskForDate(dateKey, task.id),
                onEdit: () => onEditTask(task),
              ),
            );
          }),

        const SizedBox(height: 6),

        // 6. شريط الملخص اليومي للدرجات والنسبة المئوية
        DailyScoreSummaryCard(
          dayStats: dayStats,
          isDarkMode: controller.isDarkMode,
        ),
        const SizedBox(height: 12),

        // 7. أزرار الإجراءات السريعة (معاينة جدول الأسبوع الكامل + بدء أسبوع جديد)
        QuickActionsRow(
          isDarkMode: controller.isDarkMode,
          onOpenWeeklySheet: onOpenWeeklySheet,
          onResetWeek: onResetWeek,
        ),
        const SizedBox(height: 16),

        // 8. قسم الأحاديث النبوية الشريفة
        HadithInspirationSection(isDarkMode: controller.isDarkMode),
      ],
    );
  }
}

// ============================================================================
// 7. القسم الثاني: واجهة إحصائيات الشهر (Monthly Dashboard View)
// ============================================================================

class _MonthlyDashboardTabView extends StatelessWidget {
  final TrackerController controller;

  const _MonthlyDashboardTabView({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final stats = controller.currentMonthDashboardStats;
    final isDark = controller.isDarkMode;
    final monthTitle =
        '${AppStrings.monthsAr[stats.month - 1]} ${stats.year}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. شريط التنقل بين الأشهر
        MonthSelectorBar(
          monthTitle: monthTitle,
          isDarkMode: isDark,
          onPreviousMonth: () => controller.stepDashboardMonth(-1),
          onNextMonth: () => controller.stepDashboardMonth(1),
        ),
        const SizedBox(height: 12),

        // 2. لافتة مؤشر الإنجاز الشهري التراكمي
        HeroProgressBanner(
          title: 'مؤشر الإنجاز الشهري التراكمي',
          subtitleBadge:
              'أيام التفاعل: ${stats.activeDaysCount} من ${stats.daysInMonth} يوماً',
          earnedScore: stats.earnedPoints,
          maxScore: stats.maxPoints,
          percentage: stats.overallPercentage,
          footerRightText:
              'إجمالي الأعمال المنجزة: ${stats.completedTasksCount} عمل',
          footerLeftText: 'أعلى نسبة يومية: ${stats.bestDayPercentage}%',
        ),
        const SizedBox(height: 12),

        // 3. شبكة مؤشرات الأداء الرئيسية (KPIs) المتجاوبة بالكامل ضد الـ Overflow
        ResponsiveKpiGrid(
          stats: stats,
          isDarkMode: isDark,
        ),
        const SizedBox(height: 14),

        // 4. الرسم البياني لمنحنى الإنجاز اليومي خلال الشهر
        DashboardSectionCard(
          title: 'منحنى الإنجاز اليومي خلال الشهر (%)',
          trailingText: '${stats.daysInMonth} يوماً',
          isDarkMode: isDark,
          child: SizedBox(
            height: 175,
            child: MonthlyBarChartWidget(
              dailyPercentages: stats.dailyPercentages,
              isDarkMode: isDark,
            ),
          ),
        ),
        const SizedBox(height: 14),

        // 5. خريطة الالتزام الحرارية للشهر (Calendar Heatmap)
        DashboardSectionCard(
          title: 'خريطة الالتزام الشهرية',
          trailingText: 'اضغط على أي يوم لفتحه',
          isDarkMode: isDark,
          child: MonthlyHeatmapCalendar(
            year: stats.year,
            month: stats.month,
            daysInMonth: stats.daysInMonth,
            controller: controller,
          ),
        ),
        const SizedBox(height: 14),

        // 6. تحليل الأداء الشهري لكل عمل
        DashboardSectionCard(
          title: 'تحليل الأداء الشهري لكل عمل',
          trailingText: 'مرتب حسب القائمة',
          isDarkMode: isDark,
          child: stats.taskPerformances.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'لا توجد أعمال مسجلة حالياً.',
                    textAlign: TextAlign.center,
                  ),
                )
              : Column(
                  children: stats.taskPerformances
                      .map(
                        (perf) => TaskMonthlyPerformanceTile(
                          performance: perf,
                          isDarkMode: isDark,
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }
}

// ============================================================================
// 8. REUSABLE ATOMIC & MOLECULAR WIDGETS (مكونات الواجهة القابلة لإعادة الاستخدام)
// ============================================================================

/// شريط التبديل العلوي وزر الوضع الليلي
class TopNavigationHeader extends StatelessWidget {
  final int currentTabIndex;
  final bool isDarkMode;
  final ValueChanged<int> onSelectTab;
  final VoidCallback onToggleTheme;

  const TopNavigationHeader({
    super.key,
    required this.currentTabIndex,
    required this.isDarkMode,
    required this.onSelectTab,
    required this.onToggleTheme,
  });

  @override
  Widget build(BuildContext context) {
    final navBg =
        isDarkMode ? AppPalette.darkSurface : AppPalette.lightSurface;
    final borderCol =
        isDarkMode ? AppPalette.darkBorder : AppPalette.lightBorder;

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: navBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderCol),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _SegmentTabButton(
                    title: AppStrings.dailyTab,
                    icon: Icons.wb_sunny_outlined,
                    isSelected: currentTabIndex == 0,
                    isDarkMode: isDarkMode,
                    onTap: () => onSelectTab(0),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _SegmentTabButton(
                    title: AppStrings.monthlyTab,
                    icon: Icons.insights_rounded,
                    isSelected: currentTabIndex == 1,
                    isDarkMode: isDarkMode,
                    onTap: () => onSelectTab(1),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Material(
          color: navBg,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onToggleTheme,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderCol),
              ),
              alignment: Alignment.center,
              child: Icon(
                isDarkMode
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
                color: isDarkMode
                    ? AppPalette.neonMint
                    : AppPalette.primaryDark,
                size: 21,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SegmentTabButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final bool isDarkMode;
  final VoidCallback onTap;

  const _SegmentTabButton({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.isDarkMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeBg = isDarkMode ? AppPalette.primary : AppPalette.primary;
    final activeText = Colors.white;
    final inactiveText =
        isDarkMode ? AppPalette.darkMuted : AppPalette.lightMuted;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppPalette.primary.withOpacity(0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: isSelected ? activeText : inactiveText,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? activeText : inactiveText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// لافتة الآية القرآنية بتصميم إسلامي عصري (تم إصلاح الشارة الفارغة فيها)
class QuranicVerseBanner extends StatelessWidget {
  final int maxDailyScore;
  final int tasksCount;
  final bool isDarkMode;

  const QuranicVerseBanner({
    super.key,
    required this.maxDailyScore,
    required this.tasksCount,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveLayout.of(context);
    final surface =
        isDarkMode ? AppPalette.darkSurface : AppPalette.lightSurface;
    final borderCol =
        isDarkMode ? AppPalette.darkBorder : AppPalette.lightBorder;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: responsive.cardPadding,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.auto_awesome,
                size: 13,
                color: isDarkMode ? AppPalette.neonMint : AppPalette.goldAccent,
              ),
              Container(
                width: 48,
                height: 3,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: isDarkMode ? AppPalette.neonMint : AppPalette.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Icon(
                Icons.auto_awesome,
                size: 13,
                color: isDarkMode ? AppPalette.neonMint : AppPalette.goldAccent,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            AppStrings.quranVerse,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: responsive.isCompactPhone ? 15.0 : 16.8,
              fontWeight: FontWeight.w800,
              height: 1.65,
              color: isDarkMode ? AppPalette.darkText : AppPalette.primaryDark,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              _InfoPillBadge(
                icon: Icons.menu_book_rounded,
                text: AppStrings.quranReference,
                isDarkMode: isDarkMode,
                isPrimary: true,
              ),
              _InfoPillBadge(
                icon: Icons.stars_rounded,
                text: 'الرصيد اليومي: $maxDailyScore د ($tasksCount عمل)',
                isDarkMode: isDarkMode,
                isPrimary: false,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoPillBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isDarkMode;
  final bool isPrimary;

  const _InfoPillBadge({
    required this.icon,
    required this.text,
    required this.isDarkMode,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isPrimary
        ? (isDarkMode
            ? AppPalette.primary.withOpacity(0.35)
            : const Color(0xFFE5F4F1))
        : (isDarkMode
            ? AppPalette.darkSurfaceAlt
            : AppPalette.lightSurfaceAlt);
    final fg = isPrimary
        ? (isDarkMode ? AppPalette.neonMint : AppPalette.primaryDark)
        : (isDarkMode ? AppPalette.darkMuted : AppPalette.lightMuted);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: isDarkMode
              ? AppPalette.darkBorder
              : const Color(0xFFC2DDD8),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11.2,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// بطاقة التقدم الرئيسية (Hero Progress Banner) مع حلقة تقدم دائرية وتصميم متجاوب
class HeroProgressBanner extends StatelessWidget {
  final String title;
  final String subtitleBadge;
  final int earnedScore;
  final int maxScore;
  final int percentage;
  final String? footerRightText;
  final String? footerLeftText;

  const HeroProgressBanner({
    super.key,
    required this.title,
    required this.subtitleBadge,
    required this.earnedScore,
    required this.maxScore,
    required this.percentage,
    this.footerRightText,
    this.footerLeftText,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveLayout.of(context);
    final clampedPerc = percentage.clamp(0, 100);

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0A2420),
            Color(0xFF13403A),
            Color(0xFF0D2E29),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF215A52)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A2420).withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: CustomPaint(
          painter: _GeometricStarsPainter(),
          child: Padding(
            padding: EdgeInsets.all(responsive.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // حلقة النسبة المئوية الفاخرة
                    SizedBox(
                      width: responsive.isCompactPhone ? 58 : 66,
                      height: responsive.isCompactPhone ? 58 : 66,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CircularProgressIndicator(
                            value: clampedPerc / 100.0,
                            strokeWidth: 6,
                            backgroundColor:
                                Colors.white.withOpacity(0.12),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppPalette.neonMint,
                            ),
                            strokeCap: StrokeCap.round,
                          ),
                          Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Padding(
                                padding: const EdgeInsets.all(6.0),
                                child: Text(
                                  '$clampedPerc%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),

                    // تفاصيل الدرجات وشريط التقدم
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  color: Color(0xFFA7DFD4),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(
                                  subtitleBadge,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '$earnedScore',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize:
                                      responsive.isCompactPhone ? 20 : 23,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                ' / $maxScore درجة',
                                style: const TextStyle(
                                  color: Color(0xFF9CD5C9),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // شريط التقدم المضيء
                          Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final ratio = clampedPerc / 100.0;
                                return Align(
                                  alignment: Alignment.centerRight,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 350),
                                    curve: Curves.easeOutCubic,
                                    width: constraints.maxWidth * ratio,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          AppPalette.neonMintGlow,
                                          AppPalette.neonMint,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (footerRightText != null || footerLeftText != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.only(top: 10),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                    ),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        if (footerRightText != null)
                          Text(
                            footerRightText!,
                            style: const TextStyle(
                              color: Color(0xFF9CD5C9),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        if (footerLeftText != null)
                          Text(
                            footerLeftText!,
                            style: const TextStyle(
                              color: AppPalette.neonMintGlow,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// شريط التنقل بالتاريخ اليومي (محمي من التداخل على الشاشات الصغيرة)
class ResponsiveDateNavigator extends StatelessWidget {
  final String dayName;
  final String formattedDate;
  final bool isToday;
  final bool isDarkMode;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onJumpToToday;

  const ResponsiveDateNavigator({
    super.key,
    required this.dayName,
    required this.formattedDate,
    required this.isToday,
    required this.isDarkMode,
    required this.onPrevious,
    required this.onNext,
    required this.onJumpToToday,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDarkMode ? AppPalette.darkSurface : AppPalette.lightSurface;
    final borderCol =
        isDarkMode ? AppPalette.darkBorder : AppPalette.lightBorder;
    final textCol = isDarkMode ? AppPalette.darkText : AppPalette.primaryDark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderCol),
      ),
      child: Row(
        children: [
          _SmallNavButton(
            icon: Icons.chevron_right_rounded,
            tooltip: 'اليوم السابق',
            isDarkMode: isDarkMode,
            onTap: onPrevious,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      dayName,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: textCol,
                      ),
                    ),
                    if (isToday)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppPalette.primary,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: const Text(
                          'اليوم',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    else
                      InkWell(
                        onTap: onJumpToToday,
                        borderRadius: BorderRadius.circular(99),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? AppPalette.primary.withOpacity(0.25)
                                : const Color(0xFFE6F4F1),
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(
                              color: AppPalette.primary.withOpacity(0.4),
                            ),
                          ),
                          child: Text(
                            'العودة لليوم ↺',
                            style: TextStyle(
                              color: isDarkMode
                                  ? AppPalette.neonMint
                                  : AppPalette.primaryDark,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  formattedDate,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode
                        ? AppPalette.darkMuted
                        : AppPalette.lightMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _SmallNavButton(
            icon: Icons.chevron_left_rounded,
            tooltip: 'اليوم التالي',
            isDarkMode: isDarkMode,
            onTap: onNext,
          ),
        ],
      ),
    );
  }
}

class _SmallNavButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isDarkMode;
  final VoidCallback onTap;

  const _SmallNavButton({
    required this.icon,
    required this.tooltip,
    required this.isDarkMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDarkMode ? AppPalette.darkSurfaceAlt : AppPalette.lightSurfaceAlt,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDarkMode ? AppPalette.darkBorder : AppPalette.lightBorder,
            ),
          ),
          child: Icon(
            icon,
            size: 21,
            color: isDarkMode ? AppPalette.darkText : AppPalette.primaryDark,
          ),
        ),
      ),
    );
  }
}

/// شريط أيام الأسبوع السبعة المتجاوب (يمنع قص أو تداخل أسماء الأيام على الهواتف الصغيرة)
class ResponsiveWeekStrip extends StatelessWidget {
  final TrackerController controller;
  final List<DateTime> weekDates;

  const ResponsiveWeekStrip({
    super.key,
    required this.controller,
    required this.weekDates,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = controller.isDarkMode;
    final selectedKey = controller.selectedDateKey;
    final todayKey = controller.todayDateKey;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isVeryNarrow = constraints.maxWidth < 340;
        final dayLabels = isVeryNarrow
            ? AppStrings.weekDaysCompact
            : AppStrings.weekDaysFull;

        return Row(
          children: List.generate(7, (idx) {
            final d = weekDates[idx];
            final dKey = AppDateUtils.toDateKey(d);
            final st = controller.getDayStatsForKey(dKey);
            final isSelected = dKey == selectedKey;
            final isSysToday = dKey == todayKey;
            final hasData = st.completedCount > 0;

            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: idx < 6 ? 4 : 0),
                child: GestureDetector(
                  onTap: () => controller.selectDate(d),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppPalette.primary
                          : (isSysToday
                              ? (isDark
                                  ? AppPalette.primary.withOpacity(0.22)
                                  : const Color(0xFFE9F6F4))
                              : (isDark
                                  ? AppPalette.darkSurface
                                  : AppPalette.lightSurface)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected || isSysToday
                            ? AppPalette.primary
                            : (isDark
                                ? AppPalette.darkBorder
                                : AppPalette.lightBorder),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            dayLabels[idx],
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark
                                      ? AppPalette.darkMuted
                                      : AppPalette.lightMuted),
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${d.day}',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                            color: isSelected
                                ? Colors.white
                                : (isDark
                                    ? AppPalette.darkText
                                    : AppPalette.lightText),
                          ),
                        ),
                        const SizedBox(height: 4),
                        // مؤشر صغير لنسبة الإنجاز في ذلك اليوم
                        Container(
                          width: 16,
                          height: 3.5,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(99),
                            color: hasData
                                ? (isSelected
                                    ? AppPalette.neonMint
                                    : AppPalette.primary)
                                : (isDark
                                    ? AppPalette.darkBorder
                                    : AppPalette.lightBorder),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

/// ترويسة قسم قائمة المهام اليومية
class TasksSectionHeader extends StatelessWidget {
  final int tasksCount;
  final bool isDarkMode;
  final VoidCallback onAddTask;
  final VoidCallback onRestoreDefaults;

  const TasksSectionHeader({
    super.key,
    required this.tasksCount,
    required this.isDarkMode,
    required this.onAddTask,
    required this.onRestoreDefaults,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.checklist_rtl_rounded,
              size: 19,
              color: isDarkMode ? AppPalette.neonMint : AppPalette.primary,
            ),
            const SizedBox(width: 6),
            Text(
              'قائمة الأوراد والأعمال اليومية ($tasksCount)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color:
                    isDarkMode ? AppPalette.darkText : AppPalette.primaryDark,
              ),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton.icon(
              onPressed: onAddTask,
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
              label: const Text(
                'إضافة عمل',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              onPressed: onRestoreDefaults,
              icon: const Icon(Icons.restore_rounded, size: 18),
              tooltip: 'استعادة الأوراد الافتراضية',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ],
    );
  }
}

/// بطاقة المهمة التفاعلية الفاخرة (تمنع تداخل الكلام وتعرض العنوان كاملاً بوضوح على كل الشاشات)
class InteractiveTaskCard extends StatelessWidget {
  final TaskItem task;
  final bool isDone;
  final bool isDarkMode;
  final VoidCallback onToggle;
  final VoidCallback onEdit;

  const InteractiveTaskCard({
    super.key,
    required this.task,
    required this.isDone,
    required this.isDarkMode,
    required this.onToggle,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final surface = isDone
        ? (isDarkMode
            ? AppPalette.primary.withOpacity(0.18)
            : const Color(0xFFF1F9F7))
        : (isDarkMode ? AppPalette.darkSurface : AppPalette.lightSurface);

    final borderCol = isDone
        ? (isDarkMode
            ? AppPalette.neonMint.withOpacity(0.45)
            : AppPalette.primary.withOpacity(0.45))
        : (isDarkMode ? AppPalette.darkBorder : AppPalette.lightBorder);

    final textCol = isDarkMode ? AppPalette.darkText : AppPalette.lightText;

    return Material(
      color: surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onToggle,
        onLongPress: onEdit,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderCol, width: isDone ? 1.4 : 1.0),
          ),
          child: Row(
            children: [
              // 1. مربع الاختيار المتحرك (Checkbox)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isDone
                      ? AppPalette.primary
                      : (isDarkMode
                          ? AppPalette.darkSurfaceAlt
                          : AppPalette.lightSurfaceAlt),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDone
                        ? AppPalette.primary
                        : (isDarkMode
                            ? AppPalette.darkMuted
                            : const Color(0xFFB3C9C6)),
                    width: 1.8,
                  ),
                ),
                alignment: Alignment.center,
                child: isDone
                    ? const Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: Colors.white,
                      )
                    : null,
              ),
              const SizedBox(width: 10),

              // 2. أيقونة التصنيف وعنوان المهمة (يتمدد بحرية لعدة أسطر دون أي قص أو تداخل)
              Icon(
                task.categoryIcon,
                size: 18,
                color: isDone
                    ? (isDarkMode ? AppPalette.neonMint : AppPalette.primary)
                    : (isDarkMode ? AppPalette.darkMuted : AppPalette.lightMuted),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 13.8,
                    fontWeight: FontWeight.w700,
                    color: textCol,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // 3. شارة الدرجات وزر التعديل السريع
              GestureDetector(
                onTap: onEdit,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isDone
                        ? AppPalette.primary.withOpacity(0.15)
                        : (isDarkMode
                            ? AppPalette.darkSurfaceAlt
                            : AppPalette.lightSurfaceAlt),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: isDarkMode
                          ? AppPalette.darkBorder
                          : AppPalette.lightBorder,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${task.score} د',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: isDarkMode
                              ? AppPalette.neonMint
                              : AppPalette.primaryDark,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.edit_outlined,
                        size: 13.5,
                        color: isDarkMode
                            ? AppPalette.darkMuted
                            : AppPalette.lightMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// شريط الملخص اليومي للدرجات والنسبة المئوية
class DailyScoreSummaryCard extends StatelessWidget {
  final DayStats dayStats;
  final bool isDarkMode;

  const DailyScoreSummaryCard({
    super.key,
    required this.dayStats,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDarkMode ? AppPalette.darkSurface : AppPalette.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppPalette.primary.withOpacity(0.4),
          width: 1.2,
        ),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.workspace_premium_rounded,
                color: AppPalette.goldAccent,
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                'حصيلة اليوم: ${dayStats.earnedPoints} من ${dayStats.maxPoints} درجة',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: isDarkMode
                      ? AppPalette.darkText
                      : AppPalette.primaryDark,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppPalette.goldAccent.withOpacity(0.14),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              'نسبة الإنجاز: ${dayStats.percentage}%',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12.5,
                color: AppPalette.goldAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// حالة عدم وجود مهام
class EmptyTasksPlaceholder extends StatelessWidget {
  final bool isDarkMode;
  final VoidCallback onAddTask;
  final VoidCallback onRestoreDefaults;

  const EmptyTasksPlaceholder({
    super.key,
    required this.isDarkMode,
    required this.onAddTask,
    required this.onRestoreDefaults,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDarkMode ? AppPalette.darkSurface : AppPalette.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? AppPalette.darkBorder : AppPalette.lightBorder,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.playlist_add_check_rounded,
            size: 44,
            color: isDarkMode ? AppPalette.darkMuted : AppPalette.lightMuted,
          ),
          const SizedBox(height: 10),
          Text(
            'لا توجد أعمال يومية مضافة حالياً',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: isDarkMode ? AppPalette.darkText : AppPalette.lightText,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: onAddTask,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppPalette.primary,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('إضافة عمل جديد'),
              ),
              OutlinedButton.icon(
                onPressed: onRestoreDefaults,
                icon: const Icon(Icons.restore_rounded, size: 18),
                label: const Text('استعادة الافتراضي'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// صف أزرار الإجراءات السريعة (محمي بـ FittedBox ضد قص النصوص في الشاشات الضيقة)
class QuickActionsRow extends StatelessWidget {
  final bool isDarkMode;
  final VoidCallback onOpenWeeklySheet;
  final VoidCallback onResetWeek;

  const QuickActionsRow({
    super.key,
    required this.isDarkMode,
    required this.onOpenWeeklySheet,
    required this.onResetWeek,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onOpenWeeklySheet,
            style: OutlinedButton.styleFrom(
              backgroundColor: isDarkMode
                  ? AppPalette.darkSurface
                  : AppPalette.lightSurface,
              foregroundColor:
                  isDarkMode ? AppPalette.neonMint : AppPalette.primaryDark,
              side: BorderSide(
                color:
                    isDarkMode ? AppPalette.darkBorder : AppPalette.lightBorder,
              ),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.table_chart_outlined, size: 18),
            label: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'معاينة جدول الأسبوع',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onResetWeek,
            style: OutlinedButton.styleFrom(
              backgroundColor: isDarkMode
                  ? AppPalette.danger.withOpacity(0.12)
                  : const Color(0xFFFEF2F2),
              foregroundColor: AppPalette.danger,
              side: BorderSide(
                color: isDarkMode
                    ? AppPalette.danger.withOpacity(0.4)
                    : const Color(0xFFFECACA),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.delete_sweep_outlined, size: 18),
            label: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'بدء أسبوع جديد',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// قسم الأحاديث النبوية الشريفة بتصميم بطاقات الاقتباس
class HadithInspirationSection extends StatelessWidget {
  final bool isDarkMode;

  const HadithInspirationSection({
    super.key,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: AppStrings.hadithCollection.map((hadith) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? AppPalette.darkSurface
                  : AppPalette.lightSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border(
                right: const BorderSide(color: AppPalette.primary, width: 4),
                top: BorderSide(
                  color: isDarkMode
                      ? AppPalette.darkBorder
                      : AppPalette.lightBorder,
                ),
                left: BorderSide(
                  color: isDarkMode
                      ? AppPalette.darkBorder
                      : AppPalette.lightBorder,
                ),
                bottom: BorderSide(
                  color: isDarkMode
                      ? AppPalette.darkBorder
                      : AppPalette.lightBorder,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      hadith['title'] ?? '',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: isDarkMode
                            ? AppPalette.neonMint
                            : AppPalette.primary,
                      ),
                    ),
                    Text(
                      hadith['source'] ?? '',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode
                            ? AppPalette.darkMuted
                            : AppPalette.lightMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  hadith['text'] ?? '',
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.65,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode
                        ? AppPalette.darkText
                        : const Color(0xFF2D423F),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// شريط اختيار الشهر في الداشبورد
class MonthSelectorBar extends StatelessWidget {
  final String monthTitle;
  final bool isDarkMode;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  const MonthSelectorBar({
    super.key,
    required this.monthTitle,
    required this.isDarkMode,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDarkMode ? AppPalette.darkSurface : AppPalette.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDarkMode ? AppPalette.darkBorder : AppPalette.lightBorder,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _SmallNavButton(
            icon: Icons.chevron_right_rounded,
            tooltip: 'الشهر السابق',
            isDarkMode: isDarkMode,
            onTap: onPreviousMonth,
          ),
          Text(
            monthTitle,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDarkMode ? AppPalette.darkText : AppPalette.primaryDark,
            ),
          ),
          _SmallNavButton(
            icon: Icons.chevron_left_rounded,
            tooltip: 'الشهر التالي',
            isDarkMode: isDarkMode,
            onTap: onNextMonth,
          ),
        ],
      ),
    );
  }
}

/// شبكة بطاقات الملخص الرقمي للشهر (KPIs) المتجاوبة بالكامل (تتمدد عمودياً دون أي Overflow)
class ResponsiveKpiGrid extends StatelessWidget {
  final MonthDashboardStats stats;
  final bool isDarkMode;

  const ResponsiveKpiGrid({
    super.key,
    required this.stats,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _KpiData(
        icon: Icons.stars_rounded,
        label: 'إجمالي درجات الشهر',
        value: '${stats.earnedPoints} د',
        sub: 'من أصل ${stats.maxPoints} درجة',
      ),
      _KpiData(
        icon: Icons.pie_chart_rounded,
        label: 'متوسط الإنجاز الشهري',
        value: '${stats.overallPercentage}%',
        sub: 'أعلى يوم: ${stats.bestDayPercentage}%',
      ),
      _KpiData(
        icon: Icons.task_alt_rounded,
        label: 'الأعمال المنجزة هذا الشهر',
        value: '${stats.completedTasksCount}',
        sub: 'مهمة مكتملة بنجاح',
      ),
      _KpiData(
        icon: Icons.local_fire_department_rounded,
        label: 'أطول سلسلة التزام',
        value: '${stats.maxStreak} يوم',
        sub: 'أيام متتالية (+50%)',
      ),
    ];

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _KpiMetricCard(data: items[0], isDarkMode: isDarkMode)),
            const SizedBox(width: 10),
            Expanded(child: _KpiMetricCard(data: items[1], isDarkMode: isDarkMode)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _KpiMetricCard(data: items[2], isDarkMode: isDarkMode)),
            const SizedBox(width: 10),
            Expanded(child: _KpiMetricCard(data: items[3], isDarkMode: isDarkMode)),
          ],
        ),
      ],
    );
  }
}

class _KpiData {
  final IconData icon;
  final String label;
  final String value;
  final String sub;

  const _KpiData({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
  });
}

class _KpiMetricCard extends StatelessWidget {
  final _KpiData data;
  final bool isDarkMode;

  const _KpiMetricCard({
    required this.data,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode ? AppPalette.darkSurface : AppPalette.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDarkMode ? AppPalette.darkBorder : AppPalette.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                data.icon,
                size: 15,
                color: isDarkMode ? AppPalette.neonMint : AppPalette.primary,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  data.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.2,
                    fontWeight: FontWeight.w700,
                    color: isDarkMode
                        ? AppPalette.darkMuted
                        : AppPalette.lightMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              data.value,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color:
                    isDarkMode ? AppPalette.darkText : AppPalette.primaryDark,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            data.sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.8,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? AppPalette.neonMint : AppPalette.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// حاوية أقسام الداشبورد الموحدة
class DashboardSectionCard extends StatelessWidget {
  final String title;
  final String? trailingText;
  final bool isDarkMode;
  final Widget child;

  const DashboardSectionCard({
    super.key,
    required this.title,
    this.trailingText,
    required this.isDarkMode,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDarkMode ? AppPalette.darkSurface : AppPalette.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? AppPalette.darkBorder : AppPalette.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isDarkMode
                      ? AppPalette.darkText
                      : AppPalette.primaryDark,
                ),
              ),
              if (trailingText != null)
                Text(
                  trailingText!,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode
                        ? AppPalette.darkMuted
                        : AppPalette.lightMuted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// الرسم البياني لمنحنى الإنجاز اليومي خلال الشهر
class MonthlyBarChartWidget extends StatelessWidget {
  final List<int> dailyPercentages;
  final bool isDarkMode;

  const MonthlyBarChartWidget({
    super.key,
    required this.dailyPercentages,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(dailyPercentages.length, (index) {
        final dayNum = index + 1;
        final perc = dailyPercentages[index].clamp(0, 100);
        final showLabel =
            dayNum == 1 || dayNum % 5 == 0 || dayNum == dailyPercentages.length;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.2),
            child: Tooltip(
              message: 'يوم $dayNum: $perc%',
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: math.max(perc / 100.0, 0.05),
                        child: Container(
                          decoration: BoxDecoration(
                            color: perc == 0
                                ? (isDarkMode
                                    ? AppPalette.darkBorder
                                    : const Color(0xFFE3ECEB))
                                : (isDarkMode
                                    ? AppPalette.neonMint
                                    : AppPalette.primary),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 12,
                    child: showLabel
                        ? FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '$dayNum',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: isDarkMode
                                    ? AppPalette.darkMuted
                                    : AppPalette.lightMuted,
                              ),
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// خريطة أيام الشهر الحرارية (محمية بـ FittedBox لمنع تداخل الأرقام على الشاشات الصغيرة)
class MonthlyHeatmapCalendar extends StatelessWidget {
  final int year;
  final int month;
  final int daysInMonth;
  final TrackerController controller;

  const MonthlyHeatmapCalendar({
    super.key,
    required this.year,
    required this.month,
    required this.daysInMonth,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = controller.isDarkMode;
    final firstDayOfMonth = DateTime(year, month, 1);
    final startOffset =
        AppDateUtils.getSaturdayBasedWeekdayIndex(firstDayOfMonth);

    final List<Widget> cells = [];

    for (int i = 0; i < startOffset; i++) {
      cells.add(const SizedBox.shrink());
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final dObj = DateTime(year, month, day);
      final dKey = AppDateUtils.toDateKey(dObj);
      final st = controller.getDayStatsForKey(dKey);

      Color cellBg;
      Color cellText;
      if (st.percentage >= 85) {
        cellBg = const Color(0xFF00B884);
        cellText = Colors.white;
      } else if (st.percentage >= 60) {
        cellBg = AppPalette.primary;
        cellText = Colors.white;
      } else if (st.percentage >= 30) {
        cellBg = const Color(0xFF82DEC9);
        cellText = const Color(0xFF0D3B32);
      } else if (st.percentage > 0) {
        cellBg = isDark ? const Color(0xFF1E4A42) : const Color(0xFFD8F3EC);
        cellText = isDark ? AppPalette.neonMint : const Color(0xFF165246);
      } else {
        cellBg = isDark ? AppPalette.darkSurfaceAlt : AppPalette.lightSurfaceAlt;
        cellText = isDark ? AppPalette.darkMuted : const Color(0xFF7B8E8D);
      }

      cells.add(
        InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: () =>
              controller.openDayFromMonthlyDashboard(year, month, day),
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: cellBg,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: isDark ? AppPalette.darkBorder : const Color(0xFFE1ECEA),
              ),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$day',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: cellText,
                    ),
                  ),
                  Text(
                    '${st.percentage}%',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: cellText.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: AppStrings.weekDaysCompact
              .map(
                (wName) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        wName,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppPalette.darkMuted
                              : AppPalette.lightMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 5,
          crossAxisSpacing: 5,
          children: cells,
        ),
      ],
    );
  }
}

/// سطر أداء المهمة الواحدة في الشهر
class TaskMonthlyPerformanceTile extends StatelessWidget {
  final TaskMonthlyPerformance performance;
  final bool isDarkMode;

  const TaskMonthlyPerformanceTile({
    super.key,
    required this.performance,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final t = performance.task;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 2,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    t.categoryIcon,
                    size: 15,
                    color:
                        isDarkMode ? AppPalette.neonMint : AppPalette.primary,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '${t.title} (${t.score} د)',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: isDarkMode
                            ? AppPalette.darkText
                            : AppPalette.lightText,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                '${performance.completedDays}/${performance.totalDaysInMonth} يوم · ${performance.earnedScore} د (${performance.percentage}%)',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: isDarkMode
                      ? AppPalette.neonMint
                      : AppPalette.primaryDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: (performance.percentage.clamp(0, 100)) / 100.0,
              minHeight: 7,
              backgroundColor: isDarkMode
                  ? AppPalette.darkBorder
                  : const Color(0xFFE6F0EE),
              valueColor: AlwaysStoppedAnimation<Color>(
                isDarkMode ? AppPalette.neonMint : AppPalette.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// بطاقة حفظ اسم المستخدم السفلية
class UserProfileFooterCard extends StatelessWidget {
  final TextEditingController controller;
  final bool isDarkMode;
  final ValueChanged<String> onChanged;

  const UserProfileFooterCard({
    super.key,
    required this.controller,
    required this.isDarkMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDarkMode ? AppPalette.darkSurface : AppPalette.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDarkMode ? AppPalette.darkBorder : AppPalette.lightBorder,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.person_outline_rounded,
            size: 20,
            color: isDarkMode ? AppPalette.neonMint : AppPalette.primary,
          ),
          const SizedBox(width: 8),
          Text(
            'الاسم:',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: isDarkMode ? AppPalette.darkText : AppPalette.lightText,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDarkMode
                    ? AppPalette.neonMint
                    : AppPalette.primaryDark,
              ),
              decoration: InputDecoration(
                hintText: 'اكتب اسمك ليظهر في الجدول الأسبوعي...',
                hintStyle: TextStyle(
                  fontSize: 12.5,
                  color: isDarkMode
                      ? AppPalette.darkMuted
                      : AppPalette.lightMuted,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 9. MODALS & DIALOGS: النوافذ المنبثقة لإدارة المهام ومعاينة جدول الأسبوع
// ============================================================================

/// نافذة إضافة أو تعديل مهمة
class TaskEditorSheet extends StatefulWidget {
  final TaskItem? existingTask;
  final void Function(String title, int score) onSave;
  final VoidCallback? onDelete;

  const TaskEditorSheet({
    super.key,
    this.existingTask,
    required this.onSave,
    this.onDelete,
  });

  @override
  State<TaskEditorSheet> createState() => _TaskEditorSheetState();
}

class _TaskEditorSheetState extends State<TaskEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _scoreCtrl;

  bool get _isEditing => widget.existingTask != null;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(
      text: _isEditing ? widget.existingTask!.title : '',
    );
    _scoreCtrl = TextEditingController(
      text: _isEditing ? widget.existingTask!.score.toString() : '10',
    );
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _scoreCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg =
        isDark ? AppPalette.darkSurface : AppPalette.lightSurface;
    final borderCol =
        isDark ? AppPalette.darkBorder : AppPalette.lightBorder;
    final textCol = isDark ? AppPalette.darkText : AppPalette.lightText;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Container(
            decoration: BoxDecoration(
              color: sheetBg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: borderCol),
            ),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: borderCol,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _isEditing
                              ? 'تعديل العمل والدرجة'
                              : 'إضافة عمل يومي جديد',
                          style: TextStyle(
                            fontSize: 17.5,
                            fontWeight: FontWeight.w800,
                            color: textCol,
                          ),
                        ),
                      ),
                      if (_isEditing && widget.onDelete != null)
                        IconButton(
                          onPressed: () {
                            Navigator.pop(context);
                            widget.onDelete!();
                          },
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: AppPalette.danger,
                          ),
                          tooltip: 'حذف المهمة',
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _titleCtrl,
                    autofocus: true,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: textCol,
                    ),
                    decoration: InputDecoration(
                      labelText: 'عنوان العمل اليومي',
                      hintText: 'مثال: صلاة الضحى، قراءة جزء، صدقة...',
                      prefixIcon: const Icon(Icons.task_alt_rounded),
                      filled: true,
                      fillColor: isDark
                          ? AppPalette.darkSurfaceAlt
                          : AppPalette.lightSurfaceAlt,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: borderCol),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'يرجى كتابة عنوان العمل اليومي';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _scoreCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: textCol,
                    ),
                    decoration: InputDecoration(
                      labelText: 'درجة العمل (نقاط الإنجاز)',
                      hintText: 'مثال: 15',
                      suffixText: 'درجة',
                      prefixIcon: const Icon(Icons.stars_rounded),
                      filled: true,
                      fillColor: isDark
                          ? AppPalette.darkSurfaceAlt
                          : AppPalette.lightSurfaceAlt,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: borderCol),
                      ),
                    ),
                    validator: (val) {
                      final parsed = int.tryParse(val?.trim() ?? '');
                      if (parsed == null || parsed <= 0) {
                        return 'يرجى إدخال درجة صحيحة أكبر من صفر';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [5, 7, 10, 15, 20, 30].map((quickScore) {
                      return ActionChip(
                        label: Text('$quickScore د'),
                        onPressed: () {
                          _scoreCtrl.text = quickScore.toString();
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'إلغاء',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (!_formKey.currentState!.validate()) return;
                            widget.onSave(
                              _titleCtrl.text.trim(),
                              int.parse(_scoreCtrl.text.trim()),
                            );
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppPalette.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: Icon(
                            _isEditing ? Icons.check_rounded : Icons.add,
                          ),
                          label: Text(
                            _isEditing ? 'حفظ التعديلات' : 'إضافة العمل',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// نافذة التأكيد الموحدة
class AppConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final bool isDestructive;

  const AppConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.isDestructive,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        content: Text(
          message,
          style: const TextStyle(height: 1.5, fontSize: 13.8),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isDestructive ? AppPalette.danger : AppPalette.primary,
              foregroundColor: Colors.white,
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }
}

/// نافذة معاينة جدول الأسبوع التفاعلي الكامل
class WeeklyMatrixSheet extends StatelessWidget {
  final TrackerController controller;

  const WeeklyMatrixSheet({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final isDark = controller.isDarkMode;
        final bg = isDark ? AppPalette.darkSurface : AppPalette.lightSurface;
        final borderCol =
            isDark ? AppPalette.darkBorder : AppPalette.lightBorder;
        final textCol = isDark ? AppPalette.darkText : AppPalette.lightText;
        final weekStats = controller.selectedWeekStats;
        final rangeText = AppDateUtils.formatWeekRange(weekStats.weekDates);

        return Directionality(
          textDirection: TextDirection.rtl,
          child: DraggableScrollableSheet(
            initialChildSize: 0.86,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (_, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                  border: Border.all(color: borderCol),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'معاينة جدول الأسبوع الكامل',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: textCol,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                rangeText,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? AppPalette.darkMuted
                                      : AppPalette.lightMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: scrollController,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: _FullWeekInteractiveTable(
                            controller: controller,
                            weekDates: weekStats.weekDates,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppPalette.darkSurfaceAlt
                            : AppPalette.lightSurfaceAlt,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderCol),
                      ),
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        spacing: 12,
                        runSpacing: 6,
                        children: [
                          Text(
                            'الاسم: ${controller.userName.trim().isEmpty ? "غير محدد" : controller.userName.trim()}',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12.8,
                              color: textCol,
                            ),
                          ),
                          Text(
                            'إجمالي الأسبوع: ${weekStats.earnedPoints} / ${weekStats.maxPoints} درجة (${weekStats.percentage}%)',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12.8,
                              color: isDark
                                  ? AppPalette.neonMint
                                  : AppPalette.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _FullWeekInteractiveTable extends StatelessWidget {
  final TrackerController controller;
  final List<DateTime> weekDates;

  const _FullWeekInteractiveTable({
    required this.controller,
    required this.weekDates,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = controller.isDarkMode;
    final borderCol = isDark ? AppPalette.darkBorder : AppPalette.lightBorder;
    final headerBg =
        isDark ? const Color(0xFF1A3A35) : const Color(0xFFE2F0ED);
    final textCol = isDark ? AppPalette.darkText : AppPalette.lightText;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: borderCol),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Table(
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        columnWidths: const {
          0: FixedColumnWidth(195),
          1: FixedColumnWidth(50),
          2: FixedColumnWidth(62),
          3: FixedColumnWidth(62),
          4: FixedColumnWidth(62),
          5: FixedColumnWidth(62),
          6: FixedColumnWidth(62),
          7: FixedColumnWidth(62),
          8: FixedColumnWidth(62),
        },
        border: TableBorder.all(color: borderCol, width: 1),
        children: [
          TableRow(
            decoration: BoxDecoration(color: headerBg),
            children: [
              Container(
                color: AppPalette.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: const Text(
                  'العمل اليومي',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'د',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                ),
              ),
              ...List.generate(7, (idx) {
                final d = weekDates[idx];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: [
                      Text(
                        AppStrings.weekDaysFull[idx],
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 11.5,
                          color: textCol,
                        ),
                      ),
                      Text(
                        '${d.day}/${d.month}',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: isDark
                              ? AppPalette.darkMuted
                              : AppPalette.lightMuted,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
          ...controller.tasks.map((task) {
            return TableRow(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Text(
                    task.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: textCol,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    '${task.score}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: isDark
                          ? AppPalette.neonMint
                          : AppPalette.primaryDark,
                    ),
                  ),
                ),
                ...weekDates.map((d) {
                  final dKey = AppDateUtils.toDateKey(d);
                  final done = controller.isTaskDone(dKey, task.id);
                  return InkWell(
                    onTap: () => controller.toggleTaskForDate(dKey, task.id),
                    child: Container(
                      height: 36,
                      alignment: Alignment.center,
                      color: done
                          ? AppPalette.primary
                              .withOpacity(isDark ? 0.25 : 0.12)
                          : Colors.transparent,
                      child: done
                          ? Icon(
                              Icons.check_rounded,
                              size: 18,
                              color: isDark
                                  ? AppPalette.neonMint
                                  : AppPalette.primary,
                            )
                          : null,
                    ),
                  );
                }),
              ],
            );
          }),
          // صف المجموع بالدرجات
          TableRow(
            decoration: BoxDecoration(
              color:
                  isDark ? const Color(0xFF183833) : const Color(0xFFE9F4F2),
            ),
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Text(
                  'المجموع (درجات)',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '${controller.maxDailyScore}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              ...weekDates.map((d) {
                final st =
                    controller.getDayStatsForKey(AppDateUtils.toDateKey(d));
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    '${st.earnedPoints}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: isDark
                          ? AppPalette.neonMint
                          : AppPalette.primaryDark,
                    ),
                  ),
                );
              }),
            ],
          ),
          // صف النسبة المئوية
          TableRow(
            decoration: BoxDecoration(
              color:
                  isDark ? const Color(0xFF2B2212) : const Color(0xFFFFFBEB),
            ),
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Text(
                  'النسبة المئوية',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: AppPalette.goldAccent,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '%',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: AppPalette.goldAccent,
                  ),
                ),
              ),
              ...weekDates.map((d) {
                final st =
                    controller.getDayStatsForKey(AppDateUtils.toDateKey(d));
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    '${st.percentage}%',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: AppPalette.goldAccent,
                    ),
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 10. رسام الزخرفة الهندسية الإسلامية الخلفية
// ============================================================================

class _GeometricStarsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.045)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    const double step = 56.0;
    for (double x = 28; x < size.width + step; x += step) {
      for (double y = 28; y < size.height + step; y += step) {
        _drawStar(canvas, Offset(x, y), 18, 8, paint);
      }
    }
  }

  void _drawStar(
    Canvas canvas,
    Offset center,
    double outerR,
    double innerR,
    Paint paint,
  ) {
    final path = Path();
    const int points = 8; // نجمة ثمانية إسلامية
    for (int i = 0; i < points * 2; i++) {
      final r = (i.isEven) ? outerR : innerR;
      final angle = (i * math.pi / points) - (math.pi / 2);
      final pt = Offset(
        center.dx + r * math.cos(angle),
        center.dy + r * math.sin(angle),
      );
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
