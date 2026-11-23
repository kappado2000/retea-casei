// Teste la cerere, ca pe calculator. Fiecare întoarce Rezultat(titlu, verdict, nivel, randuri).
import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'monitor.dart';

class Rezultat {
  final String titlu, verdict, nivel; // nivel: ok | avertisment | eroare
  final List<(String, String)> randuri;
  Rezultat(this.titlu, this.verdict, this.nivel, this.randuri);
}

typedef Progres = void Function(String);

Future<Rezultat> pingSerie(
  String ip, {
  int n = 20,
  int pauzaMs = 200,
  Progres? progres,
}) async {
  final v = <double?>[];
  for (var i = 0; i < n; i++) {
    v.add(await ping(ip, timeoutSec: 1));
    if (i % 5 == 4) progres?.call('${i + 1}/$n pachete…');
    await Future.delayed(Duration(milliseconds: pauzaMs));
  }
  final ok = v.whereType<double>().toList();
  final pierd = 100 * (n - ok.length) / n;
  if (ok.isEmpty) {
    return Rezultat('Ping', 'Nu răspunde deloc', 'eroare', [
      ('Trimise', '$n'),
      ('Primite', '0'),
    ]);
  }
  final med = ok.reduce((a, b) => a + b) / ok.length;
  final jit = sqrt(
    ok.map((x) => (x - med) * (x - med)).reduce((a, b) => a + b) / ok.length,
  );
  final (verdict, nivel) = pierd == 0 && med < 20 && jit < 10
      ? ('Legătură excelentă', 'ok')
      : pierd <= 5 && med < 60
      ? ('Legătură bună', 'ok')
      : pierd <= 15
      ? ('Legătură instabilă', 'avertisment')
      : ('Legătură proastă', 'eroare');
  return Rezultat('Ping ($n pachete)', verdict, nivel, [
    ('Pierdute', '${pierd.toStringAsFixed(0)}% (${n - ok.length} din $n)'),
    ('Timp mediu', '${med.toStringAsFixed(1)} ms'),
    (
      'Minim / maxim',
      '${ok.reduce(min).toStringAsFixed(0)} / ${ok.reduce(max).toStringAsFixed(0)} ms',
    ),
    ('Jitter', '${jit.toStringAsFixed(1)} ms'),
    (
      'Grafic',
      v
          .map(
            (x) => x == null
                ? '·'
                : x < 10
                ? '▁'
                : x < 30
                ? '▃'
                : x < 80
                ? '▅'
                : '█',
          )
          .join(' '),
    ),
  ]);
}

Future<Rezultat> web(String ip) async {
  final r = <(String, String)>[];
  var nivel = 'eroare', verdict = 'Interfața web nu răspunde';
  for (final schema in ['http', 'https']) {
    final sw = Stopwatch()..start();
    try {
      final c = HttpClient()..badCertificateCallback = (_, _, _) => true;
      final req = await c
          .getUrl(Uri.parse('$schema://$ip/'))
          .timeout(const Duration(seconds: 5));
      final resp = await req.close().timeout(const Duration(seconds: 5));
      await resp.drain<void>();
      c.close(force: true);
      r.add((
        schema.toUpperCase(),
        'cod ${resp.statusCode} · ${sw.elapsedMilliseconds} ms',
      ));
      if (resp.statusCode < 500) {
        nivel = 'ok';
        verdict = 'Interfața web răspunde (${sw.elapsedMilliseconds} ms)';
      }
    } catch (e) {
      r.add((schema.toUpperCase(), 'nu răspunde'));
    }
  }
  return Rezultat('Interfața web', verdict, nivel, r);
}

const porturiVerificate = [
  (53, 'DNS', false),
  (80, 'HTTP', false),
  (443, 'HTTPS', false),
  (22, 'SSH', false),
  (23, 'Telnet', true),
  (21, 'FTP', true),
  (445, 'Partajare Windows', true),
  (1883, 'MQTT', true),
  (5555, 'Android ADB', true),
  (5900, 'VNC', true),
  (8080, 'HTTP alt', false),
  (502, 'Modbus', true),
];

