<template>
    <v-spacer class="align-self-center w-50">
        <h1>MMDVM Config [{{ section }}] section</h1>
        <form @submit.prevent="submit">
            <template v-for="item in config">
                <p>{{ item.key }}</p>
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
    data() {
        return {
            section: '',
            config: {}
        }
    },
    mounted() {
        fetch("http://localhost:8085/api/" + this.section)
            .then(response => response.json())
            .then(json => {
                this.config = json
            });
    },
    expose: ['navigate'],
    methods: {
        navigate(section) {
            this.section = section
            fetch("http://localhost:8085/api/" + section)
                .then(response => response.json())
                .then(json => {
                    this.config = json
                });
        },
        async update() {
            const response = await fetch("http://localhost:8085/api/" + this.section, {
                method: "PUT",
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify(this.config)
            });
            const result = await response.json();
            console.log("Success:", result);
        }
    }
}

</script>