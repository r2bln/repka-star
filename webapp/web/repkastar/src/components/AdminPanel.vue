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
        fetch("http://localhost:8085/api/General")
            .then(response => response.json())
            .then(json => {
                this.config = json
            });
    }
}

</script>

<template>
    <h1>{{ title }}</h1>
    <h3>Props:</h3>
    <div v-for="(value, key) in config" :key="key">
        {{ key }}: {{ value }}
    </div>
</template>