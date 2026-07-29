# Todoist Today plasmoid

This Plasma 6 widget displays the Today list from the Todoist desktop
application, including overdue tasks.

The application writes an owner-readable local cache after every successful
sync. The widget refreshes that cache every 30 seconds without storing or
handling the Todoist API token.

Install it for the current user:

```sh
kpackagetool6 --type Plasma/Applet --install org.suryask.todoisttoday
```
