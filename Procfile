web: /bin/bash -l -c "bundle exec puma -C config/puma.rb"
worker: /bin/bash -l -c "bundle exec rake solid_queue:start"