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
      employeeId: widget.employeeId,
        startDate:  _fmt(_firstOfMonth),
        endDate:    _fmt(_lastOfMonth),
        limit:      50,
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

  static const _bg        = Color(0xFF434B5E);  //restored original dark page background
  static const _card      = Color(0xFFE4E8F0);   // the old background tone now used for day containers
  static const _cardBorder= Color(0xFFC7CEDB);
  static const _accent    = Color(0xFF2F5CFF);
  static const _green     = Color(0xFF14A44D);
  static const _amber     = Color(0xFFE08900);
  static const _textPrimary   = Colors.white;         // page-level text (title, month label, empty/error states) — needs to read on dark bg
  static const _textSecondary = Color(0xFF8B9CC0);    // page-level secondary text
  static const _textOnCard        = Color(0xFF1B1F27); // text inside the light day cards — needs to read on light bg
  static const _textOnCardSecondary = Color(0xFF667085);

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
                  color: _textOnCard, size: 18),
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
                color: _card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _accent, width: 1.4),
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
          color: enabled ? _textOnCard : _textOnCardSecondary.withAlpha(150),
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
          color: _card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: 1.4),
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
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
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
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: date + status badge
          Row(
            children: [
              // Date bubble (larger)
              Container(
                width: 64,
                height: 72,
                decoration: BoxDecoration(
                  color: _accent.withAlpha(30),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _accent.withAlpha(90)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DateTime.parse(record.date).day.toString(),
                      style: const TextStyle(
                        color: _accent,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _weekdayShort(record.date),
                      style: const TextStyle(
                        color: _accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Full date label + status badge
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fmtDateLabel(record.date),
                      style: const TextStyle(
                        color: _textOnCard,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withAlpha(60),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: statusColor, width: 1.4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isComplete ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                            color: statusColor,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isComplete ? 'Complete' : 'Incomplete',
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          Divider(color: _cardBorder, height: 1),
          const SizedBox(height: 16),

          // Detailed IN / OUT / Hours row
          Row(
            children: [
              Expanded(
                child: _detailBlock(
                  icon: Icons.login_rounded,
                  label: 'Clock In',
                  value: _fmtTime(record.clockIn),
                  color: _green,
                ),
              ),
              Container(width: 1, height: 44, color: _cardBorder),
              Expanded(
                child: _detailBlock(
                  icon: Icons.logout_rounded,
                  label: 'Clock Out',
                  value: _fmtTime(record.clockOut),
                  color: _amber,
                ),
              ),
              Container(width: 1, height: 44, color: _cardBorder),
              Expanded(
                child: _detailBlock(
                  icon: Icons.timelapse_rounded,
                  label: 'Total Hours',
                  value: record.hoursWorked,
                  color: _accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailBlock({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: _textOnCardSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: _textOnCard,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _timeChip(IconData icon, String label, String time, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
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
