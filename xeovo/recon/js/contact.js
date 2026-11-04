function onLoad() {
  document.querySelector(".captcha input").addEventListener("change", () => {
    hcaptcha.execute();
  });
}
