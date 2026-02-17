const HistoryBack = {
  mounted() {
    this.el.addEventListener("click", (event) => {
      event.preventDefault();

      window.history.back();
    });

    if (this.el.dataset.escapeBack !== undefined) {
      this.handleKeydown = (event) => {
        if (event.key === "Escape") {
          window.history.back();
        }
      };

      window.addEventListener("keydown", this.handleKeydown);
    }
  },

  destroyed() {
    if (this.handleKeydown) {
      window.removeEventListener("keydown", this.handleKeydown);
    }
  },
};

export default HistoryBack;
