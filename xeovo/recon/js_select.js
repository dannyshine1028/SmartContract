function choicesAddSeparator(dropdown) {
  const separator = document.createElement("div");
  separator.classList.add("horizontal-separator");
  dropdown.prepend(separator);
}

document.querySelectorAll("select.searchable").forEach((select) => {
  new Choices(select, {
    position: "bottom",
    searchPlaceholderValue: "Search",
    itemSelectText: null,
  });
  const input = document.querySelector(".choices input.choices__input");
  const parent = input.parentElement;
  parent.removeChild(input);
  const wrapper = document.createElement("div");
  wrapper.classList.add("search-wrapper");
  wrapper.appendChild(input);
  const separator = document.createElement("div");
  separator.classList.add("horizontal-separator");
  parent.prepend(wrapper);
  parent.prepend(separator);
});

document.querySelectorAll("select.no-search").forEach((select) => {
  new Choices(select, {
    position: "bottom",
    itemSelectText: null,
    searchEnabled: false,
    shouldSort: false,
    classNames: {
      containerOuter: ["choices", "no-search"],
    },
  });
});

document
  .querySelectorAll(".choices.no-search .choices__list--dropdown")
  .forEach(choicesAddSeparator);
