const events = [...document.querySelectorAll("#timeline .events>div")];
const dotsContainer = document.querySelector("#timeline .dots");
const dots = document.querySelectorAll("#timeline .dot");
const dotWidth = dots[1].clientWidth;

let eventIndex = 0;

function toggleActive() {
  dots[eventIndex].classList.toggle("active");
  events[eventIndex].classList.toggle("active");
  document
    .querySelector(
      ".years [data-year='" +
        events[eventIndex].getAttribute("data-year") +
        "']",
    )
    .classList.toggle("active");
}

function setEventIndex(index) {
  toggleActive();
  eventIndex = index;
  toggleActive();
  dotsContainer.scrollTo({
    left: -dotWidth * eventIndex,
    behavior: "smooth",
  });
}

document
  .querySelector("#timeline button.left")
  .addEventListener("click", () => {
    if (eventIndex < events.length - 1) {
      setEventIndex(eventIndex + 1);
    }
  });

document
  .querySelector("#timeline button.right")
  .addEventListener("click", () => {
    if (eventIndex > 0) {
      setEventIndex(eventIndex - 1);
    }
  });

for (let i = 0; i < dots.length; ++i) {
  dots[i].addEventListener("click", () => {
    setEventIndex(i);
  });
}

document.querySelectorAll(".years>p").forEach((e) => {
  e.addEventListener("click", () => {
    const year = e.getAttribute("data-year");
    const yearEvents = document.querySelectorAll(
      ".events div[data-year='" + year + "']",
    );
    setEventIndex(events.indexOf(yearEvents[yearEvents.length - 1]));
  });
});
