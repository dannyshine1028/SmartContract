function randomString(length) {
  const characters =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
  let result = "";
  for (let i = 0; i < length; i++) {
    result += characters.charAt(Math.floor(Math.random() * characters.length));
  }
  return result;
}

const usernameField = document.querySelector("input[name='username']");

document.getElementById("randomize").addEventListener("click", () => {
  usernameField.value = randomString(16);
});

// disable submit button on submit, to avoid duplicate requests
document.querySelector("main form").addEventListener('submit', () => {
  const button = document.querySelector("button[type=submit]");
  button.disabled = true;
  // re-enable it automatically after five seconds,
  // in case the request was cancelled and must be re-sent.
  setTimeout(() => {
    button.disabled = false;
  }, 5000);
});
