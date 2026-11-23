// Tema și componentele comune — aceleași culori ca aplicația de pe calculator.
import 'dart:math';

import 'package:flutter/material.dart';

class Culori {
  final bool inchisa;
  const Culori(this.inchisa);
  Color get bg => inchisa ? const Color(0xFF0B1120) : const Color(0xFFEEF2F7);
  Color get surface => inchisa ? const Color(0xFF111A2E) : Colors.white;
  Color get surface2 =>
      inchisa ? const Color(0xFF16223A) : const Color(0xFFF5F7FB);
  Color get border =>
      inchisa ? const Color(0xFF22314D) : const Color(0xFFE3E8EF);
  Color get text => inchisa ? const Color(0xFFE5ECF6) : const Color(0xFF0F172A);
  Color get muted =>
      inchisa ? const Color(0xFF8A9BB5) : const Color(0xFF64748B);
  Color get accent =>
      inchisa ? const Color(0xFF3B82F6) : const Color(0xFF2563EB);
  Color get accent2 =>
      inchisa ? const Color(0xFF6366F1) : const Color(0xFF4F46E5);
  Color get ok => inchisa ? const Color(0xFF22C55E) : const Color(0xFF16A34A);
  Color get warn => inchisa ? const Color(0xFFF59E0B) : const Color(0xFFD97706);
  Color get err => inchisa ? const Color(0xFFEF4444) : const Color(0xFFDC2626);
  Color get idle => inchisa ? const Color(0xFF64748B) : const Color(0xFF94A3B8);

  Color stare(String s) =>
      {'ok': ok, 'degradat': warn, 'cazut': err}[s] ?? idle;
  Color fondStare(String s) => inchisa
      ? ({
              'ok': const Color(0xFF0D2619),
              'degradat': const Color(0xFF2A200B),
              'cazut': const Color(0xFF2C1215),
            }[s] ??
            surface)
      : ({
              'ok': const Color(0xFFEFFDF4),
              'degradat': const Color(0xFFFFFBEB),
              'cazut': const Color(0xFFFEF2F2),
            }[s] ??
            surface);
  Color conturStare(String s) => inchisa
      ? ({
              'ok': const Color(0xFF1F5A3A),
              'degradat': const Color(0xFF6B4F12),
              'cazut': const Color(0xFF7A2A31),
            }[s] ??
            border)
      : ({
              'ok': const Color(0xFF86EFAC),
              'degradat': const Color(0xFFFCD34D),
              'cazut': const Color(0xFFFCA5A5),
            }[s] ??
            border);

  // tente pentru dale: (fond, culoare puternică)
  (Color, Color) tenta(String n) {
    final l = {
      'sky': (
        const Color(0xFFE0F2FE),
        const Color(0xFF0284C7),
        const Color(0xFF0C2738),
        const Color(0xFF38BDF8),
      ),
      'violet': (
        const Color(0xFFEDE9FE),
        const Color(0xFF7C3AED),
        const Color(0xFF1E1838),
        const Color(0xFFA78BFA),
      ),
      'teal': (
        const Color(0xFFCCFBF1),
        const Color(0xFF0D9488),
        const Color(0xFF0A2B29),
        const Color(0xFF2DD4BF),
      ),
      'amber': (
        const Color(0xFFFEF3C7),
        const Color(0xFFB45309),
        const Color(0xFF2B210B),
        const Color(0xFFFBBF24),
      ),
      'rose': (
        const Color(0xFFFFE4E6),
        const Color(0xFFE11D48),
        const Color(0xFF2E1219),
        const Color(0xFFFB7185),
      ),
      'lime': (
        const Color(0xFFECFCCB),
        const Color(0xFF4D7C0F),
        const Color(0xFF1A260E),
        const Color(0xFFA3E635),
      ),
    }[n]!;
    return inchisa ? (l.$3, l.$4) : (l.$1, l.$2);
  }

  Color dbm(int? d) {
    if (d == null) return idle;
    if (d >= -60) return ok;
    if (d >= -67) return const Color(0xFF65A30D);
    if (d >= -75) return warn;
    return err;
  }
}

Culori culori(BuildContext c) =>
    Culori(Theme.of(c).brightness == Brightness.dark);

String calitateDbm(int? d) {
  if (d == null) return '—';
  if (d >= -55) return 'excelent';
  if (d >= -65) return 'foarte bun';
  if (d >= -70) return 'bun';
  if (d >= -75) return 'slab';
  return 'foarte slab';
}

ThemeData temaApp(bool inchisa) {
  final c = Culori(inchisa);
  return ThemeData(
    useMaterial3: true,
    brightness: inchisa ? Brightness.dark : Brightness.light,
    scaffoldBackgroundColor: c.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: c.accent,
      brightness: inchisa ? Brightness.dark : Brightness.light,
      surface: c.surface,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: c.bg,
      foregroundColor: c.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        color: c.text,
      ),
    ),
    cardTheme: CardThemeData(
      color: c.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: c.border),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.surface,
      indicatorColor: c.accent.withValues(alpha: 0.15),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.text),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.accent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    ),
  );
}

