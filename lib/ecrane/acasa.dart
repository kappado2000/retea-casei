import 'package:flutter/material.dart';

import '../config.dart';
import '../monitor.dart';
import '../tema.dart';
import 'aparat.dart';

class EcranAcasa extends StatelessWidget {
  final Monitor m;
  final void Function(int) laTab;
  const EcranAcasa(this.m, this.laTab, {super.key});

  String? _parinte(String id) => m.parinteReal(id) ?? aparat(id)!.parinte;

  @override
  Widget build(BuildContext context) {
    final c = culori(context);
    final g = m.stareGenerala;
    final prob = m.probleme;
    final net = m.net.values.map((t) => t.latenta).whereType<double>().toList();
    final nCl = (m.ruter?.clientiPeNod.values ?? []).fold<int>(
      0,
      (s, l) => s + l.length,
    );
    final upt = int.tryParse(m.ruter?.status['wan_ipv4_uptime'] ?? '');
    // arborele: AX73 → copiii lui → nepoții
    final infra = aparate
        .where((a) => a.tip == 'infra' && a.id != 'ax73')
        .map((a) => a.id)
        .toList();
    final n1 = infra.where((i) => _parinte(i) == 'ax73').toList();
    final arbore = <(String, int)>[('ax73', 0)];
    for (final i in n1) {
      arbore.add((i, 1));
      for (final j in infra.where((x) => !n1.contains(x) && _parinte(x) == i)) {
        arbore.add((j, 2));
      }
    }
    return RefreshIndicator(
      onRefresh: m.reimprospateaza,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.fondStare(g),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: c.conturStare(g)),
            ),
            child: Row(
              children: [
                Icon(
                  g == 'ok'
                      ? Icons.check_circle
                      : g == 'necunoscut'
                      ? Icons.hourglass_top
                      : Icons.error,
                  color: c.stare(g),
                  size: 34,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        g == 'ok'
                            ? 'Totul funcționează'
                            : g == 'necunoscut'
                            ? 'Se verifică rețeaua…'
                            : '${prob.length + (m.stareInternet == 'cazut' ? 1 : 0)} probleme',
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (prob.isNotEmpty || m.stareInternet == 'cazut')
                        Text(
                          [
                            if (m.stareInternet == 'cazut') 'Internetul',
                            ...prob.map((t) => t.a.numeComplet),
                          ].join(', '),
                          style: TextStyle(color: c.muted, fontSize: 13),
                        ),
                      if (m.eroareRuter.isNotEmpty)
                        Text(
                          m.eroareRuter,
                          style: TextStyle(color: c.warn, fontSize: 12),
                        ),
                      if (m.ruter != null && m.eroareRuter.isEmpty)
                        Text(
                          'date de la ruter ${cand(m.ruter!.cand)}',
                          style: TextStyle(color: c.muted, fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Tila(
                  'Internet',
                  etichete[m.stareInternet]!,
                  sub: [
                    if (net.isNotEmpty)
                      '${net.reduce((a, b) => a < b ? a : b).toStringAsFixed(0)} ms',
                    if (upt != null) 'online ${durataText(upt)}',
                  ].join(' · '),
                  nuanta: 'sky',
                  culoareValoare: c.stare(m.stareInternet),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Tila(
                  'Dispozitive',
                  m.ruter == null ? '—' : '$nCl',
                  sub: m.ruter == null
                      ? 'după citirea ruterului'
                      : 'pe ${m.ruter!.clientiPeNod.values.where((l) => l.isNotEmpty).length} noduri',
                  nuanta: 'teal',
                  onTap: () => laTab(2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Harta rețelei',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: c.text,
            ),
          ),
          const SizedBox(height: 8),
          _NodInternet(m),
          for (final (id, nivel) in arbore) _RandNod(m, id, nivel),
          const SizedBox(height: 16),
          Text(
            'Aparate importante',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: c.text,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in aparate.where((a) => a.tip == 'iot'))
                ActionChip(
                  avatar: Icon(
                    Icons.circle,
                    size: 12,
                    color: c.stare(m.tinte[a.id]!.stare),
                  ),
                  label: Text(a.nume),
                  backgroundColor: c.fondStare(m.tinte[a.id]!.stare),
                  side: BorderSide(color: c.conturStare(m.tinte[a.id]!.stare)),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => EcranAparat(m, a.id)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NodInternet extends StatelessWidget {
  final Monitor m;
  const _NodInternet(this.m);
  @override
  Widget build(BuildContext context) {
    final c = culori(context);
    final s = m.stareInternet;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: c.fondStare(s),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: c.stare(s), width: 1.6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.public, size: 18, color: c.stare(s)),
            const SizedBox(width: 8),
            const Text(
              'Internet · Digi',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _RandNod extends StatelessWidget {
  final Monitor m;
  final String id;
  final int nivel;
  const _RandNod(this.m, this.id, this.nivel);
  @override
  Widget build(BuildContext context) {
    final c = culori(context);
    final t = m.tinte[id]!;
    final a = t.a;
    final cablu = a.rol.contains('cablu') || id == 'ax73';
    final dbm = m.semnalUplink(id);
    final cl = m.clienti(id);
    final legatura = id == 'ax73'
        ? 'PPPoE'
        : cablu
        ? 'cablu'
        : dbm != null
        ? 'aer · $dbm dBm'
        : 'aer';
    final colLeg = cablu
        ? c.stare(t.stare == 'necunoscut' ? 'ok' : t.stare)
        : c.dbm(dbm);
    return Padding(
      padding: EdgeInsets.only(left: 22.0 * nivel, top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            children: [
              Container(width: 2.5, height: 12, color: colLeg),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colLeg),
                ),
                child: Text(
                  legatura,
                  style: TextStyle(
                    fontSize: 10,
                    color: colLeg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(width: 2.5, height: 12, color: colLeg),
            ],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => EcranAparat(m, id)),
              ),
              // contur uniform (Flutter nu acceptă colțuri rotunjite cu laturi de culori diferite);
              // banda colorată din stânga e un Container separat
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: c.fondStare(t.stare),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: c.conturStare(t.stare)),
                ),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(width: 5, color: c.stare(t.stare)),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
                          child: Row(
                            children: [
                              Icon(
                                a.esteAp ? Icons.wifi : Icons.router,
                                color: c.stare(t.stare),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      a.nume,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      a.loc,
                                      style: TextStyle(
                                        color: c.muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    t.latenta == null
                                        ? '—'
                                        : '${t.latenta!.toStringAsFixed(0)} ms',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: c.stare(t.stare),
                                    ),
                                  ),
                                  if (cl != null)
                                    Text(
                                      '${cl.length} clienți',
                                      style: TextStyle(
                                        color: c.muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
