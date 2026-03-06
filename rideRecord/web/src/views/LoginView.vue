<script setup lang="ts">
import { ref } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const router = useRouter()
const route = useRoute()
const authStore = useAuthStore()

const loading = ref(false)
const error = ref('')

async function handleGuestLogin() {
  loading.value = true
  error.value = ''

  try {
    await authStore.loginAsGuest()
    const redirect = route.query.redirect as string || '/'
    router.push(redirect)
  } catch (e) {
    error.value = '登录失败，请重试'
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div class="min-h-[80vh] flex items-center justify-center">
    <div class="bg-white rounded-xl shadow-lg p-8 w-full max-w-md">
      <!-- Logo -->
      <div class="text-center mb-8">
        <div class="text-6xl mb-4">🚴</div>
        <h1 class="text-2xl font-bold text-gray-800">RideRecord</h1>
        <p class="text-gray-500 mt-2">智能骑行记录</p>
      </div>

      <!-- Login options -->
      <div class="space-y-4">
        <!-- Guest login -->
        <button
          @click="handleGuestLogin"
          :disabled="loading"
          class="w-full py-3 px-4 bg-gray-100 hover:bg-gray-200 text-gray-800 rounded-lg transition-colors disabled:opacity-50"
        >
          {{ loading ? '登录中...' : '游客模式体验' }}
        </button>

        <!-- Error message -->
        <p v-if="error" class="text-red-500 text-center text-sm">
          {{ error }}
        </p>
      </div>

      <!-- Terms -->
      <p class="text-center text-gray-400 text-xs mt-8">
        登录即表示同意
        <a href="#" class="text-primary-600 hover:underline">用户协议</a>
        和
        <a href="#" class="text-primary-600 hover:underline">隐私政策</a>
      </p>
    </div>
  </div>
</template>
