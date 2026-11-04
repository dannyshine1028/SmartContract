const form = document.querySelector("main form");
const clusterSelect = form.querySelector("select[name=cluster]");
const keys = form.querySelector(".keys");
let keysRadio;
const qrButton = form.querySelector("button.qrcode");
const dlButton = form.querySelector("button.download");
const csrfToken = document.querySelector("meta[name=x-csrf-token]").content;

function refreshKeysRadio() {
  keysRadio = [...form.querySelectorAll("input[name=id]")];
}

function apiRequest(path, params) {
  const url = new URL(window.location.origin);
  url.username = "";
  url.password = "";
  url.pathname = "/api/" + path;
  return fetch(url.toString(), {
    method: "POST",
    body: new URLSearchParams({
      csrfmiddlewaretoken: csrfToken,
      ...params,
    }),
  });
}

// create a new key if we need to, and add it to the table
async function wgPrepareKey() {
  const keyInput = form.querySelector("input[name=id]:checked");
  if (keyInput === null || keyInput.value !== "") {
    return;
  }
  const response = await apiRequest("createwgkey");
  if (!response.ok) {
    throw new Error(`Failed to create key: error ${response.status}`);
  }
  const data = await response.json();

  const tr = document.createElement("tr");
  const td1 = document.createElement("td");
  const input = document.createElement("input");
  input.type = "radio";
  input.name = "id";
  input.value = data.peer_id;
  input.id = "wg-key-" + data.peer_id;
  input.checked = true;
  td1.appendChild(input);
  const label = document.createElement("label");
  label.setAttribute("for", "wg-key-" + data.peer_id);
  label.innerText = data.name;
  td1.appendChild(label);
  tr.appendChild(td1);
  const td2 = document.createElement("td");
  td2.classList.add("name");
  const p = document.createElement("p");
  p.innerText = "unnamed";
  td2.appendChild(p);
  const edit = document.createElement("input");
  edit.classList.add("edit");
  edit.type = "image";
  edit.src = "/static/images/icon-edit.svg";
  td2.appendChild(edit);
  tr.appendChild(td2);
  const tdDelete = document.createElement("td");
  tdDelete.classList.add("delete");
  const deleteInput = document.createElement("input");
  deleteInput.type = "image";
  deleteInput.src = "/static/images/icon-delete.svg";
  tdDelete.appendChild(deleteInput);
  tr.appendChild(tdDelete);
  const genNew = keys.querySelector("tr.gen-new");
  genNew.parentElement.insertBefore(tr, genNew);
  refreshKeysRadio();
  wgSetupButtons(tr);
}

async function renameKey(peer_id, newName) {
  if (newName) {
    const response = await apiRequest("renamewgkey/" + peer_id, {
      name: newName,
    });
    if (response.ok) {
      return true;
    } else {
      throw new Error(`Failed to rename peer: error ${response.status}`);
    }
  }
  return false;
}

// setup actions buttons
function wgSetupButtons(tr) {
  const name = tr.querySelector("td.name");
  if (!name) return;
  const peer_id = tr.querySelector("input[name=id]").value;
  const edit = name.querySelector(".edit");
  edit.addEventListener("click", (e) => {
    e.preventDefault();
    const input = document.createElement("input");
    input.type = "text";
    input.placeholder = "Create new name";
    input.maxLength = 21;
    const p = name.querySelector("p");
    p.style.display = "none";
    edit.style.display = "none";
    name.appendChild(input);
    input.focus();
    const restoreUI = (success) => {
      input.remove();
      if (success) {
        p.childNodes[0].textContent = input.value;
      }
      p.style.removeProperty("display");
      edit.style.removeProperty("display");
    };
    input.addEventListener("keydown", async (e) => {
      if (e.key === "Enter") {
        e.preventDefault();
        renameKey(peer_id, input.value).then(restoreUI);
      }
    });
    input.addEventListener("blur", () =>
      renameKey(peer_id, input.value).then(restoreUI),
    );
  });
  tr.querySelector(".delete input").addEventListener("click", async (e) => {
    e.preventDefault();
    const response = await apiRequest("deletewgkey/" + peer_id);
    if (!response.ok) {
      throw new Error(`Failed to delete peer: error ${response.status}`);
    }
    tr.remove();
    refreshKeysRadio();
    onKeySelectionChange();
  });
}

function updateQrCodeButton() {
  qrButton.disabled =
    !keysRadio.some((e) => e.checked) || clusterSelect.value === "all";
}

function onKeySelectionChange() {
  dlButton.disabled = !keysRadio.some((e) => e.checked);
  updateQrCodeButton();
}

function displayTooltipContent(input) {
  const content = input.nextElementSibling;
  const rect = input.getBoundingClientRect();
  content.classList.remove("left");
  content.classList.remove("bottom");
  content.classList.add("visible");
  if (
    rect.right + content.getBoundingClientRect().width + 20 <
    window.innerWidth
  ) {
    content.classList.add("left");
    content.style.left = `${rect.right}px`;
    content.style.removeProperty("top");
  } else {
    content.classList.add("bottom");
    content.style.top = `${rect.bottom + window.scrollY}px`;
    const x = Math.min(
      rect.x + rect.width / 2 - content.clientWidth / 2,
      window.innerWidth - content.clientWidth,
    );
    content.style.left = `${x}px`;
  }
}

refreshKeysRadio();

document.querySelectorAll("input.tooltip").forEach((input) => {
  input.addEventListener("click", (e) => {
    e.preventDefault();
    displayTooltipContent(input);
  });
  if (window.innerWidth > 701) {
    input.addEventListener("mouseenter", () => displayTooltipContent(input));
  }
});

window.addEventListener("resize", () => {
  document.querySelectorAll("input.tooltip").forEach((input) => {
    if (input.nextElementSibling.classList.contains("visible")) {
      displayTooltipContent(input);
    }
  });
});

document.querySelectorAll(".tooltip-content .close").forEach((input) => {
  input.addEventListener("click", (e) => {
    e.preventDefault();
    input.parentElement.classList.remove("visible");
  });
});

qrButton.addEventListener("click", async (e) => {
  if (!form.checkValidity()) {
    return;
  }
  e.preventDefault();
  await wgPrepareKey();
  const url = new URL(form.action);
  url.username = "";
  url.password = "";
  url.search = new URLSearchParams(new FormData(form));
  const response = await fetch(url.toString());
  if (!response.ok) {
    throw new Error(`Failed to download config: error ${response.status}`);
  }
  const data = await response.text();
  const popup = document.querySelector("main .qr-popup");
  const img = popup.querySelector(".img");
  img.innerHTML = "";
  new QRCode(img, {
    text: data,
    correctLevel: QRCode.CorrectLevel.L,
    colorDark: "#000",
    colorLight: "#fff",
  });
  popup.classList.add("visible");
  popup.querySelector(".close").addEventListener("click", () => {
    popup.classList.remove("visible");
  });
});

clusterSelect.addEventListener("change", updateQrCodeButton);

keysRadio.forEach((e) => e.addEventListener("change", onKeySelectionChange));

keys.querySelectorAll("tr").forEach(wgSetupButtons);

dlButton.addEventListener("click", async (e) => {
  if (form.checkValidity()) {
    e.preventDefault();
    await wgPrepareKey();
    form.submit();
  }
});
