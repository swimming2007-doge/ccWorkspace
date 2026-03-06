<script setup lang="ts">
import { onMounted, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useRidesStore } from '@/stores/rides'

const route = useRoute()
const router = useRouter()
const ridesStore = useRidesStore()

onMounted(() => {
  const id = route.params.id as string
  ridesStore.fetchRide(id)
})

const ride = computed(() => ridesStore.currentRide)

function formatDistance(meters: number): string {
  return (meters / 1000).toFixed(2)
}

function formatDuration(seconds: number): string {
  const hours = Math.floor(seconds / 3600)
  const minutes = Math.floor((seconds % 3600) / 60)
  const secs = seconds % 60
  if (hours > 0) {
    return `${hours}:${String(minutes).padStart(2, '0')}:${String(secs).padStart(2, '0')}`
  }
  return `${minutes}:${String(secs).padStart(2, '0')}`
}

function formatDate(dateStr: string): string {
  const date = new Date(dateStr)
  return `${date.getFullYear()}年${date.getMonth() + 1}月${date.getDate()}日 ${date.getHours()}:${String(date.getMinutes()).padStart(2, '0')}`
}

function goBack() {
  router.back()
}

async function handleExport(format: string) {
  // TODO: Implement export
  console.log('Export as', format)
}

async function handleDelete() {
  if (!ride.value) return
  if (!confirm('确定要删除这条骑行记录吗？')) return

  await ridesStore.deleteRide(ride.value.id)
  router.push('/rides')
}
</script>

<template>
  <div class="space-y-6">
    <!-- Header -->
    <div class="flex items-center space-x-4">
      <button @click="goBack" class="text-gray-500 hover:text-gray-700">
        ← 返回
      </button>
      <h1 class="text-2xl font-bold text-gray-800">
        {{ ride?.title || '骑行详情' }}
      </h1>
    </div>

    <!-- Loading -->
    <div v-if="ridesStore.loading" class="text-center py-16 text-gray-400">
      加载中...
    </div>

    <!-- Detail -->
    <template v-else-if="ride">
      <!-- Stats grid -->
      <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div class="bg-white rounded-xl shadow-sm p-6 text-center">
          <div class="text-3xl font-bold text-primary-600">
            {{ formatDistance(ride.distance) }}
          </div>
          <div class="text-gray-500 text-sm mt-1">公里</div>
        </div>

        <div class="bg-white rounded-xl shadow-sm p-6 text-center">
          <div class="text-3xl font-bold text-primary-600">
            {{ formatDuration(ride.duration) }}
          </div>
          <div class="text-gray-500 text-sm mt-1">时长</div>
        </div>

        <div class="bg-white rounded-xl shadow-sm p-6 text-center">
          <div class="text-3xl font-bold text-primary-600">
            {{ ride.avgSpeed.toFixed(1) }}
          </div>
          <div class="text-gray-500 text-sm mt-1">平均速度 (km/h)</div>
        </div>

        <div class="bg-white rounded-xl shadow-sm p-6 text-center">
          <div class="text-3xl font-bold text-primary-600">
            {{ ride.calories }}
          </div>
          <div class="text-gray-500 text-sm mt-1">热量 (kcal)</div>
        </div>
      </div>

      <!-- Details -->
      <div class="bg-white rounded-xl shadow-sm p-6">
        <h2 class="text-lg font-semibold text-gray-800 mb-4">详细信息</h2>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div class="flex justify-between py-2 border-b border-gray-100">
            <span class="text-gray-500">开始时间</span>
            <span class="text-gray-800">{{ formatDate(ride.startTime) }}</span>
          </div>

          <div class="flex justify-between py-2 border-b border-gray-100">
            <span class="text-gray-500">结束时间</span>
            <span class="text-gray-800">{{ ride.endTime ? formatDate(ride.endTime) : '--' }}</span>
          </div>

          <div class="flex justify-between py-2 border-b border-gray-100">
            <span class="text-gray-500">移动时间</span>
            <span class="text-gray-800">{{ formatDuration(ride.movingTime) }}</span>
          </div>

          <div class="flex justify-between py-2 border-b border-gray-100">
            <span class="text-gray-500">最大速度</span>
            <span class="text-gray-800">{{ ride.maxSpeed.toFixed(1) }} km/h</span>
          </div>

          <div class="flex justify-between py-2 border-b border-gray-100">
            <span class="text-gray-500">平均心率</span>
            <span class="text-gray-800">{{ ride.avgHeartRate ? `${ride.avgHeartRate} bpm` : '--' }}</span>
          </div>

          <div class="flex justify-between py-2 border-b border-gray-100">
            <span class="text-gray-500">最大心率</span>
            <span class="text-gray-800">{{ ride.maxHeartRate ? `${ride.maxHeartRate} bpm` : '--' }}</span>
          </div>

          <div class="flex justify-between py-2 border-b border-gray-100">
            <span class="text-gray-500">累计爬升</span>
            <span class="text-gray-800">{{ ride.elevationGain.toFixed(0) }} m</span>
          </div>

          <div class="flex justify-between py-2 border-b border-gray-100">
            <span class="text-gray-500">累计下降</span>
            <span class="text-gray-800">{{ ride.elevationLoss.toFixed(0) }} m</span>
          </div>
        </div>
      </div>

      <!-- Map placeholder -->
      <div class="bg-white rounded-xl shadow-sm p-6">
        <h2 class="text-lg font-semibold text-gray-800 mb-4">骑行轨迹</h2>
        <div class="bg-gray-100 rounded-lg h-64 flex items-center justify-center text-gray-400">
          📍 轨迹地图 ({{ ride.trackPointCount }} 个轨迹点)
        </div>
      </div>

      <!-- Actions -->
      <div class="flex space-x-4">
        <button
          @click="handleExport('gpx')"
          class="flex-1 py-3 bg-primary-600 text-white rounded-lg hover:bg-primary-700 transition-colors"
        >
          导出 GPX
        </button>
        <button
          @click="handleDelete"
          class="px-6 py-3 bg-red-50 text-red-600 rounded-lg hover:bg-red-100 transition-colors"
        >
          删除记录
        </button>
      </div>
    </template>

    <!-- Not found -->
    <div v-else class="text-center py-16 text-gray-400">
      骑行记录不存在
    </div>
  </div>
</template>
