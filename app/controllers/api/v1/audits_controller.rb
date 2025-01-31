# app/controllers/api/v1/audits_controller.rb

class Api::V1::AuditsController < ApplicationController
  include Filterable, Sortable, Pagy::Backend
  before_action :authenticate_user!
  authorize_resource class: false

  SEARCHABLE_FIELDS = %w[event item_type].freeze
  SORTABLE_FIELDS = %w[created_at event item_type ip whodunnit].freeze

  def index
    # Initialize the scope
    audits = PaperTrail::Version.all.includes(:item)

    # Apply filters
    audits = apply_filters(audits, params, SEARCHABLE_FIELDS)

    # Apply sorting
    audits = apply_sorting(audits, params, SORTABLE_FIELDS)

    # Paginate the audits using Pagy
    @pagy, audits = pagy(audits, items: params[:per_page] || 20, page: params[:page])

    # Map audits with additional calculated fields
    audits_with_calculated_fields = audits.map do |audit|
      {
        id: audit.id,
        event: audit.event.titleize,
        item_type: audit.item_type,
        item_id: audit.item_id,
        changes: audit.changeset, # Provides a hash of changes
        user: audit.whodunnit ? User.find(audit.whodunnit).full_name : "System",
        created_at: audit.created_at,
        ip: audit&.ip || 'N/A',
        user_agent: audit&.user_agent || 'N/A'
      }
    end

    # Render JSON response with audits and pagination metadata
    render json: {
      audits: audits_with_calculated_fields,
      pagination: pagy_metadata(@pagy)
    }, status: :ok
  end
end
