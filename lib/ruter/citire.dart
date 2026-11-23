// Citirea datelor de pe AX73 și de pe extendere (doar citire). Nu se afișează niciodată câmpuri cu parole.
import '../config.dart';
import 'tplink.dart';

class Client {
  final String mac, ip, nume, banda;
  final int? semnal, rx, tx;
  Client(
    this.mac,
    this.ip,
    this.nume,
    this.banda, {
    this.semnal,
    this.rx,
    this.tx,
  });
}

class NodMesh {
  final String mac, ip, nume, stare, legatura;
  final int? bare, viteza5, viteza2;
  NodMesh(
    this.mac,
    this.ip,
    this.nume,
    this.stare,
    this.legatura, {
    this.bare,
    this.viteza5,
    this.viteza2,
  });
}

class DateRuter {
  final Map<String, String?> status = {};
  final List<NodMesh> mesh = [];
  final Map<String, List<Client>> clientiPeNod = {}; // id aparat -> clienți
  final Map<String, Map<String, dynamic>> uplink = {}; // id extender -> rootAP
  final Map<String, String> firmware = {}; // id -> versiune
  String eroare = '';
  bool ok = false;
  DateTime cand = DateTime.now();
}

int? _int(dynamic x) => x == null ? null : int.tryParse('$x');

List _lista(dynamic x) => x is List ? x : const [];

Future<DateRuter> citesteTot(String parola) async {
  final d = DateRuter();
  if (parola.isEmpty) {
    d.eroare = 'Pune parola de admin a ruterului în Setări.';
    return d;
  }
  final c = ClientSG('http://$ruterIp', parola);
  try {
    await c.login();
  } on EroareRuter catch (e) {
    d.eroare = '$e';
    return d;
  } catch (e) {
    // fără răspuns de la ruter: telefonul nu e în rețeaua casei sau iOS blochează rețeaua locală
    d.eroare =
        'Telefonul nu ajunge la ruter ($ruterIp). Ești pe Wi-Fi-ul casei (sau pe VPN)? '
        'În Configurări → Confidențialitate și securitate → Rețea locală, „Rețeaua casei” trebuie să fie pornită.';
    return d;
  }
  try {
    final a = await c.cerere('admin/status?form=all');
    if (a is Map) {
      for (final k in [
        'wireless_2g_channel',
        'wireless_5g_channel',
        'wireless_5g_htmode',
        'wan_ipv4_ipaddr',
        'wan_ipv4_uptime',
      ]) {
        d.status[k] = a[k]?.toString();
      }
    }
    final fw = await c.cerere('admin/firmware?form=upgrade');
    if (fw is Map) d.firmware['ax73'] = '${fw['firmware_version'] ?? ''}';
    final noduri = await c.cerere(
      'admin/easymesh_network?form=mesh_sclient_list_all',
    );
    if (noduri is List) {
      for (final n in noduri) {
        d.mesh.add(
          NodMesh(
            macNormal(n['mac']),
            '${n['ip'] ?? ''}',
            '${n['name'] ?? ''}',
            '${n['status'] ?? ''}',
            '${n['connect_type'] ?? ''}',
            bare: _int(n['signal_strength']),
          ),
        );
      }
    }
    final laSateliti = <String>{};
    for (var i = 0; i < d.mesh.length; i++) {
      final n = d.mesh[i];
      if (n.stare != 'connected') {
        continue; // ex. RE315 scos din mesh: clienții lui nu se văd de aici
      }
      final q = 'operation=read&mac=${n.mac.toUpperCase()}';
      final det = await c.cerere(
        'admin/easymesh_network?form=mesh_sclient_detail&$q',
        q,
      );
      if (det is! Map) continue;
      d.mesh[i] = NodMesh(
        n.mac,
        n.ip,
        n.nume,
        n.stare,
        '${det['connect_type'] ?? n.legatura}',
        bare: n.bare,
        viteza5: _int(det['link_speed_5g']),
        viteza2: _int(det['link_speed_24g']),
      );
      final ap = aparatDupaMac(n.mac);
      final lista = <Client>[];
      for (final x in _lista(det['mesh_nclient_list'])) {
        final m = macNormal(x['mac']);
        laSateliti.add(m);
        lista.add(
          Client(
            m,
            '${x['ip'] ?? ''}',
            '${x['name'] ?? ''}',
            '${x['connection_type'] ?? ''}',
            semnal: _int(x['signal_strength']),
            rx: _int(x['rxrate']),
            tx: _int(x['txrate']),
          ),
        );
      }
      if (ap != null) d.clientiPeNod[ap.id] = lista;
    }
    // clienții legați direct de AX73 (Wi-Fi + cablu), fără cei de la sateliți
    final directi = <Client>[];
    final satMac = d.mesh.map((n) => n.mac).toSet();
    if (a is Map) {
      for (final x in _lista(a['access_devices_wireless_host'])) {
        final m = macNormal(x['macaddr']);
        if (laSateliti.contains(m) ||
            satMac.contains(m) ||
            '${x['ipaddr']}' == '0.0.0.0') {
          continue;
        }
        directi.add(
          Client(
            m,
            '${x['ipaddr'] ?? ''}',
            '${x['hostname'] ?? ''}',
            '${x['wire_type'] ?? ''}',
          ),
        );
      }
      for (final x in _lista(a['access_devices_wired'])) {
        final m = macNormal(x['macaddr']);
        if (laSateliti.contains(m) || satMac.contains(m)) continue;
        directi.add(
          Client(m, '${x['ipaddr'] ?? ''}', '${x['hostname'] ?? ''}', 'cablu'),
        );
      }
    }
    d.clientiPeNod['ax73'] = directi;
    d.ok = true;
  } catch (e) {
    d.eroare = 'AX73: $e';
  } finally {
    await c.logout();
  }

  // extenderele RE505X (terasă: legătura spre părinte; etaj: clienții lui)
  for (final id in ['re505ext', 'apetaj']) {
    final ap = aparat(id)!;
    final ip = id == 're505ext'
        ? (d.mesh.where((n) => acelasiAparat(n.mac, ap.mac!)).firstOrNull?.ip ??
              ap.ipImplicit)
        : ap.ipImplicit;
    final re = ClientRE('http://$ip', parola);
    try {
      await re.login();
      final fw = await re.cerere('admin/firmware?form=upgrade');
      if (fw is Map) d.firmware[id] = '${fw['firmware_version'] ?? ''}';
      if (id == 're505ext') {
        final root = await re.cerere('admin/status?form=rootAP');
        if (root is Map) d.uplink[id] = Map<String, dynamic>.from(root);
      } else {
        final st = await re.cerere('admin/status?form=ap_status');
        if (st is Map) {
          final lista = <Client>[];
          for (final x in _lista(st['wirelessGrid'])) {
            lista.add(
              Client(
                macNormal(x['mac']),
                '${x['ipaddr'] ?? x['ip'] ?? ''}',
                '${x['name'] ?? ''}',
                '${x['type'] ?? ''}',
                rx: _int(x['rxrate']),
                tx: _int(x['txrate']),
              ),
            );
          }
          d.clientiPeNod[id] = lista;
          final macuri = lista.map((c) => c.mac).toSet();
          d.clientiPeNod['ax73'] = (d.clientiPeNod['ax73'] ?? [])
              .where((c) => !macuri.contains(c.mac))
              .toList();
        }
      }
    } catch (_) {
      // extenderul nu răspunde sau refuză — rămâne doar ping-ul
    } finally {
      await re.logout();
    }
  }
  d.cand = DateTime.now();
  return d;
}
