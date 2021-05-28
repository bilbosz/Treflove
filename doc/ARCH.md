Player perspective:
* Login
    * Username
* Menu
    * Start
    * Exit

Runnables:
* Run server
* Run client
    * Game Master
    * Player

Serwer przechowuje dane i obsługuje komunikaty otrzymane od klienta. Obsługuje logikę gry. Klient wyświetla stan serwera przeznaczony dla oczu gracza. Gracz ma nazwę i hasło. Serwer i klient będzie się posługiwać tym samym kodem, dzięki czemu nie trzeba będzie synchronizować stanu jednego i drugiego. Graczowi po odpaleniu gry pojawi się okno logowania. Wejdzie do menu. Menu będzie się składać z: Dołącz do sesji, Wyjście. Dla GMa: Rozpocznij sesję, Wyjście.
Po wejściu do gry gracz zobaczy:
Świat - planszę do walki
    Podłoże
    Przeszkody
    Tokeny
        Atrybuty
        Radius
        Tagi (np. Nieprzytomny, Sojusznicy/Przeciwnicy, Aury)
    Menu trybów:
        Tryb akcji
        Tryb pomiaru
    

Jak chcę reprezentować obiekty?
Chcę mieć możliwość stworzenia obiektu jako updateable, drawable, gameObject itd. w momencie wczytywania go.
Najlepiej jak będzie kompozycją wielu obiektów.