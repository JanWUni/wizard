# Wizard für Roblox

Ein erster spielbarer Prototyp mit deutschem Interface und einem magischen Kartentisch: allein gegen zwei Bots üben oder mit 3–6 Menschen auf einem Server spielen.

## Neues 3D-Asset-Lab

Für die grafische Neuausrichtung gibt es eine **separate Testszene `AssetLab.rbxl`**: dunkle magische Taverne, räumlicher Kartentisch, Sitzperspektive, sechs Kartenmuster mit Vorder-/Rückseiten und Kartenbewegungen. In Studio öffnen und **Spielen** drücken. Das bestehende Spiel bleibt bis zur Auswahl der Gestaltung unverändert. [Bedienung, Zielbild und Asset-Prüfung](docs/art/ASSET-LAB.md).

## Direkt in Roblox Studio starten

1. Dieses Repository herunterladen oder klonen.
2. **`Wizard.rbxlx` in Roblox Studio öffnen** (Datei → Aus Datei öffnen).
3. **Spielen** drücken und **Mit Bots üben** wählen.
4. Deine Stichzahl ansagen und danach eine gold umrandete Handkarte anklicken.

Die Place-Datei enthält alle Skripte und baut die Spielhalle beim Start selbst auf. Es werden keine fremden Modelle, Kartenbilder, Plugins, HTTP-Anfragen oder Asset-IDs benötigt. Querformat empfiehlt sich auf kleinen Displays.

### Mit Freunden testen

In Studios Mehrspieler-Testmodus einen Server mit 3–6 Clients starten. Der erste Spieler ist Gastgeber und klickt auf **Mehrspieler starten**. Alle Spieler in der Lobby werden in Beitrittsreihenfolge aufgenommen, maximal sechs. Wer während einer Partie beitritt, schaut zu und kann an der nächsten Partie teilnehmen. Alternativ die Experience mit eigenen Roblox-Zugriffseinstellungen veröffentlichen und gemeinsam denselben Server betreten.

**Ein Server enthält einen Tisch.** Der Übungsmodus setzt ausschließlich den startenden Spieler und zwei Bots an den Tisch; andere anwesende Spieler schauen zu. Nach Spielende gelangt der Gastgeber über **Zur Lobby** zurück. Bei einem Verbindungsabbruch übernimmt ein Bot den Platz bis zum Ende der Partie. Wenn alle menschlichen Teilnehmer gehen, wird der Tisch freigegeben. Ein Wiedereinstieg in einen bereits durch einen Bot besetzten Platz ist noch nicht vorgesehen.

## Enthalten

- 60 Karten: vier Farben mit den Werten 1–13, vier Wizards und vier Narren.
- Runden mit steigender Kartenanzahl: 20 / 15 / 12 / 10 Runden bei 3 / 4 / 5 / 6 Teilnehmern.
- Wechselnder Geber, Trumpfkarte, Trumpfwahl durch den Geber bei aufgedecktem Wizard; kein Trumpf bei Narr oder vollständig verteiltem Stapel.
- Ansagen im Uhrzeigersinn ab dem Spieler nach dem Geber, Bedienpflicht und vollständige Wizard-/Narren-Sonderfälle.
- Richtige Ansage: `20 + 10 × Stiche`; sonst `−10 × Abweichung`.
- Grundregeln: Die Summe der Ansagen darf der Anzahl der Stiche entsprechen. Die Variante „Plus/minus Eins“ ist nicht aktiviert.
- Punkteverlauf, geteilte Siege bei Gleichstand, Regelhilfe und 45-Sekunden-Zuglimit mit automatischer Ersatzaktion.
- Server entscheidet über alle Spielzüge und Punkte. Jeder Client erhält ausschließlich seine eigenen Handkarten und öffentliche Informationen.
- Einfache Bots auf Basis der eigenen Hand und des öffentlichen Stichs; keine Einsicht in andere Hände.

## Projekt bearbeiten

Quelltexte sind maßgeblich; nach Änderungen muss die Place-Datei neu gebaut werden. Installiere [Rojo](https://rojo.space/docs/v7/getting-started/installation/) (getestet mit **7.7.1**) und [Luau](https://github.com/luau-lang/luau/releases/tag/0.743) (**0.743**).

```sh
rojo build default.project.json -o Wizard.rbxlx
python3 tools/check.py
```

Für laufende Synchronisierung mit installiertem Rojo-Studio-Plugin:

```sh
rojo serve
```

Verbinde das Plugin in einer separaten Test-Experience mit dem lokalen Projekt. Änderungen im Studio-Explorer werden nicht automatisch in die Quelltexte zurückgeschrieben.

| Pfad | Aufgabe |
| --- | --- |
| `src/shared/Rules.lua` | Karten, Mischen, Bedienpflicht, Stichgewinner, Punkte |
| `src/server/Engine.lua` | Zustandsautomat, Runden, Ansagen, öffentliche Ansichten, Botentscheidungen |
| `src/server/Main.server.lua` | Lobby, RemoteEvents, Zuglimit, Ratenlimit, Verbindungsabbrüche |
| `src/server/World.lua` | Prozedural erzeugte 3D-Spielhalle |
| `src/client/Main.client.lua` | Kamera, Oberfläche, Karten, Eingaben, Regelhilfe |
| `tests/` | Regeltests und vollständige simulierte Partien |
| `tools/check.py` | Luau-Kompilierung, Tests und Prüfung der Place-Struktur |

## Prüfung und Grenzen

22 Regel- und Simulationstests decken Sonderregeln, ungültige Eingaben, private Handkarten, Geberwechsel und 80 vollständige Partien mit 3–6 Teilnehmern ab (1.140 Runden, 41.478 Aktionen). Weitere 12 Tests prüfen den tatsächlichen Servercode mit simuliertem Transport: Lobby, Gastgeberrechte, Zuschauer, veraltete Anfragen, Zeitlimit, Botübernahme, Ratenlimit und Rückkehr zur Lobby. GitHub Actions führt sie mit festgelegten Werkzeugversionen aus und baut die Studio-Datei erneut.

**Noch manuell in Roblox Studio zu prüfen:** Darstellung, Touch-/Controller-Bedienung, tatsächliche RemoteEvent-Übertragung, Verbindungsabbrüche und Mehrspielerbetrieb. Ein Luau-Test ersetzt keinen Test in der Roblox-Engine. Die erste Version wurde außerhalb von Roblox Studio erstellt.

Noch nicht enthalten: mehrere Tische, private Raumcodes, über Servergrenzen hinweg gespeicherte Statistiken, Ranglisten, Wiederaufnahme nach Reconnect und ein eigenes Tutorial. Punkte gelten für die laufende Partie und werden nicht dauerhaft gespeichert.

## Quellen und Gestaltung

Die Regeln orientieren sich an der [Wizard-Grundanleitung von AMIGO](https://blog.amigo-spiele.de/content/ap/rule/02206-DE-AmigoRule.pdf). Für die Netzwerkschnittstelle wurde die [Roblox-Dokumentation zur Servervalidierung](https://create.roblox.com/docs/scripting/security/client-server-boundary) herangezogen. Karten und Spielwelt werden aus einfachen Formen und Text erzeugt; Originalillustrationen oder Verlagstexte sind nicht enthalten. Dies ist ein unabhängiges Fanprojekt.
