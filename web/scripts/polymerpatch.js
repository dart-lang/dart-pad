/* Patch to work around a polymer polyfill issue. */

// Patch key event listening.
document.addEventListener('keydown', function(event) {
  if (window.dartKeyListener) {
    if (window.dartKeyListener(event)) {
      event.preventDefault();
    }
  }
});

// Patch window message listening.
window.addEventListener('message', function(event) {
  var data = event.data;

  if (data.sender == 'frame') {
    if (window.dartMessageListener) {
      window.dartMessageListener(data);
    }
  }
});
