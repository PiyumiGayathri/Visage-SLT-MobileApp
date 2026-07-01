import 'package:flutter/material.dart';
import 'services/attendance_history_service.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  /// The raw employee ID returned by the face-verification API (e.g. "019918")
  final String employeeId;

  const AttendanceHistoryScreen({super.key, required this.employeeId});

  @override
  State<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  // Currently displayed month
  late DateTime _currentMonth;

  // State
  bool _isLoading = false;
  String? _errorMessage;
  List<AttendanceRecord> _records = [];

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
    _loadHistory();
  }

  // ── Date helpers ─────────────────────────────────────────────────────────

  String _fmt(DateTime d, {String sep = '-'}) =>
      '${d.year}${sep}${d.month.toString().padLeft(2, '0')}${sep}${d.day.toString().padLeft(2, '0')}';

  String _monthLabel(DateTime d) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[d.month - 1]} ${d.year}';
  }

  DateTime get _firstOfMonth => DateTime(_currentMonth.year, _currentMonth.month, 1);
  DateTime get _lastOfMonth  => DateTime(_currentMonth.year, _currentMonth.month + 1, 0);

  // ── Data loading ──────────────────────────────────────────────────────────

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _records = [];
    });

    try {
      final records = await AttendanceHistoryService.fetchHistory(
      employeeId: '019918',        // TEMP HARDCODE FOR TESTING
      startDate: '2026-06-01',     // TEMP HARDCODE FOR TESTING
      endDate: '2026-06-30',       // TEMP HARDCODE FOR TESTING
      limit: 10,                   // TEMP HARDCODE FOR TESTING
      );
      if (mounted) {
        setState(() {
          _records = records;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
    _loadHistory();
  }

  void _nextMonth() {
    final now = DateTime.now();
    final isCurrentOrFuture =
        _currentMonth.year > now.year ||
        (_currentMonth.year == now.year && _currentMonth.month >= now.month);
    if (isCurrentOrFuture) return; // Don't go into the future
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
    _loadHistory();
  }

  // ── Time formatting helpers ───────────────────────────────────────────────

  String _fmtTime(DateTime? dt) {
    if (dt == null) return '--:--';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _fmtDateLabel(String dateStr) {
    // dateStr is "yyyy-MM-dd"
    try {
      final d = DateTime.parse(dateStr);
      const days   = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]}';
    } catch (_) {
      return dateStr;
    }
  }

  // ── Palette ───────────────────────────────────────────────────────────────

 static const _bg        = Color(0xFFF4F6F9);   // soft neutral background instead of near-black
  static const _card      = Color(0xFFFFFFFF);   // plain white cards instead of dark navy
  static const _cardBorder= Color(0xFFE1E5EC);   // light grey border instead of dark slate
  static const _accent    = Color(0xFF3B5FE0);   // calmer blue, less saturated than the old neon indigo
  static const _green     = Color(0xFF2E9E5B);   // muted, readable green instead of neon mint
  static const _amber     = Color(0xFFB8720C);   // deeper amber that reads clearly on white (the old bright amber is hard to read on light backgrounds)
  static const _textPrimary   = Color(0xFF1B1F27); // near-black instead of pure white
  static const _textSecondary = Color(0xFF667085); // medium grey instead of pale blue-grey

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            _buildMonthNavigator(),
            _buildSummaryRow(),
            const SizedBox(height: 12),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _cardBorder),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: _textPrimary, size: 18),
            ),
          ),
          const SizedBox(width: 16),

          // Title + employee id
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Attendance History',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'ID: ${widget.employeeId}',
                  style: const TextStyle(
                    color: _textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Refresh
          GestureDetector(
            onTap: _loadHistory,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _accent.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _accent.withAlpha(80)),
              ),
              child: const Icon(Icons.refresh_rounded, color: _accent, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  // ── Month navigator ───────────────────────────────────────────────────────

  Widget _buildMonthNavigator() {
    final now = DateTime.now();
    final isCurrentMonth =
        _currentMonth.year == now.year && _currentMonth.month == now.month;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous
          _navArrow(Icons.chevron_left_rounded, _previousMonth),

          // Month label
          Column(
            children: [
              Text(
                _monthLabel(_currentMonth),
                style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),

          // Next
          _navArrow(
            Icons.chevron_right_rounded,
            isCurrentMonth ? null : _nextMonth,
          ),
        ],
      ),
    );
  }

  Widget _navArrow(IconData icon, VoidCallback? onTap) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: enabled ? _card : _card.withAlpha(80),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: enabled ? _cardBorder : _cardBorder.withAlpha(60),
          ),
        ),
        child: Icon(
          icon,
          color: enabled ? _textPrimary : _textSecondary.withAlpha(80),
          size: 22,
        ),
      ),
    );
  }

  // ── Summary row ───────────────────────────────────────────────────────────

  Widget _buildSummaryRow() {
    if (_isLoading || _errorMessage != null) return const SizedBox.shrink();

    final presentCount = _records.length;
    final completeCount = _records.where((r) => r.clockOut != null).length;
    final incompleteCount = presentCount - completeCount;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        children: [
          _summaryChip('Present', presentCount, _green),
          const SizedBox(width: 10),
          _summaryChip('Complete', completeCount, _accent),
          const SizedBox(width: 10),
          _summaryChip('Incomplete', incompleteCount, _amber),
        ],
      ),
    );
  }

  Widget _summaryChip(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Column(
          children: [
            Text(
              count.toString(),
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color.withAlpha(180),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Body (loading / error / list) ─────────────────────────────────────────

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: _accent),
            SizedBox(height: 16),
            Text('Loading history...', style: TextStyle(color: _textSecondary)),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline_rounded,
                    color: Colors.redAccent, size: 40),
              ),
              const SizedBox(height: 20),
              const Text('Unable to load data',
                  style: TextStyle(
                      color: _textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadHistory,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_records.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _textSecondary.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.calendar_today_rounded,
                  color: _textSecondary, size: 40),
            ),
            const SizedBox(height: 20),
            const Text(
              'No attendance records',
              style: TextStyle(
                  color: _textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'No records found for ${_monthLabel(_currentMonth)}',
              style: const TextStyle(color: _textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      itemCount: _records.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _buildRecordCard(_records[i]),
    );
  }

  // ── Record card ───────────────────────────────────────────────────────────

  Widget _buildRecordCard(AttendanceRecord record) {
    final isComplete = record.clockOut != null;
    final statusColor = isComplete ? _green : _amber;

    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Date bubble
          Container(
            width: 52,
            height: 60,
            decoration: BoxDecoration(
              color: _accent.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _accent.withAlpha(60)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  DateTime.parse(record.date).day.toString(),
                  style: const TextStyle(
                    color: _accent,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _weekdayShort(record.date),
                  style: TextStyle(
                    color: _accent.withAlpha(180),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _fmtDateLabel(record.date),
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _timeChip(Icons.login_rounded, 'IN', _fmtTime(record.clockIn), _green),
                    const SizedBox(width: 8),
                    _timeChip(Icons.logout_rounded, 'OUT', _fmtTime(record.clockOut), _amber),
                  ],
                ),
              ],
            ),
          ),

          // Hours + status
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withAlpha(80)),
                ),
                child: Text(
                  isComplete ? 'Complete' : 'Incomplete',
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                record.hoursWorked,
                style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _timeChip(IconData icon, String label, String time, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 4),
          Text(
            '$label $time',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _weekdayShort(String dateStr) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    try {
      return days[DateTime.parse(dateStr).weekday - 1];
    } catch (_) {
      return '';
    }
  }
}
