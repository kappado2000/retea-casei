// Aparatele rețelei casei — aceleași ca în aplicația de pe calculator (Retea/config.py).
class Aparat {
  final String id, nume, rol, loc, tip; // tip: infra | iot | info
  final String? mac, macMesh, verificare, parinte, parinteDorit;

  /// (url, text): cum recunoaștem aparatul după ce răspunde, oricare i-ar fi IP-ul
  final (String, String)? semnatura;
  final String ipImplicit;
  final double pierderiMax, msMax;
  const Aparat(
    this.id,
    this.nume,
    this.rol,
    this.loc,
    this.tip,
    this.ipImplicit, {
    this.mac,
    this.macMesh,
    this.verificare,
    this.parinte,
    this.parinteDorit,
    this.semnatura,
    this.pierderiMax = 10,
    this.msMax = 60,
  });

  String get numeComplet => '$nume · $loc';
  bool get esteAp => rol.contains('AP');
}

const ruterIp = '192.168.0.1';
const internet = [('1.1.1.1', 'Cloudflare'), ('8.8.8.8', 'Google')];

const aparate = <Aparat>[
  Aparat(
    'ax73',
    'Archer AX73',
    'Ruter principal · EasyMesh',
    'Bibliotecă',
    'infra',
    '192.168.0.1',
    mac: '5c-62-8b-ba-77-e0',
    msMax: 30,
  ),
  Aparat(
    'ax53s',
    'Archer AX53',
    'Satelit mesh · cablu',
    'Sufragerie',
    'infra',
    '192.168.0.143',
    mac: 'ec-75-0c-aa-34-68',
    parinte: 'ax73',
    msMax: 40,
  ),
  Aparat(
    'ax53g',
    'Archer AX53',
    'Satelit mesh · cablu',
    'Garaj',
    'infra',
    '192.168.0.76',
    mac: 'ec-b9-31-ce-fe-28',
    parinte: 'ax73',
    msMax: 40,
  ),
  Aparat(
    're505ext',
    'RE505X',
    'Satelit mesh · aer',
    'Terasa din față',
    'infra',
    '192.168.0.219',
    mac: '1c-61-b4-c9-64-48',
    parinte: 'ax53s',
    parinteDorit: 'ax53g',
    pierderiMax: 12,
  ),
  Aparat(
    'apetaj',
    'RE505X',
    'Satelit AX73 · cablu, fără mesh',
    'Hol mansardă',
    'infra',
    '192.168.0.172',
    mac: '5c-e9-31-73-05-cd',
    parinte: 'ax73',
    msMax: 40,
  ),
  Aparat(
    're315',
    'RE315',
    'Repeater 2.4 GHz (în afara mesh)',
    'Sufragerie · tablou',
    'infra',
    '192.168.0.165',
    macMesh: 'ac-15-a2-d4-27-9a',
    parinte: 'ax53s',
    semnatura: ('http://{ip}/', 'tplink'),
    pierderiMax: 10,
    msMax: 80,
  ),
  Aparat(
    'eap245',
    'EAP245',
    'AP Omada · cablu',
    'Foișor',
    'infra',
    '192.168.0.102',
    mac: '00-31-92-e8-07-36',
    parinte: 'ax73',
    pierderiMax: 12,
  ),
  Aparat(
    'invertor',
    'Invertor SUN2000',
    'Fotovoltaice Huawei',
    'Exterior',
    'iot',
    '192.168.0.52',
    mac: 'd8-10-9f-5e-1e-4b',
    pierderiMax: 20,
    msMax: 400,
  ),
  Aparat(
    'lektrico',
    'Lektrico 1P7K',
    'Încărcător mașină',
    'Exterior',
    'iot',
    '192.168.0.5',
    mac: '4c-75-25-25-ab-37',
    pierderiMax: 20,
    msMax: 400,
    verificare: 'http://{ip}/rpc/Sys.GetInfo',
    semnatura: ('http://{ip}/rpc/Sys.GetInfo', '"1p7k_'),
  ),
  Aparat(
    'm2w',
    'Lektrico M2W',
    'Contor energie',
    'Tablou',
    'iot',
    '192.168.0.217',
    pierderiMax: 60,
    msMax: 800,
    verificare: 'http://{ip}/rpc/Sys.GetInfo',
    semnatura: ('http://{ip}/rpc/Sys.GetInfo', '"m2w_'),
  ),
  Aparat(
    'shelly',
    'Shelly Uni',
    'Poartă',
    'Poartă',
    'iot',
    '192.168.0.174',
    mac: '30-76-f5-38-55-74',
    pierderiMax: 25,
    msMax: 500,
    verificare: 'http://{ip}/shelly',
    semnatura: ('http://{ip}/shelly', '3076f5385574'),
  ),
];

Aparat? aparat(String? id) => aparate.where((a) => a.id == id).firstOrNull;

String macNormal(String? m) =>
    (m ?? '').toLowerCase().replaceAll(':', '-').trim();

/// TP-Link folosește MAC-uri înrudite pe benzi/porturi: același mijloc (octeții 2–5).
bool acelasiAparat(String a, String b) {
  final x = macNormal(a).split('-'), y = macNormal(b).split('-');
  return x.length == 6 &&
      y.length == 6 &&
      x.sublist(1, 5).join() == y.sublist(1, 5).join();
}

Aparat? aparatDupaMac(String mac) {
  for (final a in aparate) {
    for (final m in [a.mac, a.macMesh]) {
      if (m != null && acelasiAparat(m, mac)) return a;
    }
  }
  return null;
}
