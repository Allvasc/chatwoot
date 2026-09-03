<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import NextButton from 'dashboard/components-next/button/Button.vue';
import NextSelect from 'dashboard/components-next/select/Select.vue';
import { generateTimeSlots, DEFAULT_BREAK_ROW } from '../helpers/businessHour';

const props = defineProps({
  dayNames: {
    type: Object,
    default: () => ({}),
  },
});

const rows = defineModel({
  type: Array,
  default: () => [],
});

const { t } = useI18n();

const timeOptions = generateTimeSlots(30).map(slot => ({
  value: slot,
  label: slot,
}));

const dayOptions = computed(() =>
  [1, 2, 3, 4, 5, 6, 0].map(day => ({
    value: day,
    label: props.dayNames[day] || String(day),
  }))
);

const updateRow = (index, key, value) => {
  rows.value = rows.value.map((row, i) =>
    i === index ? { ...row, [key]: value } : row
  );
};

const addRow = () => {
  rows.value = [...rows.value, { ...DEFAULT_BREAK_ROW }];
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
      <div class="flex flex-wrap items-end gap-3">
        <label class="flex flex-col gap-1 text-body-main text-n-slate-11">
          {{ t('INBOX_MGMT.BUSINESS_HOURS.BREAKS.DAY') }}
          <NextSelect
            :model-value="row.day"
            :options="dayOptions"
            @update:model-value="value => updateRow(index, 'day', value)"
          />
        </label>
        <label class="flex flex-col gap-1 text-body-main text-n-slate-11">
          {{ t('INBOX_MGMT.BUSINESS_HOURS.BREAKS.FROM') }}
          <NextSelect
            :model-value="row.from"
            :options="timeOptions"
            @update:model-value="value => updateRow(index, 'from', value)"
          />
        </label>
        <label class="flex flex-col gap-1 text-body-main text-n-slate-11">
          {{ t('INBOX_MGMT.BUSINESS_HOURS.BREAKS.TO') }}
          <NextSelect
            :model-value="row.to"
            :options="timeOptions"
            @update:model-value="value => updateRow(index, 'to', value)"
          />
        </label>
        <NextButton
          type="button"
          variant="ghost"
          color="ruby"
          size="sm"
          icon="i-lucide-trash-2"
          :aria-label="t('INBOX_MGMT.BUSINESS_HOURS.BREAKS.REMOVE')"
          @click="removeRow(index)"
        />
      </div>
      <label class="flex flex-col gap-1 text-body-main text-n-slate-11">
        {{ t('INBOX_MGMT.BUSINESS_HOURS.BREAKS.MESSAGE') }}
        <textarea
          :value="row.message"
          rows="2"
          class="w-full m-0 text-body-main text-n-slate-12 bg-n-alpha-black2 rounded-lg outline outline-1 -outline-offset-1 outline-n-weak"
          :placeholder="
            t('INBOX_MGMT.BUSINESS_HOURS.BREAKS.MESSAGE_PLACEHOLDER')
          "
          @input="event => updateRow(index, 'message', event.target.value)"
        />
      </label>
    </div>

    <p v-if="!rows.length" class="text-body-main text-n-slate-11">
      {{ t('INBOX_MGMT.BUSINESS_HOURS.BREAKS.EMPTY') }}
    </p>

    <div>
      <NextButton
        type="button"
        variant="link"
        size="sm"
        icon="i-lucide-plus"
        :label="t('INBOX_MGMT.BUSINESS_HOURS.BREAKS.ADD')"
        @click="addRow"
      />
    </div>
  </div>
</template>
