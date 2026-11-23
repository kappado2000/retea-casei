// Motorul de monitorizare al telefonului: rulează cât timp aplicația e deschisă.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dart_ping/dart_ping.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';
import 'ruter/citire.dart';

const etichete = {
  'ok': 'Funcționează',
  'degradat': 'Probleme',
  'cazut': 'Nu răspunde',
  'necunoscut': 'Se verifică…',
};

Future<double?> ping(String ip, {int timeoutSec = 2}) async {
  try {
    final r = await Ping(
      ip,
      count: 1,
      timeout: timeoutSec,
    ).stream.first.timeout(Duration(seconds: timeoutSec + 2));
    final t = r.response?.time;
    if (r.error != null || t == null) return null;
    return max(0.5, t.inMicroseconds / 1000.0);
  } catch (_) {
    return null;
  }
}

class Tinta {
  final Aparat a;
  String ip;
  final List<double?> istoric = [];
  final List<double?> lung =
      []; // ultimele ~6 ore, câte un punct la 10 s (pentru grafic)
  int esecuri = 0, succese = 0;
  String stare = 'necunoscut', motiv = '';
  bool? httpOk;
  DateTime? vazut;
  Tinta(this.a) : ip = a.ipImplicit;

  double? get pierderi => istoric.isEmpty
      ? null
      : 100 * istoric.where((x) => x == null).length / istoric.length;
  double? get latenta {
    final v = istoric.whereType<double>().toList()..sort();
    return v.isEmpty ? null : v[v.length ~/ 2];
  }

  double? get jitter {
    final v = istoric.whereType<double>().toList();
    if (v.length < 3) return null;
    final m = v.reduce((a, b) => a + b) / v.length;
    return sqrt(
      v.map((x) => (x - m) * (x - m)).reduce((a, b) => a + b) / v.length,
    );
  }
}

class Eveniment {
  final DateTime ts;
  final String nivel, aparat, mesaj;
  Eveniment(this.ts, this.nivel, this.aparat, this.mesaj);
  Map<String, dynamic> toJson() => {
    't': ts.millisecondsSinceEpoch,
    'n': nivel,
    'a': aparat,
    'm': mesaj,
  };
  static Eveniment fromJson(Map j) => Eveniment(
    DateTime.fromMillisecondsSinceEpoch(j['t']),
    j['n'],
    j['a'],
    j['m'],
  );
}

class SesiuneIntensiva {
  final String id, ip;
  final Duration durata;
  final DateTime start = DateTime.now();
  final List<(DateTime, double?)> esantioane = [];
  bool gata = false;
  Timer? _t;
  SesiuneIntensiva(this.id, this.ip, this.durata);
  double get progres =>
      min(1, DateTime.now().difference(start).inSeconds / durata.inSeconds);
}

class Monitor extends ChangeNotifier with WidgetsBindingObserver {
  final tinte = {for (final a in aparate) a.id: Tinta(a)};
  final net = {
    for (final (ip, nume) in internet)
      ip: Tinta(Aparat('net:$ip', nume, '', '', 'net', ip)),
  };
  String stareInternet = 'necunoscut';
  DateRuter? ruter;
  String eroareRuter = '';
  bool citesteRuter = false;
  final List<Eveniment> jurnal = [];
  final Map<String, SesiuneIntensiva> intensiv = {};
  final List<Map<String, dynamic>> intensivGata = [];
  Timer? _timer;
  int _tic = 0;
  bool _activ = false;
  final _secure = const FlutterSecureStorage();
  SharedPreferences? _prefs;
  Map<String, Map<String, String>> inventar =
      {}; // mac -> {nume, categorie, proprietar}

