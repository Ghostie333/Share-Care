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

---

## 💻 Wygląd aplikacji

<table>
  <tr>
    <td align="center" width="50%">
      <b>Strona główna</b><br />
      <img src="https://github.com/user-attachments/assets/abaed7da-aceb-4142-bec0-0b06387f34a6" width="100%" alt="Strona główna" />
    </td>
    <td align="center" width="50%">
      <b>Wyszukiwarka</b><br />
      <img src="https://github.com/user-attachments/assets/ad78874e-100b-490d-b7cf-8394cbe2c1b5" width="100%" alt="Wyszukiwarka" />
    </td>
  </tr>
  <tr>
    <td align="center" width="50%">
      <b>Tworzenie ogłoszenia</b><br />
      <img src="https://github.com/user-attachments/assets/3fb1a639-f6a7-449f-94ba-0bbf6d1bcf56" width="100%" alt="Tworzenie ogłoszenia" />
    </td>
    <td align="center" width="50%">
      <b>Podgląd ogłoszenia</b><br />
      <img src="https://github.com/user-attachments/assets/f99e0dd1-19a3-4067-a3d4-9a7cf4592eeb" width="100%" alt="Podgląd ogłoszenia" />
    </td>
  </tr>
  <tr>
    <td align="center" width="50%">
      <b>Chat</b><br />
      <img src="https://github.com/user-attachments/assets/0b345ede-2f96-4a5f-a0ce-65946d298ce9" width="100%" alt="Chat" />
    </td>
    <td align="center" width="50%">
      <b>Profil użytkownika</b><br />
      <img src="https://github.com/user-attachments/assets/fea3fcd5-55c7-4fd2-a493-81eac5d1e679" width="100%" alt="Profil użytkownika" />
    </td>
  </tr>
</table>

---

## 💻 Jak uruchomić projekt lokalnie

### Wymagania wstępne
Do uruchomienia całej aplikacji potrzebujesz [Docker](https://docs.docker.com/get-docker/)

### 1. Pobranie repozytorium
```bash
git clone https://github.com/Ghostie333/Share-Care.git
cd Share-Care
```
### 2. Uruchomienie kontenera z aplikacją
W folderze z aplikacją otwieramy okno terminalu i wpisujemy komendę:
```bash
docker compose --env-file shareCare.env -f docker-compose.dev.yml up -d --build
```
### 3. Wejście na stronę aplikacji:
```bash
http://127.0.0.1:7070
```
