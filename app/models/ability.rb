# frozen_string_literal: true

class Ability
  include CanCan::Ability

  def initialize(user)
    user ||= User.new # guest user (not logged in)

    if user.admin?
      Rails.logger.debug 'User is an admin'
      can :manage, :all # Admins can do everything
      can :resend_confirmation, User
      can :read, PaperTrail::Version
    elsif user.seller?
      Rails.logger.debug 'User is a seller'
      # Sellers can read, create, and update contracts they created
      can :read, Project
      can :read, Contract, creator_id: user.id
      can :update, Contract, creator_id: user.id
      can :create, Contract
      can :cancel, Contract, creator_id: user.id
      can :reopen, Contract, creator_id: user.id

      can :read, Lot

      # Sellers can manage users, but only edit their own information
      can :manage, Notification, user_id: user.id
      can :read, User, id: user.id
      can :read, User, role: 'user'
      can :update, User, id: user.id # Only update their own information
      can :update, User, role: 'user' # Sellers can update users with role 'user'
      can :payments, User, id: user.id
      can :summary, User, id: user.id
      can :summary, User, role: 'user'
      can :resend_confirmation, User, id: user.id

    else
      Rails.logger.debug 'User is a regular user or guest'
      # Regular users or guests
      can %i[update read], User, id: user.id
      can :read, Contract, applicant_user_id: user.id
      can :read, Payment, contract: { applicant_user_id: user.id }
      can :manage, Payment, contract: { applicant_user_id: user.id }
      can :manage, Notification, user_id: user.id

      # Explicitly allow access to the `payments` and `summary` actions
      can :payments, User, id: user.id
      can :payment_history, User, id: user.id
      can :summary, User, id: user.id

      can :send_recovery_code, User, id: user.id
      can :verify_recovery_code, User, id: user.id
      can :update_password_with_code, User, id: user.id
    end
  end
end
