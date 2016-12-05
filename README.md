# Kontrolery
Przykładowe skrypty sterujące, tzw. "kontrolery" wg. modelu narzędzi administracyjnych Dona Jones'a. Korzystają z modułu PBFunkcje.

* Kontrolery to najczęściej zlepek cmdletów - standardowych oraz własnych, zdefiniowanych w module narzędziowym.
* Są specyficzne dla określonego procesu lub zadania i zwykle nie muszą przestrzegać jakiejś określonej struktury - mają "po prostu działać".
* Jesli jakaś częśc skryptu ma być zuniwersalizowana, powinna zostać przesunięta do modułu z funkcjami narzędziowymi.

Przykładowe kontrolery:

<b>Panel Kontrolny</b> - skrypt zbiera informacje o przepływach danych między systemami i publikuje je w postaci pliku html.

<b>Procedura Awaryjna</b> - skrypt konfiguruje awaryjny serwer aplikacji. Na koniec przeprowadza proste testy akceptacyjne (Pester), które wysyła do Administracji. Zawiera skrypt wstępnie konfigurujący serwer za pomocą DSC (Desired State Configuration).

<b>Przechwytywanie Artykułów</b> - narzędzie przechwytuje z trafiającego do sklepu cennika obserwowane akrtykuły i podmienia ich nazwy wg. wzoru.

<b>Konfiguracja Plikowa</b> - narzędzie umożliwia Operatorom masową konfigurację wag za pomocą plików xml wgrywanych do urządzeń. Wyświetla menu wyboru. Do porównania zawartości pików używa funkcji hashującej.

<b>Monitoring</b> - Skaner sieciowy urządzeń. Dane z poprzednich skanów trzyma w plikach xml. Dla urządzeń niewidocznych od 3 godzin tworzy zgłoszenie w HelpDesku.
