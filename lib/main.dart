import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

final notif = FlutterLocalNotificationsPlugin();
const days = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];

AndroidFlutterLocalNotificationsPlugin? get _androidNotif =>
    notif.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

// ==================== السمات والألوان ====================
class AppTheme {
  final String name;
  final ThemeMode mode;
  final Color primary;
  final Color secondary;
  final Color accent;
  final Color background;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;

  const AppTheme({
    required this.name,
    required this.mode,
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.background,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
  });
}

class AppThemes {
  static const seaViolet = AppTheme(
    name: 'البحر البنفسجي',
    mode: ThemeMode.light,
    primary: Color(0xFFFF33E2),
    secondary: Color(0xFF190B28),
    accent: Color(0xFFB347D9),
    background: Color(0xFFF5F0F7),
    surface: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF190B28),
    textSecondary: Color(0xFF6B5B73),
  );

  static const azureOcean = AppTheme(
    name: 'المحيط اللازوردي',
    mode: ThemeMode.light,
    primary: Color(0xFF00B4D8),
    secondary: Color(0xFF0077B6),
    accent: Color(0xFF90E0EF),
    background: Color(0xFFF0F9FC),
    surface: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF023047),
    textSecondary: Color(0xFF5C7A8A),
  );

  static const violetLightning = AppTheme(
    name: 'البرق البنفسجي',
    mode: ThemeMode.dark,
    primary: Color(0xFF9D4EDD),
    secondary: Color(0xFF10002B),
    accent: Color(0xFFE0AAFF),
    background: Color(0xFF0D001A),
    surface: Color(0xFF1A0B2E),
    textPrimary: Color(0xFFF5EBFF),
    textSecondary: Color(0xFFB8A9C9),
  );

  static const List<AppTheme> all = [seaViolet, azureOcean, violetLightning];

  static AppTheme byName(String name) =>
      all.firstWhere((t) => t.name == name, orElse: () => seaViolet);
}

// ==================== الإشعارات ====================
Future<void> initNotif() async {
  tzdata.initializeTimeZones();
  tz.setLocalLocation(tz.UTC);
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  await notif.initialize(const InitializationSettings(android: android));
  await _androidNotif?.requestNotificationsPermission();
  if (!(await _androidNotif?.canScheduleExactNotifications() ?? true)) {
    await _androidNotif?.requestExactAlarmsPermission();
  }
}

Future<bool> scheduleAlarm(int id, String title, DateTime when, {bool silent = false}) async {
  if (!when.isAfter(DateTime.now())) return false;
  final canExact = await _androidNotif?.canScheduleExactNotifications() ?? true;
  await notif.zonedSchedule(
    id,
    silent ? title : 'تذكير: $title',
    silent ? '' : 'حان وقت: $title',
    tz.TZDateTime.from(when, tz.UTC),
    NotificationDetails(
      android: AndroidNotificationDetails(
        silent ? 'silent' : 'alarm',
        silent ? 'تنبيهات صامتة' : 'تنبيهات صوتية',
        importance: silent ? Importance.low : Importance.max,
        priority: silent ? Priority.low : Priority.high,
        playSound: !silent,
        enableVibration: !silent,
      ),
    ),
    androidScheduleMode: canExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle,
    uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
  );
  return true;
}

Future<void> cancelAlarm(int id) => notif.cancel(id);

// ==================== النماذج ====================
class Task {
  int id;
  String title;
  DateTime when;
  bool muted;
  Task({required this.id, required this.title, required this.when, this.muted = false});

  Map<String, dynamic> toJson() =>
      {'id': id, 'title': title, 'when': when.toIso8601String(), 'muted': muted};

  static Task fromJson(Map<String, dynamic> j) => Task(
        id: j['id'] as int,
        title: j['title'] as String,
        when: DateTime.parse(j['when'] as String),
        muted: j['muted'] as bool? ?? false,
      );
}

