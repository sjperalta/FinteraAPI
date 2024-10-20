# app/models/ability.rb

class Ability
  include CanCan::Ability

  def initialize(user)
    user ||= User.new # usuario invitado (sin iniciar sesión)

    if user.admin?
      can :manage, :all  # Los administradores pueden hacer todo
    elsif user.seller?
      can :read, Project   # Los vendedores pueden ver proyectos
      can :create, ReservationRequest   # Los vendedores pueden crear solicitudes de reserva
      can :cancel, ReservationRequest   # Los vendedores pueden cancelar solicitudes de reserva
      can :create, User
    else
      can :read, Project   # Los usuarios normales solo pueden ver proyectos
    end
  end
end
