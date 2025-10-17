# FinteraAPI

API backend for Fintera built with Ruby on Rails.

This README documents how to clone, set up and run the project locally, run tests
and a short overview of available endpoints and developer tips.

## Table of contents

- [Prerequisites](#prerequisites)
- [Clone & install](#clone--install)
- [Environment variables](#environment-variables)
- [Database setup](#database-setup)
- [Running the app](#running-the-app)
- [Background jobs](#background-jobs)
- [Testing](#testing)
- [API endpoints - quick reference](#api-endpoints---quick-reference)
- [Project structure highlights](#project-structure-highlights)
- [Developer tips & conventions](#developer-tips--conventions)

---

## Prerequisites

- Ruby (use the version in `.ruby-version`). Use `rbenv` or `rvm` to manage versions.
- Bundler (`gem install bundler`)
- PostgreSQL (or the DB configured via `config/database.yml`)
- Node + Yarn (only if JS/assets are used in your environment)

## Clone & install

1. Clone the repository:

```bash
git clone git@github.com:your_org/FinteraAPI.git
cd FinteraAPI
```

2. Install gems:

```bash
bundle install
```

3. Copy and edit environment files (project may use `credentials` and `ENV` vars):

```bash
cp .env.example .env
# edit .env to set DB credentials, SECRET_KEY_BASE, SENTRY_DSN, REDIS_URL, etc.
```

4. Create the database and run migrations:

```bash
bin/rails db:create
bin/rails db:migrate
```

5. (Optional) Seed the database:

```bash
bin/rails db:seed
```

Note about migrations: this project prefers using `def up` / `def down` rather than `change` in new migrations.
After creating a migration, append the generated SQL to `db/migration.sql` using the helper:

```bash
bin/rails db:append_migration_sql "[path/to/migration_file.rb]"
```

## Environment variables

Common variables used by the app (add to your `.env` or environment):

- `DATABASE_URL` or DB config in `config/database.yml`
- `SECRET_KEY_BASE` — Rails secret key
- `SENTRY_DSN` — (optional) Sentry DSN for error reporting
- `RESEND_API_KEY` — Resend API key for email delivery
- External API keys (payment providers, etc.) depending on your deployment

## Database setup

This application uses ActiveRecord migrations. Typical commands:

```bash
bin/rails db:migrate
bin/rails db:rollback
```

## Running the app

Start the Rails server locally:

```bash
bin/rails server
```

Then visit `http://localhost:3000` (or call the API endpoints under `/api/v1`).

## Background jobs

Jobs are implemented with ActiveJob and **Solid Queue** (database-backed job queue, no Redis required).

- Configuration: `config/solid_queue.yml` and `config/recurring.yml`
- For comprehensive documentation, see [`docs/solid_queue_guide.md`](docs/solid_queue_guide.md)

### Running Solid Queue Locally

Start the worker process:

```bash
bundle exec rake solid_queue:start
```

Or use a process manager (Overmind/Foreman) with the Procfile:

```bash
overmind start
# or
foreman start
```

### Monitoring Jobs

- **Web UI**: Visit `http://localhost:3000/jobs` for Mission Control Jobs interface
- **Rails Console**: See monitoring examples in `docs/solid_queue_guide.md`

### Running Jobs Manually

Enqueue or execute jobs directly from the Rails console:

```bash
bundle exec rails console
# enqueue (async)
GenerateStatisticsJob.perform_later
# enqueue with arguments
GenerateStatisticsJob.perform_later('last_hour')
# run immediately (synchronous)
GenerateStatisticsJob.perform_now(Date.parse('2025-09-24'))
```

Or using `rails runner`:

```bash
# enqueue async
bundle exec rails runner "GenerateStatisticsJob.perform_later"
# run now
bundle exec rails runner "GenerateStatisticsJob.perform_now(Date.parse('2025-09-24'))"
```

### Common Jobs (examples)

This project includes background jobs under `app/jobs`. Below are commonly-used jobs with example commands.

**Scheduled Jobs (Recurring)**:
- `CheckPaymentsOverdueJob` — Runs daily at 8am, sends overdue payment reminders
- `UpdateOverdueInterestJob` — Runs daily at 12am, updates interest for overdue payments
- `GenerateStatisticsJob` — Runs hourly, generates system statistics
- `GenerateRevenueJob` — Runs daily at 1am, aggregates revenue reports
- `ReleaseUnpaidReservationJob` — Runs daily at 2am, releases unpaid reservations

**Manual Execution Examples**:

```ruby
# Generate statistics
GenerateStatisticsJob.perform_later('last_hour')
GenerateStatisticsJob.perform_now(Date.parse('2025-09-24'))

# Generate revenue
GenerateRevenueJob.perform_later
GenerateRevenueJob.perform_now

# Check overdue payments
CheckPaymentsOverdueJob.perform_later
CheckPaymentsOverdueJob.perform_now

# Update overdue interest
UpdateOverdueInterestJob.perform_later
UpdateOverdueInterestJob.perform_now

# Release unpaid reservations
ReleaseUnpaidReservationJob.perform_later
ReleaseUnpaidReservationJob.perform_now
```

**Notification Jobs**:

```ruby
# Notify admins about payment receipt
NotifyAdminPaymentReceiptJob.perform_later(payment_id)

# Notify about contract submission
NotifyContractSubmissionJob.perform_later(contract_id)

# Notify contract approval
SendContractApprovalNotificationJob.perform_later(contract_id)

# Notify payment approval
SendPaymentApprovalNotificationJob.perform_later(payment_id)

# Notify reservation approval
SendReservationApprovalNotificationJob.perform_later(payment_id)

# Send password reset code
SendResetCodeJob.perform_later(user_id, code)
```

**Tips**:
- `perform_later` enqueues the job for async execution
- `perform_now` executes the job immediately in the current process
- Replace `*_id` and arguments with real values when calling jobs
- For inline execution in test/dev, configure `ActiveJob::Base.queue_adapter = :inline`
- Monitor job execution via Mission Control Jobs UI at `/jobs`

## Testing

Test suite uses RSpec. Run all specs with:

```bash
bundle exec rspec
```

Run a single spec file:

```bash
bundle exec rspec spec/models/statistic_spec.rb -fd
```

Testing conventions in this project:

- Prefer RSpec `expect` syntax.
- Avoid FactoryBot; tests generally use real model builders or mocks/doubles to keep unit tests fast.
- Mock side-effects (mailers, external APIs, heavy callbacks) to keep specs isolated and deterministic.

If you have migrations that generate SQL, the helper `bin/rails db:append_migration_sql` appends SQL statements into `db/migration.sql`.

## API endpoints - quick reference

The API is versioned and organized under `/api/v1`. Below are common endpoints present in the codebase; check `config/routes.rb` for full routing.

- Authentication
	- `POST /api/v1/auth/sign_in` — sign in (returns tokens/cookies)
	- `POST /api/v1/auth` — sign up / registration flows

- Users
	- `GET /api/v1/users/:id` — show user
	- `POST /api/v1/users` — create user
	- `PUT /api/v1/users/:id` — update user

- Projects & Lots
	- `GET /api/v1/projects` — list projects
	- `GET /api/v1/projects/:id` — show project
	- `GET /api/v1/projects/:project_id/lots` — list lots

- Contracts
	- `POST /api/v1/projects/:project_id/lots/:lot_id/contracts` — create contract
	- `POST /api/v1/projects/:project_id/lots/:lot_id/contracts/:id/approve` — approve contract

- Payments
	- `GET /api/v1/payments/:id` — show payment
	- `POST /api/v1/payments/:id/upload_receipt` — upload a receipt (multipart)

- Notifications
	- `GET /api/v1/notifications` — list notifications
	- `POST /api/v1/notifications/:id/mark_as_read` — mark notification read

Examples:

```bash
curl -H "Authorization: Bearer <token>" http://localhost:3000/api/v1/projects
```

For authoritative API documentation, check `spec/integration` and `swagger_helper.rb` — the project uses rswag to generate OpenAPI specs in tests.

## Project structure highlights

- `app/models` — ActiveRecord models (Contract, Payment, Project, Lot, Revenue, Statistic, Notification, User, etc.)
- `app/controllers/api` — API controllers organized by version
- `app/services` — business logic and report generation
- `app/jobs` — background jobs for notifications, revenue/statistics generation, etc.
- `spec/` — RSpec tests (models, services, jobs, mailers, integration)
- `lib/` — helpers and utilities (e.g. `json_web_token.rb`, `number_to_words.rb`)

## Developer tips & conventions

- Strings: prefer double quotes for Ruby strings unless single quotes avoid escaping.
- Tests: write focused unit specs with mocks for external systems; reserve integration specs for end-to-end behavior.
- AASM: many domain models use AASM for state machines — in unit tests either persist objects or stub persistence/guards to avoid flaky transitions.
- Mailers: localize subjects and bodies using Rails I18n; check `config/locales` for available translations.
- Linting & formatting: keep changes minimal and consistent with existing style.

## Useful commands

- Install gems: `bundle install`
- Start server: `bin/rails server`
- Open console: `bin/rails console`
- Run migrations: `bin/rails db:migrate`
- Run tests: `bundle exec rspec`

## Need more?

If you want, I can generate:

- Postman collection or OpenAPI snippet from controller/rswag specs
- A CONTRIBUTING.md with developer workflow and PR checklist
- Dockerfile and `docker-compose.yml` for local development

---

If you'd like the README adapted to a particular deployment environment (Heroku/Docker/Kubernetes) or want me to add a short Quick Start, tell me which one and I'll add it.

