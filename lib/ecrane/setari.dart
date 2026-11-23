import 'package:flutter/material.dart';

import '../monitor.dart';
import '../tema.dart';

class EcranJurnal extends StatelessWidget {
  final Monitor m;
  const EcranJurnal(this.m, {super.key});
  @override
  Widget build(BuildContext context) {
    final c = culori(context);
    if (m.jurnal.isEmpty) {
      return Center(
        child: Text('Niciun eveniment încă.', style: TextStyle(color: c.muted)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: m.jurnal.length,
      separatorBuilder: (_, _) => Divider(color: c.border, height: 1),
      itemBuilder: (_, i) {
        final e = m.jurnal[i];
        final col =
            {'eroare': c.err, 'avertisment': c.warn, 'ok': c.ok}[e.nivel] ??
            c.accent;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.circle, size: 10, color: col),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.mesaj,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      ora(e.ts),
                      style: TextStyle(color: c.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class EcranSetari extends StatefulWidget {
  final Monitor m;
  final ValueNotifier<ThemeMode> tema;
  const EcranSetari(this.m, this.tema, {super.key});
  @override
  State<EcranSetari> createState() => _EcranSetariState();
}

class _EcranSetariState extends State<EcranSetari> {
  final parola = TextEditingController();
  String mesaj = '';

  @override
  Widget build(BuildContext context) {
    final c = culori(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
      children: [
        Sectiune(
          'Ruterul AX73',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Parola de admin (aceeași ca pe calculator). Se păstrează în Keychain-ul iPhone-ului. '
                'Aplicația doar CITEȘTE de pe ruter și extendere — nu schimbă nicio setare.',
                style: TextStyle(color: c.muted, fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: parola,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Parola admin',
                  hintText: '•••••• (lasă gol ca s-o păstrezi)',
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () async {
                  if (parola.text.isEmpty) return;
                  await widget.m.seteazaParola(parola.text);
                  parola.clear();
                  setState(
                    () => mesaj = widget.m.eroareRuter.isEmpty
                        ? 'Salvat ✓ — datele de la ruter s-au citit.'
                        : widget.m.eroareRuter,
                  );
                },
                child: const Text('Salvează și citește ruterul'),
              ),
              if (mesaj.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(mesaj),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Sectiune(
          'Aspect',
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                label: Text('Ca iPhone-ul'),
              ),
              ButtonSegment(value: ThemeMode.light, label: Text('Deschisă')),
              ButtonSegment(value: ThemeMode.dark, label: Text('Închisă')),
            ],
            selected: {widget.tema.value},
            onSelectionChanged: (s) =>
                setState(() => widget.tema.value = s.first),
          ),
        ),
        const SizedBox(height: 14),
        Sectiune(
          'Când nu ești acasă',
          Text(
            'Telefonul verifică aparatele direct, deci trebuie să fie în rețeaua casei. De pe drum: pornește '
            'serverul VPN WireGuard pe AX73 (Avansat → Server VPN → WireGuard), adaugă un „cont” pentru iPhone, '
            'scanează codul QR cu aplicația WireGuard și pornește VPN-ul înainte să deschizi Rețeaua casei. '
            'Alarmele permanente vin prin ntfy de la calculator, când e pornit.',
            style: TextStyle(color: c.muted, fontSize: 13),
          ),
        ),
        const SizedBox(height: 14),
        Sectiune(
          'Ce nu poate iPhone-ul',
          Text(
            '• scanarea rețelelor Wi-Fi și harta acoperirii măsurate (doar pe laptop)\n'
            '• supravegherea în fundal: iOS oprește aplicația la scurt timp după ce o închizi\n'
            '• clienții RE315 și ai EAP245 (îi vezi pe calculator)',
            style: TextStyle(color: c.muted, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