class Note {
  int id;
  String title;
  String content;
  DateTime createdAt;
  Note({required this.id, required this.title, required this.content, required this.createdAt});

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
      };

  static Note fromJson(Map<String, dynamic> j) => Note(
        id: j['id'] as int,
        title: j['title'] as String,
        content: j['content'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

// ==================== التطبيق الرئيسي ====================
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initNotif();
  runApp(const StudentApp());
}

class StudentApp extends StatefulWidget {
  const StudentApp({super.key});
  @override
  State<StudentApp> createState() => _StudentAppState();
}

class _StudentAppState extends State<StudentApp> {
  AppTheme _theme = AppThemes.seaViolet;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('theme') ?? AppThemes.seaViolet.name;
    setState(() => _theme = AppThemes.byName(name));
  }

  Future<void> _saveTheme(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme', name);
    setState(() => _theme = AppThemes.byName(name));
  }

  ThemeData _buildTheme(AppTheme t) {
    final isDark = t.mode == ThemeMode.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      colorScheme: ColorScheme(
        brightness: isDark ? Brightness.dark : Brightness.light,
        primary: t.primary,
        onPrimary: isDark ? Colors.black : Colors.white,
        secondary: t.secondary,
        onSecondary: isDark ? Colors.white : Colors.white,
        surface: t.surface,
        onSurface: t.textPrimary,
        error: Colors.red,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: t.background,
      cardColor: t.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: t.surface,
        foregroundColor: t.textPrimary,
        elevation: 0,
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: t.textPrimary),
        bodyMedium: TextStyle(color: t.textPrimary),
        bodySmall: TextStyle(color: t.textSecondary),
        titleLarge: TextStyle(color: t.textPrimary, fontWeight: FontWeight.bold),
        titleMedium: TextStyle(color: t.textPrimary),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: t.primary,
        foregroundColor: isDark ? Colors.black : Colors.white,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: t.surface,
        indicatorColor: t.primary.withOpacity(0.2),
        labelTextStyle: MaterialStateProperty.all(
          TextStyle(color: t.textPrimary, fontSize: 12),
        ),
        iconTheme: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return IconThemeData(color: t.primary);
          }
          return IconThemeData(color: t.textSecondary);
        }),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: t.surface,
        titleTextStyle: TextStyle(color: t.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
        contentTextStyle: TextStyle(color: t.textPrimary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: TextStyle(color: t.textSecondary),
        hintStyle: TextStyle(color: t.textSecondary),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: t.textSecondary.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: t.primary),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'fati calendar',
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: _buildTheme(_theme),
        home: HomePage(theme: _theme, onThemeChange: _saveTheme),
      );
}

// ==================== الصفحة الرئيسية ====================
class HomePage extends StatefulWidget {
  final AppTheme theme;
  final Future<void> Function(String) onThemeChange;
  const HomePage({super.key, required this.theme, required this.onThemeChange});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int tab = 0;
  Map<String, List<dynamic>> schedule = {};
  List<Task> tasks = [];
  List<Note> notes = [];
  int _nextId = 1;

  @override
  void initState() {
    super.initState();
    loadAll();
  }

  Future<void> loadAll() async {
    final raw = await rootBundle.loadString('assets/schedule.json');
    final decoded = json.decode(raw) as Map<String, dynamic>;
    schedule = decoded.map((k, v) => MapEntry(k, v as List<dynamic>));

    final prefs = await SharedPreferences.getInstance();
    final savedTasks = prefs.getStringList('tasks') ?? [];
    tasks = [];
    for (final s in savedTasks) {
      try {
        tasks.add(Task.fromJson(json.decode(s) as Map<String, dynamic>));
      } catch (_) {}
    }
    if (tasks.isNotEmpty) {
      _nextId = tasks.map((t) => t.id).reduce((a, b) => a > b ? a : b) + 1;
    }

    final savedNotes = prefs.getStringList('notes') ?? [];
    notes = [];
    for (final s in savedNotes) {
      try {
        notes.add(Note.fromJson(json.decode(s) as Map<String, dynamic>));
      } catch (_) {}
    }
    if (notes.isNotEmpty) {
      final maxNoteId = notes.map((n) => n.id).reduce((a, b) => a > b ? a : b);
      if (maxNoteId >= _nextId) _nextId = maxNoteId + 1;
    }

    if (mounted) setState(() {});
  }

