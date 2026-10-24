# Deploying SBC Analytics

Stack: Elixir/Phoenix app, PostgreSQL (accounts, sites, permissions) and ClickHouse
(pageview events), all run by Docker Compose on one Linux server. The app serves HTTPS
itself with an automatic Let's Encrypt certificate, so no separate web server is needed.

Recommended server: Ubuntu 24.04, 2+ CPU, 4 GB RAM, 40 GB disk.

## 1. Before the first start

1. Point a DNS `A` record for `analytics.sbc-creative.com` at the server's IP.
2. Open ports 80 and 443 in any firewall.
3. Copy this repository to the server, e.g. `/opt/sbc-analytics`.

## 2. Start it

```sh
cd /opt/sbc-analytics/deploy
sh setup.sh
```

`setup.sh` installs Docker, writes `.env` with fresh secrets, adds swap and builds and
starts everything. Edit `.env` afterwards for SMTP (needed for password-reset and
report emails) and `SOURCE_CODE_URL`, then run `docker compose up -d` again.

## 3. Create the founding admin, right away

Open https://analytics.sbc-creative.com. A fresh install sends you to a registration
page. **The first account registered becomes the founding admin**, so do this as soon as
the site is up. After that, public registration is closed.

## 4. Everyday use: the admin panel

Account menu → **Admin panel** (or `/admin`):

- **Sites → New site**: add a customer's website, then copy its tracking snippet from the
  site page ("Tracking snippet") into their site.
- **Users → New user**: create a customer login and tick the sites they may see. Send them
  the email address and password through a secure channel.
- **Viewer** = dashboard only. **Editor** = can also change site settings such as goals.
- Tick **Platform admin** for SBC staff: they manage everything and see every site.

Customers only ever see the sites you give them. They cannot add sites or sign up.

## Updating

```sh
cd /opt/sbc-analytics && git pull   # or copy the new code over
cd deploy && docker compose up -d --build
```

Database migrations run automatically on start.

## Backups

All data lives in the Docker volumes `sbc-analytics_postgres-data` and
`sbc-analytics_clickhouse-data`. Back up both, e.g. with a nightly provider snapshot.

## License note

The app is based on AGPL-3.0 code. Keep `LICENSE.md`, and set `SOURCE_CODE_URL` to a
place where users can download this modified source (a public Git repository is enough).
