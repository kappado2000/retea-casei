import 'dart:io';

import 'package:dart_ping_ios/dart_ping_ios.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ecrane/acasa.dart';
import 'ecrane/aparat.dart';
import 'ecrane/dispozitive.dart';
import 'ecrane/setari.dart';
import 'inventar.dart';
import 'monitor.dart';
import 'tema.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isIOS) DartPingIOS.register();
  await incarcaOui();
  final prefs = await SharedPreferences.getInstance();
  final temaSalvata = ThemeMode.values[prefs.getInt('tema') ?? 0];
  final tema = ValueNotifier(temaSalvata);
  final m = Monitor();
  await m.porneste();
  tema.addListener(() => prefs.setInt('tema', tema.value.index));
  runApp(AplicatieRetea(m, tema));
}

class AplicatieRetea extends StatelessWidget {
  final Monitor m;
  final ValueNotifier<ThemeMode> tema;
  const AplicatieRetea(this.m, this.tema, {super.key});
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: tema,
      builder: (_, mod, _) => MaterialApp(
        title: 'Rețeaua casei',
        debugShowCheckedModeBanner: false,
        theme: temaApp(false),
        darkTheme: temaApp(true),
        themeMode: mod,
        home: Cadru(m, tema),
      ),
    );
  }
}

class Cadru extends StatefulWidget {
  final Monitor m;
  final ValueNotifier<ThemeMode> tema;
  const Cadru(this.m, this.tema, {super.key});
  @override
  State<Cadru> createState() => _CadruState();
}

class _CadruState extends State<Cadru> {
  int tab = kDebugMode && Platform.isWindows
      ? int.tryParse(Platform.environment['RETEA_TAB'] ?? '') ?? 0
      : 0;
  static const titluri = [
    'Rețeaua casei',
    'Aparate',
    'Dispozitive',
    'Jurnal',
    'Setări',
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.m,
      builder: (context, _) {
        final m = widget.m;
        final ecrane = [
          EcranAcasa(m, (i) => setState(() => tab = i)),
          ListaAparate(m),
          EcranDispozitive(m),
          EcranJurnal(m),
          EcranSetari(m, widget.tema),
        ];
        return Scaffold(
          appBar: AppBar(
            title: Text(titluri[tab]),
            actions: [
              if (m.citesteRuter)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Reîmprospătează',
                  onPressed: m.reimprospateaza,
                ),
            ],
          ),
          body: SafeArea(top: false, child: ecrane[tab]),
          bottomNavigationBar: NavigationBar(
            selectedIndex: tab,
            onDestinationSelected: (i) => setState(() => tab = i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Acasă',
              ),
              NavigationDestination(
                icon: Icon(Icons.router_outlined),
                selectedIcon: Icon(Icons.router),
                label: 'Aparate',
              ),
              NavigationDestination(
                icon: Icon(Icons.devices_outlined),
                selectedIcon: Icon(Icons.devices),
                label: 'Dispozitive',
              ),
              NavigationDestination(icon: Icon(Icons.history), label: 'Jurnal'),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: 'Setări',
              ),
            ],
          ),
        );
      },
    );
  }
}
