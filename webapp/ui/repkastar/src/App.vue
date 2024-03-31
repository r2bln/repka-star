<script setup>
import { ref } from 'vue'

const editor = ref(null)

</script>

<template>
  <v-app>
    <v-navigation-drawer>
      <v-list-item title="Repka Star" subtitle="admin panel"></v-list-item>
      <v-divider></v-divider>
      <v-list-item link title="Info" @click="resetEditor('Info')"></v-list-item>
      <v-list-item link title="General" @click="resetEditor('General')"></v-list-item>
      <v-list-item link title="Modem" @click="resetEditor('Modem')"></v-list-item>
    </v-navigation-drawer>
    <ConfigEditor ref="editor"/>
  </v-app>
</template>

<script>

export default {
  methods: {
    resetEditor(loc) {
      this.$refs.editor.navigate(loc)
    }
  },
  mounted() {
    this.resetEditor("Info")
  }
}

</script>