  Future<void> saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        'tasks', tasks.map((t) => json.encode(t.toJson())).toList());
  }

  Future<void> saveNotes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        'notes', notes.map((n) => json.encode(n.toJson())).toList());
  }

  Future<bool> addTask(String title, DateTime when, {bool silent = false}) async {
    final t = Task(id: _nextId, title: title, when: when, muted: silent);
    final ok = await scheduleAlarm(t.id, t.title, t.when, silent: silent);
    if (!ok) return false;
    _nextId++;
    tasks.add(t);
    await saveTasks();
    if (mounted) setState(() {});
    return true;
  }

  Future<void> toggleMute(Task t) async {
    t.muted = !t.muted;
    if (t.muted) {
      await cancelAlarm(t.id);
    } else {
      await scheduleAlarm(t.id, t.title, t.when);
    }
    await saveTasks();
    if (mounted) setState(() {});
  }

  Future<void> deleteTask(Task t) async {
    await cancelAlarm(t.id);
    tasks.remove(t);
    await saveTasks();
    if (mounted) setState(() {});
  }

  Future<void> muteAll() async {
    await notif.cancelAll();
    for (final t in tasks) {
      t.muted = true;
    }
    await saveTasks();
    if (mounted) setState(() {});
  }

  Future<void> addNote(String title, String content) async {
    final n = Note(
      id: _nextId++,
      title: title,
      content: content,
      createdAt: DateTime.now(),
    );
    notes.add(n);
    await saveNotes();
    if (mounted) setState(() {});
  }

  Future<void> updateNote(Note n) async {
    await saveNotes();
    if (mounted) setState(() {});
  }

  Future<void> deleteNote(Note n) async {
    notes.remove(n);
    await saveNotes();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      ScheduleTab(schedule: schedule, theme: widget.theme),
      TasksTab(
        tasks: tasks,
        theme: widget.theme,
        onAdd: addTask,
        onMute: toggleMute,
        onDelete: deleteTask,
      ),
      NotesTab(
        notes: notes,
        theme: widget.theme,
        onAdd: addNote,
        onUpdate: updateNote,
        onDelete: deleteNote,
      ),
      SettingsTab(
        theme: widget.theme,
        onThemeChange: widget.onThemeChange,
        onMuteAll: muteAll,
      ),
    ];
    return Scaffold(
      body: screens[tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.calendar_month), label: 'الجدول'),
          NavigationDestination(icon: Icon(Icons.alarm), label: 'المنبهات'),
          NavigationDestination(icon: Icon(Icons.note_alt), label: 'المذكرات'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'الإعدادات'),
        ],
      ),
    );
  }
}

