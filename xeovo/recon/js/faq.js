const ANIMATION_DURATION = 400;
const faq = document.querySelector("main .faq");
const faqFullHeight = faq.scrollHeight;
const questions = faq.querySelectorAll(".drop-down");
const collapsibleQuestions = faq.querySelectorAll(
  ".collapse-limit, .collapse-limit ~ .drop-down",
);

function hideCollapsibleQuestions() {
  collapsibleQuestions.forEach((question) => {
    question.style.display = "none";
  });
}

function showCollapsibleQuestions() {
  collapsibleQuestions.forEach((question) => {
    question.style.display = "block";
  });
}

function animateHeight(element, endHeight, duration, then = null) {
  const startHeight = element.clientHeight;
  let startTime = null;
  function animationStep(timestamp) {
    if (!startTime) startTime = timestamp;
    const progress = Math.min((timestamp - startTime) / duration, 1);
    const newHeight = startHeight + progress * (endHeight - startHeight);
    element.style.height = `${newHeight}px`;
    if (progress < 1) {
      requestAnimationFrame(animationStep);
    } else {
      element.style.height = "auto";
      then?.();
    }
  }
  requestAnimationFrame(animationStep);
}

hideCollapsibleQuestions();

document.getElementById("search").addEventListener("input", (e) => {
  const search = e.target.value.toLowerCase();
  questions.forEach((question) => {
    if (question.innerText.toLowerCase().includes(search)) {
      question.style.display = "block";
    } else {
      question.style.display = "none";
    }
  });
});

document.getElementById("see-more").addEventListener("click", () => {
  faq.classList.toggle("expanded");
  if (faq.classList.contains("expanded")) {
    faq.style.height = `${faq.clientHeight}px`;
    showCollapsibleQuestions();
    animateHeight(faq, faqFullHeight, ANIMATION_DURATION);
  } else {
    const foldedHeight =
      faq.querySelector(".collapse-limit").offsetTop - faq.offsetTop;
    animateHeight(
      faq,
      foldedHeight,
      ANIMATION_DURATION,
      hideCollapsibleQuestions,
    );
  }
});
