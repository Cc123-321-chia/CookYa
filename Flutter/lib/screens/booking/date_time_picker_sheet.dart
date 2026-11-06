// screens/booking/date_time_picker_sheet.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import '../../models/booking_models.dart';

class DateTimePickerResult {
  final DateTime date;
  final DaySlotOption slot;
  final int quantity;

  DateTimePickerResult({
    required this.date,
    required this.slot,
    required this.quantity,
  });
}

Future<DateTimePickerResult?> showDateTimePickerSheet({
  required BuildContext context,
  required CookingClassModel classItem,
}) {
  return showModalBottomSheet<DateTimePickerResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _DateTimePickerSheet(classItem: classItem),
  );
}

class _DateTimePickerSheet extends StatefulWidget {
  final CookingClassModel classItem;

  const _DateTimePickerSheet({required this.classItem});

  @override
  State<_DateTimePickerSheet> createState() => _DateTimePickerSheetState();
}

class _DateTimePickerSheetState extends State<_DateTimePickerSheet> {
  final DateTime _today = DateTime.now();

  // Currently displayed month (first day of month)
  late DateTime _month;

  // Selected day
  DateTime? _selectedDay;

  // Per-day remaining capacity for the displayed month
  final Map<String, int> _monthRemaining = {};

  // Slots for the selected day
  List<DaySlotOption> _slots = [];
  DaySlotOption? _selectedSlot;
  int _quantity = 1;

  bool _loadingMonth = false;
  bool _loadingSlots = false;

