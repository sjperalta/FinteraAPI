# Solid Queue Guide for FinteraAPI

## Overview

Solid Queue is a database-backed Active Job queue adapter for Ruby on Rails applications. As of October 2025, FinteraAPI has migrated from Sidekiq/Redis to Solid Queue to simplify infrastructure and reduce external dependencies.

### Benefits Over Sidekiq

- **No Redis dependency**: Uses your existing PostgreSQL database
- **Simpler infrastructure**: One less service to manage and monitor
- **Built into Rails 8**: First-class support from the Rails core team
- **Transactional job enqueueing**: Jobs are part of your database transactions
- **Mission Control Jobs UI**: Modern, beautiful web interface for monitoring
- **Lower operational costs**: No need for separate Redis hosting

## Architecture

### Core Components

1. **Dispatchers**: Schedule and distribute jobs to workers
2. **Workers**: Execute jobs from specific queues
3. **Recurring Tasks**: Cron-like scheduled jobs (replaces Sidekiq Scheduler)
4. **Database Tables**: All job state stored in PostgreSQL

### Queue Priority

FinteraAPI uses three queue priorities:

- **high**: Critical, time-sensitive jobs (3-5 workers, fastest polling)
- **default**: Standard background jobs (5-10 workers, normal polling)
- **mailers**: Email sending jobs (2-3 workers, slower polling)

## Configuration

### Main Configuration (`config/solid_queue.yml`)

The main configuration defines workers and dispatchers for each environment:

```yaml
production:
  dispatchers:
    - polling_interval: 1  # Check for new jobs every second
      batch_size: 500
      recurring_schedule_file: config/recurring.yml
  
  workers:
    - queues: high
      threads: 5
      processes: 3
      polling_interval: 0.1  # Fast polling for urgent jobs
    
    - queues: default
      threads: 10
      processes: 5
      polling_interval: 1
    
    - queues: mailers
      threads: 3
      processes: 2
      polling_interval: 2
```

**Key Settings:**
- `threads`: Concurrent jobs per process
- `processes`: Number of worker processes
- `polling_interval`: How often to check for new jobs (seconds)
- `batch_size`: Jobs claimed per polling cycle

### Recurring Tasks (`config/recurring.yml`)

Scheduled jobs that run at specified intervals:

```yaml
production:
  send_overdue_payment_mail:
    class: CheckPaymentsOverdueJob
    queue: default
    schedule: every day at 8am
    description: "Send overdue payment reminders"
  
  update_overdue_interest:
    class: UpdateOverdueInterestJob
    schedule: every day at 12am
    
  generate_statistics_hourly:
    class: GenerateStatisticsJob
    args: ["last_hour"]
    schedule: every hour
  
  generate_revenue_daily:
    class: GenerateRevenueJob
    schedule: every day at 1am
  
  release_unpaid_reservation:
    class: ReleaseUnpaidReservationJob
    schedule: every day at 2am
```

**Schedule Formats:**
- `every hour`
- `every day at 8am`
- `every monday at 9am`
- Cron syntax: `"0 */4 * * *"` (every 4 hours)

### Application Configuration

**config/application.rb:**
```ruby
config.active_job.queue_adapter = :solid_queue
config.solid_queue.connects_to = { database: { writing: :primary } }
```

**config/environments/production.rb:**
```ruby
config.active_job.queue_adapter = :solid_queue
config.active_job.queue_name_prefix = 'FinteraAPI_production'
```

## Running Solid Queue

### Development

Start the Solid Queue worker in a separate terminal:

```bash
bundle exec rake solid_queue:start
```

Or use a process manager like Overmind/Foreman with the Procfile:

```bash
overmind start
# or
foreman start
```

### Production (Railway)

The `Procfile` defines the worker process:

```
web: bundle exec puma -C config/puma.rb
worker: bundle exec rake solid_queue:start
```

Railway will automatically start both processes.

### Systemd Service (VPS/Dedicated Server)

Create `/etc/systemd/system/fintera-worker.service`:

