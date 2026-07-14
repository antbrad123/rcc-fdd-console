# RCC FDD Console — KCE

Live fault-detection console for the King's Cross Estate FDD programme.

**Live app:** `https://<your-username>.github.io/rcc-fdd-console/`

## How it fits together

| Layer | What it holds | Why |
|---|---|---|
| **GitHub Pages** | The app (`index.html`) | Free static hosting; version history on every change |
| **Supabase** | Live per-building FDD status | Single source of truth; edits save natively from the app |
| **`index.html` (baked)** | Fault library + KODE build playbook | Chains and build steps don't exist in the spreadsheets — they ship with the code |
| **`/docs`** | Register + Fault Tables `.xlsx` | Controlled documents for issue/reporting. Snapshots, not the master |

## Security model

The Supabase **anon key is publishable** — it's designed to sit in public client code.
What actually protects the data is **Row Level Security**:

- **Anyone** with the link can *read* (so you can share a live view with stakeholders)
- **Only a signed-in user** can *write*

That's enforced by Postgres, not by the browser, so it can't be bypassed by editing the page.
Never put the `service_role` key in this repo — that one bypasses RLS.

## Setup

1. Run `supabase_setup.sql` in Supabase → SQL Editor
2. Import `seed_fdd_status.csv` into the `fdd_status` table
3. Create your user: Supabase → Authentication → Users → Add user
4. Paste your project URL + anon key into the `SB_CONFIG` block at the top of `index.html`
5. Commit and push — GitHub Pages deploys automatically

## Everyday use

Open the app → **Sign in to edit** → change statuses on the Register page.
Every change saves to Supabase automatically. Everything is audited in `fdd_status_log`.

To issue a spreadsheet snapshot: Register → **Export snapshot .xlsx**.
