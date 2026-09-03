class Conversations::PermissionFilterService
  attr_reader :conversations, :user, :account

  def initialize(conversations, user, account, plan_hint_selective_filter: false)
    @conversations = conversations
    @user = user
    @account = account
    @plan_hint_selective_filter = plan_hint_selective_filter
  end

  def perform
    return conversations if user_role == 'administrator'

    accessible_conversations
  end

  private

  def accessible_conversations
    scope = team_restricted? ? conversations.where(team_id: visible_team_ids) : conversations

    return hinted_accessible_conversations(scope) if @plan_hint_selective_filter

    scope.where(inbox: user.inboxes.where(account_id: account.id))
  end

  def team_restricted?
    account_user&.conversation_visibility == 'assigned_teams'
  end

  def visible_team_ids
    ids = user.teams.where(account_id: account.id).pluck(:id)
    ids << nil if ActiveModel::Type::Boolean.new.cast(ENV.fetch('TEAM_RESTRICTED_SEES_UNASSIGNED_TEAM', false))
    ids
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
