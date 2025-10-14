const HistoryBack = {
  mounted() {
    this.el.addEventListener("click", (event) => {
      event.preventDefault();

      window.history.back();
    });
  },
};

export default HistoryBack;
