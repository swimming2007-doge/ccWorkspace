<script setup lang="ts">
import { computed } from 'vue'
import { RouterLink, useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const router = useRouter()
const authStore = useAuthStore()

const isAuthenticated = computed(() => authStore.isAuthenticated)

function handleLogout() {
  authStore.logout()
  router.push('/login')
}
</script>

<template>
  <nav class="bg-white shadow-sm border-b border-gray-200">
    <div class="container mx-auto px-4">
      <div class="flex items-center justify-between h-16">
        <!-- Logo -->
        <RouterLink to="/" class="flex items-center space-x-2">
          <span class="text-2xl">🚴</span>
          <span class="text-xl font-bold text-gray-800">RideRecord</span>
        </RouterLink>

        <!-- Navigation -->
        <div v-if="isAuthenticated" class="flex items-center space-x-6">
          <RouterLink
            to="/"
            class="text-gray-600 hover:text-primary-600 transition-colors"
            active-class="text-primary-600 font-medium"
          >
            看板
          </RouterLink>
          <RouterLink
            to="/rides"
            class="text-gray-600 hover:text-primary-600 transition-colors"
            active-class="text-primary-600 font-medium"
          >
            骑行记录
          </RouterLink>
          <RouterLink
            to="/stats"
            class="text-gray-600 hover:text-primary-600 transition-colors"
            active-class="text-primary-600 font-medium"
          >
            统计
          </RouterLink>
        </div>

        <!-- User menu -->
        <div v-if="isAuthenticated" class="flex items-center space-x-4">
          <button
            @click="handleLogout"
            class="text-gray-600 hover:text-gray-800 transition-colors"
          >
            退出
          </button>
        </div>
      </div>
    </div>
  </nav>
</template>
