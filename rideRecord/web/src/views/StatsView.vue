<script setup lang="ts">
import { ref, onMounted } from 'vue'
import api from '@/lib/api'

interface MonthlyStats {
  year: number
  month: number
  rides: number
  distance: number
  duration: number
  calories: number
  avgSpeed: number
}

const monthlyStats = ref<MonthlyStats[]>([])
const loading = ref(true)

onMounted(async () => {
  try {
    monthlyStats.value = await api.get<MonthlyStats[]>('/rides/stats/monthly')
  } finally {
    loading.value = false
  }
})

function formatDistance(meters: number): string {
  return (meters / 1000).toFixed(0)
}

function formatDuration(seconds: number): string {
  const hours = Math.floor(seconds / 3600)
  return `${hours}h`
}

const maxDistance = computed(() => {
  return Math.max(...monthlyStats.value.map(s => s.distance), 1)
})
</script>

<template>
  <div class="space-y-6">
    <h1 class="text-2xl font-bold text-gray-800">统计分析</h1>

    <!-- Loading -->
    <div v-if="loading" class="text-center py-16 text-gray-400">
      加载中...
    </div>

    <!-- Monthly stats -->
    <template v-else>
      <div class="bg-white rounded-xl shadow-sm p-6">
        <h2 class="text-lg font-semibold text-gray-800 mb-4">月度统计</h2>

        <div v-if="monthlyStats.length === 0" class="text-center py-8 text-gray-400">
          暂无统计数据
        </div>

        <div v-else class="space-y-4">
          <div
            v-for="stat in monthlyStats"
            :key="`${stat.year}-${stat.month}`"
            class="border-b border-gray-100 last:border-0 pb-4 last:pb-0"
          >
            <div class="flex items-center justify-between mb-2">
              <span class="font-medium text-gray-800">
                {{ stat.year }}年{{ stat.month }}月
              </span>
              <span class="text-gray-500 text-sm">
                {{ stat.rides }} 次骑行
              </span>
            </div>

            <!-- Distance bar -->
            <div class="h-4 bg-gray-100 rounded-full overflow-hidden">
              <div
                class="h-full bg-primary-500 rounded-full transition-all"
                :style="{ width: `${(stat.distance / maxDistance) * 100}%` }"
              ></div>
            </div>

            <!-- Stats row -->
            <div class="flex items-center justify-between mt-2 text-sm text-gray-500">
              <span>{{ formatDistance(stat.distance) }} km</span>
              <span>{{ formatDuration(stat.duration) }}</span>
              <span>{{ stat.calories }} kcal</span>
              <span>{{ stat.avgSpeed.toFixed(1) }} km/h</span>
            </div>
          </div>
        </div>
      </div>
    </template>
  </div>
</template>

<script lang="ts">
import { computed } from 'vue'
</script>
