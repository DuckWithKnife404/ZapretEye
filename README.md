# ZapretEye (zeye)

**ZapretEye** (сокр. **`zeye`**) — это обёртка над [Flowseal/zapret-discord-youtube](https://github.com/flowseal/zapret-discord-youtube):
красивый CMD-интерфейс, тихое автообновление движка с релизов Flowseal, проверка стратегий через HTTPS,
команды `zeye add/remove/list` прямо в консоли и иконка в трее. После запуска окно CMD закрывается,
а `winws.exe` продолжает работать скрыто.

- **Автор обёртки:** DuckWithKnife404
- **Движок и стратегии:** Flowseal (внешняя зависимость, в этом репозитории **не распространяется**)
- **Базовая версия движка:** 1.10.2
- **Репозиторий:** [DuckWithKnife404/ZapretEye](https://github.com/DuckWithKnife404/ZapretEye)
- **Лицензия обёртки:** MIT (см. [LICENSE](LICENSE)). Права на код Flowseal/zapret принадлежат его авторам.

> ⚠️ Проект рассчитан на **Windows 10/11** (используются встроенные `curl.exe`, PowerShell 5, `wscript`).

---

## Возможности

| | |
|---|---|
| 🖥 **CMD-панель** | ASCII-«глазик», шапка `ZAPRET EYE / Flowseal and DuckWithKnife404`, статус стратегии и движка |
| 🔄 **Автообновление** | Тихо тянет последние релизы Flowseal через GitHub API (`curl.exe`), без браузера |
| ✅ **Проверка стратегий** | Прогоняет каждую `.bat`-стратегию и меряет HTTPS-запрос к YouTube с таймаутом 5 с; выводит таблицу вердиктов |
| ➕ **CLI `zeye`** | `zeye add "domain.com"` дописывает домен и **мгновенно перезапускает** `winws.exe` |
| 🟢 **Трей** | Иконка `assets\icon.ico` через PowerShell `NotifyIcon` + контекстное меню (панель / статус / перезапуск / выход) |
| 🙈 **Скрытый режим** | После запуска стратегия работает без окна, CMD-панель закрывается сама |

---

## Установка

1. Скачайте/склонируйте репозиторий:
   ```bat
   git clone https://github.com/DuckWithKnife404/ZapretEye.git
   cd ZapretEye
   ```
2. Запустите панель:
   ```bat
   src\menu.bat
   ```
3. При **первом запуске**:
   - ZapretEye молча скачает последний релиз движка Flowseal в папку `zapret-engine\`;
   - предложит выбрать стратегию по умолчанию (например, `service_all.bat` / ALT-варианты) — она сохранится в `config.json` и станет автоматической;
   - зарегистрирует команду `zeye` в `PATH` (папка `C:\zeye-tools\`);
   - запустит `winws.exe` скрыто, поднимет иконку в трее, подождёт ~10 с и закроет окно.

Движок (`winws.exe`, `lists\`, `.bat`-стратегии) **не входит в репозиторий** — он скачивается
автообновлением с официальных релизов Flowseal (см. [.gitignore](.gitignore)).

---

## Команды CLI

После установки команда `zeye` доступна в любом новом окне CMD:

```bat
zeye add "domain.com"      :: добавить домен в список и применить сразу (тихий перезапуск winws.exe)
zeye remove "domain.com"   :: убрать домен из списка и применить сразу
zeye list                  :: показать пользовательские домены (list-general-user.txt)
zeye start                 :: запустить/перезапустить winws.exe скрыто
zeye stop                  :: остановить winws.exe
zeye restart               :: тихий перезапуск winws.exe
zeye help                  :: справка
```

Как это работает: копия `zeye.bat` лежит в `C:\zeye-tools\` и читает реальный путь к репозиторию
из `C:\zeye-tools\config-path.txt` (его пишет `src\install-path.ps1`). Поэтому перенос/копирование
репозитория не ломает CLI — после перемещения достаточно заново выполнить `install-path.ps1`.

Откат интеграции в PATH:

```bat
src\uninstall-path.bat     :: убирает C:\zeye-tools из PATH пользователя и удаляет папку
```

---

## Структура проекта

```text
ZapretEye/
├── assets/
│   └── icon.ico            # иконка трея
├── src/
│   ├── zeye.bat            # CLI: add/remove/list/start/stop/restart/help
│   ├── menu.bat            # CMD-панель (глазик, статус, меню)
│   ├── update.ps1          # автообновление движка с релизов Flowseal
│   ├── check.ps1           # проверка стратегий через HTTPS (таймаут 5 с)
│   ├── tray.ps1            # иконка в трее (NotifyIcon) + контекстное меню
│   ├── install-path.ps1    # установка C:\zeye-tools в PATH + config-path.txt
│   ├── uninstall-path.bat  # откат PATH
│   └── lib/
│       ├── restart.bat     # тихий перезапуск winws.exe (VBScript-обёртка, окно 0)
│       ├── config.ps1      # программное чтение/запись config.json (get|set|ensure)
│       └── paths.bat       # общие пути
├── zapret-engine/          # движок Flowseal (скачивается, НЕ коммитится)
├── config.json             # настройки (правится только программно)
├── LICENSE                 # MIT (обёртка)
├── README.md
└── .gitignore
```

---

## Конфигурация (`config.json`)

Файл создаётся и редактируется **программно** (через `src\lib\config.ps1`), руками его редактировать не требуется:

```json
{
  "default_strategy": "service_all",
  "check_url": "https://www.youtube.com/",
  "check_timeout": 5,
  "tray_icon": "assets\\icon.ico",
  "engine_dir": "zapret-engine"
}
```

| Ключ | Назначение |
|---|---|
| `default_strategy` | Стратегия по умолчанию (выбирается при первом запуске панели) |
| `last_profile` | Имя файла стратегии (`*.bat`) — используется для тихого перезапуска `winws.exe` |
| `check_url` | URL для проверки стратегий (по умолчанию — YouTube) |
| `check_timeout` | Таймаут HTTPS-проверки, сек (по умолчанию 5) |
| `tray_icon` | Путь к иконке трея |
| `engine_dir` | Папка движка относительно корня проекта |

### Кодировка файлов

Все `.bat` и `.ps1` сохранены в **UTF-8 без BOM** с окончаниями строк **CRLF**.
В начале каждого `.bat` выполняется `chcp 65001 >nul`, поэтому кириллица в CMD-панели
корректна как в Windows Terminal, так и в классическом `conhost` (шрифт «Растр» или
Consolas/Lucida Console). При редактировании скриптов не переводите их в cp866/cp1251 —
иначе интерфейс снова начнёт выводиться «кракозябрами».

---

## Как работают ключевые механизмы

### Автообновление движка (`src/update.ps1`)
1. Читает локальную версию из `zapret-engine\version.txt`.
2. Через GitHub API получает последний релиз `Flowseal/zapret-discord-youtube`.
3. Если есть новая версия — качает `.zip` в `%TEMP%` (без открытия браузера),
   распаковывает и копирует поверх `zapret-engine\`.
4. **Исключения при копировании:** `list-general-user.txt` (ваши домены), `version.txt`
   и кастомные стратегии с префиксом `zeye-*.bat` — они никогда не затираются.
5. Обновляет `version.txt`.

### Проверка стратегий (`src/check.ps1`)
Для каждого `.bat`-файла стратегии в движке: запуск скрыто → запрос
`curl -o NUL -s -w "%{http_code} %{time_total}" --max-time 5 https://www.youtube.com/` → остановка
`winws.exe`. Вердикт «РАБОТАЕТ»: HTTP-код `200` и время ответа < 5 с.
Результат выводится таблицей: стратегия / код / время / вердикт.
**QUIC/UDP не проверяется — только HTTPS (TCP 443).**

### Мгновенное применение домена (`zeye add`)
`add` пишет домен в `zapret-engine\lists\list-general-user.txt` (дубли отфильтровываются,
значения санитизируются), затем `lib\restart.bat` тихо убивает `winws.exe` и запускает
стратегию заново скрытно (через `WScript.Shell.Run ..., 0, False`).

### Трей (`src/tray.ps1`)
PowerShell + `System.Windows.Forms.NotifyIcon`, иконка `assets\icon.ico`.
Контекстное меню:
- **Открыть панель** — запускает `menu.bat`;
- **Статус** — всплывающая подсказка: запущен ли `winws.exe`, какая стратегия;
- **Перезапустить** — тихий перезапуск движка;
- **Выход** — останавливает `winws.exe` и убирает иконку.

---

## Troubleshooting

| Проблема | Решение |
|---|---|
| `zeye` не находится в CMD | Откройте **новое** окно CMD (PATH обновляется для новых процессов) или выполните `powershell -File src\install-path.ps1` снова |
| Переместили папку проекта | Запустите `src\install-path.ps1` ещё раз — он перепишет `C:\zeye-tools\config-path.txt` |
| Движок не скачался | Проверьте интернет и доступ к `api.github.com` / `objects.githubusercontent.com`; повторите: `powershell -NoProfile -ExecutionPolicy Bypass -File src\update.ps1` |
| Блокируется антивирусом | `winws.exe` выполняет DPI-манипуляции — это известная особенность zapret; добавьте папку в исключения |
| Не запускаются `.ps1` | Все вызовы идут с `-ExecutionPolicy Bypass`; при ручном запуске используйте ту же опцию |
| Вместо кириллицы «кракозябры» (`╨Ч╨░...`) | Скрипты должны оставаться в UTF-8 (без BOM). Проверьте, что редактор не перекодировал их в cp866/cp1251 и не сменил CRLF на LF; `chcp 65001` выполняется автоматически в начале каждого `.bat` |

---

## Лицензия и авторство

- Код обёртки **ZapretEye** — MIT License © [DuckWithKnife404](https://github.com/DuckWithKnife404).
- Движок, стратегии и списки — проект [Flowseal/zapret-discord-youtube](https://github.com/flowseal/zapret-discord-youtube);
  его код в этот репозиторий **не включается** и скачивается с официальных релизов Flowseal.
  Авторство Flowseal указано в шапке интерфейса: *Flowseal and DuckWithKnife404*.