// ---------------------------------------------------------------- componente
class Pastila extends StatelessWidget {
  final String text, stare;
  const Pastila(this.text, this.stare, {super.key});
  @override
  Widget build(BuildContext context) {
    final c = culori(context);
    final col = c.stare(stare);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: col.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '●  $text',
        style: TextStyle(color: col, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}

class Tila extends StatelessWidget {
  final String eticheta, valoare, sub, nuanta;
  final Color? culoareValoare;
  final VoidCallback? onTap;
  const Tila(
    this.eticheta,
    this.valoare, {
    this.sub = '',
    this.nuanta = 'sky',
    this.culoareValoare,
    this.onTap,
    super.key,
  });
  @override
  Widget build(BuildContext context) {
    final c = culori(context);
    final (fond, tare) = c.tenta(nuanta);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: fond,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              eticheta.toUpperCase(),
              style: TextStyle(
                color: tare,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              valoare,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: culoareValoare ?? c.text,
              ),
            ),
            if (sub.isNotEmpty)
              Text(
                sub,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: c.muted, fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }
}

class BareSemnal extends StatelessWidget {
  final int? dbm;
  const BareSemnal(this.dbm, {super.key});
  @override
  Widget build(BuildContext context) {
    final c = culori(context);
    final n = dbm == null
        ? 0
        : dbm! >= -60
        ? 4
        : dbm! >= -67
        ? 3
        : dbm! >= -75
        ? 2
        : 1;
    return SizedBox(
      width: 22,
      height: 14,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < 4; i++)
            Padding(
              padding: const EdgeInsets.only(right: 1.5),
              child: Container(
                width: 4,
                height: 3.5 * (i + 1),
                decoration: BoxDecoration(
                  color: i < n ? c.dbm(dbm) : c.border,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class Sparkline extends StatelessWidget {
  final List<double?> v;
  final Color culoare;
  final double inaltime;
  const Sparkline(this.v, this.culoare, {this.inaltime = 36, super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
    height: inaltime,
    width: double.infinity,
    child: CustomPaint(painter: _Spark(v, culoare)),
  );
}

class _Spark extends CustomPainter {
  final List<double?> v;
  final Color c;
  _Spark(this.v, this.c);
  @override
  void paint(Canvas canvas, Size s) {
    final ok = v.whereType<double>().toList();
    if (v.length < 2 || ok.isEmpty) return;
    var mn = ok.reduce(min), mx = ok.reduce(max);
    if (mx - mn < 1) mx = mn + 1;
    final h = s.height - 4;
    final cale = Path(), umple = Path();
    var primul = true;
    for (var i = 0; i < v.length; i++) {
      final x = i * s.width / (v.length - 1);
      final y = v[i];
      if (y == null) {
        canvas.drawCircle(
          Offset(x, s.height - 2),
          1.8,
          Paint()..color = const Color(0xFFDC2626),
        );
        continue;
      }
      final py = 2 + h - (y - mn) / (mx - mn) * h;
      if (primul) {
        cale.moveTo(x, py);
        umple.moveTo(x, h + 2);
        umple.lineTo(x, py);
        primul = false;
      } else {
        cale.lineTo(x, py);
        umple.lineTo(x, py);
      }
    }
    umple.lineTo(s.width, h + 2);
    canvas.drawPath(umple, Paint()..color = c.withValues(alpha: 0.15));
    canvas.drawPath(
      cale,
      Paint()
        ..color = c
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_) => true;
}

class Sectiune extends StatelessWidget {
  final String titlu;
  final Widget copil;
  final Widget? dreapta;
  const Sectiune(this.titlu, this.copil, {this.dreapta, super.key});
  @override
  Widget build(BuildContext context) {
    final c = culori(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  titlu,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              ?dreapta,
            ],
          ),
          const SizedBox(height: 10),
          copil,
        ],
      ),
    );
  }
}

String cand(DateTime? t) {
  if (t == null) return '—';
  final d = DateTime.now().difference(t);
  if (d.inSeconds < 60) return 'acum';
  if (d.inMinutes < 60) return 'acum ${d.inMinutes} min';
  if (d.inHours < 24) return 'acum ${d.inHours} h';
  return '${t.day.toString().padLeft(2, '0')}.${t.month.toString().padLeft(2, '0')} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

String ora(DateTime t) =>
    '${t.day.toString().padLeft(2, '0')}.${t.month.toString().padLeft(2, '0')} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';

String durataText(int sec) {
  final z = sec ~/ 86400, h = (sec % 86400) ~/ 3600, m = (sec % 3600) ~/ 60;
  if (z > 0) return '$z zile $h h';
  if (h > 0) return '$h h $m min';
  return '$m min';
}
