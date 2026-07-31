# GigShield — Data & Database Specification (Supabase / Postgres)

---

## 1. Where every piece of data comes from

| Data | Source | Justification |
|---|---|---|
| Job entries | Live user input (manual form or OCR-confirmed) | Real data entered during the demo itself |
| Fair-rate benchmarks | **Hand-authored reference table** you seed once | The brief explicitly states "a small reference dataset is enough" — this is not claimed as an official/scraped source, and you should say so plainly if asked |
| Chatbot responses | Live Gemma 3 4B call, grounded with the worker's real recent job rows | Never hardcoded |
| Weekly insight text | Live Gemma 3 4B call, grounded with real aggregated query results | Never hardcoded |
| User identity | Supabase Anonymous Auth session (or a simple locally-generated UUID stored in device storage if skipping auth entirely) | No real personal data collection needed for a hackathon demo |

---

## 2. Entity Relationship Overview

```
 users (Supabase auth.users, built-in)
    │
    │ 1-to-many
    ▼
 jobs ───────────many-to-one──────────► benchmarks
 (each job references a platform,
  benchmarks are looked up by platform
  at insert time, not foreign-keyed —
  see §3.2 rationale)
```

---

## 3. Table Definitions

### 3.1 `benchmarks`

Seed/reference data. Not user-editable through the app UI. Small enough to hardcode entirely, but stored as a table (rather than a constant in code) so both the FastAPI backend and any Postgres function can read from the same source of truth.

```sql
create table benchmarks (
  platform        text primary key,
  rate_per_km     numeric(6,2) not null,
  rate_per_min    numeric(6,2) not null
);

insert into benchmarks (platform, rate_per_km, rate_per_min) values
  ('uber',   12.00, 1.50),
  ('rapido',  9.00, 1.20),
  ('zomato',  8.00, 1.00),
  ('swiggy',  8.00, 1.00),
  ('other',  10.00, 1.30);
```

**Note on realism for your pitch**: be ready to explain these are reasonable, self-authored reference rates for demo purposes — not claimed as official platform data — exactly as the brief's own bonus feature ("community fairness benchmark... simulate crowdsourced fare data") implicitly acknowledges is expected at this stage.

### 3.2 `jobs`

```sql
create table jobs (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null default auth.uid(),
  platform        text not null references benchmarks(platform),
  fare            numeric(8,2) not null check (fare >= 0),
  distance_km     numeric(6,2) not null check (distance_km >= 0),
  duration_min    numeric(6,2) not null check (duration_min >= 0),
  expected_fare   numeric(8,2) not null,
  is_underpaid    boolean not null,
  source          text not null check (source in ('manual', 'ocr')),
  job_timestamp   timestamptz not null default now(),
  created_at      timestamptz not null default now()
);

create index idx_jobs_user_timestamp on jobs (user_id, job_timestamp desc);
```