```ini
[Unit]
Description=FinteraAPI Solid Queue Worker
After=network.target

[Service]
Type=simple
User=deploy
WorkingDirectory=/var/www/fintera-api
Environment="RAILS_ENV=production"
ExecStart=/usr/local/bin/bundle exec rake solid_queue:start
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

Enable and start:
```bash
sudo systemctl enable fintera-worker
sudo systemctl start fintera-worker
sudo systemctl status fintera-worker
```

## Monitoring

### Mission Control Jobs UI

Access the web interface at: **http://localhost:3000/jobs** (development) or **https://your-domain.com/jobs** (production)

**Features:**
- View all jobs (queued, in-progress, finished, failed)
- Filter by queue, job class, status
- Retry failed jobs
- View job arguments and error traces
- Monitor recurring tasks
- Pause/resume queues

**Authentication**: You should add authentication to protect this endpoint in production:

```ruby
# config/routes.rb
authenticate :user, ->(user) { user.admin? } do
  mount MissionControl::Jobs::Engine, at: '/jobs'
end
```

### Rails Console Monitoring

```ruby
# Job counts
SolidQueue::Job.count
SolidQueue::Job.where(finished_at: nil).count  # Pending

# Failed jobs
SolidQueue::FailedExecution.includes(:job).last(10)

# Recent jobs
SolidQueue::Job.order(created_at: :desc).limit(10)

# Queue statistics
SolidQueue::Job.group(:queue_name).count

# Recurring tasks
SolidQueue::RecurringTask.all

# Active workers
SolidQueue::Process.where(kind: 'Worker').where('last_heartbeat_at > ?', 1.minute.ago)
```

### Database Queries

```sql
-- Jobs waiting to be processed
SELECT queue_name, COUNT(*) 
FROM solid_queue_jobs 
WHERE finished_at IS NULL 
GROUP BY queue_name;

-- Failed jobs in last 24 hours
SELECT j.class_name, fe.error, fe.created_at
FROM solid_queue_failed_executions fe
JOIN solid_queue_jobs j ON fe.job_id = j.id
WHERE fe.created_at > NOW() - INTERVAL '24 hours'
ORDER BY fe.created_at DESC;

-- Job processing time
SELECT 
  class_name,
  AVG(EXTRACT(EPOCH FROM (finished_at - created_at))) as avg_duration_seconds
FROM solid_queue_jobs
WHERE finished_at IS NOT NULL
GROUP BY class_name;
```

## Common Jobs in FinteraAPI

### Scheduled Jobs (Recurring)

| Job | Schedule | Purpose |
|-----|----------|---------|
| `CheckPaymentsOverdueJob` | Daily 8am | Send overdue payment reminders |
| `UpdateOverdueInterestJob` | Daily 12am | Update interest on overdue payments |
| `GenerateStatisticsJob` | Hourly | Generate system statistics |
| `GenerateRevenueJob` | Daily 1am | Generate revenue reports |
| `ReleaseUnpaidReservationJob` | Daily 2am | Release unpaid lot reservations |
| `UpdateCreditScoresJob` | On-demand | Recalculate user credit scores |

### Manual Job Execution

```ruby
# Enqueue a job immediately
CheckPaymentsOverdueJob.perform_later

# Enqueue with arguments
GenerateStatisticsJob.perform_later('last_hour')

# Schedule for later
UpdateCreditScoresJob.set(wait: 5.minutes).perform_later(user_ids: [1, 2, 3])

# Set custom queue and priority
NotifyAdminPaymentReceiptJob.set(queue: :high, priority: 10).perform_later(payment_id: 123)
```

## Database Tables

Solid Queue creates these tables in your database:

- `solid_queue_jobs`: All job records
- `solid_queue_scheduled_executions`: Jobs scheduled for future execution
- `solid_queue_ready_executions`: Jobs ready to be claimed by workers
- `solid_queue_claimed_executions`: Jobs currently being processed
- `solid_queue_failed_executions`: Failed job records with error details
- `solid_queue_blocked_executions`: Jobs blocked by concurrency limits
- `solid_queue_recurring_executions`: Recurring task execution tracking
- `solid_queue_recurring_tasks`: Recurring task definitions
- `solid_queue_processes`: Active worker and dispatcher processes
- `solid_queue_pauses`: Paused queue records
- `solid_queue_semaphores`: Concurrency control primitives

## Troubleshooting

### Jobs Not Processing

**Symptom**: Jobs remain in `solid_queue_jobs` with `finished_at` NULL

**Checklist**:
1. Is the worker running? `ps aux | grep solid_queue`
2. Check worker logs: `tail -f log/production.log`
3. Verify database connection: `rails dbconsole`
4. Check queue is not paused: `SolidQueue::Pause.all`

### High Database Load

**Symptom**: Increased database CPU/IO from polling

**Solutions**:
1. Increase `polling_interval` (less frequent polling)
2. Reduce `batch_size` (fewer jobs per query)
3. Reduce number of worker processes
4. Add database indexes (should be auto-created by migration)

### Failed Jobs

**View failures**:
```ruby
SolidQueue::FailedExecution.includes(:job).last(20).each do |failed|
  puts "Job: #{failed.job.class_name}"
  puts "Error: #{failed.error}"
  puts "---"
