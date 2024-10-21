class Ability
  include CanCan::Ability

  def initialize(user)
    user ||= User.new # usuario invitado (sin iniciar sesión)

    if user.admin?
      can :manage, :all  # Los administradores pueden hacer todo
    elsif user.seller?
      # Los vendedores pueden leer, crear y actualizar contratos, pero solo los suyos
      can :read, Project
      can :read, Lot
      can :read, Contract, user_id: user.id  # Solo sus contratos
      can :update, Contract, user_id: user.id
      can :create, Contract

      can :update, Lot
      can :create, Lot
      can :destroy, Lot

      # Los vendedores pueden gestionar usuarios, pero quizás solo puedan editar algunos usuarios
      can :read, User
      can :create, User
      can :update, User, id: user.id  # Solo pueden actualizar su propia información
    else
      # Usuarios invitados o clientes
      can :read, :all
      can :read, User, id: user.id  # Solo pueden leer su propia información
    end
  end
end
