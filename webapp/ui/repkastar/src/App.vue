<script setup>
import { ref } from 'vue'

const editor = ref(null)

</script>

<template>
  <v-app>
    <v-navigation-drawer>
      <v-list-item title="MMDVM Host" subtitle="config"></v-list-item>
      <v-divider></v-divider>
      <v-list-item link title="General" @click="resetEditor('General')"></v-list-item>
      <v-list-item link title="Info" @click="resetEditor('Info')"></v-list-item>
      <v-list-item link title="Modem" @click="resetEditor('Modem')"></v-list-item>
      <v-list-item link title="DMR" @click="resetEditor('DMR')"></v-list-item>
      <v-list-item link title="DMR Network" @click="resetEditor('DMR Network')"></v-list-item>
      <v-divider :thickness="10"></v-divider>
      <v-list-item title="DMRGateway" subtitle="config"></v-list-item>
      <v-divider></v-divider>
      <v-list-item link title="General" @click="resetEditor('General')"></v-list-item>
      <v-list-item link title="Info" @click="resetEditor('Info')"></v-list-item>
      <v-list-item link title="XLX Network" @click="resetEditor('XLX Network')"></v-list-item>
      <v-list-item link title="DMR Network 1" @click="resetEditor('DMR Network 1')"></v-list-item>
      <v-divider></v-divider>
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