end
```

**Retry all failed jobs**:
```ruby
SolidQueue::FailedExecution.find_each do |failed|
  failed.job.class_name.constantize.perform_later(*failed.job.arguments)
end
```

### Recurring Tasks Not Running

**Check task definition**:
```ruby
SolidQueue::RecurringTask.find_by(key: 'send_overdue_payment_mail')
```

**Verify dispatcher is running**:
```ruby
SolidQueue::Process.where(kind: 'Dispatcher').where('last_heartbeat_at > ?', 1.minute.ago)
```

**Manually trigger a recurring task**:
```ruby
task = SolidQueue::RecurringTask.find_by(key: 'send_overdue_payment_mail')
task.enqueue
```

## Performance Tuning

### Worker Configuration

**High throughput** (many small jobs):
```yaml
threads: 20
processes: 5
polling_interval: 0.5
```

**Memory constrained**:
```yaml
threads: 5
processes: 2
polling_interval: 2
```

**CPU intensive jobs**:
```yaml
threads: 2
processes: 10
polling_interval: 1
```

### Database Optimization

1. **Regular maintenance**:
```ruby
# Add to recurring tasks
clear_finished_jobs:
  command: "SolidQueue::Job.clear_finished_in_batches"
  schedule: every hour
```

2. **Vacuum tables periodically**:
```sql
VACUUM ANALYZE solid_queue_jobs;
VACUUM ANALYZE solid_queue_ready_executions;
```

3. **Monitor table sizes**:
```sql
SELECT 
  schemaname,
  tablename,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE tablename LIKE 'solid_queue%'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

## Migration Notes

### What Changed from Sidekiq

**Removed**:
- Redis dependency and configuration
- `config/initializers/sidekiq.rb`
- `config/sidekiq.yml`
- `config/schedule.yml` (replaced by `config/recurring.yml`)
- Sidekiq Web UI (replaced by Mission Control Jobs)
- `REDIS_URL`, `SIDEKIQ_USERNAME`, `SIDEKIQ_PASSWORD` env vars

**Added**:
- `config/solid_queue.yml` - worker/dispatcher configuration
- `config/recurring.yml` - scheduled jobs
- Mission Control Jobs UI at `/jobs`
- Database tables for job storage

**Unchanged**:
- Job classes (all `ApplicationJob` subclasses work as-is)
- `perform_later` and `perform_now` methods
- Job arguments and serialization
- ActiveJob API

### Backward Compatibility

No changes required to existing job classes. ActiveJob provides a stable interface that works with any adapter.

## Best Practices

1. **Use appropriate queues**: Route urgent jobs to `high` queue
2. **Set job priorities**: Use `priority` option for fine-grained control
3. **Clean up finished jobs**: Run cleanup task regularly
4. **Monitor failed jobs**: Set up alerts for failed job rate
5. **Use transactions**: Jobs enqueued in transactions only persist if transaction commits
6. **Idempotent jobs**: Design jobs to be safely retried
7. **Argument serialization**: Only pass serializable arguments (IDs, not ActiveRecord objects)
8. **Timeout protection**: Use `timeout` gem for long-running jobs
9. **Resource limits**: Don't spawn unlimited workers - respect database connection limits
10. **Test recurring tasks**: Verify schedules in test environment

## Additional Resources

- [Solid Queue GitHub](https://github.com/basecamp/solid_queue)
- [Mission Control Jobs](https://github.com/basecamp/mission_control-jobs)
- [Active Job Guide](https://guides.rubyonrails.org/active_job_basics.html)
- [Rails 8 Release Notes](https://edgeguides.rubyonrails.org/8_0_release_notes.html)

## Support

For issues or questions:
- Check logs: `tail -f log/production.log`
- Rails console debugging: `rails console -e production`
- Database inspection: `rails dbconsole`
- Contact dev team: #engineering Slack channel
