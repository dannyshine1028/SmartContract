const sideMenuWrapper = document.getElementById("side-menu-wrapper");
const serverMessages = document.querySelector(".server-messages");

function getCookie(key) {
  return document.cookie
    .split("; ")
    .find((row) => row.startsWith(key + "="))
    ?.split("=")[1];
}

function setCookie(key, value) {
  var date = new Date();
  date.setTime(date.getTime() + 10 * 365 * 24 * 60 * 60 * 1000);
  var expires = "; expires=" + date.toUTCString();
  document.cookie = key + "=" + value + expires + "; path=/;"; // secure";
}

function hashCode(str) {
  let hash = 0;
  for (let i = 0, len = str.length; i < len; i++) {
    let chr = str.charCodeAt(i);
    hash = (hash << 5) - hash + chr;
    hash |= 0; // Convert to 32bit integer
  }
  return hash;
}

function addFileInput() {
  const input = document.createElement("input");
  input.type = "file";
  input.name = "files";
  input.multiple = true;
  const attachedFile = document.getElementById("attached-file");
  attachedFile.innerHTML = "";
  attachedFile.appendChild(input);
  return input;
}

function createAlert(message, error = true) {
  const div = document.createElement("div");
  div.classList.add("message");
  if (error) {
    div.classList.add("error");
  }
  const p = document.createElement("p");
  p.textContent = message;
  div.appendChild(p);
  const closeButton = document.createElement("input");
  closeButton.type = "image";
  closeButton.src = "/static/images/icon-close.svg";
  closeButton.classList.add("close-icon-button");
  div.appendChild(closeButton);
  serverMessages.appendChild(div);
  setupMessagesClose();
}

document.querySelectorAll(".notice").forEach((notice) => {
  const cookieName = "notice-closed";
  const cookieValue = hashCode(notice.innerText).toString();
  if (getCookie(cookieName) == cookieValue) {
    return;
  }
  notice.style.display = "flex";
  notice.querySelector("input").addEventListener("click", () => {
    notice.style.display = "none";
    setCookie(cookieName, cookieValue);
  });
});

document
  .querySelector(".form-submit-button.upload")
  ?.addEventListener("click", (e) => {
    e.preventDefault();
    addFileInput().click();
  });
