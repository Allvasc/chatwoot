class Conversations::PermissionFilterService
  attr_reader :conversations, :user, :account

  def initialize(conversations, user, account, plan_hint_selective_filter: false)
    @conversations = conversations
    @user = user
    @account = account
    @plan_hint_selective_filter = plan_hint_selective_filter
  end

  def perform
    return conversations if user_role == 'administrator' && !team_restricted?

    accessible_conversations
  end

  private

  def accessible_conversations
    scope = team_restricted? ? conversations.where(team_id: visible_team_ids) : conversations

    # a team-restricted administrator is scoped to their teams across every inbox,
    # without the inbox-membership limit that applies to agents
    return scope if user_role == 'administrator'

    return hinted_accessible_conversations(scope) if @plan_hint_selective_filter

    scope.where(inbox: user.inboxes.where(account_id: account.id))
  end

  def team_restricted?
    account_user&.conversation_visibility == 'assigned_teams'
  end

  # Team-restricted members also see conversations not yet routed to any team
  # (the shared "unassigned team" queue), so those don't sit in limbo with nobody
  # able to pick them up. Restricted agents are still additionally scoped to their
  # own inboxes by #accessible_conversations.
  def visible_team_ids
    user.teams.where(account_id: account.id).pluck(:id) + [nil]
  end

  # Same rows as accessible_conversations. `inbox_id + 0` keeps the planner from
  # driving the query through an inbox scan, which it grossly misestimates when a
  # highly selective filter (e.g. labels) is present on large accounts (CW-7787).
  def hinted_accessible_conversations(scope = conversations)
    scope.where(
      '(conversations.inbox_id + 0) IN (
        SELECT inbox_members.inbox_id FROM inbox_members
        INNER JOIN inboxes ON inboxes.id = inbox_members.inbox_id
        WHERE inbox_members.user_id = :user_id AND inboxes.account_id = :account_id
      )',
      user_id: user.id, account_id: account.id
    )
  end

  def account_user
    AccountUser.find_by(account_id: account.id, user_id: user.id)
  end

  def user_role
    account_user&.role
  end
end

Conversations::PermissionFilterService.prepend_mod_with('Conversations::PermissionFilterService')
