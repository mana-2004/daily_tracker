import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DailyTrackerApp());
}

// ==================== نماذج البيانات (Models) ====================

class TaskItem {
  final int id;
  String title;
  int score; // الدرجات المخصصة للمهمة بدلاً من الدقائق

  TaskItem({
    required this.id,
    required this.title,
    required this.score,
  });

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
}

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

// ==================== الثيمات والألوان (Light & Dark Themes) ====================

class AppColors {
  // ألوان الهوية الأساسية
  static const Color primary = Color(0xFF26756F);
  static const Color primaryDark = Color(0xFF133935);
  static const Color primaryDeeper = Color(0xFF0D2724);
  static const Color neonMint = Color(0xFF00E6A8);
  static const Color neonMintGlow = Color(0xFF38F9D7);
  static const Color danger = Color(0xFFD93838);
  static const Color amber = Color(0xFFD97706);

  // ألوان الوضع النهاري
  static const Color lightBg = Color(0xFFEEF3F2);
  static const Color lightPaper = Color(0xFFFFFFFF);
  static const Color lightCardAlt = Color(0xFFF5FAF9);
  static const Color lightBorder = Color(0xFFCBD8D7);
  static const Color lightText = Color(0xFF1F2E30);
  static const Color lightMuted = Color(0xFF647778);

  // ألوان الوضع الليلي
  static const Color darkBg = Color(0xFF0B1917);
  static const Color darkPaper = Color(0xFF122623);
  static const Color darkCardAlt = Color(0xFF17312D);
  static const Color darkBorder = Color(0xFF234741);
  static const Color darkText = Color(0xFFE6F4F1);
  static const Color darkMuted = Color(0xFF8AB2AC);
}

// ==================== التطبيق الرئيسي ====================

class DailyTrackerApp extends StatefulWidget {
  const DailyTrackerApp({super.key});

  @override
  State<DailyTrackerApp> createState() => _DailyTrackerAppState();
}

class _DailyTrackerAppState extends State<DailyTrackerApp> {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isDark = prefs.getBool('tracker_dark_mode') ?? false;
      setState(() {
        _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
      });
    } catch (_) {}
  }

  Future<void> _toggleTheme() async {
    final newIsDark = _themeMode != ThemeMode.dark;
    setState(() {
      _themeMode = newIsDark ? ThemeMode.dark : ThemeMode.light;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('tracker_dark_mode', newIsDark);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'جدول الأعمال اليومية والداشبورد الشهري',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.lightBg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
          primary: AppColors.primary,
          surface: AppColors.lightPaper,
        ),
        cardColor: AppColors.lightPaper,
        dividerColor: AppColors.lightBorder,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.darkBg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.neonMint,
          brightness: Brightness.dark,
          primary: AppColors.neonMint,
          surface: AppColors.darkPaper,
        ),
        cardColor: AppColors.darkPaper,
        dividerColor: AppColors.darkBorder,
      ),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      home: HomeScreen(
        isDarkMode: _themeMode == ThemeMode.dark,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}

// ==================== الشاشة الرئيسية للتطبيق ====================

