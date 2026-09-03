<script setup>
import { useI18n } from 'vue-i18n';
import NextButton from 'dashboard/components-next/button/Button.vue';
import NextSelect from 'dashboard/components-next/select/Select.vue';
import { generateTimeSlots, DEFAULT_HOLIDAY_ROW } from '../helpers/businessHour';

const rows = defineModel({
  type: Array,
  default: () => [],
});

const { t } = useI18n();

const timeOptions = generateTimeSlots(30).map(slot => ({
  value: slot,
  label: slot,
}));

const updateRow = (index, changes) => {
  rows.value = rows.value.map((row, i) =>
    i === index ? { ...row, ...changes } : row
  );
};

const addRow = () => {
  rows.value = [...rows.value, { ...DEFAULT_HOLIDAY_ROW }];
};

const removeRow = index => {
  rows.value = rows.value.filter((_, i) => i !== index);
};
</script>

<template>
  <div class="flex flex-col gap-3">
    <div
      v-for="(row, index) in rows"
      :key="index"
      class="flex flex-col gap-3 p-4 rounded-xl outline outline-1 -outline-offset-1 outline-n-weak"
    >
      <div class="flex flex-wrap items-end gap-4">
        <label class="flex flex-col gap-1 text-body-main text-n-slate-11">
          {{ t('INBOX_MGMT.BUSINESS_HOURS.HOLIDAYS.DATE') }}
          <input
            :value="row.date"
            type="date"
            class="m-0 text-body-main text-n-slate-12 bg-n-alpha-black2 rounded-lg outline outline-1 -outline-offset-1 outline-n-weak"
            @input="event => updateRow(index, { date: event.target.value })"
          />
        </label>
        <label class="flex items-center gap-2 text-body-main text-n-slate-12">
          <input
            :checked="row.repeatsYearly"
            type="checkbox"
            class="m-0"
            @change="
              event => updateRow(index, { repeatsYearly: event.target.checked })
            "
          />
          {{ t('INBOX_MGMT.BUSINESS_HOURS.HOLIDAYS.REPEATS_YEARLY') }}
        </label>
        <label class="flex items-center gap-2 text-body-main text-n-slate-12">
          <input
            :checked="row.allDay"
            type="checkbox"
            class="m-0"
            @change="event => updateRow(index, { allDay: event.target.checked })"
          />
          {{ t('INBOX_MGMT.BUSINESS_HOURS.HOLIDAYS.ALL_DAY') }}
        </label>
        <NextButton
          variant="ghost"
          color="ruby"
          size="small"
          icon="i-lucide-trash-2"
          :aria-label="t('INBOX_MGMT.BUSINESS_HOURS.HOLIDAYS.REMOVE')"
          @click="removeRow(index)"
        />
      </div>

      <div v-if="!row.allDay" class="flex flex-wrap items-end gap-3">
        <label class="flex flex-col gap-1 text-body-main text-n-slate-11">
          {{ t('INBOX_MGMT.BUSINESS_HOURS.HOLIDAYS.FROM') }}
          <NextSelect
            :model-value="row.from"
            :options="timeOptions"
            @update:model-value="value => updateRow(index, { from: value })"
          />
        </label>
        <label class="flex flex-col gap-1 text-body-main text-n-slate-11">
          {{ t('INBOX_MGMT.BUSINESS_HOURS.HOLIDAYS.TO') }}
          <NextSelect
            :model-value="row.to"
            :options="timeOptions"
            @update:model-value="value => updateRow(index, { to: value })"
          />
        </label>
      </div>

      <label class="flex flex-col gap-1 text-body-main text-n-slate-11">
        {{ t('INBOX_MGMT.BUSINESS_HOURS.HOLIDAYS.MESSAGE') }}
        <textarea
          :value="row.message"
          rows="2"
          class="w-full m-0 text-body-main text-n-slate-12 bg-n-alpha-black2 rounded-lg outline outline-1 -outline-offset-1 outline-n-weak"
          :placeholder="
            t('INBOX_MGMT.BUSINESS_HOURS.HOLIDAYS.MESSAGE_PLACEHOLDER')
          "
          @input="event => updateRow(index, { message: event.target.value })"
        />
      </label>
    </div>

    <p v-if="!rows.length" class="text-body-main text-n-slate-11">
      {{ t('INBOX_MGMT.BUSINESS_HOURS.HOLIDAYS.EMPTY') }}
    </p>

    <div>
      <NextButton
        variant="link"
        size="small"
        icon="i-lucide-plus"
        :label="t('INBOX_MGMT.BUSINESS_HOURS.HOLIDAYS.ADD')"
        @click="addRow"
      />
    </div>
  </div>
</template>
