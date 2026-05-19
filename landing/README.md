# Job Site Records — landing page (`landing/`)

Source for **jobsiterecords.com**: a one-page PHP + SQLite early-access waitlist.

This is a **validation tool**, not the mobile app. The goal is to learn whether
contractors care about the problem enough to give us an email, a sentence
about their current pain, and whether they are open to giving product feedback (no call required).

## What's in here

| File | What it does |
| --- | --- |
| `index.php` | Landing page + waitlist form. Validates input, stores rows in SQLite, blocks duplicates, has a honeypot field for bots. |
| `export.php` | Password-protected CSV export of the subscribers table. |
| `sitemap.xml` | Static XML sitemap for Google (upload to `htdocs`). Regenerate after adding pages. |
| `sitemap.php` | Same sitemap, generated dynamically (backup URL). |
| `generate-sitemap.php` | CLI: `php landing/generate-sitemap.php` → refreshes `sitemap.xml`. |
| `.htaccess` | Apache hardening — blocks direct download of `.sqlite`, dotfiles, etc., and sets default security headers. |

By default the SQLite file lives at `../private/subscribers.sqlite` (outside the
web root). On shared hosting where that folder isn't writable, the app falls
back to `landing/.data/subscribers.sqlite` (blocked from HTTP by `.htaccess`).

## Requirements

- PHP 8.0+ with the `pdo_sqlite` extension (it's bundled with PHP by default).
- Apache (the `.htaccess` rules are Apache-only) — or any other web server, in
  which case you'll need to translate the rules yourself.

## Local test run

From the repo root:

```bash
mkdir -p private
JOBSITERECORDS_DB="$PWD/private/subscribers.sqlite" \
  php -S 127.0.0.1:8080 -t landing
```

Then open <http://127.0.0.1:8080> and submit the form. The SQLite file appears
at `private/subscribers.sqlite`.

## Sitemap

Submit **`https://jobsiterecords.com/sitemap.xml`** in Google Search Console.

| URL | How it is produced |
| --- | --- |
| `/sitemap.php` | Built on the server on every request (always up to date). |
| `/sitemap.xml` | Static file. Committed in git and/or **written on the server** when something hits `sitemap.php` and `htdocs` is writable. |

1984 ignores `.htaccess` rewrites for `sitemap.xml`, so you need a real file on disk.
After deploy, open **`https://jobsiterecords.com/sitemap.php` once** in a browser — that
refreshes `sitemap.xml` on the host if PHP can write to `htdocs`.

When you add pages locally, run `php landing/generate-sitemap.php` before upload, or hit
`sitemap.php` on the server again after uploading new PHP files.

## Deploying

Two reasonable layouts:

### Recommended — DB outside the document root

```
yourserver:/var/www/jobsiterecords/
├── private/                 # NOT served over HTTP
│   └── subscribers.sqlite   # created automatically on first POST
└── landing/                 # set this as the Apache DocumentRoot
    ├── index.php
    ├── export.php
    └── .htaccess
```

Point the Apache `DocumentRoot` (or nginx `root`) at `.../jobsiterecords/landing`.
Nothing else is needed — `index.php` will create `../private/` and the
SQLite file on the first submission, as long as the web user can write to
the parent directory.

### Cheap shared-hosting fallback — DB inside the docroot

If your host only gives you a single `public_html` and you can't put anything
above it, set the env var to keep the DB at least in a non-obvious path:

```apache
SetEnv JOBSITERECORDS_DB "/home/youruser/public_html/.data/subscribers.sqlite"
```

The `.htaccess` already blocks `.sqlite` downloads, and dotfile directories
like `.data/` are blocked too — but this is still strictly worse than putting
the DB outside the docroot. Use it only if you have to.

## Exporting subscribers

1. Set the password as an environment variable in your web server config
   (Apache `SetEnv`, nginx `fastcgi_param`, or your hosting panel). **Do not
   hard-code it into a file.**

   ```apache
   SetEnv JOBSITERECORDS_EXPORT_PASSWORD "some-long-random-string"
   ```

2. Visit:

   ```
   https://jobsiterecords.com/export.php?password=some-long-random-string
   ```

   You'll get a `jobsiterecords-subscribers-YYYYMMDD-HHMMSS.csv` download with all
   subscribers (UTF-8, Excel-friendly BOM).

3. Rotate the password after each export, or — easier — delete `export.php`
   from the server once you've grabbed the CSV and re-upload it next time
   you need it.

If the env var is missing or still set to `change-me`, `export.php` refuses
to run.

## Environment variables

| Variable | Purpose | Default |
| --- | --- | --- |
| `JOBSITERECORDS_DB` | Absolute path to the SQLite file. | `../private/…` if writable, else `landing/.data/…` |
| `JOBSITERECORDS_EXPORT_PASSWORD` | Password required to download the CSV. | _(unset — export is disabled)_ |

## The schema

```sql
CREATE TABLE subscribers (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    email        TEXT    NOT NULL UNIQUE,
    name         TEXT,
    company      TEXT,
    role         TEXT,
    pain_point   TEXT,
    open_to_call INTEGER NOT NULL DEFAULT 0,
    consent      INTEGER NOT NULL DEFAULT 0,
    created_at   TEXT    NOT NULL,   -- ISO-8601 UTC
    ip_address   TEXT,
    user_agent   TEXT
);
```

`pain_point` and `open_to_call` are the most useful columns — they're what
turn a passive email list into a list of validation interviews.

## What this page deliberately doesn't do

- No analytics / tracking pixels.
- No marketing-automation integration (Mailchimp, Brevo, etc.). When you
  outgrow SQLite, export the CSV and import it into whatever tool you pick.
- No login, no dashboard, no admin UI. If you need to look at the rows,
  open the SQLite file with `sqlite3` or DB Browser for SQLite.
- No "selected clients are beta testing" copy. The page is honest about
  where the product is — preparing for launch, validating with real users.
