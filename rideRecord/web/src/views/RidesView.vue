<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useRidesStore } from '@/stores/rides'

const ridesStore = useRidesStore()
const loadingMore = ref(false)

onMounted(() => {
  ridesStore.fetchRides(true)
})

async function loadMore() {
  if (ridesStore.loading || !ridesStore.hasMore) return

  loadingMore.value = true
  await ridesStore.fetchRides()
  loadingMore.value = false
}

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
  const now = new Date()
  const diff = now.getTime() - date.getTime()
  const days = Math.floor(diff / (1000 * 60 * 60 * 24))

  if (days === 0) return '今天'
  if (days === 1) return '昨天'
  if (days < 7) return `${days}天前`
  return `${date.getMonth() + 1}月${date.getDate()}日`
}
</script>

<template>
  <div class="space-y-6">
    <!-- Header -->
    <div class="flex items-center justify-between">
      <h1 class="text-2xl font-bold text-gray-800">骑行记录</h1>
      <span class="text-gray-500">{{ ridesStore.totalRides }} 条记录</span>
    </div>

    <!-- Ride list -->
    <div class="bg-white rounded-xl shadow-sm overflow-hidden">
      <div v-if="ridesStore.rides.length === 0 && !ridesStore.loading" class="text-center py-16 text-gray-400">
        暂无骑行记录
      </div>

      <div v-else class="divide-y divide-gray-100">
        <RouterLink
          v-for="ride in ridesStore.rides"
          :key="ride.id"
          :to="`/rides/${ride.id}`"
          class="flex items-center p-4 hover:bg-gray-50 transition-colors"
        >
          <!-- Icon -->
          <div class="w-12 h-12 bg-primary-100 rounded-full flex items-center justify-center mr-4">
            <span class="text-2xl">🚴</span>
          </div>

          <!-- Info -->
          <div class="flex-1 min-w-0">
            <div class="font-medium text-gray-800 truncate">
              {{ ride.title || '骑行记录' }}
            </div>
            <div class="text-sm text-gray-500 flex items-center space-x-2">
              <span>{{ formatDate(ride.startTime) }}</span>
              <span>·</span>
              <span>{{ formatDuration(ride.duration) }}</span>
            </div>
          </div>

          <!-- Stats -->
          <div class="text-right ml-4">
            <div class="font-semibold text-gray-800">
              {{ formatDistance(ride.distance) }} km
            </div>
            <div class="text-sm text-gray-500">
              {{ ride.avgSpeed.toFixed(1) }} km/h
            </div>
          </div>

          <!-- Arrow -->
          <div class="ml-2 text-gray-400">›</div>
        </RouterLink>
      </div>

      <!-- Load more -->
      <button
        v-if="ridesStore.hasMore"
        @click="loadMore"
        :disabled="loadingMore"
        class="w-full py-4 text-primary-600 hover:bg-gray-50 transition-colors disabled:opacity-50"
      >
        {{ loadingMore ? '加载中...' : '加载更多' }}
      </button>
    </div>
  </div>
</template>
