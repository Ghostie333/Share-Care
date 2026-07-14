# 🤝 Share&Care

**Share&Care** to nowoczesna aplikacja webowa stworzona z myślą o niemarnowaniu zasobów. Umożliwia użytkownikom szybkie i bezproblemowe oddawanie niepotrzebnych rzeczy (ubrań, sprzętów) oraz żywności osobom, które najbardziej tego potrzebują. Możliwe jest również wypożyczanie rzeczy za kaucją.

---

## 🚀 Główne Funkcjonalności
* 📦 **Oddawanie rzeczy i żywności** – łatwe wystawianie ogłoszeń z kategoryzacją.
* 🔄 **Wypożyczanie** – możliwość wypożyczenia przedmiotu za kaucją.
* 📍 **Interaktywna mapa** – lokalizacja punktów odbioru oraz ogłoszeń w czasie rzeczywistym.
* 💳 **Bezpieczne płatności/darowizny** – integracja z systemem PayU umożliwiająca opłacanie kaucji.
* 📱 **Responsywny interfejs** – pełna wygoda korzystania zarówno na komputerach, jak i urządzeniach mobilnych.

---

## 🛠️ Stack Technologiczny

| Warstwa | Technologia | Zastosowanie |
| :--- | :--- | :--- |
| **Backend** | ![ASP.NET](https://img.shields.io/badge/.NET_8-512BD4?style=flat-square&logo=dotnet&logoColor=white) | Logika biznesowa, REST API |
| **Frontend** | ![Flutter](https://img.shields.io/badge/Flutter-02569B?style=flat-square&logo=flutter&logoColor=white) | Responsywny interfejs webowy |
| **Baza danych** | ![MongoDB](https://img.shields.io/badge/MongoDB-47A248?style=flat-square&logo=mongodb&logoColor=white) | Przechowywanie danych użytkowników i ogłoszeń |
| **Mapy** | ![MapTiler](https://img.shields.io/badge/MapTiler-00C4B4?style=flat-square&logo=maplibre&logoColor=white) | Wizualizacja lokalizacji na mapie |
| **Płatności** | ![PayU](https://img.shields.io/badge/PayU-99CC33?style=flat-square) | Szybkie i bezpieczne płatności online |
| **Hosting** | ![Oracle Cloud](https://img.shields.io/badge/Oracle_Cloud-F80000?style=flat-square&logo=oracle&logoColor=white) | Stabilna i wydajna infrastruktura chmurowa |

---

## 💻 Jak uruchomić projekt lokalnie

### Wymagania wstępne
Do uruchomienia całej aplikacji w środowisku deweloperskim potrzebujesz jedynie:
* [Docker](https://docs.docker.com/get-docker/) (razem z Docker Compose)

### 1. Pobranie repozytorium
```bash
git clone https://github.com/Ghostie333/Share-Care.git
cd Share-Care
```
### 2. Otworzenie folderu Share-Care
W folderze z aplikacją otwieramy okno terminalu i wpisujemy komendę:
```bash
docker compose --env-file shareCare.env -f docker-compose.dev.yml up -d --build
```
Zbuduje ona kontener z naszą aplikacją i uruchomi go.
### 3. Wejście na stronę aplikacji:
```bash
http://localhost:7070/
```
