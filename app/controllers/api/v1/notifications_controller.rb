# frozen_string_literal: true

module Api
  module V1
    # Controller for managing user notifications
    class NotificationsController < ApplicationController
      before_action :authenticate_user!
      before_action :set_notification, only: %i[show update destroy]

      # GET /api/v1/notifications
      # Returns paginated notifications with optional filtering
      def index
        scope = filter_notifications
        @pagy, notifications = pagy(scope)

        render json: {
          notifications: notifications.as_json(
            only: %i[id title message created_at read_at notification_type]
          ),
          pagination: pagy_metadata(@pagy)
        }
      end

      # GET /api/v1/notifications/:id
      def show
        render json: @notification.as_json(
          only: %i[id title message created_at read_at notification_type notifiable_id]
        )
      end

      # PATCH/PUT /api/v1/notifications/:id
      # Mark a notification as read
      def update
        if @notification.mark_as_read!
          render json: @notification, status: :ok
        else
          render json: { errors: @notification.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/notifications/:id
      def destroy
        @notification.destroy!
        head :no_content
      end

      # POST /api/v1/notifications/mark_all_as_read
      # Mark all unread notifications as read
      def mark_all_as_read
        count = current_user.notifications.unread.update_all(read_at: Time.current)
        render json: { message: I18n.t('notifications.marked_as_read'), count: }, status: :ok
      end

      private

      def set_notification
        @notification = current_user.notifications.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: I18n.t('notifications.not_found') }, status: :not_found
      end

      # Filter notifications based on query parameters
      def filter_notifications
        scope = current_user.notifications.includes(:notifiable).order(created_at: :desc)

        # Filter by read/unread status
        scope = filter_by_status(scope)

        # Filter by type if specified
        scope = scope.where(notification_type: params[:type]) if params[:type].present?

        scope
      end

      # Filter by read status
      def filter_by_status(scope)
        case params[:status]
        when 'read'
          scope.read
        when 'unread'
          scope.unread
        else
          scope
        end
      end
    end
  end
end
