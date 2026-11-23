import 'package:flutter/material.dart';

import '../config.dart';
import '../inventar.dart' as inv;
import '../monitor.dart';
import '../ruter/citire.dart';
import '../tema.dart';
import '../teste.dart' as teste;
import 'aparat.dart';

class EcranDispozitive extends StatefulWidget {
  final Monitor m;
  const EcranDispozitive(this.m, {super.key});
  @override
  State<EcranDispozitive> createState() => _EcranDispozitiveState();
}

class _EcranDispozitiveState extends State<EcranDispozitive> {
  String cauta = '', cat = '';

  @override
  Widget build(BuildContext context) {
    final m = widget.m;
    final c = culori(context);
    final toti = <(String, Client)>[
      for (final e
          in (m.ruter?.clientiPeNod ?? <String, List<Client>>{}).entries)
        for (final x in e.value) (e.key, x),
    ];
    final peCat = <String, int>{};
    for (final (_, x) in toti) {
      final k = categorieClient(m, x);
      peCat[k] = (peCat[k] ?? 0) + 1;
    }
    final afisati =
        toti.where((p) {
          final x = p.$2;
          if (cat.isNotEmpty && categorieClient(m, x) != cat) return false;
          final t =
              '${numeClient(m, x)} ${x.ip} ${x.mac} ${inv.producator(x.mac)}'
                  .toLowerCase();
          return cauta.isEmpty || t.contains(cauta.toLowerCase());
        }).toList()..sort(
          (p, q) => numeClient(
            m,
            p.$2,
          ).toLowerCase().compareTo(numeClient(m, q.$2).toLowerCase()),
        );
    if (m.ruter == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Text(
            m.eroareRuter.isNotEmpty
                ? m.eroareRuter
                : 'Se citește lista de la ruter…',
            textAlign: TextAlign.center,
            style: TextStyle(color: c.muted),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: m.citesteRuterAcum,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Caută nume, IP, MAC, producător…',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: c.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: c.border),
              ),
            ),
            onChanged: (v) => setState(() => cauta = v),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text('Toate ${toti.length}'),
                    selected: cat.isEmpty,
                    onSelected: (_) => setState(() => cat = ''),
                  ),
                ),
                for (final k in inv.categorii.where((k) => (peCat[k] ?? 0) > 0))
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text('$k ${peCat[k]}'),
                      selected: cat == k,
                      onSelected: (_) =>
                          setState(() => cat = cat == k ? '' : k),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          for (final (nod, x) in afisati) RandClient(m, x, nodId: nod),
        ],
      ),
    );
  }
}

class RandClient extends StatelessWidget {
  final Monitor m;
  final Client x;
  final String nodId;
  const RandClient(this.m, this.x, {required this.nodId, super.key});
  @override
  Widget build(BuildContext context) {
    final c = culori(context);
    final prod = inv.producator(x.mac);
    return InkWell(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => FisaClient(m, x, nodId),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 30,
              child: x.semnal != null
                  ? BareSemnal(x.semnal)
                  : Icon(Icons.cable, size: 16, color: c.muted),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    numeClient(m, x),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    [
                      x.ip,
                      if (prod.isNotEmpty) prod,
                      aparat(nodId)?.numeComplet ?? nodId,
                    ].join(' · '),
                    style: TextStyle(color: c.muted, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (x.semnal != null)
              Text(
                '${x.semnal} dBm',
                style: TextStyle(
                  color: c.dbm(x.semnal),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class FisaClient extends StatefulWidget {
  final Monitor m;
  final Client x;
  final String nodId;
  const FisaClient(this.m, this.x, this.nodId, {super.key});
  @override
  State<FisaClient> createState() => _FisaClientState();
}

class _FisaClientState extends State<FisaClient> {
  late final nume = TextEditingController(
    text: widget.m.inventar[widget.x.mac]?['nume'] ?? '',
  );
  late final prop = TextEditingController(
    text: widget.m.inventar[widget.x.mac]?['proprietar'] ?? '',
  );
  late String cat = categorieClient(widget.m, widget.x);
  teste.Rezultat? rez;
  bool ruleaza = false;

  @override
  Widget build(BuildContext context) {
    final c = culori(context);
    final x = widget.x;
    final prod = inv.producator(x.mac);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        14,
        18,
        MediaQuery.of(context).viewInsets.bottom + 18,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              numeClient(widget.m, x),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            Text(
              'IP ${x.ip} · MAC ${x.mac}${prod.isNotEmpty ? ' · $prod' : ''}',
              style: TextStyle(color: c.muted, fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Tila(
                    'Legat la',
                    aparat(widget.nodId)?.nume ?? '—',
                    sub: aparat(widget.nodId)?.loc ?? '',
                    nuanta: 'sky',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Tila(
                    'Semnal',
                    x.semnal == null ? '—' : '${x.semnal} dBm',
                    sub: x.semnal == null
                        ? x.banda
                        : '${calitateDbm(x.semnal)} · ${x.banda}',
                    nuanta: 'violet',
                    culoareValoare: x.semnal == null ? null : c.dbm(x.semnal),
                  ),
                ),
              ],
            ),
            if (x.rx != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Viteza legăturii: ${x.rx} / ${x.tx} Mbps',
                  style: TextStyle(color: c.muted),
                ),
              ),
            const SizedBox(height: 14),
            TextField(
              controller: nume,
              decoration: InputDecoration(labelText: 'Nume', hintText: x.nume),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: inv.categorii.contains(cat) ? cat : 'Altele',
              decoration: const InputDecoration(labelText: 'Categorie'),
              items: [
                for (final k in inv.categorii)
                  DropdownMenuItem(value: k, child: Text(k)),
              ],
              onChanged: (v) => setState(() => cat = v ?? cat),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: prop,
              decoration: const InputDecoration(labelText: 'Proprietar'),
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: () {
                widget.m.seteazaInventar(x.mac, {
                  'nume': nume.text.trim(),
                  'categorie': cat,
                  'proprietar': prop.text.trim(),
                });
                Navigator.pop(context);
              },
              child: const Text('Salvează'),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: ruleaza
                      ? null
                      : () => _t(() => teste.pingSerie(x.ip)),
                  child: const Text('Ping rapid'),
                ),
                OutlinedButton(
                  onPressed: ruleaza
                      ? null
                      : () => _t(() => teste.porturi(x.ip)),
                  child: const Text('Servicii'),
                ),
                OutlinedButton(
                  onPressed: ruleaza ? null : () => _t(() => teste.web(x.ip)),
                  child: const Text('Interfața web'),
                ),
              ],
            ),
            if (ruleaza)
              const Padding(
                padding: EdgeInsets.all(8),
                child: LinearProgressIndicator(),
              ),
            if (rez != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${rez!.verdict}\n${rez!.randuri.map((r) => '${r.$1}: ${r.$2}').join('\n')}',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _t(Future<teste.Rezultat> Function() f) async {
    setState(() => ruleaza = true);
    final r = await f();
    if (mounted) {
      setState(() {
        rez = r;
        ruleaza = false;
      });
    }
  }
}
