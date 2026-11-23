// Clienți TP-Link (DOAR citire) — port în Dart al bibliotecii Python tplinkrouterc6u.
//
//  * ClientSG   — Archer AX73 cu firmware „SG” (SHA256 + RSA-OAEP + AES-CBC + HMAC-SHA256)
//  * ClientRE   — extendere RE505X (parola criptată RSA PKCS#1 v1.5, cereri în clar)
//
// Ruterul acceptă o singură sesiune de administrare: ne logăm, citim, ne delogăm.
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:pointycastle/export.dart';

class EroareRuter implements Exception {
  final String mesaj;
  EroareRuter(this.mesaj);
  @override
  String toString() => mesaj;
}

// ---------------------------------------------------------------- criptografie
final _rnd = () {
  final r = FortunaRandom();
  final s = Random.secure();
  r.seed(
    KeyParameter(Uint8List.fromList(List.generate(32, (_) => s.nextInt(256)))),
  );
  return r;
}();

BigInt _hex(String h) => BigInt.parse(h, radix: 16);

String _hexOf(Uint8List b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

String _rsa(String text, String nHex, String eHex, {required bool oaep}) {
  final cheie = RSAPublicKey(_hex(nHex), _hex(eHex));
  final AsymmetricBlockCipher c = oaep
      ? OAEPEncoding(RSAEngine())
      : PKCS1Encoding(RSAEngine());
  c.init(
    true,
    ParametersWithRandom(PublicKeyParameter<RSAPublicKey>(cheie), _rnd),
  );
  final out = c.process(Uint8List.fromList(utf8.encode(text)));
  return _hexOf(out).padLeft(nHex.length, '0');
}

String _sha256(String s) =>
    _hexOf(SHA256Digest().process(Uint8List.fromList(utf8.encode(s))));

String _hmac(String cheie, String text) {
  final h = HMac(SHA256Digest(), 64)
    ..init(KeyParameter(Uint8List.fromList(utf8.encode(cheie))));
  return _hexOf(h.process(Uint8List.fromList(utf8.encode(text))));
}

class _Aes {
  final String cheie, iv;
  _Aes()
    : cheie = List.generate(16, (_) => _rnd.nextUint8() % 10).join(),
      iv = List.generate(16, (_) => _rnd.nextUint8() % 10).join();

  // AES-CBC cu umplere PKCS7 făcută manual (PaddedBlockCipherImpl nu acceptă textul gol)
  Uint8List _cbc(bool cripteaza, Uint8List date) {
    final c = CBCBlockCipher(AESEngine())
      ..init(
        cripteaza,
        ParametersWithIV(
          KeyParameter(Uint8List.fromList(utf8.encode(cheie))),
          Uint8List.fromList(utf8.encode(iv)),
        ),
      );
    final out = Uint8List(date.length);
    for (var i = 0; i < date.length; i += 16) {
      c.processBlock(date, i, out, i);
    }
    return out;
  }

  String cripteaza(String s) {
    final b = utf8.encode(s);
    final p = 16 - b.length % 16;
    return base64.encode(
      _cbc(true, Uint8List.fromList([...b, ...List.filled(p, p)])),
    );
  }

  String decripteaza(String s) {
    final d = _cbc(false, base64.decode(s));
    final p = d.isEmpty ? 0 : d.last;
    return utf8.decode(d.sublist(0, d.length - (p > 0 && p <= 16 ? p : 0)));
  }

  String get formatat => 'k=$cheie&i=$iv';
}

String? _sysauth(http.Response r) {
  final c = r.headers['set-cookie'];
  if (c == null) return null;
  final m = RegExp(r'sysauth=([^;]+)').firstMatch(c);
  return m?.group(1);
}

// ---------------------------------------------------------------- AX73 (SG)
class ClientSG {
  final String host; // ex. http://192.168.0.1
  final String parola;
  final String utilizator;
  final Duration timeout;
  late _Aes _aes;
  String _hash = '';
  int _seq = 0;
  String _nn = '', _ee = '';
  String _stok = '', _cookie = '';
  bool logat = false;

  ClientSG(
    this.host,
    this.parola, {
    this.utilizator = 'admin',
    this.timeout = const Duration(seconds: 12),
  });

  Map<String, String> get _antet => {
    'Referer': '$host/webpages/index.html',
    'Origin': host,
    'Content-Type': 'application/x-www-form-urlencoded',
  };

  Future<Map<String, dynamic>> _postJson(
    String url, {
    String? body,
    Map<String, String>? antet,
  }) async {
    final r = await http
        .post(Uri.parse(url), body: body, headers: antet)
        .timeout(timeout);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<void> login() async {
    final k = await _postJson(
      '$host/cgi-bin/luci/;stok=/login?form=keys&operation=read',
    );
    final pw = (k['data']['password'] as List).cast<String>();
    final a = await _postJson(
      '$host/cgi-bin/luci/;stok=/login?form=auth&operation=read',
    );
    _seq = (a['data']['seq'] as num).toInt();
    _nn = a['data']['key'][0];
    _ee = a['data']['key'][1];
    _hash = _sha256('$utilizator$parola');
    _aes = _Aes();
    final parolaCript = _rsa(parola, pw[0], pw[1], oaep: false);
    final date = _aes.cripteaza(
      'operation=login&password=$parolaCript&confirm=true',
    );
    final semn = _semnLogin(date.length);
    final r = await http
        .post(
          Uri.parse('$host/cgi-bin/luci/;stok=/login?form=login'),
          body: 'sign=$semn&data=${Uri.encodeComponent(date)}',
          headers: _antet,
        )
        .timeout(timeout);
    Map<String, dynamic> dec;
    try {
      dec = jsonDecode(
        _aes.decripteaza((jsonDecode(r.body) as Map)['data']),
      ) as Map<String, dynamic>;
    } catch (_) {
      throw EroareRuter(
        'AX73 a refuzat login-ul (cod ${r.statusCode}) — verifică parola sau dacă e cineva logat '
        'în interfața web.',
      );
    }
    if (dec['success'] != true) {
      final date = dec['data'] is Map ? dec['data'] as Map : const {};
      final cod = '${dec['errorcode'] ?? date['errorcode'] ?? 'necunoscut'}';
      final incercari = date['failureCount'] != null
          ? ' (încercări greșite: ${date['failureCount']} din ${date['attemptsAllowed'] ?? '?'})'
          : '';
      throw EroareRuter(switch (cod) {
        'login failed' =>
          'AX73 a respins parola$incercari. Verifică parola (literele mari/mici contează).',
        'user conflict' => 'Altcineva e logat chiar acum în interfața AX73 (browser sau laptop). Reîncerc la următoarea citire.',
        'exceeded max attempts' =>
          'AX73 a blocat temporar login-ul după prea multe parole greșite$incercari. Așteaptă câteva minute.',
        _ => 'Login respins de AX73: $cod$incercari',
      });
    }
    _stok = dec['data']['stok'];
    _cookie = _sysauth(r) ?? '';
    logat = true;
  }

  String _semnLogin(int lungime) {
    final s = '${_aes.formatat}&h=$_hash&s=${_seq + lungime}';
    final octetiRsa = _nn.length ~/ 2;
    final pas = min(53, octetiRsa - 2 * 20 - 2);
    final b = StringBuffer();
    for (var i = 0; i < s.length; i += pas) {
      b.write(
        _rsa(s.substring(i, min(i + pas, s.length)), _nn, _ee, oaep: true),
      );
    }
    return b.toString();
  }

  String _semnCerere(int lungime) {
    final s = 'h=$_hash&s=${_seq + lungime}';
    final b = StringBuffer();
    for (var i = 0; i < s.length; i += 53) {
      b.write(_hmac(_aes.formatat, s.substring(i, min(i + 53, s.length))));
    }
    return b.toString();
  }

  /// Cerere autentificată; întoarce câmpul „data” al răspunsului (sau tot răspunsul la erori, dacă ignoraErori).
  Future<dynamic> cerere(
    String cale, [
    String date = 'operation=read',
    bool ignoraErori = true,
  ]) async {
    if (!logat) throw EroareRuter('nelogat');
    // parametrii identici din cale și din corp: îi păstrăm doar în cale (ca ruterul să nu-i vadă dublați)
    if (cale.contains('?')) {
      final dinCale = Uri.splitQueryString(cale.split('?')[1]);
      final corp = Uri.splitQueryString(date)
        ..removeWhere((k, v) => dinCale[k] == v);
      date = corp.entries.map((e) => '${e.key}=${e.value}').join('&');
    }
    final cript = _aes.cripteaza(date);
    _hash = _sha256(cript);
    final semn = _semnCerere(cript.length);
    final r = await http
        .post(
          Uri.parse('$host/cgi-bin/luci/;stok=$_stok/$cale'),
          body: 'sign=$semn&data=${Uri.encodeComponent(cript)}',
          headers: {..._antet, 'Cookie': 'sysauth=$_cookie'},
        )
        .timeout(timeout);
    final dec = jsonDecode(
      _aes.decripteaza((jsonDecode(r.body) as Map)['data']),
    );
    if (dec is Map && dec['success'] == true) return dec['data'] ?? dec;
    if (ignoraErori) return dec is Map ? (dec['data'] ?? dec) : dec;
    throw EroareRuter('Eroare la $cale');
  }

  Future<void> logout() async {
    if (!logat) return;
    try {
      final cript = _aes.cripteaza('operation=write');
      _hash = _sha256(cript);
      await http
          .post(
            Uri.parse(
              '$host/cgi-bin/luci/;stok=$_stok/admin/system?form=logout',
            ),
            body:
                'sign=${_semnCerere(cript.length)}&data=${Uri.encodeComponent(cript)}',
            headers: {..._antet, 'Cookie': 'sysauth=$_cookie'},
          )
          .timeout(timeout);
    } catch (_) {}
    logat = false;
  }
}

// ---------------------------------------------------------------- RE505X
class ClientRE {
  final String host, parola;
  final Duration timeout;
  String _stok = '', _cookie = '';
  bool logat = false;

  ClientRE(
    this.host,
    this.parola, {
    this.timeout = const Duration(seconds: 10),
  });

  Map<String, String> _antet(String pagina) => {
    'Accept': 'application/json, text/javascript, */*; q=0.01',
    'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
    'Origin': host,
    'X-Requested-With': 'XMLHttpRequest',
    'Referer': '$host/webpages/$pagina',
  };

  Future<void> login() async {
    final k = await http
        .post(
          Uri.parse(
            '$host/cgi-bin/luci/;stok=/login?form=login&operation=read',
          ),
          headers: _antet('login.html'),
        )
        .timeout(timeout);
    final pw = ((jsonDecode(k.body) as Map)['data']['password'] as List)
        .cast<String>();
    final cript = _rsa(parola, pw[0], pw[1], oaep: false);
    final r = await http
        .post(
          Uri.parse('$host/cgi-bin/luci/;stok=/login?form=login'),
          body: 'operation=login&password=$cript',
          headers: _antet('login.html'),
        )
        .timeout(timeout);
    try {
      _stok = (jsonDecode(r.body) as Map)['data']['stok'];
      _cookie = _sysauth(r) ?? '';
      logat = true;
    } catch (_) {
      throw EroareRuter('Login respins de extender ($host)');
    }
  }

  Future<dynamic> cerere(String cale, [String date = 'operation=read']) async {
    final r = await http
        .post(
          Uri.parse('$host/cgi-bin/luci/;stok=$_stok/$cale'),
          body: date,
          headers: {..._antet('index.html'), 'Cookie': 'sysauth=$_cookie'},
        )
        .timeout(timeout);
    final j = jsonDecode(r.body);
    if (j is Map) return j['data'] ?? j;
    return j;
  }

  Future<void> logout() async {
    if (!logat) return;
    try {
      await cerere('admin/system?form=logout', 'operation=write');
    } catch (_) {}
    logat = false;
  }
}
