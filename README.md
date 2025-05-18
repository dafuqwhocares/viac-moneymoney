# VIAC Extension for MoneyMoney

Diese Web Banking Extension ermöglicht den Zugriff auf das Säule 3a-Konto von VIAC in MoneyMoney (CH) inklusive der dortigen Portfolios und liquiden Cash-Werte.

## Funktionen

- **Zugriff auf Portfolios:**  
  Die Extension ermöglicht den Zugriff auf Ihre VIAC Portfolios.
- **Automatische Portfolio-Erkennung:**  
  Vorhandene Portfolios werden automatisch erkannt und in MoneyMoney hinzugefügt.
- **Anzeige von Vermögenswerten:**  
  Detaillierte Auflistung der investierten ETFs/Fonds und weiterer Vermögenswerte.
- **Anzeige liquider Mittel:**  
  Der aktuelle Cash-Bestand (liquide Mittel) des Kontos wird angezeigt.
- **Gesamter Kontostand:**  
  Der gesamte aktuelle Wert des Portfolios wird ausgegeben.

## Aktuelle Einschränkungen

- Derzeit sind keine spezifischen Einschränkungen bekannt. Bei Problemen oder Fehlern bitte ein Issue im Repository eröffnen.

## Installation und Nutzung

### Betaversion installieren

Diese Extension funktioniert ausschließlich mit Beta-Versionen von MoneyMoney. Eine signierte Version kann auf der offiziellen Website heruntergeladen werden: https://moneymoney.app/extensions/

### Installation

1. **Öffne MoneyMoney** und gehe zu den Einstellungen (Cmd + ,).
2. Gehe in den Reiter **Extensions** und deaktiviere den Haken bei **"Verify digital signatures of extensions"**.
3. Wähle im Menü **Help > Show Database in Finder**.
4. Kopiere die Datei `VIAC.lua` aus diesem Repository in den Extensions-Ordner:
   `~/Library/Containers/com.moneymoney-app.retail/Data/Library/Application Support/MoneyMoney/Extensions`
5. In MoneyMoney sollte nun beim Hinzufügen eines neuen Kontos der Service-Typ **ZKB** erscheinen.

## Lizenz

Diese Software wird unter der **MIT License mit dem Commons Clause Zusatz** bereitgestellt.  
Das bedeutet, dass Änderungen und Weiterverteilungen (auch modifizierte Versionen) erlaubt sind – eine kommerzielle Nutzung bzw. der Verkauf der Software oder abgeleiteter Werke ist jedoch ohne die ausdrückliche Zustimmung des Autors untersagt. 
