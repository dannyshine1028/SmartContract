const domainSwitch = document.querySelector(".domain-switch select");
if (domainSwitch) {
  new Choices(domainSwitch, {
    position: "bottom",
    itemSelectText: null,
    searchEnabled: false,
    shouldSort: false,
    callbackOnCreateTemplates: function (
      template,
      escapeForTemplate,
      getClassNames,
    ) {
      return {
        choice: (classNames, data) => {
          let status = "";
          switch (data.element.dataset.available) {
            case "0":
              status = `<span class="status partial">partially blocked</span>`;
              break;
            case "1":
              status = `<span class="status blocked">mostly blocked</span>`;
              break;
            case "2":
              status = `<span class="status available">mostly available</span>`;
              break;
          }
          return template(`<div
            class="domain
              ${getClassNames(classNames.item).join(" ")}
              ${getClassNames(classNames.itemChoice).join(" ")}
              ${getClassNames(data.disabled ? classNames.itemDisabled : classNames.itemSelectable).join(" ")}"
            data-select-text="${this.config.itemSelectText}" data-choice
            ${data.disabled ? 'data-choice-disabled aria-disabled="true"' : "data-choice-selectable"}
            data-id="${data.id}" data-value="${escapeForTemplate(data.value)}"
            ${data.groupId > 0 ? 'role="treeitem"' : 'role="option"'}>
            <span class="name">${data.label}</span>
            ${status}
          </div>
        `);
        },
      };
    },
  });
  choicesAddSeparator(
    document.querySelector(".domain-switch .choices__list--dropdown"),
  );
  domainSwitch.addEventListener("choice", () => {
    const search = new URLSearchParams(window.location.search);
    search.set("domain", domainSwitch.querySelector("option:checked").value);
    window.location.search = search;
  });
}

document.querySelectorAll(".platforms select").forEach((platformSwitch) => {
  const update = () => {
    const option = platformSwitch.querySelector("option:checked");
    console.log(option);
    if (option !== null && option) {
      const dlUrl = option.dataset.dlUrl;
      const subUrl = option.dataset.subUrl;

      const dlLink = document.querySelector("#" + platformSwitch.id + "-dl-url");
      const subLink = document.querySelector("#" + platformSwitch.id + "-sub-url");
      dlLink.href = dlUrl;
      subLink.href = subUrl;
    }
  };
  platformSwitch.addEventListener("choice", update);
  update();
});

document.querySelectorAll(".platforms a.config").forEach((link) => {
  makeCopyable(link, () => link.href);
  link.addEventListener("click", (e) => {
    e.preventDefault();
    createAlert("Link copied to clipboard", false);
  });
});

function formatTimeDelta(td) {
  if (td < 0) return "0 seconds";
  td /= 1000; // work on seconds
  if (td > 3600) return Math.round(td / 3600) + " hours";
  if (td > 60) return Math.round(td / 60) + " minutes";
  return Math.round(td) + " seconds";
}

document.querySelectorAll("span.countdown").forEach((countdownElement) => {
  const update = () => {
    const date = new Date(parseFloat(countdownElement.dataset.date) * 1000);
    const now = new Date();
    countdownElement.innerText = formatTimeDelta(date - now);
  };
  setInterval(update, 1000);
  update();
});
