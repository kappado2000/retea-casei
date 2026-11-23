import 'package:flutter_test/flutter_test.dart';
import 'package:retea/config.dart';
import 'package:retea/inventar.dart';
import 'package:retea/monitor.dart';

void main() {
  test('supravegherea intensivă găsește căderile de cel puțin 3 secunde', () {
    final t0 = DateTime(2026, 11, 23, 10);
    final e = <(DateTime, double?)>[
      for (var i = 0; i < 10; i++)
        (t0.add(Duration(seconds: i)), (i >= 3 && i <= 6) ? null : 5.0),
    ];
    final r = rezumatIntensiv(e);
    expect((r['caderi'] as List).length, 1);
    expect(r['primite'], 6);
    expect(verdictIntensiv(r).$2, 'eroare');
  });

  test('aparatele TP-Link se recunosc după MAC-uri înrudite', () {
    expect(aparatDupaMac('0e-b9-31-ce-fe-26')?.id, 'ax53g');
    expect(aparatDupaMac('6a-61-b4-c9-64-47')?.id, 're505ext');
  });

  test('MAC privat = telefon', () {
    expect(macPrivat('ae-11-22-33-44-55'), isTrue);
    expect(categorie('', 'MAC privat'), 'Telefon / tabletă');
    expect(categorie('Lektrico-1p7k', 'Espressif'), 'Energie');
  });
}
