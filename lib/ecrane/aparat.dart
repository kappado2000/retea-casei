import 'package:flutter/material.dart';

import '../config.dart';
import '../inventar.dart' as inv;
import '../monitor.dart';
import '../ruter/citire.dart';
import '../tema.dart';
import '../teste.dart' as teste;
import 'dispozitive.dart';

class ListaAparate extends StatelessWidget {
  final Monitor m;
  const ListaAparate(this.m, {super.key});
  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: m.reimprospateaza,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          for (final (titlu, tip) in [
            ('Echipamente de rețea', 'infra'),
            ('Aparate importante', 'iot'),
          ]) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 12, 0, 8),
              child: Text(
                titlu,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            for (final a in aparate.where((a) => a.tip == tip))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: CardAparat(m, a.id),
              ),
          ],
        ],
      ),
    );
  }
}

class CardAparat extends StatelessWidget {
  final Monitor m;
  final String id;
  const CardAparat(this.m, this.id, {super.key});
  @override
  Widget build(BuildContext context) {
    final c = culori(context);
    final t = m.tinte[id]!;
    final cl = m.clienti(id);
    final dbm = m.semnalUplink(id);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => EcranAparat(m, id)),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        decoration: BoxDecoration(
          color: c.fondStare(t.stare),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.conturStare(t.stare)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  t.a.tip == 'infra'
                      ? (t.a.esteAp ? Icons.wifi : Icons.router)
                      : Icons.memory,
                  color: c.stare(t.stare),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.a.nume,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        '${t.a.loc} · ${t.a.rol}',
                        style: TextStyle(color: c.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Pastila(etichete[t.stare]!, t.stare),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              [
                'IP ${t.ip}',
                if (t.latenta != null) '${t.latenta!.toStringAsFixed(0)} ms',
                if (t.pierderi != null && t.istoric.length >= 3)
                  'pierderi ${t.pierderi!.toStringAsFixed(0)}%',
                if (dbm != null) '$dbm dBm',
                if (cl != null) '${cl.length} clienți',
              ].join(' · '),
              style: const TextStyle(fontSize: 13),
            ),
            if (t.motiv.isNotEmpty)
              Text(
                t.motiv,
                style: TextStyle(color: c.stare(t.stare), fontSize: 12),
              ),
            const SizedBox(height: 6),
            Sparkline(
              t.istoric,
              c.stare(t.stare == 'necunoscut' ? 'ok' : t.stare),
              inaltime: 30,
            ),
          ],
        ),
      ),
    );
  }
}

class EcranAparat extends StatefulWidget {
  final Monitor m;
  final String id;
  const EcranAparat(this.m, this.id, {super.key});
  @override
  State<EcranAparat> createState() => _EcranAparatState();
}

class _EcranAparatState extends State<EcranAparat> {
  teste.Rezultat? rez;
  String progres = '';
  bool ruleaza = false;
  Duration durata = const Duration(hours: 1);

