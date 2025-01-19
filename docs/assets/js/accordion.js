// accordion.js

document.addEventListener('DOMContentLoaded', function () {
  const detailsElements = document.querySelectorAll('.accordion details');

  detailsElements.forEach((details) => {
    details.addEventListener('toggle', function () {
      if (details.open) {
        detailsElements.forEach((el) => {
          if (el !== details) {
            el.open = false;
          }
        });
      }
    });
  });
});
