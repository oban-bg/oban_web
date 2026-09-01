const HistoryBack = {
  mounted() {
    this.el.addEventListener("click", (event) => {
      event.preventDefault();

      this.goBack();
    });

    if (this.el.dataset.escapeBack !== undefined) {
      this.handleKeydown = (event) => {
        if (event.key === "Escape" && !this.withinField(event.target)) {
          this.goBack();
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

  goBack() {
    const message = this.el.dataset.confirmBack;

    if (!message || window.confirm(message)) {
      window.history.back();
    }
  },

  withinField(target) {
    return target instanceof Element && target.closest("input, select, textarea") !== null;
  },
};

export default HistoryBack;
