# N. Barbershop

An offline Android app for one barbershop owner. He logs each client, and the app splits every sale between barber and shop, tracks what the shop owes each barber, records expenses, and exports to Excel. It needs no internet and no account; everything is stored on the phone.

Built with Flutter. Version 1.1.0.

## What it does

- **Add a client in three taps:** barber, service, Save. The app works out the barber's share and the shop's share.
- **Barber balances:** earnings minus payouts and cash advances, always computed from the records, never stored.
- **Expenses**, taken out of the shop's share only.
- **Close the day** with a cash drawer check. A closed day needs a PIN to change.
- **Reports** by day, week and month, with an Excel export (one sheet per month).
- **Records:** every entry in one table, with filters, search, and tap-to-edit, void or restore.
- **Past days:** a calendar and a tally grid for copying a forgotten day from a notebook.
- **Backup and restore** to a single file.
- **Guided tutorial** on sample data, light and dark themes.

## Built with

- Flutter and Dart, Android only
- SQLite on the device, with versioned migrations that only ever add to the schema
- Excel export and the Android share sheet
- 183 automated tests covering the money rules, the database and the upgrade from older versions

## How the code is laid out

| Folder | Holds |
| --- | --- |
| `lib/domain/` | Business rules in pure Dart: the split, rounding, balances, reports, the tally. No Flutter imports. |
| `lib/data/` | The SQLite database, migrations, repositories, Excel export, backup. |
| `lib/ui/` | Screens and widgets. All on-screen text is in `lib/ui/strings.dart`. |
| `test/` | Unit tests for the rules and the database, including a migration test against a real version 1 database file. |

Rules the code holds throughout:

- Money is stored as integer centavos.
- A sale keeps the price and percent it was made with; later changes in Settings never alter past sales.
- Entries are voided, never deleted.
- A database migration may only add tables and columns.

## Ownership

N. Barbershop was conceived, specified and designed by **Gian Kyle B. Villanueva** for a working barbershop: the problem, the business rules, the screens and the testing on the shop's phone.

The code is shared here for viewing as part of a portfolio. It is not open source. Copying, modifying, distributing or publishing this app, in whole or in part, is not permitted without written permission.

Copyright © 2026 Gian Kyle B. Villanueva. All rights reserved. See [LICENSE](LICENSE).
