import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import api from '@/lib/api'

export interface Ride {
  id: string
  userId: string
  title?: string
  startTime: string
  endTime?: string
  duration: number
  movingTime: number
  distance: number
  avgSpeed: number
  maxSpeed: number
  avgHeartRate?: number
  maxHeartRate?: number
  calories: number
  elevationGain: number
  elevationLoss: number
  trackPointCount: number
  synced: boolean
  createdAt: string
}

export interface RideDetail extends Ride {
  trackPoints: TrackPoint[]
}

export interface TrackPoint {
  timestamp: string
  latitude: number
  longitude: number
  altitude?: number
  speed?: number
  heartRate?: number
}

export interface RideStats {
  totalRides: number
  totalDistance: number
  totalDuration: number
  totalCalories: number
  avgSpeed: number
}

export const useRidesStore = defineStore('rides', () => {
  const rides = ref<Ride[]>([])
  const currentRide = ref<RideDetail | null>(null)
  const stats = ref<RideStats | null>(null)
  const loading = ref(false)
  const hasMore = ref(true)
  const page = ref(1)

  const totalRides = computed(() => rides.value.length)

  async function fetchRides(reset = false): Promise<void> {
    if (reset) {
      page.value = 1
      rides.value = []
      hasMore.value = true
    }

    if (!hasMore.value) return

    loading.value = true
    try {
      const response = await api.get<{ data: Ride[] }>('/rides', {
        params: { page: page.value, limit: 20 }
      })

      if (reset) {
        rides.value = response.data
      } else {
        rides.value.push(...response.data)
      }

      hasMore.value = response.data.length === 20
      page.value++
    } finally {
      loading.value = false
    }
  }

  async function fetchRide(id: string): Promise<void> {
    loading.value = true
    try {
      currentRide.value = await api.get<RideDetail>(`/rides/${id}`)
    } finally {
      loading.value = false
    }
  }

  async function fetchStats(): Promise<void> {
    stats.value = await api.get<RideStats>('/rides/stats')
  }

  async function deleteRide(id: string): Promise<void> {
    await api.delete(`/rides/${id}`)
    rides.value = rides.value.filter(r => r.id !== id)
    if (currentRide.value?.id === id) {
      currentRide.value = null
    }
  }

  function clearCurrentRide(): void {
    currentRide.value = null
  }

  return {
    rides,
    currentRide,
    stats,
    loading,
    hasMore,
    totalRides,
    fetchRides,
    fetchRide,
    fetchStats,
    deleteRide,
    clearCurrentRide
  }
})
