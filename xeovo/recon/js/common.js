const STATUS_API_URL = "https://status.xeovo.com/status.json";
const navbarWrapper = document.getElementById("navbar-wrapper");
const toggleButtons = document.querySelectorAll("#navbar .toggle-button");
const clickDropDowns = [...document.querySelectorAll(".drop-down.clickable")];
const currencyInputs = document.querySelectorAll(
  '.currency input[name="currency"]',
);
const currencySymbols = document.querySelectorAll("span.currency-symbol");

function updateCurrency(input) {
  currencySymbols.forEach((e) => {
    e.textContent = input.value;
  });
  const rate = input.dataset.rate ? parseFloat(input.dataset.rate) : 1;
  document.querySelectorAll("span.amount").forEach((span) => {
    span.textContent = (span.dataset.eurAmount * rate).toFixed(2);
  });
}

if (currencyInputs.length > 0) {
  updateCurrency(document.querySelector('input[name="currency"]:checked'));

  currencyInputs.forEach((input) => {
    input.addEventListener("change", (e) => {
      updateCurrency(e.target);
    });
  });
}

function makeCopyable(element, text_) {
  element.addEventListener("click", () => {
    let text = text_;
    if (typeof text === "function") {
      text = text();
    }
    if (navigator.clipboard) {
      navigator.clipboard.writeText(text);
    } else {
      if (document.body.createTextRange) {
        const range = document.body.createTextRange();
        range.moveToElement(element);
        range.select();
      } else if (window.getSelection) {
        selection = window.getSelection();
        const range = document.createRange();
        range.selectNodeContents(element);
        selection.removeAllRanges();
        selection.addRange(range);
      }
      document.execCommand("copy");
      window.getSelection().removeAllRanges();
    }
  });
  element.addEventListener("copy", (e) => {
    let text = text_;
    if (typeof text === "function") {
      text = text();
    }
    e.preventDefault();
    e.clipboardData.setData("text/plain", text);
  });
}

function setupMessagesClose() {
  document.querySelectorAll(".server-messages .message").forEach((m) => {
    m.querySelector("input").addEventListener("click", () => {
      m.parentNode.removeChild(m);
    });
  });
}

toggleButtons.forEach((e) => {
  e.addEventListener("click", () => {
    navbarWrapper.classList.toggle("menu-open");
    toggleButtons.forEach((e) => {
      e.classList.toggle("active");
    });
  });
});

document.querySelectorAll(".drop-down").forEach((d) => {
  const content = d.querySelector(".content");
  d.addEventListener("click", (e) => {
    if (!content.contains(e.target)) {
      d.classList.toggle("expanded");
    }
  });
});

document.addEventListener("click", (e) => {
  const currentClickDropDown = clickDropDowns.find((d) => d.contains(e.target));
  clickDropDowns
    .filter((e) => !e.isSameNode(currentClickDropDown))
    .forEach((e) => {
      e.classList.remove("expanded");
    });
});

setupMessagesClose();

const serviceStatus = document.querySelectorAll(".service-status");
if (serviceStatus.length > 0) {
  const setStatus = (status) => {
    serviceStatus.forEach((e) => e.classList.add(status));
  };
  fetch(STATUS_API_URL)
    .then((response) => response.json())
    .then((json) => setStatus(json.overall_status))
    .catch((error) => {
      console.error(error);
      setStatus("major_outage");
    });
}

window.addEventListener('load', () => {
    const errorBlock = document.querySelector("#form-errors-json");
    if (!errorBlock) return;
    const errors = JSON.parse(errorBlock.innerHTML);
    for (let name in errors) {
        const errorMsg = document.createElement("p");
        errorMsg.classList.add("error");
        errorMsg.textContent = errors[name];
        let fieldName = name;
        if (name === "__all__") {
            if (errors[name][0].code === "invalid_login") {
                fieldName = "password";
                document.querySelector("input[name='password']").placeholder =
                    "Wrong Password";
            }
        }
        // try to find a field-wrapper div to add the message to
        if (fieldName.match(/^[a-z-]+/)) {
            const fieldWrapper = document.querySelector(".field-wrapper." + fieldName);
            if (fieldWrapper) {
                fieldWrapper.classList.add("error");
                fieldWrapper.appendChild(errorMsg);
                return;
            }
        }
        // otherwise just plop it between titles and form elements
        const form = document.querySelector("#form-errors-json").closest("form");
        const title = form.querySelector("h1, h2, h3, h4, h5, h6");
        if (title) {
            title.after(errorMsg);
        } else {
            form.prepend(errorMsg);
        }
    }
});
