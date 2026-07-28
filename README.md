# Todoist

A fast native Todoist client for KDE Plasma, built with C++23, Qt 6,
Kirigami, KDE Wallet, and KDE notifications.

## Features

- Today (including overdue tasks), Inbox, projects, and sections
- Create, edit, complete, and delete tasks
- Natural-language due dates and task priorities
- Create projects and sections
- Automatic five-minute background refresh
- Local desktop reminders for tasks with a due time
- API token stored in KDE Wallet
- Plasma styling, system colours, and background blur

## Build and run

```sh
cmake --preset dev
cmake --build --preset dev
./build/bin/todoistclient
```

To connect, copy the personal API token from **Todoist Settings → Integrations
→ Developer**. The app stores it in KDE Wallet and reconnects on future
launches.

## Install locally

```sh
cmake --install build --prefix "$HOME/.local"
```

The app then appears as **Todoist** in Plasma's application launcher.
