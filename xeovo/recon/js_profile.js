document
  .getElementById("delete-account-button")
  .addEventListener("click", (e) => {
    if (
      !confirm(
        "Warning: this operation cannot be undone. Deleting your account will permanently remove data from our systems.",
      )
    ) {
      e.preventDefault();
    }
  });
