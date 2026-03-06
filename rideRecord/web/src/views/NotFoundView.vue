<script setup lang="ts">
import { RouterLink } from 'vue-router'
</script>

<template>
  <div class="min-h-[60vh] flex items-center justify-center">
    <div class="text-center">
      <div class="text-8xl mb-4">🚴</div>
      <h1 class="text-4xl font-bold text-gray-800 mb-2">404</h1>
      <p class="text-gray-500 mb-8">页面不存在或已被删除</p>
      <RouterLink
        to="/"
        class="inline-block px-6 py-3 bg-primary-600 text-white rounded-lg hover:bg-primary-700 transition-colors"
      >
        返回首页
      </RouterLink>
    </div>
  </div>
</template>
