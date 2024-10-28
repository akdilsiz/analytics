defmodule Plausible.Teams.Test do
  @moduledoc """
  Convenience assertions for teams schema transition
  """
  alias Plausible.Repo
  import Plausible.Factory

  use ExUnit.CaseTemplate

  defmacro __using__(_) do
    quote do
      import Plausible.Teams.Test
    end
  end

  def random_domain() do
    "#{:crypto.strong_rand_bytes(8) |> Base.encode16(padding: false)}.example.com"
  end

  def random_email() do
    "#{:crypto.strong_rand_bytes(8) |> Base.encode16(padding: false)}@example.com"
  end

  def create_user(args \\ []) do
    name = Keyword.get(args, :name, "John Doe")
    email = Keyword.get(args, :email, random_email())
    {:ok, user} = Plausible.Auth.create_user(name, email, "super-strong-plausible-test")
    user
  end

  def subscribe(user, :growth) do
    today = Date.utc_today()

    {:ok, _} =
      Plausible.Billing.subscription_created(%{
        "event_time" => "#{today} 01:03:52",
        "alert_name" => "subscription_created",
        "passthrough" => "#{user.id}",
        "email" => user.email,
        "subscription_id" => "857097",
        "subscription_plan_id" => "654177",
        "update_url" => "update_url.com",
        "cancel_url" => "cancel_url.com",
        "status" => "active",
        "next_bill_date" => "#{Date.shift(today, day: 30)}",
        "unit_price" => "6.00",
        "currency" => "EUR"
      })

    user
  end

  def create_site() do
    create_site(insert(:user), [])
  end

  def create_site(owner, args \\ []) do
    domain = Keyword.get(args, :domain, random_domain())
    args = args |> Map.new() |> Map.put(:domain, domain)
    {:ok, data} = Plausible.Sites.create(owner, args)
    data
  end

  def add_guest_membership(site, user, role) do
    site = Repo.preload(site, :owner)
    inviter = site.owner
    {:ok, guest_invitation} = Plausible.Teams.Invitations.invite(site, inviter, user.email, role)
    Plausible.Teams.Invitations.accept(guest_invitation.team_invitation.invitation_id, user)
  end

  # def add_team_membership(team, user, :owner) do
  #   assert {:ok, new_membership} = AcceptInvitation.transfer_ownership(site, new_owner)
  #
  # end
  #
  def assert_team_exists(user, team_id \\ nil) do
    assert %{team_memberships: memberships} = Repo.preload(user, team_memberships: :team)

    tm =
      case memberships do
        [tm] -> tm
        _ -> raise "Team doesn't exist for user #{user.id}"
      end

    assert tm.role == :owner
    assert tm.team.id

    if team_id do
      assert tm.team.id == team_id
    end

    tm.team
  end

  def assert_team_membership(user, team, role \\ :owner) do
    assert membership =
             Repo.get_by(Plausible.Teams.Membership,
               team_id: team.id,
               user_id: user.id,
               role: role
             )

    membership
  end

  def assert_team_attached(site, team_id \\ nil) do
    assert site = %{team: team} = site |> Repo.reload!() |> Repo.preload([:team, :owner])

    assert membership = assert_team_membership(site.owner, team)

    assert membership.team_id == team.id

    if team_id do
      assert team.id == team_id
    end

    team
  end

  def assert_guest_invitation(team, site, email, role) do
    assert team_invitation =
             Repo.get_by(Plausible.Teams.Invitation,
               email: email,
               team_id: team.id,
               role: :guest
             )

    assert Repo.get_by(Plausible.Teams.GuestInvitation,
             team_invitation_id: team_invitation.id,
             site_id: site.id,
             role: role
           )
  end

  def assert_guest_membership(team, site, user, role) do
    assert team_membership =
             Repo.get_by(Plausible.Teams.Membership,
               user_id: user.id,
               team_id: team.id,
               role: :guest
             )

    assert Repo.get_by(Plausible.Teams.GuestMembership,
             team_membership_id: team_membership.id,
             site_id: site.id,
             role: role
           )
  end
end
