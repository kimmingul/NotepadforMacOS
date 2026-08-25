# App Store listing — Polski (pl)

App Store Connect → Notepad Classic → pl. Uploaded via the App Store Connect API for v1.2.9.
Limits: app name 30, subtitle 30, promotional text 170, keywords 100, description 4000.

## Subtitle (21/30)
Bez AI. Karty. Sesja.

## Promotional Text (139/170)
Notatnik tekstowy dla Maca: bez AI, bez konta, bez chmury. Karty i przywracanie sesji zachowują niezapisane notatki. UTF-8, EUC-KR, UTF-16.

## Keywords (78/100)
notatnik,edytor tekstu,czysty tekst,kodowanie,karty,notatki,edytor,txt,unicode

## Description (1672/4000)
Szybki i prywatny edytor czystego tekstu dla macOS. Dla osób przyzwyczajonych do Notatnika z Windows i dla tych, które chcą kart oraz przywracania, których nie ma w TextEdit.

Bez AI. Bez konta. Bez wymuszonej chmury. Tylko tekst.

Automatyczne przywracanie sesji
Zamknij aplikację z otwartymi kartami, także z niezapisanymi notatkami: przy kolejnym uruchomieniu, również po restarcie komputera, wszystko wróci bez zmian. W ustawieniach wybierasz, czy każde uruchomienie kontynuuje poprzednią sesję, czy zaczyna nową.

Wiele kart
Pracuj nad wieloma dokumentami w jednym oknie. Kolejność zmieniasz przeciąganiem, przełączasz Ctrl-Tab, a karty niezapisane mają *.

Kodowania
Otwiera i zapisuje w UTF-8, UTF-8 z BOM, EUC-KR i UTF-16 (LE/BE). Z paska stanu można otworzyć ponownie w innym kodowaniu lub przekonwertować treść, a o znakach niemożliwych do zapisania aplikacja wyraźnie ostrzega.

Pisownia i autokorekta
Korzysta ze słowników systemowych macOS, bez sieci. Autokorekta jest opcjonalna, a sprawdzanie można wyłączyć dla rozszerzeń kodu i dzienników.

Podgląd opcjonalny
Podgląd .md i .html obok siebie lub na pełnym ekranie. Skrypty nie są wykonywane. Zdalne obrazy i CSS wczytują się tylko po zezwoleniu w danej karcie.

Ponadto
• Znajdź i zamień w linii, liczba trafień, uwzględnianie wielkości liter
• Podświetlanie Markdown, JSON, XML, HTML i dzienników
• Drukowanie, przejdź do wiersza, wstaw godzinę i datę, zawijanie, powiększenie
• Wiele okien, tryb jasny i ciemny, interfejs w 16 językach

Prywatność
Działa w pełnej piaskownicy, bez reklam, i nie zbiera żadnych danych. Sieć jest używana tylko w kartach, w których zezwolisz na zdalne obrazy w podglądzie.

## What's New — v1.2.9 (1061/4000)
Poprawki przy otwieraniu i zamykaniu plików.

• Otwarcie dokumentu z Findera nie dodaje mu już atrybutu kwarantanny macOS. Wcześniej samo czytanie wystarczało, by go dodać, mimo że nic nie było zapisywane, a potem Finder prosił o sprawdzenie pliku przy każdym otwarciu — w tej aplikacji i w każdej innej. Teraz otwarcie tylko czyta; plik jest zapisywany wyłącznie przy zapisie.

• Plik, który nie chciał się otworzyć, otwiera się. Jeśli karta nie mogła zostać przywrócona przy uruchomieniu, ponowne otwarcie pliku tylko przełączało na pustą kartę bez czytania.

• Ten sam plik osiągnięty inną ścieżką — inna wielkość liter lub łącze symboliczne — nie otwiera się już jako dwie karty nadpisujące sobie zmiany.

• Pisanie w karcie, której pliku nie udało się odczytać, nie pomija już ostrzeżenia przed zastąpieniem oryginału.

• Zamknięcie ostatniej karty zamyka okno. Wcześniej wyglądało to, jakby nic się nie stało.

• Otwarcie pliku nie zostawia już obok pustej karty „Bez nazwy”.

• Błędy zapisu podają prawdziwą przyczynę, zamiast zawsze pytać o lokalizację.
