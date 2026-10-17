import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../widgets/lucky_common.dart';

// ---------------------------------------------------------------------------
// Algorithm
// ---------------------------------------------------------------------------

/// La pirámide es una FUNCIÓN PURA de la fecha, así que se calcula acá y no
/// se pide al backend: la misma fecha da siempre la misma pirámide, funciona
/// sin señal y cualquier fecha del selector responde al instante — antes las
/// anteriores a la primera corrida del cron devolvían 404.
///
/// Builds pyramid rows from [date].
/// Base row: digits of DDMMYYYY (8 digits).
/// Each next row: (a + b) % 10 for every adjacent pair.
/// Stops when only one digit remains.
List<List<int>> _buildPyramidRows(DateTime date) {
  final dd = date.day.toString().padLeft(2, '0');
  final mm = date.month.toString().padLeft(2, '0');
  final yyyy = date.year.toString();
  final base = '$dd$mm$yyyy'.split('').map(int.parse).toList();
  final rows = <List<int>>[base];
  while (rows.last.length > 1) {
    final prev = rows.last;
    rows.add([
      for (var i = 0; i < prev.length - 1; i++)
        (prev[i] + prev[i + 1]) % 10,
    ]);
  }
  return rows;
}

/// Derives up to 6 recommended 2-digit lottery numbers from the pyramid.
///
/// Strategy:
/// 1. tip + each digit of the penultimate row (length 2).
/// 2. each digit of penultimate row + tip.
/// 3. tip + each digit of the 3rd-from-last row (length 3).
/// Deduplicates and caps at 6.
List<String> _recommendedFrom(List<List<int>> rows) {
  if (rows.length < 2) return [];
  final seen = <String>{};
  final result = <String>[];

  void add(int a, int b) {
    final s = '$a$b';
    if (seen.add(s)) result.add(s);
  }

  final tip = rows.last.first;
  final pen = rows[rows.length - 2]; // length 2

  for (final d in pen) {
    add(tip, d);
  }
  for (final d in pen) {
    add(d, tip);
  }

  if (rows.length >= 3) {
    final third = rows[rows.length - 3]; // length 3
    for (final d in third) {
      if (result.length >= 6) break;
      add(tip, d);
    }
  }

  return result.take(6).toList();
}

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

class PyramidLuckyPage extends StatefulWidget {
  const PyramidLuckyPage({super.key});

  @override
  State<PyramidLuckyPage> createState() => _PyramidLuckyPageState();
}

class _PyramidLuckyPageState extends State<PyramidLuckyPage> {
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = DateTime(now.year, now.month, now.day);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year, now.month, now.day),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final rows = _buildPyramidRows(_date);
    final recommended = _recommendedFrom(rows);
    return Scaffold(
      appBar: AppBar(title: const Text('Pirámide de la Suerte')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            LuckyDateHeader(date: _date, onTap: _pickDate),
            _PyramidView(rows: rows),
            RecommendedSection(numbers: recommended),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pyramid widget
// ---------------------------------------------------------------------------

class _PyramidView extends StatelessWidget {
  const _PyramidView({required this.rows});

  final List<List<int>> rows;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Colors.white, AppTheme.accentSoft],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.14),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            // Base at top, tip at bottom.
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: row
                      .map<Widget>((n) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: _NumberDot(value: n),
                          ))
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NumberDot extends StatelessWidget {
  const _NumberDot({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.accent, AppTheme.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.25),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        '$value',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 17,
        ),
      ),
    );
  }
}
