<script setup>
const props = defineProps(['location'])
console.log(props.location)
</script>

<template>
    <v-spacer class="align-self-center w-50">
        <h1>MMDVM Config [{{ location }}] section</h1>
        <form @submit.prevent="submit">
            <template v-for="item in config">
                <p>{{item.key}}</p>
                <v-text-field v-model=item.value></v-text-field>
            </template>

            <v-btn @click="update">
                update
            </v-btn>
        </form>
    </v-spacer>
</template>

<script>

export default {
    name: "ConfigEditor",
    props: ["location"],
    setup(props) {
        console.log(props.location)
    },
    data() {
        return {
            config: {}
        }
    },
    mounted() {
        fetch("http://localhost:8085/api/" + this.location)
            .then(response => response.json())
            .then(json => {
                this.config = json
            });
    },
    expose: ['navigate'],
    methods: {
        navigate(location) {
            fetch("http://localhost:8085/api/" + location)
            .then(response => response.json())
            .then(json => {
                this.config = json
            });
        },
        update() {
            alert("push to backend")
        }
    }
}

</script>