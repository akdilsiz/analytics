defmodule Plausible.Site.Memberships.Invitations do
  @moduledoc false

  use Plausible

  import Ecto.Query, only: [from: 2]

  alias Plausible.Site
  alias Plausible.Auth
  alias Plausible.Repo
  alias Plausible.Billing.Quota
  alias Plausible.Billing.Feature

  @type missing_features_error() :: {:missing_features, [Feature.t()]}

  @spec find_for_user(String.t(), Auth.User.t()) ::
          {:ok, Auth.Invitation.t()} | {:error, :invitation_not_found}
  def find_for_user(invitation_id, user) do
    invitation =
      Auth.Invitation
      |> Repo.get_by(invitation_id: invitation_id, email: user.email)
      |> Repo.preload([:site, :inviter])

    if invitation do
      {:ok, invitation}
    else
      {:error, :invitation_not_found}
    end
  end

  @spec find_for_site(String.t(), Plausible.Site.t()) ::
          {:ok, Auth.Invitation.t()} | {:error, :invitation_not_found}
  def find_for_site(invitation_id, site) do
    invitation =
      Auth.Invitation
      |> Repo.get_by(invitation_id: invitation_id, site_id: site.id)
      |> Repo.preload([:site, :inviter])

    if invitation do
      {:ok, invitation}
    else
      {:error, :invitation_not_found}
    end
  end

  @spec delete_invitation(Auth.Invitation.t()) :: :ok
  def delete_invitation(invitation) do
    Repo.delete_all(from(i in Auth.Invitation, where: i.id == ^invitation.id))

    :ok
  end

  @spec ensure_transfer_valid(Site.t(), Auth.User.t() | nil, Site.Membership.role()) ::
          :ok | {:error, :transfer_to_self}
  def ensure_transfer_valid(%Site{} = site, %Auth.User{} = new_owner, :owner) do
    {:ok, team} = Plausible.Teams.get_or_create(new_owner)

    if Plausible.Teams.Memberships.team_role(team, site) == :owner do
      {:error, :transfer_to_self}
    else
      :ok
    end
  end

  def ensure_transfer_valid(_site, _invitee, _role) do
    :ok
  end

  on_ee do
    @spec ensure_can_take_ownership(Site.t(), Auth.User.t()) ::
            :ok | {:error, Quota.Limits.over_limits_error() | :no_plan}
    def ensure_can_take_ownership(site, new_owner) do
      site = Repo.preload(site, :owner)
      new_owner = Plausible.Users.with_subscription(new_owner)
      plan = Plausible.Billing.Plans.get_subscription_plan(new_owner.subscription)

      active_subscription? = Plausible.Billing.Subscriptions.active?(new_owner.subscription)

      if active_subscription? && plan != :free_10k do
        new_owner
        |> Quota.Usage.usage(pending_ownership_site_ids: [site.id])
        |> Quota.ensure_within_plan_limits(plan)
      else
        {:error, :no_plan}
      end
    end
  else
    @spec ensure_can_take_ownership(Site.t(), Auth.User.t()) :: :ok
    def ensure_can_take_ownership(_site, _new_owner) do
      :ok
    end
  end

  @spec check_feature_access(Site.t(), Auth.User.t(), boolean()) ::
          :ok | {:error, missing_features_error()}
  def check_feature_access(_site, _new_owner, true = _selfhost?) do
    :ok
  end

  def check_feature_access(site, new_owner, false = _selfhost?) do
    missing_features =
      Quota.Usage.features_usage(nil, [site.id])
      |> Enum.filter(&(&1.check_availability(new_owner) != :ok))

    if missing_features == [] do
      :ok
    else
      {:error, {:missing_features, missing_features}}
    end
  end
end
