# Enable channel_voice (WhatsApp / Twilio calling) everywhere.
#
# channel_voice has shipped in features.yml as `enabled: false` for a while, so it
# is already present in the ACCOUNT_LEVEL_FEATURE_DEFAULTS InstallationConfig with
# that stale value. ConfigLoader runs with reconcile_only_new: true on deploy and
# keeps the existing entry, so flipping features.yml alone changes nothing for new
# OR existing accounts. This migration mirrors
# 20250416182131_flip_chatwoot_v4_default_feature_flag_installation_config.rb:
#   1. flip the stored default so newly created accounts get it, and
#   2. backfill the flag on every existing account.
class EnableChannelVoiceForExistingAccounts < ActiveRecord::Migration[7.1]
  def up
    config = InstallationConfig.find_by(name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS')
    if config&.value.present?
      config.value = config.value.map do |feature|
        feature['name'] == 'channel_voice' ? feature.merge('enabled' => true) : feature
      end
      config.save!
    end

    Account.find_in_batches(batch_size: 100) do |accounts|
      accounts.each { |account| account.enable_features!('channel_voice') }
    end

    GlobalConfig.clear_cache
  end

  def down
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
end
