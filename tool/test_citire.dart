// ignore_for_file: avoid_print
import 'dart:io';

import 'package:retea/ruter/citire.dart';

Future<void> main() async {
  final t = DateTime.now();
  final d = await citesteTot(Platform.environment['RETEA_PAROLA'] ?? '');
  print(
    'ok=${d.ok} eroare="${d.eroare}" în ${DateTime.now().difference(t).inMilliseconds} ms',
  );
  print('status: ${d.status}');
  print('firmware: ${d.firmware}');
  print(
    'uplink terasa: ${d.uplink['re505ext']?['ap_mac_5g']} ${d.uplink['re505ext']?['ap_rssi_5g']}',
  );
  d.clientiPeNod.forEach(
    (k, v) => print(
      '$k: ${v.length} clienți ${v.take(3).map((c) => '${c.nume}/${c.ip}/${c.semnal}').toList()}',
    ),
  );
}
