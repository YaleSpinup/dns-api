# config/puma.rb
threads 2, 16
workers 4
worker_timeout 120
preload_app!
