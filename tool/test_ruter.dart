// ignore_for_file: avoid_print
// Test local (pe PC): dart run tool/test_ruter.dart  — parola din variabila de mediu RETEA_PAROLA.
import 'dart:convert';
import 'dart:io';

import 'package:retea/ruter/tplink.dart';

Future<void> main() async {
  final p = Platform.environment['RETEA_PAROLA'] ?? '';
  final c = ClientSG('http://192.168.0.1', p);
  await c.login();
  print('AX73 login OK');
  try {
    final noduri = await c.cerere(
      'admin/easymesh_network?form=mesh_sclient_list_all',
    ) as List;
    for (final n in noduri) {
      print(
        'NOD ${n['name']} ${n['ip']} ${n['status']} ${n['connect_type']} clienti=${n['client_num']}',
      );
    }
    final q = 'operation=read&mac=EC-75-0C-AA-34-68';
    final d = await c.cerere(
      'admin/easymesh_network?form=mesh_sclient_detail&$q',
      q,
    ) as Map;
    print(
      'AX53 sufragerie: ${(d['mesh_nclient_list'] as List).length} clienți, ex: '
      '${jsonEncode((d['mesh_nclient_list'] as List).take(2).toList())}',
    );
    final fw = await c.cerere('admin/firmware?form=upgrade') as Map;
    print('firmware ${fw['firmware_version']}');
  } finally {
    await c.logout();
  }
  final re = ClientRE('http://192.168.0.219', p);
  await re.login();
  final root = await re.cerere('admin/status?form=rootAP') as Map;
  print(
    'RE505X terasa -> ${root['ap_mac_5g']} rssi5 ${root['ap_rssi_5g']} rssi2 ${root['ap_rssi_24g']}',
  );
  await re.logout();
}