**Design notes**:
- `platform` references `benchmarks(platform)` as a real foreign key — this is exactly the kind of relational integrity that would be awkward in Firestore and is trivial in Postgres, reinforcing the earlier stack choice.
- `expected_fare` and `is_underpaid` are **computed at insert time** and stored (not computed on every read) — this keeps dashboard queries fast and simple, and keeps the historical record honest even if you ever change the benchmark table later (a job's fairness result reflects the benchmark that existed when it was logged, not retroactively).
- `job_timestamp` (when the job happened) is separate from `created_at` (when the row was inserted) — matters if you ever backfill a job logged a bit late, and is good practice to model correctly even in a hackathon build.

### 3.3 Computing `expected_fare` / `is_underpaid` — two valid approaches, pick one

**Approach A — Postgres function + trigger (recommended if using Supabase directly from Flutter for inserts)**:
```sql
create or replace function compute_fairness()
returns trigger as $$
declare
  b record;
begin
  select rate_per_km, rate_per_min into b
  from benchmarks where platform = new.platform;

  if not found then
    select rate_per_km, rate_per_min into b
    from benchmarks where platform = 'other';
  end if;

  new.expected_fare := round((b.rate_per_km * new.distance_km) + (b.rate_per_min * new.duration_min), 2);
  new.is_underpaid := new.fare < (new.expected_fare * 0.85);
  return new;
end;
$$ language plpgsql;

create trigger trg_compute_fairness
before insert on jobs
for each row execute function compute_fairness();
```
This means Flutter can insert a job directly into Supabase with just `platform, fare, distance_km, duration_min, source` and the fairness result is computed server-side automatically, correctly, and consistently — no FastAPI round trip needed for this at all. **This is the recommended approach** given the 8-hour constraint, since it removes an entire endpoint from your build list.

**Approach B — FastAPI computes it, then inserts**: only use this if your team is more comfortable writing Python than SQL under time pressure. Functionally equivalent, just moves the logic to `fairness.py` in the backend (see TRD §3.2) and requires Flutter to call your FastAPI `/jobs` endpoint instead of Supabase directly for job creation specifically (OCR scan and read-only queries can still go straight to Supabase either way).

### 3.4 Dashboard aggregation — as a Postgres view

```sql
create or replace view weekly_dashboard as
select
  user_id,
  sum(fare) as total_earnings,
  round(sum(duration_min) / 60.0, 1) as total_hours,
  count(*) filter (where is_underpaid) as flagged_count
from jobs
where job_timestamp >= now() - interval '7 days'
group by user_id;
```
Flutter (or FastAPI) can simply `select * from weekly_dashboard where user_id = ...` instead of hand-aggregating on every dashboard load. For the daily-earnings chart and platform breakdown specifically, two more small queries (grouped by day / grouped by platform, same 7-day window) are simplest as direct queries rather than additional views, since they're each only needed in one place.

### 3.5 `chat_messages` (optional — only if persisting chat history matters to you)

```sql
create table chat_messages (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid(),
  role        text not null check (role in ('user', 'assistant')),
  content     text not null,
  created_at  timestamptz not null default now()
);
```
Skip this table entirely if you're comfortable with chat history resetting each session — it's not required by the brief and isn't worth the extra build time unless everything else is already done early.

---

## 4. Row-Level Security (RLS) — Supabase specifics

Supabase enables RLS by default on new tables, which will silently block all reads/writes until policies exist. For a hackathon demo, the simplest correct approach:

```sql
alter table jobs enable row level security;

create policy "Users can manage their own jobs"
on jobs for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

alter table benchmarks enable row level security;
create policy "Anyone can read benchmarks"
on benchmarks for select
using (true);
```
This is a real, correct security model (not a hack) and costs almost nothing to set up — worth doing properly rather than disabling RLS entirely, both because it's not much extra work and because "we implemented proper row-level security" is a small but genuine technical-execution point in your favor.

---

## 5. Direct SQLite fallback mapping (if you pivot away from Supabase on the day)

| Supabase/Postgres | SQLite equivalent |
|---|---|
| `uuid primary key default gen_random_uuid()` | `TEXT PRIMARY KEY` (generate UUIDs in Python via `uuid.uuid4()`) |
| `numeric(8,2)` | `REAL` |
| `timestamptz` | `TEXT` (ISO 8601 string) or `DATETIME` |
| Trigger-computed fairness | Compute in `fairness.py` before insert (Approach B above becomes mandatory, since SQLite triggers are far more awkward to write) |
| RLS policies | Not applicable — single local file, no concept of per-request auth; scope everything by a locally-stored `user_id` value in application code instead |
| Dashboard view | A plain SQL `SELECT` with `GROUP BY`, run fresh each time — no persistent view object needed for a local single-file DB at this scale |

---

## 6. Seed/Test Data for Rehearsal

Before your final demo, seed a handful of realistic rows so the dashboard/insight don't look sparse on a fresh account when you're rehearsing timing:

```sql
insert into jobs (user_id, platform, fare, distance_km, duration_min, source, job_timestamp) values
  (auth.uid(), 'zomato', 60.00, 6.0, 25, 'manual', now() - interval '1 day'),
  (auth.uid(), 'zomato', 95.00, 5.5, 20, 'manual', now() - interval '2 days'),
  (auth.uid(), 'uber',   180.00, 10.0, 30, 'manual', now() - interval '3 days'),
  (auth.uid(), 'rapido',  70.00, 6.5, 22, 'manual', now() - interval '4 days');
```
(`expected_fare`/`is_underpaid` will populate automatically if you used the trigger approach in §3.3.) Use this only for rehearsal timing/screenshots — your **actual recorded demo video** should show jobs being logged live, per the brief's expected flow, not a pre-seeded dashboard appearing out of nowhere.
