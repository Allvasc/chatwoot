# Undo the premature channel_voice rollout.
#
# A previous commit flipped channel_voice to `enabled: true` in features.yml and
# added a backfill migration (20260903000003) that turned the flag on for every
# account plus the ACCOUNT_LEVEL_FEATURE_DEFAULTS InstallationConfig. channel_voice
# is a premium Chatwoot feature and must NOT ship enabled on this shared image.
#
# features.yml is back to `enabled: false`. This migration reverses the stored
# state in case 20260903000003 already ran in an environment. It is a safe no-op
# where that backfill never executed.
class DisableChannelVoiceEverywhere < ActiveRecord::Migration[7.1]
  def up
    config = InstallationConfig.find_by(name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS')
    if config&.value.present?
      config.value = config.value.map do |feature|
        feature['name'] == 'channel_voice' ? feature.merge('enabled' => false) : feature
      end
      config.save!
    end

    Account.find_in_batches(batch_size: 100) do |accounts|
      accounts.each { |account| account.disable_features!('channel_voice') }
    end

    GlobalConfig.clear_cache
  end

  def down
    # Intentionally irreversible: we do not want to re-enable a premium feature.
    raise ActiveRecord::IrreversibleMigration
  end
end
