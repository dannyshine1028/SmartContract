document.querySelectorAll(".tabs").forEach((tabs) => {
  const titles = tabs.querySelectorAll(".titles>*");
  const contents = tabs.querySelectorAll(".contents>*");
  titles.forEach((title, i) => {
    title.addEventListener("click", () => {
      titles.forEach((title) => title.classList.remove("active"));
      contents.forEach((content) => content.classList.remove("active"));
      title.classList.add("active");
      contents[i].classList.add("active");
    });
  });
});
