class Ability
  include CanCan::Ability

  def initialize(user)

    user ||= User.new

    if user.admin?
      can :manage, :all
    elsif user.id
      can :manage, HealthDataStandards::SVS::ValueSet
      can :manage, Measure
    else
      # need to be able to view published measures???
    end

  end
end