  static const List<String> _weekdayHeaders = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
  ];

  @override
  void initState() {
    super.initState();
    _month = DateTime(_today.year, _today.month, 1);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadMonth();
      if (!mounted) return;
      final firstAvailable = _firstAvailableDayInMonth();
      final day = firstAvailable ?? _today;
      setState(() => _selectedDay = day);
      _loadSlots(day);
    });
  }

  // ---------- Helpers ----------

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  int _remainingFor(DateTime d) {
    return _monthRemaining[_fmtDate(d)] ?? 0;
  }

  DateTime? _firstAvailableDayInMonth() {
    final todayMidnight = DateTime(_today.year, _today.month, _today.day);
    final days = _daysInMonth(_month);
    for (int day = 1; day <= days; day++) {
      final d = DateTime(_month.year, _month.month, day);
      if (d.isBefore(todayMidnight)) continue;
      if (_remainingFor(d) > 0) return d;
    }
    return null;
  }

  int _daysInMonth(DateTime m) {
    final next = DateTime(m.year, m.month + 1, 1);
    return next.subtract(const Duration(days: 1)).day;
  }

  // ---------- Loading ----------

  Future<void> _loadMonth() async {
    setState(() => _loadingMonth = true);
    final result = await ApiService.getClassMonthOverview(
      classId: widget.classItem.id,
      year: _month.year,
      month: _month.month,
    );
    if (!mounted) return;
    if (result['success'] == true) {
      final list = result['data'] as List;
      final map = <String, int>{};
      for (final item in list) {
        final d = item['date'] as String? ?? '';
        final r = item['remaining'];
        map[d] = (r is int) ? r : int.tryParse('$r') ?? 0;
      }
      setState(() {
        _monthRemaining
          ..clear()
          ..addAll(map);
        _loadingMonth = false;
      });
    } else {
      setState(() => _loadingMonth = false);
    }
  }

  Future<void> _loadSlots(DateTime day) async {
    setState(() {
      _loadingSlots = true;
      _slots = [];
      _selectedSlot = null;
      _quantity = 1;
    });

    final result = await ApiService.getClassDaySlots(
      classId: widget.classItem.id,
      date: _fmtDate(day),
    );

    if (!mounted) return;

    if (result['success'] == true) {
      final list = (result['data'] as List)
          .map((e) => DaySlotOption.fromJson(e))
          .toList();
      setState(() {
        _slots = list;
        _loadingSlots = false;
      });
    } else {
      setState(() => _loadingSlots = false);
    }
  }

  // ---------- Navigation ----------

  void _onDayTap(DateTime d) {
    setState(() => _selectedDay = d);
    _loadSlots(d);
  }

  Future<void> _goPrevMonth() async {
    final prev = DateTime(_month.year, _month.month - 1, 1);
    // Prevent going before the current month
    if (prev.isBefore(DateTime(_today.year, _today.month, 1))) return;
    setState(() => _month = prev);
    await _loadMonth();
    if (!mounted) return;
    final firstAvailable = _firstAvailableDayInMonth();
    final day = firstAvailable ?? prev;
    setState(() => _selectedDay = day);
    _loadSlots(day);
  }

  Future<void> _goNextMonth() async {
    final next = DateTime(_month.year, _month.month + 1, 1);
    setState(() => _month = next);
    await _loadMonth();
    if (!mounted) return;
    final firstAvailable = _firstAvailableDayInMonth();
    final day = firstAvailable ?? next;
    setState(() => _selectedDay = day);
    _loadSlots(day);
  }

  bool get _canGoPrev {
    final thisMonth = DateTime(_today.year, _today.month, 1);
    return _month.isAfter(thisMonth);
  }

  // ---------- Build ----------

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.92;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: Color(0xFFFFF9E6),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFC9A96E).withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                Text(
                  'Select Date & Time',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF6B4C2A),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Color(0xFF6B4C2A)),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMonthNavigator(),
                  _buildWeekdayHeader(),
                  _buildMonthGrid(),
                  const SizedBox(height: 8),
                  _buildLegend(),
                  const SizedBox(height: 20),
                  _buildSlotsHeader(),
                  _buildSlotList(),
                  if (_selectedSlot != null) _buildQuantityPicker(),
                  const SizedBox(height: 20),
                  _buildContinueButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Month navigator ----------

  Widget _buildMonthNavigator() {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          IconButton(
            onPressed: _canGoPrev ? _goPrevMonth : null,
            icon: const Icon(Icons.chevron_left),
            color: const Color(0xFFFFB347),
          ),
          Expanded(
            child: Center(
              child: Text(
                '${months[_month.month - 1]} ${_month.year}',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF6B4C2A),
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: _goNextMonth,
            icon: const Icon(Icons.chevron_right),
            color: const Color(0xFFFFB347),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: _weekdayHeaders.map((name) {
          return Expanded(
            child: Center(
              child: Text(
                name,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFC9A96E),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMonthGrid() {
    if (_loadingMonth) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFFFFB347)),
        ),
      );
    }

    final firstOfMonth = DateTime(_month.year, _month.month, 1);
    // Monday = index 0
    final leadingEmpty = (firstOfMonth.weekday - 1) % 7;
    final daysInMonth = _daysInMonth(_month);
    final todayMidnight = DateTime(_today.year, _today.month, _today.day);

    final cells = <Widget>[];
    for (int i = 0; i < leadingEmpty; i++) {
      cells.add(const SizedBox());
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final d = DateTime(_month.year, _month.month, day);
      final isPast = d.isBefore(todayMidnight);
      final remaining = _remainingFor(d);
      final isFull = remaining <= 0;
      final isSelected = _selectedDay != null &&
          _selectedDay!.year == d.year &&
          _selectedDay!.month == d.month &&
          _selectedDay!.day == d.day;

      final disabled = isPast || isFull;

      cells.add(
        GestureDetector(
          onTap: disabled ? null : () => _onDayTap(d),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFFFB347)
                  : (disabled ? Colors.transparent : Colors.white),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$day',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : (disabled
                            ? Colors.grey.shade400
                            : const Color(0xFF6B4C2A)),
                  ),
                ),
                if (!isPast && !isFull) ...[
                  const SizedBox(height: 2),
                  Text(
                    '$remaining',
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFFFFB347),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9E6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: GridView.count(
        crossAxisCount: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.0,
        children: cells,
      ),
    );
  }

  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _legendDot(const Color(0xFFFFB347), 'Selected'),
          const SizedBox(width: 12),
          _legendDot(Colors.white, 'Available'),
          const SizedBox(width: 12),
          _legendDot(Colors.grey.shade300, 'Unavailable'),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: Colors.grey.shade300, width: 0.5),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10,
            color: const Color(0xFFC9A96E),
          ),
        ),
      ],
    );
  }

  Widget _buildSlotsHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        _selectedDay == null
            ? 'Select a day'
            : 'Slots on ${_selectedDay!.day}/${_selectedDay!.month}/${_selectedDay!.year}',
        style: GoogleFonts.poppins(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF6B4C2A),
        ),
      ),
    );
  }

  Widget _buildSlotList() {
    if (_loadingSlots) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFFFFB347)),
        ),
      );
    }
    if (_slots.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            'No time slots on this day',
            style: GoogleFonts.poppins(color: const Color(0xFFC9A96E)),
          ),
        ),
      );
    }
    return Column(
      children: _slots.map((slot) {
        final started = slot.started;
        final isFull = slot.remaining <= 0;
        final disabled = started || isFull;
        final selected = _selectedSlot?.id == slot.id && !disabled;

        return GestureDetector(
          onTap: disabled
              ? null
              : () => setState(() {
                    _selectedSlot = slot;
                    _quantity = 1;
                  }),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: disabled
                  ? Colors.grey.shade100
                  : (selected ? const Color(0xFFFFF0B5) : Colors.white),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.access_time,
                  color:
                      disabled ? Colors.grey : const Color(0xFFFFB347),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        slot.timeRange,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: disabled
                              ? Colors.grey
                              : const Color(0xFF6B4C2A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        started
                            ? 'Already started'
                            : (isFull
                                ? 'Fully booked'
                                : '${slot.remaining} seat(s) left'),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: started
                              ? Colors.grey
                              : (isFull
                                  ? Colors.redAccent
                                  : const Color(0xFFC9A96E)),
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.check_circle,
                    color: Color(0xFFFFB347),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildQuantityPicker() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Text(
            'Number of people',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6B4C2A),
            ),
          ),
          const Spacer(),
          _qtyButton(
            icon: Icons.remove,
            enabled: _quantity > 1,
            onTap: () => setState(() => _quantity--),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              '$_quantity',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF6B4C2A),
              ),
            ),
          ),
          _qtyButton(
            icon: Icons.add,
            enabled: _quantity < _selectedSlot!.remaining,
            onTap: () => setState(() => _quantity++),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ElevatedButton(
        onPressed: (_selectedDay == null || _selectedSlot == null)
            ? null
            : () {
                Navigator.pop(
                  context,
                  DateTimePickerResult(
                    date: _selectedDay!,
                    slot: _selectedSlot!,
                    quantity: _quantity,
                  ),
                );
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFFB347),
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          disabledBackgroundColor: Colors.grey.shade300,
        ),
        child: Text(
          'Continue',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _qtyButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFFFFF0B5) : Colors.grey.shade200,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? const Color(0xFF6B4C2A) : Colors.grey,
        ),
      ),
    );
  }
}