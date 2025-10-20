# frozen_string_literal: true

require 'yaml'
require 'bigdecimal'

# app/controllers/api/v1/audits_controller.rb

module Api
  module V1
    # Controller for managing audits
    class AuditsController < ApplicationController
      include Pagy::Backend
      include Sortable
      include Filterable
      before_action :authenticate_user!
      authorize_resource class: false

      SEARCHABLE_FIELDS = %w[event item_type].freeze
      SORTABLE_FIELDS = %w[created_at event item_type ip whodunnit].freeze

      def index
        # Base scope: only the fields we need (reduces memory/IO)
        audits = PaperTrail::Version.select(
          :id, :event, :item_type, :item_id, :whodunnit, :created_at, :ip, :user_agent, :object
        )

        audits = apply_filters(audits, params, SEARCHABLE_FIELDS)
        audits = apply_sorting(audits, params, SORTABLE_FIELDS)

        # Paginate first (so we only operate on the page)
        @pagy, audits = pagy(audits, items: sanitized_per_page, page: params[:page])

        # Preload the users referenced on this page (whodunnit values)
        whodunnits = audits.map(&:whodunnit).compact.uniq
        # Build a map keyed by string so it works with numeric or string whodunnits
        user_map = {}
        if whodunnits.any?
          # Attempt to find by numeric id where appropriate
          numeric_ids = whodunnits.select { |w| w.to_s =~ /\A\d+\z/ }.map(&:to_i)
          users = User.where(id: numeric_ids)
          users.each { |u| user_map[u.id.to_s] = u }
          # Optionally support UUID or other id formats: find by uuid if you use UUIDs:
          # other_ids = whodunnits - numeric_ids.map(&:to_s)
          # User.where(uuid: other_ids).each { |u| user_map[u.uuid] = u } if other_ids.any?
        end

        audits_with_calculated_fields = audits.map { |a| audit_json(a, user_map) }

        render json: { audits: audits_with_calculated_fields, pagination: pagy_metadata(@pagy) }, status: :ok
      end

      private

      def sanitized_per_page
        per = params[:per_page].to_i
        per = 20 if per <= 0
        [per, 200].min # upper limit to avoid huge pages
      end

      def find_user_display(whodunnit, user_map)
        return 'System' unless whodunnit.present?

        # Use the preloaded user map first (keys are string)
        return user_map[whodunnit]&.full_name if user_map && user_map.key?(whodunnit)

        # Try numeric id fallback
        if whodunnit.to_s =~ /\A\d+\z/
          User.find_by(id: whodunnit)&.full_name || "User ##{whodunnit}"
        else
          # If your app uses UUIDs or stores email/name in whodunnit, you can try other lookups here.
          # Otherwise return the raw whodunnit string so it's visible.
          whodunnit
        end
      end

      # Structure audit details for JSON response
      def audit_json(audit, user_map = {})
        parsed = safe_parse_object(audit.object)

        {
          id: audit.id,
          event: audit.event&.titleize,
          item_type: audit.item_type,
          item_id: audit.item_id,
          changes: audit.object,                    # original raw YAML string (optional)
          parsed_changes: parsed,                   # structured hash (safely parsed)
          changed_keys: parsed.is_a?(Hash) ? parsed.keys : [],
          human_summary: human_summary(audit, parsed),
          user: find_user_display(audit.whodunnit, user_map),
          created_at: audit.created_at,
          ip: audit.ip || 'N/A',
          user_agent: audit.user_agent || 'N/A'
        }
      end

      def safe_parse_object(yaml_str)
        return nil unless yaml_str.present?

        begin
          # Only allow plain, safe classes; convert BigDecimal/Time when present.
          raw = YAML.safe_load(yaml_str, permitted_classes: [BigDecimal, Date, Time, DateTime], aliases: true)
          normalize_parsed_hash(raw)
        rescue StandardError => e
          Rails.logger.warn("[Audits] YAML parse failed for audit object #{e.message}")
          nil
        end
      end

      # Normalize types to JSON-safe primitives
      def normalize_parsed_hash(obj)
        case obj
        when Hash
          obj.transform_values { |v| normalize_parsed_hash(v) }
        when Array
          obj.map { |v| normalize_parsed_hash(v) }
        when BigDecimal
          # Decide representation: string preserves precision; use to_f for numbers
          obj.to_s
        when Time, Date, DateTime
          obj.iso8601
        else
          obj
        end
      end

      def human_summary(audit, parsed)
        # short one-line summary used in UI (e.g., "Updated Contract #76: status, amount")
        keys = parsed.is_a?(Hash) ? parsed.keys.map(&:to_s) : []
        action = audit.event&.downcase || 'changed'
        if keys.any?
          "#{action.capitalize} #{audit.item_type} ##{audit.item_id}: #{keys.take(5).join(', ')}"
        else
          "#{action.capitalize} #{audit.item_type} ##{audit.item_id}"
        end
      end
    end
  end
end
