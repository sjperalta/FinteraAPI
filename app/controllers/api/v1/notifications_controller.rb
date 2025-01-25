# app/controllers/api/v1/notifications_controller.rb

module Api
  module V1
    class NotificationsController < ApplicationController
      before_action :authenticate_user!  # if using Devise, etc.
      before_action :set_notification, only: [:show, :update, :destroy]

      # GET /api/v1/notifications
      def index
        # Return user's notifications, most recent first
        notifications = current_user.notifications.where(read_at: nil).order(created_at: :desc)

        # Example response shape:
        render json: {
          notifications: notifications.as_json(
            only: [:id, :title, :message, :created_at, :read_at]
          )
        }
      end

      # GET /api/v1/notifications/:id
      def show
        render json: @notification
      end
      # PATCH/PUT /api/v1/notifications/:id
      # Mark a notification as read
      def update
        @notification.mark_as_read!
        render json: @notification, status: :ok
      end

      # DELETE /api/v1/notifications/:id
      def destroy
        @notification.destroy
        head :no_content
      end

      # Example endpoints for marking as read or removing could go here
      # POST /api/v1/notifications/mark_all_as_read
      def mark_all_as_read
        current_user.notifications.where(read_at: nil).update_all(read_at: Time.current)
        head :no_content
      end

      private

      def set_notification
        @notification = current_user.notifications.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Not found' }, status: :not_found
      end
    end
  end
end
