// Producătorul din MAC (baza IEEE, offline) și categoria sugerată — ca pe calculator.
import 'dart:convert';

import 'package:flutter/services.dart';

const categorii = [
  'Telefon / tabletă',
  'Calculator',
  'TV și media',
  'Casă inteligentă',
  'Energie',
  'Curte și grădină',
  'Imprimantă',
  'Cameră video',
  'Rețea',
  'Altele',
];

final _reguli = <(RegExp, String)>[
  (
    RegExp(
      r'lektrico|sun2000|huawei.*solar|fronius|solax|growatt|inverter|invertor',
      caseSensitive: false,
    ),
    'Energie',
  ),
  (
    RegExp(
      r'rain ?bird|gardena|husqvarna|irrigation|sprinkler',
      caseSensitive: false,
    ),
    'Curte și grădină',
  ),
  (
    RegExp(
      r'shelly|tuya|sonoff|espressif|esp[-_]?\d|tasmota|thermo|meross|broadlink|smart ?life|signify|govee|remote_gw',
      caseSensitive: false,
    ),
    'Casă inteligentă',
  ),
  (
    RegExp(
      r'hikvision|dahua|reolink|ezviz|imou|wyze|arlo',
      caseSensitive: false,
    ),
    'Cameră video',
  ),
  (
    RegExp(
      r'^brn|brother|canon|epson|kyocera|lexmark|xerox',
      caseSensitive: false,
    ),
    'Imprimantă',
  ),
  (
    RegExp(
      r'lgwebos|webostv|lg electronics|chromecast|google|roku|apple tv|sonos|tizen|vestel|tcl|hisense|xbox|playstation|nintendo',
      caseSensitive: false,
    ),
    'TV și media',
  ),
  (
    RegExp(
      r'tp-link|tplink|archer|deco|eap\d|omada|mikrotik|ubiquiti|netgear|d-link|zyxel',
      caseSensitive: false,
    ),
    'Rețea',
  ),
  (
    RegExp(
      r'iphone|ipad|galaxy|redmi|pixel|oneplus|huawei|honor|oppo|vivo|realme|motorola|mds-|android|samsung|xiaomi|apple',
      caseSensitive: false,
    ),
    'Telefon / tabletă',
  ),
  (
    RegExp(
      r'desktop|laptop|-pc|^pc|dell|lenovo|intel|rivet|killer|hewlett|asustek|micro-star|acer|gigabyte|surface|macbook',
      caseSensitive: false,
    ),
    'Calculator',
  ),
];

Map<String, dynamic>? _oui;

Future<void> incarcaOui() async {
  if (_oui != null) return;
  try {
    _oui = jsonDecode(
      await rootBundle.loadString('assets/oui.json'),
    ) as Map<String, dynamic>;
  } catch (_) {
    _oui = {};
  }
}

bool macPrivat(String mac) {
  try {
    return int.parse(mac.replaceAll(':', '-').split('-')[0], radix: 16) & 2 !=
        0;
  } catch (_) {
    return false;
  }
}

String producator(String mac) {
  if (mac.isEmpty) return '';
  if (macPrivat(mac)) return 'MAC privat';
  final cheie = mac.replaceAll(RegExp('[-:]'), '').toUpperCase();
  if (cheie.length < 6) return '';
  var n = '${_oui?[cheie.substring(0, 6)] ?? ''}';
  n = n.replaceAll(
    RegExp(
      r',? ?(Co\.?,? ?Ltd\.?|Inc\.?|Corporation|Corp\.?|GmbH|Limited|LLC|Technologies|Technology|Electronics)$',
      caseSensitive: false,
    ),
    '',
  );
  return n.trim();
}

String categorie(String nume, String prod) {
  final text = '$nume ${prod == 'MAC privat' ? '' : prod}';
  for (final (re, c) in _reguli) {
    if (re.hasMatch(text)) return c;
  }
  return prod == 'MAC privat' ? 'Telefon / tabletă' : 'Altele';
}
