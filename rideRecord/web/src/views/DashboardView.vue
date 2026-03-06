<script setup lang="ts">
import { onMounted, computed } from 'vue'
import { useRidesStore } from '@/stores/rides'
import { useAuthStore } from '@/stores/auth'

const ridesStore = useRidesStore()
const authStore = useAuthStore()

onMounted(async () => {
  await authStore.fetchUser()
  await Promise.all([
    ridesStore.fetchStats(),
    ridesStore.fetchRides(true)
  ])
})

const recentRides = computed(() => ridesStore.rides.slice(0, 5))
const stats = computed(() => ridesStore.stats)

function formatDistance(meters: number): string {
  return (meters / 1000).toFixed(1)
}

function formatDuration(seconds: number): string {
  const hours = Math.floor(seconds / 3600)
  const minutes = Math.floor((seconds % 3600) / 60)
  if (hours > 0) {
    return `${hours}h ${minutes}m`
  }
  return `${minutes}分钟`
}

function formatDate(dateStr: string): string {
  const date = new Date(dateStr)
  return `${date.getMonth() + 1}月${date.getDate()}日`
}
</script>

<template>
  <div class="space-y-6">
    <!-- Welcome -->
    <div class="bg-white rounded-xl shadow-sm p-6">
      <h1 class="text-2xl font-bold text-gray-800">
        你好，{{ authStore.user?.nickname || '骑行者' }} 👋
      </h1>
      <p class="text-gray-500 mt-1">查看你的骑行数据概览</p>
    </div>

    <!-- Stats cards -->
    <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
      <div class="bg-white rounded-xl shadow-sm p-6">
        <div class="text-3xl font-bold text-primary-600">
          {{ stats?.totalRides || 0 }}
        </div>
        <div class="text-gray-500 text-sm mt-1">总骑行次数</div>
      </div>

      <div class="bg-white rounded-xl shadow-sm p-6">
        <div class="text-3xl font-bold text-primary-600">
          {{ formatDistance(stats?.totalDistance || 0) }}
        </div>
        <div class="text-gray-500 text-sm mt-1">总里程 (km)</div>
      </div>

      <div class="bg-white rounded-xl shadow-sm p-6">
        <div class="text-3xl font-bold text-primary-600">
          {{ formatDuration(stats?.totalDuration || 0) }}
        </div>
        <div class="text-gray-500 text-sm mt-1">总时长</div>
      </div>

      <div class="bg-white rounded-xl shadow-sm p-6">
        <div class="text-3xl font-bold text-primary-600">
          {{ stats?.totalCalories || 0 }}
        </div>
        <div class="text-gray-500 text-sm mt-1">消耗热量 (kcal)</div>
      </div>
    </div>

    <!-- Recent rides -->
    <div class="bg-white rounded-xl shadow-sm p-6">
      <div class="flex items-center justify-between mb-4">
        <h2 class="text-lg font-semibold text-gray-800">最近骑行</h2>
        <RouterLink to="/rides" class="text-primary-600 hover:text-primary-700 text-sm">
          查看全部 →
        </RouterLink>
      </div>

      <div v-if="recentRides.length === 0" class="text-center py-8 text-gray-400">
        暂无骑行记录
      </div>

      <div v-else class="space-y-3">
        <RouterLink
          v-for="ride in recentRides"
          :key="ride.id"
          :to="`/rides/${ride.id}`"
          class="flex items-center justify-between p-4 bg-gray-50 rounded-lg hover:bg-gray-100 transition-colors"
        >
          <div>
            <div class="font-medium text-gray-800">
              {{ ride.title || formatDate(ride.startTime) }}
            </div>
            <div class="text-sm text-gray-500">
              {{ formatDate(ride.startTime) }}
            </div>
          </div>
          <div class="text-right">
            <div class="font-medium text-gray-800">
              {{ formatDistance(ride.distance) }} km
            </div>
            <div class="text-sm text-gray-500">
              {{ formatDuration(ride.duration) }}
            </div>
          </div>
        </RouterLink>
      </div>
    </div>
  </div>
</template>
