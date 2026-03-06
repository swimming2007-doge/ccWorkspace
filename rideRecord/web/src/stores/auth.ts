import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import api from '@/lib/api'

export interface User {
  id: string
  nickname: string
  avatar?: string
  email?: string
  createdAt: string
}

export const useAuthStore = defineStore('auth', () => {
  const user = ref<User | null>(null)
  const token = ref<string | null>(localStorage.getItem('token'))
  const loading = ref(false)

  const isAuthenticated = computed(() => !!token.value)

  async function login(code: string): Promise<void> {
    loading.value = true
    try {
      const response = await api.post<{
        accessToken: string
        refreshToken: string
        user: User
      }>('/auth/login', { code })

      token.value = response.accessToken
      user.value = response.user
      localStorage.setItem('token', response.accessToken)
    } finally {
      loading.value = false
    }
  }

  async function loginAsGuest(): Promise<void> {
    loading.value = true
    try {
      const response = await api.post<{
        accessToken: string
        user: User
      }>('/auth/guest')

      token.value = response.accessToken
      user.value = response.user
      localStorage.setItem('token', response.accessToken)
    } finally {
      loading.value = false
    }
  }

  async function fetchUser(): Promise<void> {
    if (!token.value) return

    loading.value = true
    try {
      user.value = await api.get<User>('/auth/me')
    } catch {
      logout()
    } finally {
      loading.value = false
    }
  }

  function logout(): void {
    user.value = null
    token.value = null
    localStorage.removeItem('token')
  }

  return {
    user,
    token,
    loading,
    isAuthenticated,
    login,
    loginAsGuest,
    fetchUser,
    logout
  }
})
