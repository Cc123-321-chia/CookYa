// screens/booking/add_availability_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import '../../models/booking_models.dart';

class AddAvailabilityScreen extends StatefulWidget {
  final CookingClassModel cookingClass;
  final ClassAvailability? existingAvailability;

  const AddAvailabilityScreen({
    super.key,
    required this.cookingClass,
    this.existingAvailability,
  });

  bool get isEditing => existingAvailability != null;

  @override
  State<AddAvailabilityScreen> createState() => _AddAvailabilityScreenState();
}

class _AddAvailabilityScreenState extends State<AddAvailabilityScreen> {
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));

  final Set<int> _selectedDays = <int>{};
  final Map<int, List<_DraftSlot>> _daySlots = {
    0: <_DraftSlot>[],
    1: <_DraftSlot>[],
    2: <_DraftSlot>[],
    3: <_DraftSlot>[],
    4: <_DraftSlot>[],
    5: <_DraftSlot>[],
    6: <_DraftSlot>[],
  };

  bool _saving = false;

  static const List<String> _weekdayShort = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
  ];

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      final a = widget.existingAvailability!;
      final s = DateTime.tryParse(a.startDate);
      final e = DateTime.tryParse(a.endDate);
      if (s != null) _startDate = s;
      if (e != null) _endDate = e;

      if (a.isDailySame && a.slots.isNotEmpty) {
        final draft = a.slots
            .map((s) => _DraftSlot(
                  start: _parseTime(s.startTime),
                  end: _parseTime(s.endTime),
                  maxSlots: s.maxSlots,
                ))
            .toList();
        final start =
            DateTime(_startDate.year, _startDate.month, _startDate.day);
        final end = DateTime(_endDate.year, _endDate.month, _endDate.day);
        DateTime d = start;
        while (!d.isAfter(end)) {
          _selectedDays.add(d.weekday - 1);
          d = d.add(const Duration(days: 1));
        }
        for (final dow in _selectedDays) {
          _daySlots[dow] = draft
              .map((x) => _DraftSlot(
                    start: x.start,
                    end: x.end,
                    maxSlots: x.maxSlots,
                  ))
              .toList();
        }
      } else {
        for (final s in a.slots) {
          final dow = s.dayOfWeek;
          if (dow == null || dow < 0 || dow > 6) continue;
          _selectedDays.add(dow);
          _daySlots[dow]!.add(_DraftSlot(
            start: _parseTime(s.startTime),
            end: _parseTime(s.endTime),
            maxSlots: s.maxSlots,
          ));
        }
      }
    }
  }

  TimeOfDay _parseTime(String t) {
    final parts = t.split(':');
    if (parts.length >= 2) {
      return TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 0,
        minute: int.tryParse(parts[1]) ?? 0,
      );
    }
    return const TimeOfDay(hour: 0, minute: 0);
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate.add(const Duration(days: 30));
        }
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _pickTime(bool isStart, _DraftSlot slot) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? slot.start : slot.end,
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        slot.start = picked;
      } else {
        slot.end = picked;
      }
    });
  }

  void _toggleDay(int dow) {
    setState(() {
      if (_selectedDays.contains(dow)) {
        _selectedDays.remove(dow);
      } else {
        _selectedDays.add(dow);
        if (_daySlots[dow]!.isEmpty) {
          _daySlots[dow]!.add(_DraftSlot(
            start: const TimeOfDay(hour: 13, minute: 0),
            end: const TimeOfDay(hour: 15, minute: 0),
            maxSlots: 10,
          ));
        }
      }
    });
  }

  void _applyToAll(int sourceDow) {
    final source = _daySlots[sourceDow]!;
    if (source.isEmpty) {
      _showError(
          'Add at least one time slot on ${_weekdayShort[sourceDow]} first.');
      return;
    }
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Apply to other days?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'This will copy the ${source.length} slot(s) from '
          '${_weekdayShort[sourceDow]} to all other selected weekdays.',
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              setState(() {
                for (final d in _selectedDays) {
                  if (d == sourceDow) continue;
                  _daySlots[d] = source
                      .map((s) => _DraftSlot(
                            start: s.start,
                            end: s.end,
                            maxSlots: s.maxSlots,
                          ))
                      .toList();
                }
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFB347),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(
              'Apply',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  int get _totalDaysCount {
    if (_selectedDays.isEmpty) return 0;
    int count = 0;
    DateTime d = DateTime(_startDate.year, _startDate.month, _startDate.day);
    final end = DateTime(_endDate.year, _endDate.month, _endDate.day);
    while (!d.isAfter(end)) {
      if (_selectedDays.contains(d.weekday - 1)) count++;
      d = d.add(const Duration(days: 1));
    }
    return count;
  }

  int get _totalSlotCount {
    if (_selectedDays.isEmpty) return 0;
    final perDowCount = <int, int>{};
    DateTime d = DateTime(_startDate.year, _startDate.month, _startDate.day);
    final end = DateTime(_endDate.year, _endDate.month, _endDate.day);
    while (!d.isAfter(end)) {
      final dow = d.weekday - 1;
      if (_selectedDays.contains(dow)) {
        perDowCount[dow] = (perDowCount[dow] ?? 0) + 1;
      }
      d = d.add(const Duration(days: 1));
    }
    int total = 0;
    perDowCount.forEach((dow, times) {
      total += (_daySlots[dow]?.length ?? 0) * times;
    });
    return total;
  }

  bool get _isAllSame {
    if (_selectedDays.isEmpty) return true;
    final first = _daySlots[_selectedDays.first]!;
    if (first.isEmpty) return false;
    for (final dow in _selectedDays) {
      final list = _daySlots[dow]!;
      if (list.length != first.length) return false;
      for (int i = 0; i < list.length; i++) {
        if (list[i].start != first[i].start ||
            list[i].end != first[i].end ||
            list[i].maxSlots != first[i].maxSlots) {
          return false;
        }
      }
    }
    return true;
  }

  Future<void> _save() async {
    if (_selectedDays.isEmpty) {
      _showError('Please select at least one weekday.');
      return;
    }
    for (final dow in _selectedDays) {
      final slots = _daySlots[dow]!;
      if (slots.isEmpty) {
        _showError('${_weekdayShort[dow]} has no time slot yet.');
        return;
      }
      for (final s in slots) {
        if (_toMinutes(s.end) <= _toMinutes(s.start)) {
          _showError(
              '${_weekdayShort[dow]}: end time must be later than start time.');
          return;
        }
        if (s.maxSlots < 1) {
          _showError('${_weekdayShort[dow]}: max people must be >= 1.');
          return;
        }
      }
    }

    setState(() => _saving = true);

    final isDailySame = _isAllSame;
    final slots = <Map<String, dynamic>>[];

    if (isDailySame) {
      final firstDow = _selectedDays.first;
      for (final s in _daySlots[firstDow]!) {
        slots.add({
          'start_time': _fmtTime(s.start),
          'end_time': _fmtTime(s.end),
          'max_slots': s.maxSlots,
        });
      }
    } else {
      for (final dow in _selectedDays) {
        for (final s in _daySlots[dow]!) {
          slots.add({
            'day_of_week': dow,
            'start_time': _fmtTime(s.start),
            'end_time': _fmtTime(s.end),
            'max_slots': s.maxSlots,
          });
        }
      }
    }

    final result = widget.isEditing
        ? await ApiService.updateAvailability(
            availabilityId: widget.existingAvailability!.id,
            startDate: _fmtDate(_startDate),
            endDate: _fmtDate(_endDate),
            isDailySame: isDailySame,
            setType: 'weekly',
            slots: slots,
          )
        : await ApiService.setAvailability(
            classId: widget.cookingClass.id,
            startDate: _fmtDate(_startDate),
            endDate: _fmtDate(_endDate),
            isDailySame: isDailySame,
            setType: 'weekly',
            slots: slots,
          );

    if (!mounted) return;
    setState(() => _saving = false);

    if (result['success'] == true) {
      Navigator.pop(context, true);
    } else {
      _showError(result['error']?.toString() ?? 'Failed to save.');
    }
  }

  void _showError(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Notice',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text(msg, style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  int _toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

  void _showPreview() {
    final dates = <DateTime>[];
    DateTime d = DateTime(_startDate.year, _startDate.month, _startDate.day);
    final end = DateTime(_endDate.year, _endDate.month, _endDate.day);
    while (!d.isAfter(end)) {
      if (_selectedDays.contains(d.weekday - 1)) dates.add(d);
      d = d.add(const Duration(days: 1));
    }

    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(16),
          constraints: const BoxConstraints(maxHeight: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Preview',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: const Color(0xFF6B4C2A))),
              const SizedBox(height: 4),
              Text(
                '${dates.length} day(s) · $_totalSlotCount slot instance(s)',
                style: GoogleFonts.poppins(
                    fontSize: 12, color: const Color(0xFFC9A96E)),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: dates.map((dt) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF0B5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('${dt.month}/${dt.day}',
                            style: GoogleFonts.poppins(fontSize: 11)),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Close',
                      style: GoogleFonts.poppins(
                          color: const Color(0xFFFFB347),
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9E6),
      appBar: AppBar(
        title: Text(
          widget.isEditing ? 'Edit Availability' : 'Set Availability',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: const Color(0xFF6B4C2A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDateRangeSection(),
            const SizedBox(height: 20),
            _buildWeekdayPicker(),
            const SizedBox(height: 20),
            ..._buildSelectedDaySections(),
            const SizedBox(height: 24),
            _buildSummaryCard(),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFB347),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5),
                    )
                  : Text(
                      widget.isEditing ? 'Save Changes' : 'Save',
                      style: GoogleFonts.poppins(
                          fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRangeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Valid Period'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
                child:
                    _dateTile('Start date', _startDate, () => _pickDate(true))),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child:
                  Icon(Icons.arrow_forward, size: 18, color: Color(0xFFC9A96E)),
            ),
            Expanded(
                child: _dateTile('End date', _endDate, () => _pickDate(false))),
          ],
        ),
      ],
    );
  }

  Widget _buildWeekdayPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Which weekdays do you teach?'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(7, (i) {
              final selected = _selectedDays.contains(i);
              return GestureDetector(
                onTap: () => _toggleDay(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 40,
                  height: 56,
                  decoration: BoxDecoration(
                    color:
                        selected ? const Color(0xFFFFB347) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _weekdayShort[i].substring(0, 1),
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? Colors.white
                              : const Color(0xFF6B4C2A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Icon(
                        selected ? Icons.check_circle : Icons.circle_outlined,
                        size: 12,
                        color: selected
                            ? Colors.white
                            : const Color(0xFFC9A96E),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildSelectedDaySections() {
    if (_selectedDays.isEmpty) {
      return [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              const Icon(Icons.touch_app, size: 40, color: Color(0xFFFFD966)),
              const SizedBox(height: 8),
              Text(
                'Pick at least one weekday above',
                style: GoogleFonts.poppins(
                    color: const Color(0xFFC9A96E), fontSize: 13),
              ),
            ],
          ),
        ),
      ];
    }

    final sorted = _selectedDays.toList()..sort();
    final widgets = <Widget>[];
    for (final dow in sorted) {
      widgets.add(_buildDaySlotsSection(dow));
      widgets.add(const SizedBox(height: 16));
    }
    return widgets;
  }

  Widget _buildDaySlotsSection(int dow) {
    final slots = _daySlots[dow]!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04), blurRadius: 6),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB347),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _weekdayShort[dow],
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              if (_selectedDays.length > 1)
                TextButton.icon(
                  onPressed: () => _applyToAll(dow),
                  icon: const Icon(Icons.copy_all_outlined,
                      size: 14, color: Color(0xFFFFB347)),
                  label: Text('Apply to others',
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: const Color(0xFFFFB347))),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: const Size(0, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ...slots.asMap().entries.map((e) {
            return _buildSlotRow(
              e.value,
              onRemove: () => setState(() => slots.removeAt(e.key)),
              onStartTap: () => _pickTime(true, e.value),
              onEndTap: () => _pickTime(false, e.value),
            );
          }),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: () {
              setState(() {
                slots.add(_DraftSlot(
                  start: const TimeOfDay(hour: 13, minute: 0),
                  end: const TimeOfDay(hour: 15, minute: 0),
                  maxSlots: 10,
                ));
              });
            },
            icon: const Icon(Icons.add, size: 16, color: Color(0xFFFFB347)),
            label: Text('Add time slot',
                style: GoogleFonts.poppins(
                    fontSize: 12, color: const Color(0xFFFFB347))),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotRow(
    _DraftSlot slot, {
    required VoidCallback onRemove,
    required VoidCallback onStartTap,
    required VoidCallback onEndTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9E6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _timeChip(slot.start, onStartTap),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text('–', style: TextStyle(color: Color(0xFFC9A96E))),
          ),
          _timeChip(slot.end, onEndTap),
          const Spacer(),
          SizedBox(
            width: 64,
            child: TextFormField(
              initialValue: slot.maxSlots.toString(),
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                labelText: 'Max',
                labelStyle: GoogleFonts.poppins(
                    fontSize: 11, color: const Color(0xFFC9A96E)),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              style: GoogleFonts.poppins(fontSize: 13),
              onChanged: (v) {
                final n = int.tryParse(v);
                if (n != null) slot.maxSlots = n;
              },
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close, size: 18, color: Colors.redAccent),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  Widget _timeChip(TimeOfDay t, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFFD966)),
        ),
        child: Text(
          _fmtTime(t),
          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final days = _totalDaysCount;
    final slotCount = _totalSlotCount;
    final isSame = _isAllSame;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0B5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFD966), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline,
                  size: 18, color: Color(0xFFFFB347)),
              const SizedBox(width: 8),
              Text('Will generate',
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF6B4C2A))),
            ],
          ),
          const SizedBox(height: 6),
          Text('$days day(s), $slotCount bookable slot(s)',
              style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF6B4C2A))),
          if (_selectedDays.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              isSame
                  ? 'Identical slots on every selected weekday'
                  : 'Custom slots per weekday',
              style: GoogleFonts.poppins(
                  fontSize: 11, color: const Color(0xFFC9A96E)),
            ),
          ],
          if (days > 0 && slotCount > 0)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _showPreview,
                icon: const Icon(Icons.calendar_month,
                    size: 16, color: Color(0xFFFFB347)),
                label: Text('Preview',
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFFFFB347),
                        fontWeight: FontWeight.w600)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF6B4C2A),
      ),
    );
  }

  Widget _dateTile(String label, DateTime d, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFFD966)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 11, color: const Color(0xFFC9A96E))),
            const SizedBox(height: 2),
            Text(
              _fmtDate(d),
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF6B4C2A),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DraftSlot {
  TimeOfDay start;
  TimeOfDay end;
  int maxSlots;

  _DraftSlot({
    required this.start,
    required this.end,
    required this.maxSlots,
  });
}