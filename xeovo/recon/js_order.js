const plans = JSON.parse(document.getElementById("order-plans").innerHTML);
const cash = document.getElementById("cash");
const couponInput = document.querySelector("#coupon input");
const couponButton = document.querySelector("#coupon button");
const orderSubTotal = document.getElementById("order-subtotal");
const orderDiscount = document.getElementById("order-discount");
const orderTotal = document.getElementById("order-total");

let couponData = null;

function updateSummary() {
  const plan = plans[document.querySelector("input[name=plan]:checked").value];
  const total = plan.total;
  orderSubTotal.textContent = `${total} EUR`;

  if (couponData === null) {
    orderDiscount.textContent = "0%";
    orderTotal.textContent = `${total} EUR`;
  } else {
    orderDiscount.textContent = `${couponData.value}%`;
    orderTotal.textContent = `${(total - total * (couponData.value / 100)).toFixed(2)} EUR`;
  }
}

function updateCash() {
  cash.disabled =
    document.querySelector("input[name=plan]:checked").value !== "12m";
  if (cash.disabled) {
    cash.checked = false;
  }
}

function updateCouponBox() {
  const recurring =
    document.querySelector(
      "input[name=payment-method]:checked + label input[name=recurring]:checked",
    ) !== null;
  couponInput.disabled = recurring || cash.checked;
  if (couponInput.disabled) {
    couponInput.value = "";
    couponButton.disabled = true;
    couponData = null;
  }
}

function onRecurringChange() {
  updateCouponBox();
  updateSummary();
}

document.querySelectorAll("input[name=plan]").forEach((e) => {
  e.addEventListener("change", () => {
    updateSummary();
    updateCash();
  });
});

cash.addEventListener("change", () => {
  updateCouponBox();
});

document.querySelectorAll("input[name=recurring]").forEach((e) => {
  e.addEventListener("change", onRecurringChange);
});
document.querySelectorAll("input[name=payment-method]").forEach((e) => {
  e.addEventListener("change", onRecurringChange);
});

couponInput.addEventListener("input", () => {
  couponButton.disabled = couponInput.value.length === 0;
});

couponButton.addEventListener("click", () => {
  const code = couponInput.value;
  const plan = document.querySelector("input[name=plan]:checked").value;

  const url = new URL(window.location.origin);
  url.username = "";
  url.password = "";
  url.pathname = "/api/couponcheck";
  url.search = new URLSearchParams({
    code: code,
    plan: plan,
  });
  fetch(url.toString()).then((response) => {
    if (response.ok) {
      response.json().then((data) => {
        if (data.error) {
          createAlert(data.error);
          return;
        }
        couponData = data;
        createAlert(`Applied coupon for -${data.value}%`, (error = false));
        updateSummary();
      });
    } else {
      createAlert(
        "We couldn't find that coupon. Make sure the code is correct.",
      );
    }
  });
});

document.getElementById("order-form").addEventListener("submit", () => {
  if (couponData === null) {
    couponInput.value = "";
  }
});

updateSummary();
updateCash();
updateCouponBox();
