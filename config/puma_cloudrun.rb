# Puma configuration optimized for Google Cloud Run

# The environment Puma will run in
environment ENV.fetch("RAILS_ENV") { "production" }

# Port to listen on
port ENV.fetch("PORT") { 8080 }

# Number of worker processes
# Cloud Run containers have limited CPU, so we use threads instead of workers
workers 0

# Number of threads per worker
# Cloud Run containers typically have 1-2 vCPUs, so 5 threads is optimal
threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
threads threads_count, threads_count

# Preload the application for better memory usage
preload_app!

# Allow puma to be restarted by `rails restart` command
plugin :tmp_restart

# Bind to all interfaces for Cloud Run
bind "tcp://0.0.0.0:#{ENV.fetch('PORT') { 8080 }}"

# Logging
stdout_redirect '/dev/stdout', '/dev/stderr', true

# Graceful shutdown for Cloud Run
on_worker_boot do
  ActiveRecord::Base.establish_connection if defined?(ActiveRecord)
end

# Optimize for Cloud Run's request handling
before_fork do
  ActiveRecord::Base.connection_pool.disconnect! if defined?(ActiveRecord)
end

# Cloud Run timeout handling
worker_timeout 30
worker_shutdown_timeout 8

# Memory and performance optimizations for Cloud Run
nakayoshi_fork if respond_to?(:nakayoshi_fork)

# Healthcheck endpoint
activate_control_app 'tcp://0.0.0.0:9293', { auth_token: 'health_check_token' }
