<script setup>

import { ref } from 'vue'
import { useField, useForm } from 'vee-validate'

const url = useField('url')
const title = 'MMDVM Admin panel'

</script>

<template>
    <h1>{{ title }}</h1>
    <form @submit.prevent="submit">
        <v-text-field v-model="config.URL" :counter="10" :error-messages="url.errorMessage.value"
            label="url"></v-text-field>

        <v-btn class="me-4" type="submit">
            submit
        </v-btn>

        <v-btn @click="handleReset">
            clear
        </v-btn>

        <v-btn @click="setUrl">
            set url
        </v-btn>
    </form>
</template>

<script>

export default {
    name: "AdminPanel",
    data() {
        return {
            title: "MMDVM Admin Panel VUE",
            config: { }
        }
    },
    mounted() {
        fetch("http://localhost:8085/api/Info")
            .then(response => response.json())
            .then(json => {
                this.config = json
            });
    },
    methods: {
      setUrl () {
        this.config.URL = 'http://some-other-url.ru'
      }
    }
}

</script>