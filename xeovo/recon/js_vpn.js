const dnsRadios = document.querySelectorAll("main form input[name=dns]");
const customDns = document.querySelector("main form input[name=custom_dns]");

dnsRadios.forEach((radio) => {
  radio.addEventListener("change", () => {
    if (radio.checked) {
      customDns.value = "";
    }
  });
});

customDns.addEventListener("input", () => {
  dnsRadios.forEach((radio) => (radio.checked = false));
});