// ==================== تبويب الجدول ====================
class ScheduleTab extends StatefulWidget {
  final Map<String, List<dynamic>> schedule;
  final AppTheme theme;
  const ScheduleTab({super.key, required this.schedule, required this.theme});
  @override
  State<ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<ScheduleTab> {
  String day = days[DateTime.now().weekday % 7];
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  static int _minutes(String hhmm) {
    final p = hhmm.split(':');
    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }

  int _currentIndex(List<dynamic> slots) {
    final today = days[DateTime.now().weekday % 7];
    if (day != today) return -1;
    final n = DateTime.now();
    final nowM = n.hour * 60 + n.minute;
    for (int i = 0; i < slots.length; i++) {
      final s = _minutes(slots[i]['start'].toString());
      final e = _minutes(slots[i]['end'].toString());
      final inside = e <= s
          ? (nowM >= s || nowM < e)
          : (nowM >= s && nowM < e);
      if (inside) return i;
    }
    return -1;
  }

  void _editSlot(int index, Map<String, dynamic> slot) {
    final actCtrl = TextEditingController(text: slot['activity'].toString());
    final startCtrl = TextEditingController(text: slot['start'].toString());
    final endCtrl = TextEditingController(text: slot['end'].toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعديل الموعد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: actCtrl,
              decoration: const InputDecoration(labelText: 'النشاط'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: startCtrl,
              decoration: const InputDecoration(labelText: 'وقت البدء (HH:MM)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: endCtrl,
              decoration: const InputDecoration(labelText: 'وقت الانتهاء (HH:MM)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                slot['activity'] = actCtrl.text.trim();
                slot['start'] = startCtrl.text.trim();
                slot['end'] = endCtrl.text.trim();
              });
              Navigator.pop(ctx);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final slots = widget.schedule[day] ?? [];
    final nowIndex = _currentIndex(slots);
    final t = widget.theme;
    return SafeArea(
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'الجدول الأسبوعي',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: t.textPrimary,
            ),
          ),
        ),
        SizedBox(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: days.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                label: Text(days[i]),
                selected: day == days[i],
                selectedColor: t.primary.withOpacity(0.3),
                labelStyle: TextStyle(
                  color: day == days[i] ? t.primary : t.textPrimary,
                ),
                onSelected: (_) => setState(() => day = days[i]),
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: slots.length,
            itemBuilder: (_, i) {
              final s = slots[i];
              final isNow = i == nowIndex;
              return Card(
                color: isNow ? t.primary.withOpacity(0.15) : t.surface,
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                child: ListTile(
                  leading: Icon(
                    isNow ? Icons.play_circle : Icons.schedule,
                    color: isNow ? t.primary : t.textSecondary,
                  ),
                  title: Text(
                    s['activity'].toString(),
                    style: TextStyle(
                      color: t.textPrimary,
                      fontWeight: isNow ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    '${s['start']} - ${s['end']}',
                    style: TextStyle(color: t.textSecondary),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isNow)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'الآن',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      IconButton(
                        icon: Icon(Icons.edit, color: t.textSecondary, size: 20),
                        onPressed: () => _editSlot(i, s),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

// ==================== تبويب المنبهات ====================
class TasksTab extends StatefulWidget {
  final List<Task> tasks;
  final AppTheme theme;
  final Future<bool> Function(String, DateTime, {bool silent}) onAdd;
  final Future<void> Function(Task) onMute;
  final Future<void> Function(Task) onDelete;
  const TasksTab({
    super.key,
    required this.tasks,
    required this.theme,
    required this.onAdd,
    required this.onMute,
    required this.onDelete,
  });
  @override
  State<TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends State<TasksTab> {
  static String _fmt(DateTime d) =>
      '${d.year}/${d.month}/${d.day}  ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  Future<void> showAddDialog() async {
    final ctrl = TextEditingController();
    bool silent = false;
    DateTime picked = DateTime.now().add(const Duration(minutes: 5));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('مهمة جديدة مع منبه'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(labelText: 'اسم المهمة'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.access_time),
              label: Text('الوقت: ${_fmt(picked)}'),
              onPressed: () async {
                final d = await showDatePicker(
                    context: ctx,
                    initialDate: picked,
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2035));
                if (d == null) return;
                if (!ctx.mounted) return;
                final t = await showTimePicker(
                    context: ctx, initialTime: TimeOfDay.fromDateTime(picked));
                if (t == null) return;
                setD(() => picked = DateTime(d.year, d.month, d.day, t.hour, t.minute));
              },
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('منبه صامت'),
              subtitle: const Text('إشعار بدون صوت'),
              value: silent,
              onChanged: (v) => setD(() => silent = v),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('حفظ وضبط المنبه')),
          ],
        ),
      ),
    );
    final title = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true || title.isEmpty) return;
    final added = await widget.onAdd(title, picked, silent: silent);
    if (!added && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الوقت المختار قد مضى، اختر وقتاً في المستقبل')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [...widget.tasks]..sort((a, b) => a.when.compareTo(b.when));
    final now = DateTime.now();
    final t = widget.theme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: showAddDialog,
        tooltip: 'مهمة جديدة',
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'المنبهات',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: t.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: sorted.isEmpty
                ? Center(
                    child: Text(
                      'لا توجد منبهات بعد.\nاضغط + لإضافة منبه',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: t.textSecondary),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 88),
                    itemCount: sorted.length,
                    itemBuilder: (_, i) {
                      final task = sorted[i];
                      final expired = task.when.isBefore(now);
                      return Card(
                        color: t.surface,
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                        child: ListTile(
                          leading: Icon(
                            expired
                                ? Icons.check_circle_outline
                                : (task.muted ? Icons.alarm_off : Icons.alarm),
                            color: (task.muted || expired)
                                ? t.textSecondary
                                : t.primary,
                          ),
                          title: Text(
                            task.title,
                            style: TextStyle(
                              color: t.textPrimary,
                              decoration:
                                  task.muted ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          subtitle: Text(
                            _fmt(task.when),
                            style: TextStyle(color: t.textSecondary),
                          ),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            if (!expired)
                              IconButton(
                                tooltip: task.muted ? 'تفعيل المنبه' : 'كتم المنبه',
                                icon: Icon(
                                  task.muted ? Icons.volume_off : Icons.volume_up,
                                  color: t.textSecondary,
                                ),
                                onPressed: () => widget.onMute(task),
                              ),
                            IconButton(
                              tooltip: 'حذف',
                              icon: Icon(Icons.delete, color: Colors.red[300]),
                              onPressed: () => widget.onDelete(task),
                            ),
                          ]),
                        ),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}

// ==================== تبويب المذكرات ====================
class NotesTab extends StatefulWidget {
  final List<Note> notes;
  final AppTheme theme;
  final Future<void> Function(String, String) onAdd;
  final Future<void> Function(Note) onUpdate;
  final Future<void> Function(Note) onDelete;
  const NotesTab({
    super.key,
    required this.notes,
    required this.theme,
    required this.onAdd,
    required this.onUpdate,
    required this.onDelete,
  });
  @override
  State<NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends State<NotesTab> {
  Future<void> _showNoteDialog({Note? existing}) async {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final contentCtrl = TextEditingController(text: existing?.content ?? '');
    final isNew = existing == null;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isNew ? 'مذكرة جديدة' : 'تعديل المذكرة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'العنوان'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: contentCtrl,
              decoration: const InputDecoration(labelText: 'المحتوى'),
              maxLines: 5,
              minLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    final title = titleCtrl.text.trim();
    final content = contentCtrl.text.trim();
    if (title.isEmpty && content.isEmpty) return;

    if (isNew) {
      await widget.onAdd(title, content);
    } else {
      existing!.title = title;
      existing.content = content;
      await widget.onUpdate(existing);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final sorted = [...widget.notes]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNoteDialog(),
        tooltip: 'مذكرة جديدة',
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'المذكرات',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: t.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: sorted.isEmpty
                ? Center(
                    child: Text(
                      'لا توجد مذكرات بعد.\nاضغط + لإضافة مذكرة',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: t.textSecondary),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 88),
                    itemCount: sorted.length,
                    itemBuilder: (_, i) {
                      final n = sorted[i];
                      return Card(
                        color: t.surface,
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 3),
                        child: ListTile(
                          leading: Icon(Icons.note, color: t.primary),
                          title: Text(
                            n.title,
                            style: TextStyle(
                              color: t.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            n.content,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: t.textSecondary),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.edit,
                                    color: t.textSecondary, size: 20),
                                onPressed: () => _showNoteDialog(existing: n),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete,
                                    color: Colors.red[300], size: 20),
                                onPressed: () => widget.onDelete(n),
                              ),
                            ],
                          ),
                          onTap: () => _showNoteDialog(existing: n),
                        ),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}

// ==================== تبويب الإعدادات ====================
class SettingsTab extends StatelessWidget {
  final AppTheme theme;
  final Future<void> Function(String) onThemeChange;
  final Future<void> Function() onMuteAll;
  const SettingsTab({
    super.key,
    required this.theme,
    required this.onThemeChange,
    required this.onMuteAll,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return SafeArea(
      child: ListView(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'الإعدادات',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: t.textPrimary,
            ),
          ),
        ),

        // اختيار السمة
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'سمة التطبيق',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: t.textPrimary,
            ),
          ),
        ),
        ...AppThemes.all.map((th) => RadioListTile<String>(
              title: Text(th.name, style: TextStyle(color: t.textPrimary)),
              subtitle: Row(
                children: [
                  _colorDot(th.primary),
                  const SizedBox(width: 4),
                  _colorDot(th.secondary),
                  const SizedBox(width: 4),
                  _colorDot(th.accent),
                ],
              ),
              value: th.name,
              groupValue: t.name,
              activeColor: t.primary,
              onChanged: (v) {
                if (v != null) onThemeChange(v);
              },
            )),

        const Divider(),

        ListTile(
          leading: Icon(Icons.notifications_active, color: t.primary),
          title: Text('اختبار المنبه', style: TextStyle(color: t.textPrimary)),
          subtitle: Text('تجربة صوت التنبيه الآن',
              style: TextStyle(color: t.textSecondary)),
          onTap: () => notif.show(
            999,
            'fati calendar',
            'التنبيهات تعمل بنجاح!',
            NotificationDetails(
              android: AndroidNotificationDetails(
                'alarm',
                'تنبيهات صوتية',
                importance: Importance.max,
                priority: Priority.high,
                color: t.primary,
              ),
            ),
          ),
        ),
        ListTile(
          leading: Icon(Icons.volume_off, color: t.textSecondary),
          title: Text('كتم جميع المنبهات',
              style: TextStyle(color: t.textPrimary)),
          subtitle: Text('إلغاء جميع التنبيهات المجدولة',
              style: TextStyle(color: t.textSecondary)),
          onTap: () async {
            await onMuteAll();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم كتم جميع المنبهات')),
              );
            }
          },
        ),

        const Divider(),

        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'fati calendar\nجدولك الأسبوعي مع منبهات قابلة للكتم ومذكرات كتابية.\nالإشعارات تعمل حتى لو كان التطبيق مغلقاً.',
            style: TextStyle(color: t.textSecondary),
          ),
        ),
      ]),
    );
  }

  Widget _colorDot(Color c) => Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24),
        ),
      );
}
