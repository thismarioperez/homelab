# postgresql-theforce Setup Guide

A general-purpose PostgreSQL server running on a Synology NAS via Container Manager, independent of the Proxmox cluster it supports. Used as the state backend for OpenTofu and available for other homelab services (n8n, Atuin, etc.). Includes pgAdmin for web-based database management.

## Why the NAS?

The state backend should not live on infrastructure managed by the tool that depends on it. The Synology NAS is always on, independent of the Proxmox cluster, and already has a backup routine — making it the right home for OpenTofu state and other persistent databases.

## Prerequisites

- Synology NAS running DSM 7+ with Container Manager installed
- SSH access to the NAS
- `psql` client on your Mac and/or PC (`brew install postgresql` on macOS, or equivalent)

---

## 1. Create the project directories

Open **File Station**, navigate to the `docker` shared folder, and create two folders:

- `postgres-theforce/postgres` — Postgres data
- `postgres-theforce/pgadmin` — pgAdmin data

## 2. Create the project in Container Manager

Open **Container Manager → Project → Create**.

- **Name:** `postgres-theforce`
- **Path:** `/docker/postgres-theforce`
- **Compose file:**

```yaml
services:
  postgres:
    container_name: postgres
    image: postgres
    mem_limit: 256m
    cpu_shares: 768
    healthcheck:
      test: ["CMD", "pg_isready", "-q", "-d", "postgres", "-U", "root"]
    environment:
      POSTGRES_USER: root
      POSTGRES_PASSWORD: <temporary-admin-password>
      POSTGRES_DB: postgres
    volumes:
      - /volume1/docker/postgres-theforce/postgres:/var/lib/postgresql:rw
    ports:
      - 15432:5432
    restart: on-failure:5

  pgadmin:
    container_name: pgAdmin
    image: dpage/pgadmin4:latest
    user: 0:0
    mem_limit: 256m
    cpu_shares: 768
    healthcheck:
      test: wget --no-verbose --tries=1 --spider http://localhost:5050
    environment:
      PGADMIN_DEFAULT_EMAIL: <your-email>
      PGADMIN_DEFAULT_PASSWORD: <temporary-pgadmin-password>
      PGADMIN_LISTEN_PORT: 5050
    ports:
      - 15050:5050
    volumes:
      - /volume1/docker/postgres-theforce/pgadmin:/var/lib/pgadmin:rw
    restart: on-failure:5
```

> **Port 15432** is used for Postgres because Synology DSM's built-in PostgreSQL already occupies 5432. **Port 15050** is used for pgAdmin.

Click through the summary and apply. Wait for both containers to show green/running in the **Container** tab.

## 3. Access pgAdmin

Open `http://<synology-ip>:15050` in your browser and log in with the email and password from the compose file.

Change the default password.

To connect pgAdmin to the Postgres instance:

1. **Add New Server**
2. **General tab** — Name: `postgres-theforce`
3. **Connection tab:**
   - Host: `db` (the Docker service name, since both containers are on the same project network)
   - Port: `5432` (the internal container port, not 15432)
   - Username: `root`
   - Password: the `POSTGRES_PASSWORD` from the compose file
4. Save


## 4. Change the admin password

**Using pgAdmin**
1. Expand your server name in the left-hand Object Explorer tree.
2. Expand the Login/Group Roles folder.
3. Right-click on the `root` user role and select Properties.
4. Navigate to the Definition tab in the window that appears.
5. Type your new password into the Password field.
6. Click the Save button at the bottom to apply changes.

**Using psql**
Connect from either machine and replace the temporary password so it's no longer visible in the Container Manager GUI:
 
```bash
psql -h <synology-ip> -p 15432 -U root -d postgres
 
ALTER ROLE root WITH PASSWORD '<real-admin-password>';
\q
```

The `POSTGRES_PASSWORD` environment variable is only used during initial database creation, so changing it via SQL is permanent.


## 5. Create databases and scoped users

Reconnect with the new password and set up each service. One Postgres server, multiple databases, each with its own isolated user.

```bash
psql -h <synology-ip> -p 15432 -U root -d postgres
```

```sql
-- OpenTofu state backend
CREATE DATABASE tofu_state;
CREATE USER tofu WITH PASSWORD '<tofu-password>';
GRANT ALL PRIVILEGES ON DATABASE tofu_state TO tofu;
\c tofu_state
CREATE SCHEMA core AUTHORIZATION tofu;
CREATE SCHEMA testbed AUTHORIZATION tofu;
-- Postgres 15+ revokes CREATE on the public schema from non-owner roles by
-- default; the pg backend needs it during `tofu init`, so grant it back.
GRANT CREATE ON SCHEMA public TO tofu;

-- Add more services as needed — same pattern:
-- CREATE DATABASE <service>;
-- CREATE USER <service_user> WITH PASSWORD '<password>';
-- GRANT ALL PRIVILEGES ON DATABASE <service> TO <service_user>;

\q
```

Each user can only access its own database. A compromised service credential can't touch other databases.

## 6. Configure the firewall

In DSM, go to **Control Panel → Firewall** and add rules:

- **Allow** ports `15432` and `15050` from your local subnet (e.g., `192.168.1.0/24`) and VPN subnet
- **Deny** everything else on those ports

This ensures the database and pgAdmin are reachable from your Mac, PC, and over VPN, but not from the internet.

## 7. Verify connectivity from both machines

```bash
# From your Mac
psql -h <synology-ip> -p 15432 -U tofu -d tofu_state -c "SELECT current_schema();"

# From your PC
psql -h <synology-ip> -p 15432 -U tofu -d tofu_state -c "SELECT current_schema();"
```

Both should connect and return a result without errors.


---

## Adding new services

To add another service to this Postgres instance, use either `psql` or pgAdmin:

```bash
psql -h <synology-ip> -p 15432 -U root -d postgres
```

```sql
CREATE DATABASE <service_name>;
CREATE USER <service_user> WITH PASSWORD '<password>';
GRANT ALL PRIVILEGES ON DATABASE <service_name> TO <service_user>;
\q
```

Point the service's database config at `<synology-ip>:15432` with the dedicated credentials.