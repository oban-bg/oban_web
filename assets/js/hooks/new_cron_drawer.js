const NewCronDrawer = {
  mounted() {
    const bg = document.getElementById("new-cron-bg")
    const panel = document.getElementById("new-cron-panel")

    // Add transition classes
    bg.classList.add("transition-opacity", "duration-300", "ease-out")
    panel.classList.add("transition-transform", "duration-300", "ease-out")

    // Start off-screen and transparent
    bg.style.opacity = "0"
    panel.style.transform = "translateX(100%)"

    // Animate in on next frame
    requestAnimationFrame(() => {
      requestAnimationFrame(() => {
        bg.style.opacity = "1"
        panel.style.transform = "translateX(0)"
      })
    })

    // Prevent body scroll
    document.body.classList.add("overflow-hidden")
  },

  destroyed() {
    document.body.classList.remove("overflow-hidden")
  }
}

export default NewCronDrawer
