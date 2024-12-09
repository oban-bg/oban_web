import { load, store } from "../lib/settings"

const Instantiator = {
  mounted() {
    this.handleEvent("select-instance", ({ name }) => {
      store("instance", name)
    })
  },
}

export default Instantiator