  Future<void> _test(Future<teste.Rezultat> Function() f) async {
    setState(() {
      ruleaza = true;
      progres = 'Rulează…';
    });
    final r = await f();
    if (!mounted) return;
    setState(() {
      rez = r;
      ruleaza = false;
      progres = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.m,
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final m = widget.m;
    final c = culori(context);
    final t = m.tinte[widget.id]!;
    final a = t.a;
    final cl = m.clienti(widget.id);
    final dbm = m.semnalUplink(widget.id);
    final par = m.parinteReal(widget.id);
    final fw = m.ruter?.firmware[widget.id];
    final ses = m.intensiv[widget.id];
    final ant = m.intensivGata.where((x) => x['id'] == widget.id).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          a.nume,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${a.loc} · ${a.rol}',
                  style: TextStyle(color: c.muted),
                ),
              ),
              Pastila(etichete[t.stare]!, t.stare),
            ],
          ),
          Text(
            'IP ${t.ip}${a.mac != null ? ' · MAC ${a.mac}' : ''}${fw != null ? '\nfirmware $fw' : ''}',
            style: TextStyle(color: c.muted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.75,
            children: [
              Tila(
                'Latență',
                t.latenta == null ? '—' : '${t.latenta!.toStringAsFixed(0)} ms',
                sub: t.jitter == null
                    ? ''
                    : 'jitter ${t.jitter!.toStringAsFixed(1)} ms',
                nuanta: 'sky',
              ),
              Tila(
                'Pierderi',
                t.pierderi == null ? '—' : '${t.pierderi!.toStringAsFixed(0)}%',
                sub: 'ultimele ${t.istoric.length} verificări',
                nuanta: 'rose',
                culoareValoare: t.pierderi == null
                    ? null
                    : c.stare((t.pierderi! <= a.pierderiMax) ? 'ok' : 'cazut'),
              ),
              Tila(
                'Legătura lui',
                dbm != null
                    ? '$dbm dBm'
                    : (a.rol.contains('cablu') || a.id == 'ax73')
                    ? 'cablu'
                    : a.tip == 'iot'
                    ? _nodIot(m, t)
                    : 'aer',
                sub: dbm != null
                    ? '${calitateDbm(dbm)} · spre ${aparat(par)?.numeComplet ?? 'părinte'}'
                    : '',
                nuanta: 'violet',
                culoareValoare: dbm != null ? c.dbm(dbm) : null,
              ),
              Tila(
                'Clienți',
                cl == null ? '—' : '${cl.length}',
                sub: cl == null
                    ? (a.id == 're315' || a.id == 'eap245'
                          ? 'doar pe calculator'
                          : 'după citirea ruterului')
                    : 'conectați acum',
                nuanta: 'teal',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Sectiune(
            'Teste',
            Column(
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _btn(
                      'Ping rapid',
                      Icons.monitor_heart,
                      () => _test(
                        () => teste.pingSerie(
                          t.ip,
                          progres: (s) => setState(() => progres = s),
                        ),
                      ),
                    ),
                    _btn(
                      'Ping 1 minut',
                      Icons.timer,
                      () => _test(
                        () => teste.pingSerie(
                          t.ip,
                          n: 60,
                          pauzaMs: 850,
                          progres: (s) => setState(() => progres = s),
                        ),
                      ),
                    ),
                    _btn(
                      'Interfața web',
                      Icons.public,
                      () => _test(() => teste.web(t.ip)),
                    ),
                    _btn(
                      'Servicii',
                      Icons.lock,
                      () => _test(() => teste.porturi(t.ip)),
                    ),
                    _btn('DNS', Icons.link, () => _test(teste.dns)),
                    _btn(
                      'Viteză internet',
                      Icons.speed,
                      () => _test(
                        () => teste.viteza(
                          progres: (s) => setState(() => progres = s),
                        ),
                      ),
                    ),
                  ],
                ),
                if (progres.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(progres, style: TextStyle(color: c.muted)),
                  ),
                if (rez != null) _Rezultat(rez!),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Sectiune(
            'Supraveghere intensivă',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ping la fiecare secundă doar la acest aparat. Pe iPhone merge cât aplicația e deschisă și ecranul aprins.',
                  style: TextStyle(color: c.muted, fontSize: 12.5),
                ),
                const SizedBox(height: 8),
                if (ses == null) ...[
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 5, label: Text('5 min')),
                      ButtonSegment(value: 15, label: Text('15 min')),
                      ButtonSegment(value: 60, label: Text('1 h')),
                      ButtonSegment(value: 240, label: Text('4 h')),
                    ],
                    selected: {durata.inMinutes},
                    onSelectionChanged: (s) =>
                        setState(() => durata = Duration(minutes: s.first)),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => m.pornesteIntensiv(widget.id, durata),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Pornește supravegherea'),
                  ),
                ] else ...[
                  LinearProgressIndicator(
                    value: ses.progres,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  const SizedBox(height: 6),
                  Text(_textRez(rezumatIntensiv(ses.esantioane), 'Până acum')),
                  Sparkline(
                    ses.esantioane
                        .map((e) => e.$2)
                        .toList()
                        .reversed
                        .take(300)
                        .toList()
                        .reversed
                        .toList(),
                    c.tenta('rose').$2,
                    inaltime: 60,
                  ),
                  OutlinedButton(
                    onPressed: () => m.opresteIntensiv(widget.id),
                    child: const Text('Oprește acum'),
                  ),
                ],
                for (final x in ant.take(4)) ...[
                  const Divider(),
                  Text(
                    '${ora(DateTime.fromMillisecondsSinceEpoch(x['start']))} · ${durataText(x['durata'])} · ${verdictIntensiv(x['rezumat']).$1}',
                    style: TextStyle(
                      fontSize: 13,
                      color: {
                        'ok': c.ok,
                        'avertisment': c.warn,
                        'eroare': c.err,
                      }[verdictIntensiv(x['rezumat']).$2],
                    ),
                  ),
                  for (final cd in (x['rezumat']['caderi'] as List).take(5))
                    Text(
                      '  cădere ${ora(DateTime.fromMillisecondsSinceEpoch(cd[0]))} (${((cd[1] - cd[0]) ~/ 1000)} s)',
                      style: TextStyle(color: c.muted, fontSize: 12),
                    ),
                ],
              ],
            ),
          ),
          if (cl != null) ...[
            const SizedBox(height: 14),
            Sectiune(
              'Clienți conectați (${cl.length})',
              Column(
                children: [
                  for (final x
                      in ([...cl]..sort(
                        (p, q) =>
                            (q.semnal ?? -200).compareTo(p.semnal ?? -200),
                      )))
                    RandClient(m, x, nodId: widget.id),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _nodIot(Monitor m, Tinta t) {
    for (final e
        in (m.ruter?.clientiPeNod ?? <String, List<Client>>{}).entries) {
      if (e.value.any((x) => x.ip == t.ip)) return aparat(e.key)?.nume ?? '—';
    }
    return '—';
  }

  String _textRez(Map r, String titlu) {
    final v = verdictIntensiv(r).$1;
    return '$titlu: $v · ${r['trimise']} ping-uri'
        '${r['medie'] != null ? ' · medie ${(r['medie'] as double).toStringAsFixed(0)} ms · max ${(r['maxim'] as double).toStringAsFixed(0)} ms' : ''}';
  }

  Widget _btn(String t, IconData i, VoidCallback f) => OutlinedButton.icon(
    onPressed: ruleaza ? null : f,
    icon: Icon(i, size: 18),
    label: Text(t),
  );
}

class _Rezultat extends StatelessWidget {
  final teste.Rezultat r;
  const _Rezultat(this.r);
  @override
  Widget build(BuildContext context) {
    final c = culori(context);
    final col =
        {'ok': c.ok, 'avertisment': c.warn, 'eroare': c.err}[r.nivel] ?? c.text;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      width: double.infinity,
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: col, width: 5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            r.titlu.toUpperCase(),
            style: TextStyle(
              color: c.muted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            r.verdict,
            style: TextStyle(
              color: col,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          for (final (a, b) in r.randuri)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(
                      a,
                      style: TextStyle(color: c.muted, fontSize: 13),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      b,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// folosit și de lista de dispozitive
String numeClient(Monitor m, Client x) {
  final inv0 = m.inventar[x.mac];
  final ap = aparatDupaMac(x.mac);
  return inv0?['nume']?.isNotEmpty == true
      ? inv0!['nume']!
      : ap?.numeComplet ?? (x.nume.isNotEmpty ? x.nume : '(fără nume)');
}

String categorieClient(Monitor m, Client x) =>
    m.inventar[x.mac]?['categorie'] ??
    inv.categorie(x.nume, inv.producator(x.mac));
