document.querySelectorAll("#colours .color .hover").forEach((hover) => {
  const colorCode = hover.querySelector(".code").textContent;
  makeCopyable(hover, colorCode);
});