  Future<void> porneste() async {
    _prefs = await SharedPreferences.getInstance();
    try {
      for (final e in jsonDecode(_prefs!.getString('jurnal') ?? '[]') as List) {
        jurnal.add(Eveniment.fromJson(e));
      }
      inventar = (jsonDecode(_prefs!.getString('inventar') ?? '{}') as Map).map(
        (k, v) => MapEntry(k as String, Map<String, String>.from(v as Map)),
      );
      intensivGata.addAll(
        (jsonDecode(_prefs!.getString('intensiv') ?? '[]') as List)
            .cast<Map<String, dynamic>>(),
      );
    } catch (_) {}
    WidgetsBinding.instance.addObserver(this);
    _reia();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reia();
    } else if (state == AppLifecycleState.paused) {
      _timer?.cancel();
      _activ = false;
    }
  }

  void _reia() {
    if (_activ) return;
    _activ = true;
    _timer?.cancel();
    _ciclu(fortat: true);
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _ciclu());
  }

  Future<String> parola() async {
    final p = await _secure.read(key: 'parola_ruter') ?? '';
    // doar pentru previzualizarea de pe PC (build debug Windows)
    if (p.isEmpty && kDebugMode && Platform.isWindows) {
      return Platform.environment['RETEA_PAROLA'] ?? '';
    }
    return p;
  }

  Future<void> seteazaParola(String p) async {
    await _secure.write(key: 'parola_ruter', value: p);
    await citesteRuterAcum();
  }

  Future<void> reimprospateaza() async {
    await _ciclu(fortat: true);
  }

  Future<void> _ciclu({bool fortat = false}) async {
    _tic++;
    final toate = [...tinte.values, ...net.values];
    final rez = await Future.wait(toate.map((t) => ping(t.ip)));
    for (var i = 0; i < toate.length; i++) {
      final t = toate[i], ms = rez[i];
      t.istoric.add(ms);
      if (t.istoric.length > 30) t.istoric.removeAt(0);
      t.lung.add(ms);
      if (t.lung.length > 2160) t.lung.removeAt(0);
      if (ms == null) {
        t.esecuri++;
        t.succese = 0;
      } else {
        t.esecuri = 0;
        t.succese++;
        t.vazut = DateTime.now();
      }
    }
    if (fortat || _tic % 3 == 0) await _http();
    _evalueaza();
    notifyListeners();
    if (fortat || _tic % 6 == 0) unawaited(citesteRuterAcum());
  }

  Future<void> _http() async {
    await Future.wait(
      tinte.values.where((t) => t.a.verificare != null).map((t) async {
        try {
          final r = await http
              .get(Uri.parse(t.a.verificare!.replaceAll('{ip}', t.ip)))
              .timeout(const Duration(seconds: 4));
          t.httpOk = r.statusCode == 200;
        } catch (_) {
          t.httpOk = false;
        }
      }),
    );
  }

  Future<void> citesteRuterAcum() async {
    if (citesteRuter) return;
    citesteRuter = true;
    notifyListeners();
    try {
      var d = await citesteTot(await parola());
      if (!d.ok && d.eroare.isNotEmpty && !d.eroare.contains('parola')) {
        // AX73 acceptă o singură sesiune: dacă citea și calculatorul, mai încercăm o dată
        await Future.delayed(const Duration(seconds: 5));
        d = await citesteTot(await parola());
      }
      eroareRuter = d.eroare;
      if (d.ok) {
        ruter = d;
        for (final n in d.mesh) {
          final a = aparatDupaMac(n.mac);
          if (a != null &&
              n.ip.isNotEmpty &&
              n.ip != '0.0.0.0' &&
              a.mac != null) {
            tinte[a.id]!.ip = n.ip;
          }
        }
      }
    } finally {
      citesteRuter = false;
      notifyListeners();
    }
  }

  (String, String) _stareBruta(Tinta t) {
    final areHttp = t.a.verificare != null;
    if (t.esecuri >= 3 && !(areHttp && t.httpOk == true)) {
      return ('cazut', 'nu răspunde de ${t.esecuri * 10} s');
    }
    if (t.istoric.length >= 12) {
      final p = t.pierderi!, ms = t.latenta;
      if (p > t.a.pierderiMax && !(areHttp && t.httpOk == true)) {
        return ('degradat', '${p.toStringAsFixed(0)}% pachete pierdute');
      }
      if (ms != null && ms > t.a.msMax) {
        return ('degradat', 'latență mare: ${ms.toStringAsFixed(0)} ms');
      }
    }
    if (areHttp && t.httpOk == false && t.esecuri > 0) {
      return ('degradat', 'nu răspunde la interfața web');
    }
    if (t.istoric.isEmpty) return ('necunoscut', '');
    return ('ok', '');
  }

  void _evalueaza() {
    for (final t in tinte.values) {
      final (noua, motiv) = _stareBruta(t);
      final veche = t.stare;
      t.stare = noua;
      t.motiv = motiv;
      if (noua != veche && veche != 'necunoscut' && t.a.tip != 'info') {
        if (noua == 'cazut') {
          _ev('eroare', t.a.id, '${t.a.numeComplet} nu răspunde');
        }
        if (noua == 'ok') {
          _ev('ok', t.a.id, '${t.a.numeComplet} funcționează din nou');
        }
      }
    }
    final ok = net.values.where((t) => t.esecuri < 3).length;
    final veche = stareInternet;
    stareInternet = tinte['ax73']!.stare == 'cazut'
        ? 'necunoscut'
        : ok == 0
        ? 'cazut'
        : (net.values.first.istoric.length >= 12 &&
              net.values.any((t) => (t.pierderi ?? 0) > 10))
        ? 'degradat'
        : 'ok';
    if (stareInternet != veche && veche != 'necunoscut') {
      _ev(
        stareInternet == 'cazut' ? 'eroare' : 'info',
        'internet',
        stareInternet == 'cazut'
            ? 'Internetul a căzut'
            : 'Internet: ${etichete[stareInternet]}',
      );
    }
  }

  void _ev(String nivel, String id, String mesaj) {
    jurnal.insert(0, Eveniment(DateTime.now(), nivel, id, mesaj));
    if (jurnal.length > 300) jurnal.removeLast();
    _prefs?.setString(
      'jurnal',
      jsonEncode(jurnal.map((e) => e.toJson()).toList()),
    );
  }

  List<Tinta> get probleme => tinte.values
      .where(
        (t) =>
            t.a.tip != 'info' && (t.stare == 'cazut' || t.stare == 'degradat'),
      )
      .toList();

  String get stareGenerala {
    if (stareInternet == 'cazut' || probleme.any((t) => t.stare == 'cazut')) {
      return 'cazut';
    }
    if (stareInternet == 'degradat' || probleme.isNotEmpty) return 'degradat';
    if (tinte.values.every((t) => t.stare == 'necunoscut')) return 'necunoscut';
    return 'ok';
  }

  // ---------------- clienți
  List<Client>? clienti(String id) => ruter?.clientiPeNod[id];

  (String, Client)? nodClient(String mac) {
    for (final e in (ruter?.clientiPeNod ?? {}).entries) {
      for (final c in e.value) {
        if (c.mac == mac) return (e.key, c);
      }
    }
    return null;
  }

  String? parinteReal(String id) {
    final u = ruter?.uplink[id];
    final mac = u?['ap_mac_5g'] ?? u?['ap_mac_24g'];
    return mac == null ? null : aparatDupaMac('$mac')?.id;
  }

  int? semnalUplink(String id) {
    final u = ruter?.uplink[id];
    if (u == null) return null;
    final v = [
      u['ap_rssi_5g'],
      u['ap_rssi_24g'],
    ].map((x) => int.tryParse('$x')).whereType<int>().where((x) => x != 0);
    return v.isEmpty ? null : v.reduce(max);
  }

  void seteazaInventar(String mac, Map<String, String> d) {
    inventar[mac] = d;
    _prefs?.setString('inventar', jsonEncode(inventar));
    notifyListeners();
  }

  // ---------------- supraveghere intensivă
  bool pornesteIntensiv(String id, Duration durata) {
    final t = tinte[id]!;
    if (intensiv.containsKey(id)) return false;
    final s = SesiuneIntensiva(id, t.ip, durata);
    intensiv[id] = s;
    _ev('info', id, 'Supraveghere intensivă pornită (${durata.inMinutes} min)');
    s._t = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (DateTime.now().difference(s.start) >= s.durata) {
        opresteIntensiv(id);
        return;
      }
      s.esantioane.add((DateTime.now(), await ping(s.ip, timeoutSec: 1)));
      notifyListeners();
    });
    notifyListeners();
    return true;
  }

  void opresteIntensiv(String id) {
    final s = intensiv.remove(id);
    if (s == null) return;
    s._t?.cancel();
    s.gata = true;
    final r = rezumatIntensiv(s.esantioane);
    intensivGata.insert(0, {
      'id': id,
      'start': s.start.millisecondsSinceEpoch,
      'durata': DateTime.now().difference(s.start).inSeconds,
      'rezumat': r,
      'serie': s.esantioane.map((e) => e.$2).toList(),
    });
    if (intensivGata.length > 20) intensivGata.removeLast();
    _prefs?.setString('intensiv', jsonEncode(intensivGata));
    _ev(
      r['caderi'].isEmpty ? 'info' : 'avertisment',
      id,
      'Supraveghere încheiată: ${verdictIntensiv(r).$1}',
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

Map<String, dynamic> rezumatIntensiv(List<(DateTime, double?)> e) {
  final ok = e.map((x) => x.$2).whereType<double>().toList()..sort();
  final caderi = <List<int>>[];
  DateTime? start, ultim;
  for (final (ts, ms) in e) {
    if (ms == null) {
      start ??= ts;
      ultim = ts;
    } else if (start != null) {
      if (ultim!.difference(start).inSeconds + 1 >= 3) {
        caderi.add([
          start.millisecondsSinceEpoch,
          ultim.millisecondsSinceEpoch + 1000,
        ]);
      }
      start = null;
    }
  }
  if (start != null && ultim!.difference(start).inSeconds + 1 >= 3) {
    caderi.add([
      start.millisecondsSinceEpoch,
      ultim.millisecondsSinceEpoch + 1000,
    ]);
  }
  final n = e.length;
  return {
    'trimise': n,
    'primite': ok.length,
    'pierderi': n == 0 ? 0.0 : 100.0 * (n - ok.length) / n,
    'medie': ok.isEmpty ? null : ok.reduce((a, b) => a + b) / ok.length,
    'maxim': ok.isEmpty ? null : ok.last,
    'p95': ok.isEmpty ? null : ok[((ok.length - 1) * 0.95).floor()],
    'caderi': caderi,
  };
}

(String, String) verdictIntensiv(Map r) {
  if (r['trimise'] == 0) return ('fără date', 'avertisment');
  if (r['primite'] == 0) return ('n-a răspuns deloc', 'eroare');
  final c = r['caderi'] as List;
  if (c.isNotEmpty) {
    final lung = c
        .map((x) => ((x[1] as int) - (x[0] as int)) ~/ 1000)
        .reduce(max);
    return ('${c.length} căderi (cea mai lungă $lung s)', 'eroare');
  }
  if ((r['pierderi'] as double) > 2 || (r['p95'] ?? 0) > 150) {
    return (
      'instabil: ${(r['pierderi'] as double).toStringAsFixed(1)}% pierderi',
      'avertisment',
    );
  }
  return (
    'stabil: ${(r['pierderi'] as double).toStringAsFixed(1)}% pierderi, medie ${(r['medie'] as double).toStringAsFixed(0)} ms',
    'ok',
  );
}