Future<Rezultat> porturi(String ip) async {
  final rez = await Future.wait(
    porturiVerificate.map((p) async {
      final sw = Stopwatch()..start();
      try {
        final s = await Socket.connect(
          ip,
          p.$1,
          timeout: const Duration(milliseconds: 1200),
        );
        s.destroy();
        return (p, sw.elapsedMilliseconds);
      } catch (_) {
        return (p, null);
      }
    }),
  );
  final deschise = rez.where((x) => x.$2 != null).toList();
  final riscante = deschise.where((x) => x.$1.$3).toList();
  return Rezultat(
    'Servicii (porturi)',
    deschise.isEmpty
        ? 'Niciun serviciu deschis'
        : '${deschise.length} servicii deschise${riscante.isEmpty ? '' : ' · ${riscante.length} riscante'}',
    riscante.isNotEmpty ? 'avertisment' : 'ok',
    [
      for (final x in rez)
        (
          '${x.$1.$1} · ${x.$1.$2}',
          x.$2 == null ? 'închis' : 'deschis (${x.$2} ms)',
        ),
    ],
  );
}

Future<Rezultat> dns() async {
  final r = <(String, String)>[];
  var ok = 0;
  for (final n in ['google.com', 'digi.ro', 'tp-link.com']) {
    final sw = Stopwatch()..start();
    try {
      final a = await InternetAddress.lookup(n)
          .timeout(const Duration(seconds: 5));
      r.add((n, '${a.first.address} · ${sw.elapsedMilliseconds} ms'));
      ok++;
    } catch (_) {
      r.add((n, 'eșuat'));
    }
  }
  return Rezultat(
    'DNS',
    ok == 3 ? 'Rezolvarea numelor merge' : 'Probleme la DNS',
    ok == 3 ? 'ok' : 'eroare',
    r,
  );
}

/// Test de viteză: câte un flux pe server (serverele limitează conexiunile paralele de la același IP).
Future<Rezultat> viteza({Progres? progres}) async {
  const surse = [
    'https://proof.ovh.net/files/1Gb.dat',
    'https://fsn1-speed.hetzner.com/1GB.bin',
    'https://nbg1-speed.hetzner.com/1GB.bin',
    'https://hel1-speed.hetzner.com/1GB.bin',
  ];
  progres?.call('Latență…');
  final pinguri = <double>[];
  for (var i = 0; i < 6; i++) {
    final p = await ping('1.1.1.1');
    if (p != null) pinguri.add(p);
  }
  progres?.call('Descărcare (10 s)…');
  final jos = await Future.wait(
    surse.map((u) async {
      final c = http.Client();
      var total = 0;
      final sw = Stopwatch()..start();
      try {
        final resp = await c
            .send(http.Request('GET', Uri.parse(u)))
            .timeout(const Duration(seconds: 8));
        if (resp.statusCode != 200) return 0.0;
        await for (final b in resp.stream) {
          total += b.length;
          if (sw.elapsedMilliseconds > 10000) break;
        }
      } catch (_) {
      } finally {
        c.close();
      }
      return total * 8 / 1e6 / max(sw.elapsedMilliseconds / 1000, 0.1);
    }),
  );
  progres?.call('Încărcare…');
  final date = List<int>.generate(15 * 1024 * 1024, (i) => i & 0xff);
  final sus = await Future.wait(
    List.generate(2, (_) async {
      final sw = Stopwatch()..start();
      try {
        await http
            .post(Uri.parse('https://speed.cloudflare.com/__up'), body: date)
            .timeout(const Duration(seconds: 30));
        return date.length * 8 / 1e6 / max(sw.elapsedMilliseconds / 1000, 0.1);
      } catch (_) {
        return 0.0;
      }
    }),
  );
  final j = jos.reduce((a, b) => a + b), s = sus.reduce((a, b) => a + b);
  pinguri.sort();
  final p = pinguri.isEmpty ? null : pinguri[pinguri.length ~/ 2];
  return Rezultat(
    'Test de viteză',
    '↓ ${j.toStringAsFixed(0)} Mbps   ↑ ${s.toStringAsFixed(0)} Mbps',
    j >= 100
        ? 'ok'
        : j >= 30
        ? 'avertisment'
        : 'eroare',
    [
      ('Descărcare', '${j.toStringAsFixed(0)} Mbps'),
      ('Încărcare', '${s.toStringAsFixed(0)} Mbps'),
      ('Ping internet', p == null ? '—' : '${p.toStringAsFixed(0)} ms'),
    ],
  );
}
