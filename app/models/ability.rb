# app/models/ability.rb

class Ability
  include CanCan::Ability

  def initialize(user)
    user ||= User.new # usuario invitado (sin iniciar sesión)

    if user.admin?
      can :manage, :all  # Los administradores pueden hacer todo
    elsif user.seller?
      can :read, Project   # Los vendedores pueden ver proyectos
      can :read, Lot
      can :read, contract
      can :create, contract   # Los vendedores pueden crear solicitudes de reserva
      can :read, User
      can :create, User
      can :update, User
    else
      can :read, Project   # Los usuarios normales solo pueden ver proyectos
      can :read, Lot
      can :read, User
      can :read, contract
    end
  end
end
