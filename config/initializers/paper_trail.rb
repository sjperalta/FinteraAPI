# frozen_string_literal: true

# config/initializers/paper_trail.rb

# PaperTrail.config.track_associations = false # Disable if not tracking associations
PaperTrail.config.enabled = true
PaperTrail.config.has_paper_trail_defaults = {
  on: %i[create update destroy]
}

PaperTrail.config.version_limit = 3 # Limit stored versions
# Add other configurations as needed
