web: /bin/bash -l -c "bundle exec puma -C config/puma.rb"
worker: /bin/bash -l -c "bundle exec sidekiq -e ${RAILS_ENV:-development} -C config/sidekiq.yml -r ./config/environment.rb"