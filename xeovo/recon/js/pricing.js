const title = document.getElementById("plan-price");

const durations = document.querySelectorAll("#plan-details .plan .duration");
const discounts = document.querySelectorAll("#plan-details .plan .discount");

let duration = parseInt(
  document.querySelector('input[name="duration"]:checked').value,
);

const currencySelector = document.getElementById("currency-selector");
currencySelector.addEventListener("change", () => {
  updateCurrency(currencySelector.options[currencySelector.selectedIndex]);
});

function refreshDuration() {
  switch (duration) {
    case 1:
      durations[0].style.display = "inline";
      durations[1].style.display = "none";
      durations[2].style.display = "none";
      discounts[0].style.display = "none";
      discounts[1].style.display = "none";
      break;
    case 6:
      durations[0].style.display = "none";
      durations[1].style.display = "inline";
      durations[2].style.display = "none";
      discounts[0].style.display = "block";
      discounts[1].style.display = "none";
      break;
    case 12:
      durations[0].style.display = "none";
      durations[1].style.display = "none";
      durations[2].style.display = "inline";
      discounts[0].style.display = "none";
      discounts[1].style.display = "block";
      break;
  }
}

refreshDuration();

document.querySelectorAll('input[name="duration"]').forEach((input) => {
  input.addEventListener("change", (e) => {
    duration = parseInt(e.target.value);
    refreshDuration();
  });
});