class HomeScreen extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  const HomeScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const List<String> _weekDaysAr = [
    'السبت',
    'الأحد',
    'الإثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
  ];

  static const List<String> _monthsAr = [
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

  // القائمة الافتراضية للأعمال اليومية بالدرجات
  static List<TaskItem> _defaultTasks() => [
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
        TaskItem(id: 12, title: 'ورد القرآن', score: 30),
        TaskItem(id: 13, title: 'الاستغفار', score: 10),
        TaskItem(id: 14, title: 'الصلاة على النبي ﷺ', score: 10),
        TaskItem(id: 15, title: 'فينا خير', score: 10),
      ];

  int _currentTabIndex = 0; // 0 = جدول اليوم، 1 = إحصائيات الشهر
  late DateTime _systemToday;
  late DateTime _selectedDate;
  late DateTime _dashboardMonthDate;

  List<TaskItem> _tasks = [];
  // السجلات المحفوظة: { "YYYY-MM-DD": { "0": true, "1": false } }
  Map<String, Map<int, bool>> _recordsByDate = {};
  final TextEditingController _userNameController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _systemToday = DateTime(now.year, now.month, now.day);
    _selectedDate = _systemToday;
    _dashboardMonthDate = DateTime(now.year, now.month, 1);
    _loadData();
  }

  @override
  void dispose() {
    _userNameController.dispose();
    super.dispose();
  }

  // ==================== إدارة التخزين المحلي (SharedPreferences) ====================

  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. تحميل المهام المخصصة أو الافتراضية
      final tasksJsonStr = prefs.getString('tracker_custom_tasks_v1');
      if (tasksJsonStr != null && tasksJsonStr.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(tasksJsonStr);
        _tasks = decoded
            .map((item) => TaskItem.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      } else {
        _tasks = _defaultTasks();
      }

      // 2. تحميل سجلات الإنجاز حسب التاريخ
      final recordsJsonStr = prefs.getString('tracker_records_by_date_v2');
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
        _recordsByDate = parsedRecords;
      }

      // 3. تحميل اسم المستخدم
      final savedName = prefs.getString('tracker_user_name') ?? '';
      _userNameController.text = savedName;
    } catch (_) {
      _tasks = _defaultTasks();
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_tasks.map((t) => t.toJson()).toList());
      await prefs.setString('tracker_custom_tasks_v1', encoded);
    } catch (_) {}
  }

  Future<void> _saveRecords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, Map<String, bool>> serializable = {};
      _recordsByDate.forEach((dateKey, taskMap) {
        serializable[dateKey] =
            taskMap.map((key, value) => MapEntry(key.toString(), value));
      });
      await prefs.setString(
          'tracker_records_by_date_v2', jsonEncode(serializable));
    } catch (_) {}
  }

  Future<void> _saveUserName(String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('tracker_user_name', value);
    } catch (_) {}
  }

  // ==================== الحسابات الديناميكية للدرجات والإحصائيات ====================

  /// إجمالي الدرجات اليومية القصوى بناءً على المهام الحالية التي يضعها المستخدم
  int get maxDailyScore =>
      _tasks.fold<int>(0, (sum, item) => sum + item.score);

  /// إجمالي الدرجات الأسبوعية القصوى (7 أيام)
  int get maxWeeklyScore => maxDailyScore * 7;

  String _toDateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// تحويل يوم الأسبوع بحيث يبدأ الأسبوع يوم السبت (السبت = 0 ... الجمعة = 6)
  int _getSatWeekIndex(DateTime date) {
    // في Dart: الإثنين=1 .. السبت=6، الأحد=7
    return (date.weekday + 1) % 7;
  }

  List<DateTime> _getWeekDates(DateTime referenceDate) {
    final satOffset = _getSatWeekIndex(referenceDate);
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

  bool _isTaskDone(String dateKey, int taskId) {
    return _recordsByDate[dateKey]?[taskId] == true;
  }

  void _toggleTaskForDate(String dateKey, int taskId) {
    HapticFeedback.lightImpact();
    setState(() {
      final dayRecord = _recordsByDate.putIfAbsent(dateKey, () => {});
      final current = dayRecord[taskId] ?? false;
      dayRecord[taskId] = !current;
    });
    _saveRecords();
  }

  DayStats _getDayStats(String dateKey) {
    int earned = 0;
    int count = 0;
    for (final task in _tasks) {
      if (_isTaskDone(dateKey, task.id)) {
        earned += task.score;
        count++;
      }
    }
    final maxPts = maxDailyScore;
    final perc = maxPts > 0 ? ((earned / maxPts) * 100).round() : 0;
    return DayStats(
      earnedPoints: earned,
      maxPoints: maxPts,
      completedCount: count,
      totalTasksCount: _tasks.length,
      percentage: perc,
    );
  }

  WeekStats _getWeekStats(DateTime refDate) {
    final weekDates = _getWeekDates(refDate);
    int weekEarned = 0;
    int weekCount = 0;
    for (final d in weekDates) {
      final st = _getDayStats(_toDateKey(d));
      weekEarned += st.earnedPoints;
      weekCount += st.completedCount;
    }
    final maxWeek = maxWeeklyScore;
    final weekPerc = maxWeek > 0 ? ((weekEarned / maxWeek) * 100).round() : 0;
    return WeekStats(
      earnedPoints: weekEarned,
      maxPoints: maxWeek,
      completedCount: weekCount,
      percentage: weekPerc,
      weekDates: weekDates,
    );
  }

  String _getMotivationText(int perc) {
    if (_tasks.isEmpty) return 'أضف مهامك اليومية للبدء في حساب درجاتك';
    if (perc == 100) return 'ما شاء الله! أتممت ورد اليوم كاملاً';
    if (perc >= 75) return 'همة عالية، بقي القليل على التمام';
    if (perc >= 40) return 'تقدم مبارك، واصل الثبات';
    if (perc > 0) return 'بداية طيبة، بارك الله في سعيك';
    return 'ابدأ يومك بذكر الله';
  }

  // ==================== إدارة المهام (إضافة / تعديل / حذف / استعادة) ====================

  Future<void> _showTaskFormSheet({TaskItem? existingTask}) async {
    final isEditing = existingTask != null;
    final titleCtrl =
        TextEditingController(text: isEditing ? existingTask.title : '');
    final scoreCtrl = TextEditingController(
        text: isEditing ? existingTask.score.toString() : '10');
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final sheetBg = isDark ? AppColors.darkPaper : AppColors.lightPaper;
        final borderCol = isDark ? AppColors.darkBorder : AppColors.lightBorder;
        final textCol = isDark ? AppColors.darkText : AppColors.lightText;

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: sheetBg,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: borderCol),
              ),
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              child: Form(
                key: formKey,
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
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isEditing ? 'تعديل المهمة والدرجة' : 'إضافة مهمة جديدة',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: textCol,
                          ),
                        ),
                        if (isEditing)
                          IconButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _confirmDeleteTask(existingTask);
                            },
                            icon: const Icon(Icons.delete_outline_rounded,
                                color: AppColors.danger),
                            tooltip: 'حذف المهمة',
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: titleCtrl,
                      autofocus: true,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: textCol,
                      ),
                      decoration: InputDecoration(
                        labelText: 'عنوان العمل اليومي',
                        hintText: 'مثال: صلاة الضحى، قراءة جزء، صدقة...',
                        prefixIcon: const Icon(Icons.task_alt_rounded),
                        filled: true,
                        fillColor: isDark
                            ? AppColors.darkCardAlt
                            : AppColors.lightCardAlt,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: borderCol),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'يرجى كتابة اسم المهمة';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: scoreCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: textCol,
                      ),
                      decoration: InputDecoration(
                        labelText: 'درجة المهمة (نقاط الإنجاز)',
                        hintText: 'مثال: 15',
                        suffixText: 'درجة',
                        prefixIcon: const Icon(Icons.stars_rounded),
                        filled: true,
                        fillColor: isDark
                            ? AppColors.darkCardAlt
                            : AppColors.lightCardAlt,
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
                      children: [5, 7, 10, 15, 20, 30].map((quickScore) {
                        return ActionChip(
                          label: Text('$quickScore د'),
                          onPressed: () {
                            scoreCtrl.text = quickScore.toString();
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
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
                              if (!formKey.currentState!.validate()) return;
                              final newTitle = titleCtrl.text.trim();
                              final newScore =
                                  int.parse(scoreCtrl.text.trim());

                              setState(() {
                                if (isEditing) {
                                  existingTask.title = newTitle;
                                  existingTask.score = newScore;
                                } else {
                                  final nextId = _tasks.isEmpty
                                      ? 0
                                      : (_tasks
                                              .map((t) => t.id)
                                              .reduce(math.max) +
                                          1);
                                  _tasks.add(TaskItem(
                                    id: nextId,
                                    title: newTitle,
                                    score: newScore,
                                  ));
                                }
                              });
                              _saveTasks();
                              Navigator.pop(ctx);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: Icon(
                                isEditing ? Icons.check_rounded : Icons.add),
                            label: Text(
                              isEditing ? 'حفظ التعديلات' : 'إضافة المهمة',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800),
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
        );
      },
    );
  }

  Future<void> _confirmDeleteTask(TaskItem task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'حذف المهمة',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: Text(
            'هل أنت متأكد من حذف "${task.title}" (${task.score} د)؟ سيتم إعادة حساب جميع النسب والدرجات تلقائياً.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
              ),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      setState(() {
        _tasks.removeWhere((t) => t.id == task.id);
      });
      _saveTasks();
    }
  }

  Future<void> _confirmRestoreDefaultTasks() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'استعادة المهام الافتراضية',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: const Text(
            'هل ترغب في استعادة قائمة الأعمال الافتراضية (16 مهمة بإجمالي 205 درجة)؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('استعادة'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      setState(() {
        _tasks = _defaultTasks();
      });
      _saveTasks();
    }
  }

  Future<void> _confirmResetWeek() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'بدء أسبوع جديد',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: const Text(
            'هل أنت متأكد من رغبتك في مسح جميع علامات هذا الأسبوع للبدء من جديد؟ (لن يتم مسح اسمك أو سجلات الأسابيع الأخرى أو مهامك المخصصة)',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
              ),
              child: const Text('نعم، مسح الأسبوع'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      final weekDates = _getWeekDates(_selectedDate);
      setState(() {
        for (final d in weekDates) {
          _recordsByDate.remove(_toDateKey(d));
        }
      });
      _saveRecords();
    }
  }

  // ==================== نافذة معاينة جدول الأسبوع الكامل ====================

  void _showWeeklyPreviewModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final bg = isDark ? AppColors.darkPaper : AppColors.lightPaper;
            final borderCol =
                isDark ? AppColors.darkBorder : AppColors.lightBorder;
            final textCol = isDark ? AppColors.darkText : AppColors.lightText;
            final weekStats = _getWeekStats(_selectedDate);
            final firstDay = weekStats.weekDates.first;
            final lastDay = weekStats.weekDates.last;
            final rangeText =
                'من السبت ${firstDay.day} ${_monthsAr[firstDay.month - 1]} إلى الجمعة ${lastDay.day} ${_monthsAr[lastDay.month - 1]} ${lastDay.year}';

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
                                  Text(
                                    rangeText,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? AppColors.darkMuted
                                          : AppColors.lightMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(ctx),
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
                              child: _buildFullWeekInteractiveTable(
                                weekStats.weekDates,
                                onToggleCell: (dateKey, taskId) {
                                  _toggleTaskForDate(dateKey, taskId);
                                  setModalState(() {});
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkCardAlt
                                : AppColors.lightCardAlt,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderCol),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'الاسم: ${_userNameController.text.trim().isEmpty ? "غير محدد" : _userNameController.text.trim()}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: textCol,
                                ),
                              ),
                              Text(
                                'إجمالي الأسبوع: ${weekStats.earnedPoints} / ${weekStats.maxPoints} درجة (${weekStats.percentage}%)',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: isDark
                                      ? AppColors.neonMint
                                      : AppColors.primary,
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
      },
    );
  }

  Widget _buildFullWeekInteractiveTable(
    List<DateTime> weekDates, {
    required void Function(String dateKey, int taskId) onToggleCell,
  }) {
    final isDark = widget.isDarkMode;
    final borderCol = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final headerBg = isDark ? const Color(0xFF1A3A35) : const Color(0xFFE2F0ED);
    final textCol = isDark ? AppColors.darkText : AppColors.lightText;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: borderCol),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Table(
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        columnWidths: const {
          0: FixedColumnWidth(210),
          1: FixedColumnWidth(54),
          2: FixedColumnWidth(66),
          3: FixedColumnWidth(66),
          4: FixedColumnWidth(66),
          5: FixedColumnWidth(66),
          6: FixedColumnWidth(66),
          7: FixedColumnWidth(66),
          8: FixedColumnWidth(66),
        },
        border: TableBorder.all(color: borderCol, width: 1),
        children: [
          // صف الترويسة
          TableRow(
            decoration: BoxDecoration(color: headerBg),
            children: [
              Container(
                color: AppColors.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: const Text(
                  'العمل',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'د',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
              ...List.generate(7, (idx) {
                final d = weekDates[idx];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: [
                      Text(
                        _weekDaysAr[idx],
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: textCol,
                        ),
                      ),
                      Text(
                        '${d.day}/${d.month}',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: isDark
                              ? AppColors.darkMuted
                              : AppColors.lightMuted,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
          // صفوف المهام
          ..._tasks.map((task) {
            return TableRow(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Text(
                    task.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
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
                      fontSize: 12.5,
                      color: isDark ? AppColors.neonMint : AppColors.primaryDark,
                    ),
                  ),
                ),
                ...weekDates.map((d) {
                  final dKey = _toDateKey(d);
                  final done = _isTaskDone(dKey, task.id);
                  return InkWell(
                    onTap: () => onToggleCell(dKey, task.id),
                    child: Container(
                      height: 36,
                      alignment: Alignment.center,
                      color: done
                          ? AppColors.primary.withOpacity(isDark ? 0.25 : 0.1)
                          : Colors.transparent,
                      child: Text(
                        done ? '✓' : '',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color:
                              isDark ? AppColors.neonMint : AppColors.primary,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            );
          }),
          // صف المجموع بالدرجات
          TableRow(
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF183833)
                  : const Color(0xFFE9F4F2),
            ),
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Text(
                  'المجموع (درجات)',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '$maxDailyScore',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 12.5),
                ),
              ),
              ...weekDates.map((d) {
                final st = _getDayStats(_toDateKey(d));
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    '${st.earnedPoints}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                      color: isDark ? AppColors.neonMint : AppColors.primaryDark,
                    ),
                  ),
                );
              }),
            ],
          ),
          // صف النسبة المئوية
          TableRow(
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF2B2212)
                  : const Color(0xFFFFFBEB),
            ),
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Text(
                  'النسبة المئوية',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                    color: AppColors.amber,
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
                    fontSize: 12.5,
                    color: AppColors.amber,
                  ),
                ),
              ),
              ...weekDates.map((d) {
                final st = _getDayStats(_toDateKey(d));
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    '${st.percentage}%',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                      color: AppColors.amber,
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

  // ==================== بناء الواجهة الرئيسية ====================

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isDark = widget.isDarkMode;
    final paperColor = isDark ? AppColors.darkPaper : AppColors.lightPaper;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Scaffold(
      floatingActionButton: _currentTabIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () => _showTaskFormSheet(),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 4,
              icon: const Icon(Icons.add_task_rounded),
              label: const Text(
                'إضافة مهمة',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            )
          : null,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
              child: Container(
                decoration: BoxDecoration(
                  color: paperColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTopBarAndTabs(),
                    const SizedBox(height: 14),
                    _buildVerseBanner(),
                    const SizedBox(height: 14),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: _currentTabIndex == 0
                          ? _buildDailyView()
                          : _buildMonthlyDashboardView(),
                    ),
                    const SizedBox(height: 16),
                    _buildFooterNameField(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // شريط التبديل العلوي + زر الوضع الليلي
  Widget _buildTopBarAndTabs() {
    final isDark = widget.isDarkMode;
    final navBg = isDark ? const Color(0xFF0E201D) : const Color(0xFFE3EEEC);

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: navBg,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildTabButton(
                    index: 0,
                    title: 'جدول اليوم',
                    icon: Icons.calendar_today_rounded,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildTabButton(
                    index: 1,
                    title: 'إحصائيات الشهر',
                    icon: Icons.bar_chart_rounded,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Material(
          color: navBg,
          borderRadius: BorderRadius.circular(13),
          child: InkWell(
            borderRadius: BorderRadius.circular(13),
            onTap: widget.onToggleTheme,
            child: Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              child: Icon(
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                color: isDark ? AppColors.neonMint : AppColors.primaryDark,
                size: 22,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabButton({
    required int index,
    required String title,
    required IconData icon,
  }) {
    final isSelected = _currentTabIndex == index;
    final isDark = widget.isDarkMode;

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentTabIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.primary : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 17,
              color: isSelected
                  ? (isDark ? Colors.white : AppColors.primary)
                  : (isDark ? AppColors.darkMuted : AppColors.primaryDark),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: isSelected
                      ? (isDark ? Colors.white : AppColors.primary)
                      : (isDark ? AppColors.darkMuted : AppColors.primaryDark),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // صندوق الآية القرآنية
  Widget _buildVerseBanner() {
    final isDark = widget.isDarkMode;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardAlt : AppColors.lightCardAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFB9D9D4),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 3.5,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.neonMint : AppColors.primary,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Text(
            '﴿ وَاتَّقُوا يَوْمًا تُرْجَعُونَ فِيهِ إِلَى اللَّهِ ثُمَّ تُوَفَّى كُلُّ نَفْسٍ مَا كَسَبَتْ وَهُمْ لَا يُظْلَمُونَ ﴾',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17.5,
              fontWeight: FontWeight.w700,
              height: 1.65,
              color: isDark ? AppColors.darkText : AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.primary.withOpacity(0.3)
                      : const Color(0xFFE6F3F0),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color:
                        isDark ? AppColors.neonMint.withOpacity(0.4) : const Color(0xFFB9D9D4),
                  ),
                ),
                child: Text(
                  '[المستوى الأول]',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.neonMint : AppColors.primaryDark,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.primary.withOpacity(0.2)
                      : const Color(0xFFE6F3F0),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'مجموع الدرجات اليومي: $maxDailyScore د',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkMuted : AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== القسم الأول: عرض اليوم الواحد ====================

  Widget _buildDailyView() {
    final dateKey = _toDateKey(_selectedDate);
    final todayKey = _toDateKey(_systemToday);
    final dayStats = _getDayStats(dateKey);
    final weekStats = _getWeekStats(_selectedDate);
    final dayIndex = _getSatWeekIndex(_selectedDate);
    final dayName = _weekDaysAr[dayIndex];
    final isToday = dateKey == todayKey;

    return Column(
      key: const ValueKey('daily_view'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. بطاقة مستوى التقدم اليومي المتقدم بالدرجات
        _buildProgressHeroBanner(
          topRightLabel: 'مستوى التقدم اليومي',
          topLeftLabel:
              '${dayStats.completedCount} / ${dayStats.totalTasksCount} عمل',
          earnedScore: dayStats.earnedPoints,
          maxScore: dayStats.maxPoints,
          percentage: dayStats.percentage,
          bottomRightText:
              'إنجاز الأسبوع: ${weekStats.earnedPoints} / ${weekStats.maxPoints} درجة (${weekStats.percentage}%)',
          bottomLeftText: _getMotivationText(dayStats.percentage),
        ),
        const SizedBox(height: 14),

        // 2. شريط التنقل بالتاريخ الفعلي
        _buildDateNavigator(dayName: dayName, isToday: isToday),
        const SizedBox(height: 12),

        // 3. شريط أيام الأسبوع المصغر
        _buildWeekStrip(
          weekDates: weekStats.weekDates,
          selectedKey: dateKey,
          todayKey: todayKey,
        ),
        const SizedBox(height: 14),

        // 4. شريط إدارة المهام السريع
        _buildTasksToolbar(),
        const SizedBox(height: 8),

        // 5. جدول أعمال اليوم الواحد (مع عمود "د" للدرجات وخيارات التعديل والحذف)
        _buildDailyTasksTable(
          dateKey: dateKey,
          dayName: dayName,
          dayStats: dayStats,
        ),
        const SizedBox(height: 14),

        // 6. أزرار الإجراءات السريعة (معاينة جدول الأسبوع + بدء أسبوع جديد)
        _buildQuickActionsRow(),
        const SizedBox(height: 16),

        // 7. الأحاديث النبوية
        _buildHadithSection(),
      ],
    );
  }

  Widget _buildProgressHeroBanner({
    required String topRightLabel,
    required String topLeftLabel,
    required int earnedScore,
    required int maxScore,
    required int percentage,
    String? bottomRightText,
    String? bottomLeftText,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0D2824),
            Color(0xFF153C37),
            Color(0xFF0F2E2A),
          ],
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1F524B)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D2824).withOpacity(0.24),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: CustomPaint(
          painter: _GeometricStarsPainter(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      topRightLabel,
                      style: const TextStyle(
                        color: Color(0xFF9CD5C9),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      topLeftLabel,
                      style: const TextStyle(
                        color: Color(0xFF9CD5C9),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 11,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final ratio =
                                (percentage.clamp(0, 100)) / 100.0;
                            return Align(
                              alignment: Alignment.centerRight,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 350),
                                curve: Curves.easeOutCubic,
                                width: constraints.maxWidth * ratio,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      AppColors.neonMintGlow,
                                      AppColors.neonMint,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          AppColors.neonMint.withOpacity(0.6),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        '$earnedScore / $maxScore د · $percentage%',
                        style: const TextStyle(
                          color: Color(0xFFC9ECE4),
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                if (bottomRightText != null || bottomLeftText != null) ...[
                  const SizedBox(height: 9),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (bottomRightText != null)
                        Flexible(
                          child: Text(
                            bottomRightText,
                            style: const TextStyle(
                              color: Color(0xFF8ABDB2),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (bottomLeftText != null)
                        Flexible(
                          child: Text(
                            bottomLeftText,
                            textAlign: TextAlign.left,
                            style: const TextStyle(
                              color: Color(0xFF8ABDB2),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateNavigator({
    required String dayName,
    required bool isToday,
  }) {
    final isDark = widget.isDarkMode;
    final bg = isDark ? AppColors.darkCardAlt : const Color(0xFFF4F9F8);
    final borderCol = isDark ? AppColors.darkBorder : const Color(0xFFB9D9D4);
    final textCol = isDark ? AppColors.darkText : AppColors.primaryDark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: borderCol),
      ),
      child: Row(
        children: [
          _buildNavIconButton(
            icon: Icons.chevron_right_rounded,
            tooltip: 'اليوم السابق',
            onTap: () {
              setState(() {
                _selectedDate = DateTime(
                  _selectedDate.year,
                  _selectedDate.month,
                  _selectedDate.day - 1,
                );
              });
            },
          ),
          Expanded(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      dayName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: textCol,
                      ),
                    ),
                    if (isToday) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
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
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${_selectedDate.day} ${_monthsAr[_selectedDate.month - 1]} ${_selectedDate.year}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                  ),
                ),
              ],
            ),
          ),
          if (!isToday) ...[
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedDate = _systemToday;
                });
              },
              style: TextButton.styleFrom(
                backgroundColor: isDark
                    ? AppColors.primary.withOpacity(0.25)
                    : const Color(0xFFE9F4F2),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'العودة لليوم',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.neonMint : AppColors.primaryDark,
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          _buildNavIconButton(
            icon: Icons.chevron_left_rounded,
            tooltip: 'اليوم التالي',
            onTap: () {
              setState(() {
                _selectedDate = DateTime(
                  _selectedDate.year,
                  _selectedDate.month,
                  _selectedDate.day + 1,
                );
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNavIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    final isDark = widget.isDarkMode;
    return Material(
      color: isDark ? AppColors.darkPaper : Colors.white,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: Icon(
            icon,
            size: 22,
            color: isDark ? AppColors.darkText : AppColors.primaryDark,
          ),
        ),
      ),
    );
  }

  Widget _buildWeekStrip({
    required List<DateTime> weekDates,
    required String selectedKey,
    required String todayKey,
  }) {
    final isDark = widget.isDarkMode;

    return Row(
      children: List.generate(7, (idx) {
        final d = weekDates[idx];
        final dKey = _toDateKey(d);
        final st = _getDayStats(dKey);
        final isSelected = dKey == selectedKey;
        final isSysToday = dKey == todayKey;
        final hasData = st.completedCount > 0;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: idx < 6 ? 5 : 0),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedDate = DateTime(d.year, d.month, d.day);
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary
                      : (isSysToday
                          ? (isDark
                              ? AppColors.primary.withOpacity(0.2)
                              : const Color(0xFFF0F9F7))
                          : (isDark ? AppColors.darkPaper : Colors.white)),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: isSelected || isSysToday
                        ? AppColors.primary
                        : (isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder),
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.28),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          )
                        ]
                      : null,
                ),
                child: Column(
                  children: [
                    Text(
                      _weekDaysAr[idx],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? Colors.white
                            : (isDark
                                ? AppColors.darkMuted
                                : AppColors.lightMuted),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${d.day}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isSelected
                            ? Colors.white
                            : (isDark
                                ? AppColors.darkText
                                : AppColors.lightText),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: hasData
                            ? (isSelected
                                ? AppColors.neonMint
                                : AppColors.primary)
                            : Colors.transparent,
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
  }

  Widget _buildTasksToolbar() {
    final isDark = widget.isDarkMode;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(
              Icons.rule_rounded,
              size: 18,
              color: isDark ? AppColors.neonMint : AppColors.primary,
            ),
            const SizedBox(width: 6),
            Text(
              'قائمة المهام اليومية (${_tasks.length})',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.darkText : AppColors.primaryDark,
              ),
            ),
          ],
        ),
        Row(
          children: [
            TextButton.icon(
              onPressed: () => _showTaskFormSheet(),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
              label: const Text(
                'إضافة مهمة',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              onPressed: _confirmRestoreDefaultTasks,
              icon: const Icon(Icons.restore_rounded, size: 18),
              tooltip: 'استعادة المهام الافتراضية',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDailyTasksTable({
    required String dateKey,
    required String dayName,
    required DayStats dayStats,
  }) {
    final isDark = widget.isDarkMode;
    final borderCol = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final headerBg = isDark ? const Color(0xFF1A3A35) : const Color(0xFFE2F0ED);
    final scoreHeaderBg =
        isDark ? const Color(0xFF15302C) : const Color(0xFFD5E9E5);
    final textCol = isDark ? AppColors.darkText : AppColors.lightText;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkPaper : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderCol),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // ترويسة الجدول: العمل اليومي | د (درجات) | اليوم
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 62,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 11),
                    color: AppColors.primary,
                    alignment: Alignment.centerRight,
                    child: const Text(
                      'العمل اليومي (اضغط على✏️ للتعديل)',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 18,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: scoreHeaderBg,
                      border: Border.symmetric(
                        vertical: BorderSide(color: borderCol),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Tooltip(
                      message: 'الدرجات المخصصة لكل مهمة',
                      child: Text(
                        'د (درجات)',
                        style: TextStyle(
                          color:
                              isDark ? AppColors.neonMint : AppColors.primaryDark,
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    color: headerBg,
                    alignment: Alignment.center,
                    child: Text(
                      dayName,
                      style: TextStyle(
                        color:
                            isDark ? AppColors.darkText : AppColors.primaryDark,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: borderCol),

          // قائمة المهام أو رسالة في حال عدم وجود مهام
          if (_tasks.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    Icons.playlist_add_check_rounded,
                    size: 42,
                    color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'لا توجد مهام حالياً. أضف مهمتك الأولى وحدد درجتها!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color:
                          isDark ? AppColors.darkMuted : AppColors.lightMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            )
          else
            ..._tasks.map((task) {
              final done = _isTaskDone(dateKey, task.id);
              final rowBg = done
                  ? (isDark
                      ? AppColors.primary.withOpacity(0.16)
                      : const Color(0xFFF6FBFA))
                  : Colors.transparent;

              return Column(
                children: [
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // خلية اسم المهمة + زر التعديل السريع
                        Expanded(
                          flex: 62,
                          child: InkWell(
                            onTap: () => _toggleTaskForDate(dateKey, task.id),
                            onLongPress: () =>
                                _showTaskFormSheet(existingTask: task),
                            child: Container(
                              color: rowBg,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 10),
                              child: Row(
                                children: [
                                  Container(
                                    width: 3,
                                    height: 22,
                                    margin: const EdgeInsets.only(left: 8),
                                    decoration: BoxDecoration(
                                      color: done
                                          ? AppColors.primary
                                          : borderCol,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      task.title,
                                      style: TextStyle(
                                        fontSize: 13.8,
                                        fontWeight: FontWeight.w700,
                                        color: textCol,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () =>
                                        _showTaskFormSheet(existingTask: task),
                                    icon: Icon(
                                      Icons.edit_outlined,
                                      size: 17,
                                      color: isDark
                                          ? AppColors.darkMuted
                                          : AppColors.lightMuted,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 28,
                                      minHeight: 28,
                                    ),
                                    tooltip: 'تعديل أو حذف المهمة',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // خلية الدرجة "د" (قابلة للضغط لتعديل الدرجة مباشرة)
                        Expanded(
                          flex: 18,
                          child: InkWell(
                            onTap: () =>
                                _showTaskFormSheet(existingTask: task),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.darkCardAlt.withOpacity(0.5)
                                    : const Color(0xFFFBFDFD),
                                border: Border.symmetric(
                                  vertical: BorderSide(color: borderCol),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${task.score} د',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? AppColors.neonMint
                                      : AppColors.primaryDark,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // خلية علامة الصح
                        Expanded(
                          flex: 20,
                          child: InkWell(
                            onTap: () => _toggleTaskForDate(dateKey, task.id),
                            child: Container(
                              color: rowBg,
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: done
                                      ? AppColors.primary
                                      : (isDark
                                          ? AppColors.darkPaper
                                          : Colors.white),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: done
                                        ? AppColors.primary
                                        : (isDark
                                            ? AppColors.darkMuted
                                            : const Color(0xFFB7CCC9)),
                                    width: 2,
                                  ),
                                  boxShadow: done
                                      ? [
                                          BoxShadow(
                                            color: AppColors.primary
                                                .withOpacity(0.28),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          )
                                        ]
                                      : null,
                                ),
                                alignment: Alignment.center,
                                child: done
                                    ? const Icon(
                                        Icons.check_rounded,
                                        size: 20,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, thickness: 1, color: borderCol),
                ],
              );
            }),

          // صف المجموع اليومي بالدرجات
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF173631)
                  : const Color(0xFFE9F4F2),
              border: const Border(
                top: BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  flex: 62,
                  child: Text(
                    'المجموع اليومي (درجات)',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      color:
                          isDark ? AppColors.darkText : AppColors.primaryDark,
                    ),
                  ),
                ),
                Expanded(
                  flex: 18,
                  child: Text(
                    '${dayStats.maxPoints} د',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                    ),
                  ),
                ),
                Expanded(
                  flex: 20,
                  child: Text(
                    '${dayStats.earnedPoints} د',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: isDark ? AppColors.neonMint : AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // صف النسبة المئوية لليوم
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF2B2111)
                  : const Color(0xFFFFFBEB),
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? const Color(0xFF5A4318)
                      : const Color(0xFFF5D08A),
                ),
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            child: Row(
              children: [
                const Expanded(
                  flex: 62,
                  child: Text(
                    'النسبة المئوية لليوم',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      color: AppColors.amber,
                    ),
                  ),
                ),
                const Expanded(
                  flex: 18,
                  child: Text(
                    '%',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      color: AppColors.amber,
                    ),
                  ),
                ),
                Expanded(
                  flex: 20,
                  child: Text(
                    '${dayStats.percentage}%',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: AppColors.amber,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsRow() {
    final isDark = widget.isDarkMode;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _showWeeklyPreviewModal,
            style: OutlinedButton.styleFrom(
              backgroundColor:
                  isDark ? AppColors.darkCardAlt : const Color(0xFFF3F8F7),
              foregroundColor:
                  isDark ? AppColors.neonMint : AppColors.primaryDark,
              side: BorderSide(
                color: isDark ? AppColors.darkBorder : const Color(0xFFB9D9D4),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
            ),
            icon: const Icon(Icons.table_chart_outlined, size: 18),
            label: const Text(
              'معاينة جدول الأسبوع',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _confirmResetWeek,
            style: OutlinedButton.styleFrom(
              backgroundColor: isDark
                  ? AppColors.danger.withOpacity(0.12)
                  : const Color(0xFFFCE8E8),
              foregroundColor: AppColors.danger,
              side: BorderSide(
                color: isDark
                    ? AppColors.danger.withOpacity(0.4)
                    : const Color(0xFFFCA5A5),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
            ),
            icon: const Icon(Icons.delete_sweep_outlined, size: 18),
            label: const Text(
              'بدء أسبوع جديد',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHadithSection() {
    return Column(
      children: [
        _buildHadithQuote(
          'قال رسول الله ﷺ: «أَحَبُّ الأَعْمَالِ إِلَى اللهِ أَدْوَمُهَا وَإِنْ قَلَّ».',
        ),
        const SizedBox(height: 8),
        _buildHadithQuote(
          'قال رسول الله ﷺ: «يَقُولُ اللَّهُ تَعَالَى: أَنَا عِنْدَ ظَنِّ عَبْدِي بِي، وَأَنَا مَعَهُ إِذَا ذَكَرَنِي، فَإِنْ ذَكَرَنِي فِي نَفْسِهِ ذَكَرْتُهُ فِي نَفْسِي، وَإِنْ ذَكَرَنِي فِي مَلَإٍ ذَكَرْتُهُ فِي مَلَإٍ خَيْرٍ مِنْهُمْ، وَإِنْ تَقَرَّبَ إِلَيَّ بِشِبْرٍ تَقَرَّبْتُ إِلَيْهِ ذِرَاعًا، وَإِنْ تَقَرَّبَ إِلَيَّ ذِرَاعًا تَقَرَّبْتُ إِلَيْهِ بَاعًا، وَإِنْ أَتَانِي يَمْشِي أَتَيْتُهُ هَرْوَلَةً».',
        ),
      ],
    );
  }

  Widget _buildHadithQuote(String text) {
    final isDark = widget.isDarkMode;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardAlt : const Color(0xFFF7FAF9),
        borderRadius: BorderRadius.circular(10),
        border: const Border(
          right: BorderSide(color: AppColors.primary, width: 3.5),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          height: 1.7,
          fontWeight: FontWeight.w600,
          color: isDark ? AppColors.darkText : const Color(0xFF405451),
        ),
      ),
    );
  }

  // ==================== القسم الثاني: داشبورد إحصائيات الشهر ====================

  Widget _buildMonthlyDashboardView() {
    final isDark = widget.isDarkMode;
    final year = _dashboardMonthDate.year;
    final month = _dashboardMonthDate.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;

    int monthEarnedPoints = 0;
    int monthCompletedTasks = 0;
    int activeDaysCount = 0;
    int bestDayPerc = 0;
    int currentStreak = 0;
    int maxStreak = 0;

    final List<int> dailyPercentages = [];
    final Map<int, int> taskMonthlyCounts = {
      for (final t in _tasks) t.id: 0,
    };

    for (int day = 1; day <= daysInMonth; day++) {
      final dObj = DateTime(year, month, day);
      final dKey = _toDateKey(dObj);
      final st = _getDayStats(dKey);

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

      for (final t in _tasks) {
        if (_isTaskDone(dKey, t.id)) {
          taskMonthlyCounts[t.id] = (taskMonthlyCounts[t.id] ?? 0) + 1;
        }
      }
    }

    final maxMonthPoints = daysInMonth * maxDailyScore;
    final monthOverallPerc = maxMonthPoints > 0
        ? ((monthEarnedPoints / maxMonthPoints) * 100).round()
        : 0;

    return Column(
      key: const ValueKey('dashboard_view'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. شريط اختيار الشهر
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCardAlt : const Color(0xFFF4F9F8),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : const Color(0xFFB9D9D4),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildNavIconButton(
                icon: Icons.chevron_right_rounded,
                tooltip: 'الشهر السابق',
                onTap: () {
                  setState(() {
                    _dashboardMonthDate = DateTime(year, month - 1, 1);
                  });
                },
              ),
              Text(
                '${_monthsAr[month - 1]} $year',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.darkText : AppColors.primaryDark,
                ),
              ),
              _buildNavIconButton(
                icon: Icons.chevron_left_rounded,
                tooltip: 'الشهر التالي',
                onTap: () {
                  setState(() {
                    _dashboardMonthDate = DateTime(year, month + 1, 1);
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 2. شريط تقدم الشهر الإجمالي بالدرجات
        _buildProgressHeroBanner(
          topRightLabel: 'مؤشر الإنجاز الشهري التراكمي',
          topLeftLabel: '$activeDaysCount من $daysInMonth يوم مسجل',
          earnedScore: monthEarnedPoints,
          maxScore: maxMonthPoints,
          percentage: monthOverallPerc,
        ),
        const SizedBox(height: 14),

        // 3. بطاقات الملخص الرقمي للشهر (KPIs)
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.65,
          children: [
            _buildKpiCard(
              label: 'إجمالي درجات الشهر',
              value: '$monthEarnedPoints د',
              sub: 'من أصل $maxMonthPoints درجة',
            ),
            _buildKpiCard(
              label: 'متوسط الإنجاز اليومي',
              value: '$monthOverallPerc%',
              sub: 'أعلى يوم: $bestDayPerc%',
            ),
            _buildKpiCard(
              label: 'الأعمال المنجزة بالشهر',
              value: '$monthCompletedTasks',
              sub: 'مهمة مكتملة',
            ),
            _buildKpiCard(
              label: 'أطول سلسلة التزام',
              value: '$maxStreak يوم',
              sub: 'أيام متتالية (+50%)',
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 4. الرسم البياني لتطور الإنجاز خلال أيام الشهر
        _buildDashboardSectionCard(
          title: 'منحنى الإنجاز اليومي خلال الشهر (%)',
          child: SizedBox(
            height: 180,
            child: _buildMonthlyBarChart(dailyPercentages),
          ),
        ),
        const SizedBox(height: 14),

        // 5. خريطة أيام الشهر (Calendar Heatmap)
        _buildDashboardSectionCard(
          title: 'خريطة أيام الشهر',
          trailingText: 'اضغط على أي يوم لفتحه',
          child: _buildMonthHeatmapGrid(
            year: year,
            month: month,
            daysInMonth: daysInMonth,
          ),
        ),
        const SizedBox(height: 14),

        // 6. تفصيل الإنجاز حسب كل عمل في الشهر
        _buildDashboardSectionCard(
          title: 'تفصيل الإنجاز حسب كل عمل في الشهر',
          child: _tasks.isEmpty
              ? const Text('لا توجد مهام مسجلة حالياً.')
              : Column(
                  children: _tasks.map((t) {
                    final doneDays = taskMonthlyCounts[t.id] ?? 0;
                    final taskPerc =
                        daysInMonth > 0 ? ((doneDays / daysInMonth) * 100).round() : 0;
                    final earnedTaskMonthScore = doneDays * t.score;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '${t.title} (${t.score} د)',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? AppColors.darkText
                                        : AppColors.lightText,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '$doneDays/$daysInMonth يوم · $earnedTaskMonthScore د ($taskPerc%)',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? AppColors.neonMint
                                      : AppColors.primaryDark,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: (taskPerc.clamp(0, 100)) / 100.0,
                              minHeight: 7,
                              backgroundColor: isDark
                                  ? AppColors.darkBorder
                                  : const Color(0xFFE9F2F0),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isDark ? AppColors.neonMint : AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String label,
    required String value,
    required String sub,
  }) {
    final isDark = widget.isDarkMode;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardAlt : const Color(0xFFF8FBFB),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFD5E6E3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: isDark ? AppColors.darkText : AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.neonMint : AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardSectionCard({
    required String title,
    String? trailingText,
    required Widget child,
  }) {
    final isDark = widget.isDarkMode;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkPaper : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.darkText : AppColors.primaryDark,
                ),
              ),
              if (trailingText != null)
                Text(
                  trailingText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
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

  Widget _buildMonthlyBarChart(List<int> dailyPercentages) {
    final isDark = widget.isDarkMode;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(dailyPercentages.length, (index) {
        final dayNum = index + 1;
        final perc = dailyPercentages[index].clamp(0, 100);
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: Tooltip(
              message: 'يوم $dayNum: $perc%',
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: math.max(perc / 100.0, 0.04),
                        child: Container(
                          decoration: BoxDecoration(
                            color: perc == 0
                                ? (isDark
                                    ? AppColors.darkBorder
                                    : const Color(0xFFE3ECEB))
                                : (isDark
                                    ? AppColors.neonMint
                                    : AppColors.primary),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (dayNum == 1 || dayNum % 5 == 0 || dayNum == dailyPercentages.length)
                    Text(
                      '$dayNum',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color:
                            isDark ? AppColors.darkMuted : AppColors.lightMuted,
                      ),
                    )
                  else
                    const SizedBox(height: 11),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildMonthHeatmapGrid({
    required int year,
    required int month,
    required int daysInMonth,
  }) {
    final isDark = widget.isDarkMode;
    final firstDayOfMonth = DateTime(year, month, 1);
    final startOffset = _getSatWeekIndex(firstDayOfMonth);

    final List<Widget> cells = [];

    // خلايا فارغة لبداية الشهر
    for (int i = 0; i < startOffset; i++) {
      cells.add(const SizedBox.shrink());
    }

    // خلايا أيام الشهر
    for (int day = 1; day <= daysInMonth; day++) {
      final dObj = DateTime(year, month, day);
      final dKey = _toDateKey(dObj);
      final st = _getDayStats(dKey);

      Color cellBg;
      Color cellText;
      if (st.percentage >= 85) {
        cellBg = const Color(0xFF00B884);
        cellText = Colors.white;
      } else if (st.percentage >= 60) {
        cellBg = AppColors.primary;
        cellText = Colors.white;
      } else if (st.percentage >= 30) {
        cellBg = const Color(0xFF82DEC9);
        cellText = const Color(0xFF0D3B32);
      } else if (st.percentage > 0) {
        cellBg = isDark ? const Color(0xFF1E4A42) : const Color(0xFFD8F3EC);
        cellText = isDark ? AppColors.neonMint : const Color(0xFF165246);
      } else {
        cellBg = isDark ? AppColors.darkCardAlt : const Color(0xFFF8FAFA);
        cellText = isDark ? AppColors.darkMuted : const Color(0xFF7B8E8D);
      }

      cells.add(
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            setState(() {
              _selectedDate = DateTime(year, month, day);
              _currentTabIndex = 0;
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: cellBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : const Color(0xFFE1ECEA),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$day',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: cellText,
                  ),
                ),
                Text(
                  '${st.percentage}%',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: cellText.withOpacity(0.88),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: _weekDaysAr
              .map(
                (wName) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      wName,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color:
                            isDark ? AppColors.darkMuted : AppColors.lightMuted,
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
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          children: cells,
        ),
      ],
    );
  }

  // الشريط السفلي لحفظ الاسم
  Widget _buildFooterNameField() {
    final isDark = widget.isDarkMode;
    return Container(
      padding: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkBorder : const Color(0xFFDCE6E4),
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            'الاسم:',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _userNameController,
              onChanged: _saveUserName,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.neonMint : AppColors.primaryDark,
              ),
              decoration: InputDecoration(
                hintText: 'اكتب اسمك هنا ليظهر في الجدول الأسبوعي...',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                ),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== رسام النجوم الهندسية الخلفية ====================

class _GeometricStarsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
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
      Canvas canvas, Offset center, double outerR, double innerR, Paint paint) {
    final path = Path();
    const int points = 5;
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
